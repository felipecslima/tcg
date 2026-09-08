/**
 * Teste de DISCRIMINAÇÃO do art-matching por pHash contra dados reais da
 * pokemontcg.io. Responde à pergunta: dá pra identificar a carta SEM escolher
 * o set (busca global), ou o espaço grande gera falso-positivo demais?
 *
 * Mede duas coisas:
 *   A) SEPARAÇÃO (teto otimista, imagem limpa): pra cada carta, distância de
 *      Hamming até a carta MAIS PARECIDA (vizinho mais próximo). Se cartas
 *      diferentes ficam longe, o hash discrimina; se ficam perto, colide.
 *      Compara vizinho dentro-do-set vs no catálogo global.
 *   B) ROBUSTEZ (simula foto): degrada a imagem de referência (rotação, blur,
 *      brilho, recompressão) e testa se o pHash degradado ainda casa a carta
 *      certa em 1º lugar — dentro-do-set vs global — e com que margem.
 *
 * Rodar:  npm run phash:validate
 * Cache das imagens em scratchpad pra reruns rápidos.
 */
import sharp from 'sharp';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { fetchSetCards } from '../src/matching/pokemontcg.js';
import { phashFromGray32, hamming, PHASH_INPUT_SIZE } from '../src/scanner/phash.js';
import type { CardRecord } from '../src/matching/types.js';

// Mix de eras: borda limpa clássica + moderno holo/full-art (o caso difícil).
const SETS = ['base1', 'base2', 'gym1', 'neo1', 'ex1', 'dp1', 'hgss1', 'bw1', 'xy1', 'sm1', 'swsh1', 'sv1'];

const CACHE = join(
  '/private/tmp/claude-501/-Users-felipelima-work-tcg/c0526f15-27a7-4577-907a-724b2fba15da/scratchpad',
  'phash-cache',
);

interface Entry {
  id: string;
  setId: string;
  name: string;
  hash: bigint;
}

/** Baixa (com cache) e devolve os pixels em cinza 32x32 da imagem da carta. */
async function grayOf(card: CardRecord): Promise<Uint8Array | null> {
  if (!card.imageSmall) return null;
  await mkdir(CACHE, { recursive: true });
  const raw = join(CACHE, `${card.id}.img`);
  let buf: Buffer;
  if (existsSync(raw)) {
    buf = await readFile(raw);
  } else {
    const res = await fetch(card.imageSmall);
    if (!res.ok) return null;
    buf = Buffer.from(await res.arrayBuffer());
    await writeFile(raw, buf);
  }
  return sharpToGray(buf);
}

async function sharpToGray(buf: Buffer): Promise<Uint8Array> {
  const n = PHASH_INPUT_SIZE;
  const data = await sharp(buf)
    .grayscale()
    .resize(n, n, { fit: 'fill' })
    .raw()
    .toBuffer();
  return new Uint8Array(data.buffer, data.byteOffset, n * n);
}

/** Variante "foto real ruim": rotação leve, blur, brilho, recompressão jpeg. */
async function degrade(buf: Buffer): Promise<Uint8Array> {
  const jpeg = await sharp(buf)
    .rotate(3, { background: '#888' })
    .modulate({ brightness: 1.12 })
    .blur(1.1)
    .jpeg({ quality: 55 })
    .toBuffer();
  return sharpToGray(jpeg);
}

async function pool<T, R>(items: T[], limit: number, fn: (t: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let i = 0;
  async function worker() {
    while (i < items.length) {
      const idx = i++;
      out[idx] = await fn(items[idx]);
    }
  }
  await Promise.all(Array.from({ length: limit }, worker));
  return out;
}

function pct(sorted: number[], p: number): number {
  const i = Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length));
  return sorted[i];
}

async function main() {
  console.log(`Baixando cartas de ${SETS.length} sets…`);
  const all: CardRecord[] = [];
  for (const s of SETS) {
    try {
      const cards = await fetchSetCards(s);
      all.push(...cards);
      console.log(`  ${s}: ${cards.length} cartas`);
    } catch (e) {
      console.log(`  ${s}: FALHOU (${String(e)})`);
    }
  }

  console.log(`\nComputando pHash de ${all.length} imagens…`);
  const entries: Entry[] = [];
  const grays = await pool(all, 16, async (c) => {
    const g = await grayOf(c);
    return { c, g };
  });
  for (const { c, g } of grays) {
    if (!g) continue;
    entries.push({ id: c.id, setId: c.setId, name: c.name, hash: phashFromGray32(g) });
  }
  console.log(`Índice: ${entries.length} cartas com hash.\n`);

  // ---- Teste A: separação (vizinho mais próximo, imagem limpa) ----
  const nnGlobal: number[] = [];
  const nnSet: number[] = [];
  let collideGlobal = 0; // vizinho a <=6 bits (arriscado)
  let dupGlobal = 0; // hash idêntico a outra carta
  for (let i = 0; i < entries.length; i++) {
    let bestG = 999;
    let bestS = 999;
    for (let j = 0; j < entries.length; j++) {
      if (i === j) continue;
      const d = hamming(entries[i].hash, entries[j].hash);
      if (d < bestG) bestG = d;
      if (entries[j].setId === entries[i].setId && d < bestS) bestS = d;
    }
    nnGlobal.push(bestG);
    if (bestS < 999) nnSet.push(bestS);
    if (bestG <= 6) collideGlobal++;
    if (bestG === 0) dupGlobal++;
  }
  const sg = [...nnGlobal].sort((a, b) => a - b);
  const ss = [...nnSet].sort((a, b) => a - b);
  console.log('== A) SEPARAÇÃO (imagem limpa, dist. ao vizinho mais próximo) ==');
  console.log(`  Global  — p5=${pct(sg, 5)} p25=${pct(sg, 25)} mediana=${pct(sg, 50)} bits`);
  console.log(`  No set  — p5=${pct(ss, 5)} p25=${pct(ss, 25)} mediana=${pct(ss, 50)} bits`);
  console.log(`  Pares perigosos global (<=6 bits): ${collideGlobal}/${entries.length}`);
  console.log(`  Hashes idênticos a outra carta:    ${dupGlobal}/${entries.length}\n`);

  // ---- Teste B: robustez a "foto" (amostra) ----
  const SAMPLE = Math.min(120, all.length);
  const step = Math.max(1, Math.floor(all.length / SAMPLE));
  const sample = all.filter((c, k) => k % step === 0).slice(0, SAMPLE);
  console.log(`== B) ROBUSTEZ (${sample.length} cartas degradadas: rot+blur+brilho+jpeg) ==`);

  let rank1Global = 0;
  let rank1Set = 0;
  const marginGlobal: number[] = [];
  const trueDist: number[] = [];
  await pool(sample, 8, async (c) => {
    const raw = join(CACHE, `${c.id}.img`);
    if (!existsSync(raw)) return;
    const buf = await readFile(raw);
    const q = phashFromGray32(await degrade(buf));

    let best = { id: '', d: 999 };
    let second = 999;
    let bestSet = { id: '', d: 999 };
    let selfD = 999;
    for (const e of entries) {
      const d = hamming(q, e.hash);
      if (e.id === c.id) selfD = d;
      if (d < best.d) {
        second = best.d;
        best = { id: e.id, d };
      } else if (d < second) second = d;
      if (e.setId === c.setId && d < bestSet.d) bestSet = { id: e.id, d };
    }
    if (best.id === c.id) rank1Global++;
    if (bestSet.id === c.id) rank1Set++;
    marginGlobal.push(second - selfD); // >0 = a carta certa venceu com folga
    trueDist.push(selfD);
  });

  const mg = [...marginGlobal].sort((a, b) => a - b);
  const td = [...trueDist].sort((a, b) => a - b);
  console.log(`  Acerto rank-1 GLOBAL:      ${rank1Global}/${sample.length} (${((100 * rank1Global) / sample.length).toFixed(1)}%)`);
  console.log(`  Acerto rank-1 DENTRO SET:  ${rank1Set}/${sample.length} (${((100 * rank1Set) / sample.length).toFixed(1)}%)`);
  console.log(`  Dist. até a carta certa — mediana=${pct(td, 50)} p90=${pct(td, 90)} bits`);
  console.log(`  Margem sobre 2º lugar   — mediana=${pct(mg, 50)} p10=${pct(mg, 10)} bits`);
  console.log(`  (margem<=0 = casou a carta ERRADA em 1º lugar)`);
}

main().catch((e) => {
  console.error('Erro:', e);
  process.exitCode = 1;
});
