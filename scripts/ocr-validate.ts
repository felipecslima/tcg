/**
 * Mede o hit-rate HONESTO do OCR client-side (Tesseract) na leitura do
 * número de coletor, com validação cruzada contra o set (pré-filtro).
 *
 * Para cada carta: baixa a imagem, roda OCR em 2 cantos × várias variantes
 * de pré-processamento, e aceita a leitura cujo número EXISTE no set.
 * Reporta: leu+validou / leu-errado / não-leu. É o que decide se o motor
 * de reconhecimento pode ser 100% client-side e grátis.
 *
 * Rodar:  npm run ocr:validate
 */
import sharp from 'sharp';
import { createWorker, PSM, type Worker } from 'tesseract.js';
import { fetchSetCards, SetIndex } from '../src/matching/index.js';
import { pickBestNumber, validNumberSet } from '../src/scanner/extractNumber.js';

interface Target { set: string; id: string; expect: string; kind: string }
const TARGETS: Target[] = [
  { set: 'base1', id: 'base1-4', expect: '4', kind: 'WOTC holo' },
  { set: 'base1', id: 'base1-58', expect: '58', kind: 'WOTC comum' },
  { set: 'base1', id: 'base1-98', expect: '98', kind: 'WOTC energia' },
  { set: 'sv3pt5', id: 'sv3pt5-6', expect: '6', kind: 'moderno holo (151)' },
  { set: 'sv3pt5', id: 'sv3pt5-1', expect: '1', kind: 'moderno comum (151)' },
  { set: 'swsh4', id: 'swsh4-25', expect: '25', kind: 'moderno holo' },
  { set: 'swsh4', id: 'swsh4-4', expect: '4', kind: 'moderno comum' },
  { set: 'sm1', id: 'sm1-1', expect: '1', kind: 'Sun&Moon comum' },
];

// cantos onde o número costuma estar (fração do card)
const BOXES = {
  right: { left: 0.78, top: 0.95, width: 0.21, height: 0.05 }, // WOTC / antigos
  left: { left: 0.03, top: 0.9, width: 0.36, height: 0.075 }, // modernos
};

async function fetchRetry(url: string, retries = 6): Promise<Response> {
  for (let i = 0; i < retries; i++) {
    try { const r = await fetch(url); if (r.ok) return r; } catch { /* */ }
    await new Promise((s) => setTimeout(s, 500 * (i + 1)));
  }
  throw new Error(`falhou: ${url}`);
}

async function ocrVariants(worker: Worker, buf: Buffer, W: number, H: number) {
  const results: { source: string; rawText: string }[] = [];
  for (const [corner, b] of Object.entries(BOXES)) {
    const region = {
      left: Math.round(W * b.left), top: Math.round(H * b.top),
      width: Math.round(W * b.width), height: Math.round(H * b.height),
    };
    const g = sharp(buf).extract(region).resize({ width: region.width * 5 }).grayscale();
    const preps: Record<string, sharp.Sharp> = {
      norm: g.clone().normalize(),
      th: g.clone().normalize().threshold(120),
      thNeg: g.clone().normalize().threshold(150).negate(),
      hiNeg: g.clone().normalize().threshold(185).negate(),
    };
    for (const [pn, pipe] of Object.entries(preps)) {
      const png = await pipe.png().toBuffer();
      const { data } = await worker.recognize(png);
      results.push({ source: `${corner}/${pn}`, rawText: data.text });
    }
  }
  return results;
}

async function main() {
  const worker = await createWorker('eng');
  await worker.setParameters({ tessedit_char_whitelist: '0123456789/', tessedit_pageseg_mode: PSM.SINGLE_LINE });

  const indices = new Map<string, SetIndex>();
  const validSets = new Map<string, Set<string>>();
  async function ctx(set: string) {
    if (!indices.has(set)) {
      const cards = await fetchSetCards(set);
      indices.set(set, SetIndex.from(cards));
      validSets.set(set, validNumberSet(indices.get(set)!, cards));
    }
    return { index: indices.get(set)!, valid: validSets.get(set)! };
  }

  // Política de aceite: AUTO só quando lê N/M e o denominador bate com o set.
  let autoCorrect = 0, autoWrong = 0, pend = 0;
  for (const t of TARGETS) {
    const { index, valid } = await ctx(t.set);
    const card = (await (await fetchRetry(`https://api.pokemontcg.io/v2/cards/${t.id}`)).json()).data;
    const imgBuf = Buffer.from(await (await fetchRetry(card.images.large)).arrayBuffer());
    const meta = await sharp(imgBuf).metadata();

    const results = await ocrVariants(worker, imgBuf, meta.width ?? 600, meta.height ?? 825);
    const ex = pickBestNumber(results, valid, card.set.printedTotal ?? 0);
    const correctId = ex.best ? index.match({ setId: t.set, number: ex.best.number }).card?.id === t.id : false;

    const auto = ex.denomMatches; // regra endurecida
    let decision: string;
    if (auto && correctId) { decision = 'AUTO ✓'; autoCorrect++; }
    else if (auto && !correctId) { decision = 'AUTO ✗ (falso-positivo)'; autoWrong++; }
    else { decision = 'PENDÊNCIA (manual)'; pend++; }

    console.log(`[${decision}] ${t.id.padEnd(11)} ${t.kind}`);
    console.log(
      `        leu: ${ex.best ? ex.best.number + (ex.best.denominator ? '/' + ex.best.denominator : '') + ' via ' + ex.best.source : '—'}` +
        ` | esperado ${t.expect} | validado-no-set: ${ex.validatedInSet} | denom-bate: ${ex.denomMatches}`,
    );
  }
  await worker.terminate();
  console.log(`\n== Política endurecida (auto só com N/M + denominador) ==`);
  console.log(`AUTO corretos: ${autoCorrect}/${TARGETS.length}`);
  console.log(`AUTO errados (falso-positivo): ${autoWrong}/${TARGETS.length}  <- crítico manter em 0`);
  console.log(`Pendência (confirmação manual): ${pend}/${TARGETS.length}`);
}

main().catch((e) => { console.error('Erro:', e); process.exitCode = 1; });
