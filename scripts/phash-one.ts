/**
 * Teste de art-matching pra UMA carta específica do catálogo.
 * Baixa a imagem de referência, degrada (simula foto) e casa por pHash
 * contra um pool multi-set — reportando top-5, dentro-do-set vs global.
 *
 * Rodar:  tsx scripts/phash-one.ts <cardId>   (ex: sv8pt5-75)
 */
import sharp from 'sharp';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { fetchSetCards } from '../src/matching/pokemontcg.js';
import { phashFromGray32, hamming, PHASH_INPUT_SIZE } from '../src/scanner/phash.js';
import type { CardRecord } from '../src/matching/types.js';

const POOL = ['base1', 'base2', 'gym1', 'neo1', 'ex1', 'dp1', 'hgss1', 'bw1', 'xy1', 'sm1', 'swsh1', 'sv1'];
const CACHE = join(
  '/private/tmp/claude-501/-Users-felipelima-work-tcg/c0526f15-27a7-4577-907a-724b2fba15da/scratchpad',
  'phash-cache',
);

async function sharpToGray(buf: Buffer): Promise<Uint8Array> {
  const n = PHASH_INPUT_SIZE;
  const data = await sharp(buf).grayscale().resize(n, n, { fit: 'fill' }).raw().toBuffer();
  return new Uint8Array(data.buffer, data.byteOffset, n * n);
}
async function degrade(buf: Buffer): Promise<Uint8Array> {
  const jpeg = await sharp(buf).rotate(3, { background: '#888' }).modulate({ brightness: 1.12 }).blur(1.1).jpeg({ quality: 55 }).toBuffer();
  return sharpToGray(jpeg);
}
async function bufOf(card: CardRecord): Promise<Buffer | null> {
  if (!card.imageSmall) return null;
  await mkdir(CACHE, { recursive: true });
  const raw = join(CACHE, `${card.id}.img`);
  if (existsSync(raw)) return readFile(raw);
  const res = await fetch(card.imageSmall);
  if (!res.ok) return null;
  const b = Buffer.from(await res.arrayBuffer());
  await writeFile(raw, b);
  return b;
}
async function pool<T, R>(items: T[], limit: number, fn: (t: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let i = 0;
  await Promise.all(Array.from({ length: limit }, async () => { while (i < items.length) { const k = i++; out[k] = await fn(items[k]); } }));
  return out;
}

async function main() {
  const queryId = process.argv[2];
  if (!queryId) throw new Error('uso: tsx scripts/phash-one.ts <cardId>');
  const querySet = queryId.slice(0, queryId.lastIndexOf('-'));

  const setIds = Array.from(new Set([...POOL, querySet]));
  console.log(`Pool: ${setIds.join(', ')}\n`);
  const all: CardRecord[] = [];
  for (const s of setIds) {
    try { all.push(...(await fetchSetCards(s))); } catch (e) { console.log(`  ${s}: falhou`); }
  }

  const entries: { c: CardRecord; hash: bigint }[] = [];
  const bufs = await pool(all, 16, async (c) => ({ c, b: await bufOf(c) }));
  for (const { c, b } of bufs) if (b) entries.push({ c, hash: phashFromGray32(await sharpToGray(b)) });
  console.log(`Índice: ${entries.length} cartas.\n`);

  const q = entries.find((e) => e.c.id === queryId);
  if (!q) throw new Error(`carta ${queryId} não encontrada no pool`);
  const buf = (await bufOf(q.c))!;

  for (const [label, gray] of [['LIMPO (referência)', await sharpToGray(buf)], ['DEGRADADO (simula foto)', await degrade(buf)]] as const) {
    const qh = phashFromGray32(gray);
    const ranked = entries.map((e) => ({ id: e.c.id, name: e.c.name, set: e.c.setId, d: hamming(qh, e.hash) })).sort((a, b) => a.d - b.d);
    const inSet = ranked.filter((r) => r.set === querySet);
    console.log(`== ${label} ==`);
    console.log(`  top-5 GLOBAL (${entries.length} cartas):`);
    for (const r of ranked.slice(0, 5)) console.log(`    ${r.d === ranked[0].d && r.id === queryId ? '★' : ' '} ${r.d} bits | ${r.id} "${r.name}"`);
    const g1 = ranked[0].id === queryId, s1 = inSet[0].id === queryId;
    console.log(`  rank-1 global: ${g1 ? 'ACERTOU' : 'ERROU (' + ranked[0].id + ')'} | rank-1 no set: ${s1 ? 'ACERTOU' : 'ERROU'}`);
    console.log(`  margem sobre 2º: ${ranked[1].d - ranked[0].d} bits\n`);
  }
}
main().catch((e) => { console.error('Erro:', e); process.exitCode = 1; });
