/**
 * Gera o índice do catálogo (public/index/tcgdex-pt.json): baixa a imagem de
 * cada carta da TCGdex, calcula o descritor com o MESMO código do browser e
 * serializa compacto. Roda uma vez (e de novo quando sair set novo).
 *
 *   npm run index:build -- --series sv,me          # séries (padrão)
 *   npm run index:build -- --sets sv08.5,me01      # sets específicos
 *   npm run index:build -- --all                    # catálogo PT inteiro (~17k, demora)
 *   opções: --lang pt  --out public/index/tcgdex-pt.json  --concurrency 12
 */
import sharp from 'sharp';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fetchSets, fetchSetCards, fetchSeriesSetIds } from '../src/vision/tcgdex.js';
import { describe, packHashes, CARD_W, CARD_H } from '../src/vision/descriptor.js';
import type { IndexJSON, IndexSet, IndexCard } from '../src/vision/catalog.js';

export const IMAGE_CACHE = join(
  '/private/tmp/claude-501/-Users-felipelima-work-tcg/c0526f15-27a7-4577-907a-724b2fba15da/scratchpad',
  'tcgdex-cache',
);

function arg(name: string, def?: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : def;
}

/** Baixa (com cache) a imagem da carta. `low` (~245px) pro índice; `high` (~600px) pra simular câmera. */
export async function fetchCardImage(card: IndexCard, size: 'low' | 'high' = 'low'): Promise<Buffer | null> {
  await mkdir(IMAGE_CACHE, { recursive: true });
  const p = join(IMAGE_CACHE, size === 'low' ? `${card.id}.webp` : `${card.id}.high.webp`);
  if (existsSync(p)) return readFile(p);
  for (let attempt = 0; attempt < 4; attempt++) {
    try {
      const res = await fetch(`${card.image}/${size}.webp`);
      if (res.status === 404) return null;
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const b = Buffer.from(await res.arrayBuffer());
      await writeFile(p, b);
      return b;
    } catch {
      await new Promise((r) => setTimeout(r, 500 * (attempt + 1)));
    }
  }
  return null;
}

/** Decodifica pra RGBA w×h. */
export async function toRGBA(buf: Buffer, w: number, h: number) {
  const data = await sharp(buf).ensureAlpha().resize(w, h, { fit: 'fill' }).raw().toBuffer();
  return { data: new Uint8ClampedArray(data.buffer, data.byteOffset, w * h * 4), width: w, height: h };
}

/** RGBA canônico — o mesmo tamanho que a câmera retificada produz pro hash. */
export const toCanonicalRGBA = (buf: Buffer) => toRGBA(buf, CARD_W, CARD_H);

async function pool<T, R>(items: T[], limit: number, fn: (t: T, i: number) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let i = 0;
  await Promise.all(Array.from({ length: limit }, async () => {
    while (i < items.length) { const k = i++; out[k] = await fn(items[k], k); }
  }));
  return out;
}

async function main() {
  const lang = arg('lang', 'pt')!;
  const out = arg('out', 'public/index/tcgdex-pt.json')!;
  const conc = Number(arg('concurrency', '12'));

  let setIds: string[];
  if (process.argv.includes('--all')) setIds = (await fetchSets(lang)).map((s) => s.id);
  else if (arg('sets')) setIds = arg('sets')!.split(',');
  else {
    const series = (arg('series', 'sv,me')!).split(',');
    setIds = (await Promise.all(series.map((s) => fetchSeriesSetIds(s, lang)))).flat();
  }
  console.log(`Sets (${setIds.length}): ${setIds.join(', ')}`);

  const sets: IndexSet[] = [];
  const cards: IndexJSON['cards'] = [];
  let skipped = 0;
  const t0 = Date.now();
  for (const setId of setIds) {
    let fetched;
    try { fetched = await fetchSetCards(setId, lang); } catch (e) { console.log(`  ${setId}: FALHOU ${String(e)}`); continue; }
    const rows = await pool(fetched.cards, conc, async (c) => {
      const buf = await fetchCardImage(c);
      if (!buf) return null;
      try {
        const d = describe(await toCanonicalRGBA(buf));
        return { ...c, d: packHashes(d), c: Array.from(d.color) };
      } catch { return null; }
    });
    const ok = rows.filter((r): r is NonNullable<typeof r> => !!r);
    skipped += rows.length - ok.length;
    cards.push(...ok);
    sets.push({ ...fetched.set, count: ok.length });
    console.log(`  ${setId} "${fetched.set.name}": ${ok.length} cartas  (${((Date.now() - t0) / 1000).toFixed(0)}s)`);
  }

  const json: IndexJSON = { v: 1, source: `tcgdex-${lang}`, builtAt: new Date().toISOString(), sets, cards };
  await mkdir(dirname(out), { recursive: true });
  const text = JSON.stringify(json);
  await writeFile(out, text);
  console.log(`\nÍndice: ${cards.length} cartas em ${sets.length} sets → ${out} (${(text.length / 1024).toFixed(0)} KB). Sem imagem: ${skipped}.`);
}

// só roda como script (o e2e importa os helpers)
if (process.argv[1]?.endsWith('build-index.ts')) {
  main().catch((e) => { console.error('Erro:', e); process.exitCode = 1; });
}
