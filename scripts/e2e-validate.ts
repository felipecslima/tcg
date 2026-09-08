/**
 * Validação END-TO-END do motor de visão com FRAMES SINTÉTICOS DE CÂMERA.
 *
 * Renderiza a carta do catálogo como se fosse vista por um celular: sobre um
 * fundo (mesa), com perspectiva, rotação, desalinhamento com o guia, glare
 * (reflexo de holo/sleeve), variação de brilho, blur e recompressão JPEG.
 * Depois roda o pipeline REAL (detectar → retificar → descrever → buscar →
 * votar) e mede:
 *   A) acerto rank-1 num frame só, global (sem set) e no set
 *   B) taxa de confirmação temporal (6 frames) e frames-até-confirmar
 *   C) falsa aceitação quando a carta NÃO está no catálogo (deve ser ~0)
 *   D) falsa aceitação sem carta nenhuma no quadro (deve ser 0)
 *
 * Rodar:  npm run e2e   (depois de npm run index:build)
 */
import sharp from 'sharp';
import { createWorker, PSM, type Worker } from 'tesseract.js';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { CardIndex, type IndexJSON, type IndexCard } from '../src/vision/catalog.js';
import { CARD_W, CARD_H, describe } from '../src/vision/descriptor.js';
import { Recognizer, recognizeOnce, THRESHOLDS, type NumberReading } from '../src/vision/recognizer.js';
import type { ParsedNumber } from '../src/scanner/numberParse.js';
import { homography, applyH, type RGBA, type Rect, type Quad, type Pt } from '../src/vision/image.js';
import { parseCollectorNumber } from '../src/scanner/numberParse.js';
import { fetchCardImage, toRGBA } from './build-index.js';

// A "carta física" simulada vem do high.webp em 2× do canônico: é o que uma
// câmera 720p vê (dígitos do número com ~12px). Do low.webp (245px) o OCR
// não lê nada — e o índice continua vindo do low, como em produção.
export const SRC_W = CARD_W * 2, SRC_H = CARD_H * 2;

// ---- OCR real do número, em Node (Tesseract), pro gate de verificação do
// Recognizer. Mesmas caixas de src/scanner/camera.ts (NUMBER_BOXES):
//   num   — SÓ os dígitos do número no layout moderno (SV/ME: "[G] [PAF PT] 028/091 ◆",
//           linha em y≈0.938–0.966, dígitos em x≈0.17–0.29 medido nas imagens da
//           TCGdex). Grid medido em frames sintéticos (13 cartas × 6 frames):
//           caixa com os selos G/PAF PT → 14% de frações certas; só os dígitos →
//           45%. A caixa larga antiga (0.90–0.975) pegava também a linha "Ilust."
//           e o Tesseract em SINGLE_LINE embaralhava tudo (2%).
//   left  — faixa larga (fallback: layouts SWSH e anteriores, número mais alto).
//   right — layouts antigos (XY e antes) com o número à direita.
// Devolve TODOS os textos crus lidos: o Recognizer compara com o impresso
// esperado. Para na primeira caixa que produz uma fração — as outras só
// trariam ruído (o rodapé direito tem o copyright, que vira dígitos soltos).
const NUM_BOXES = {
  num: { left: 0.14, top: 0.937, width: 0.24, height: 0.033 },
  left: { left: 0.03, top: 0.9, width: 0.36, height: 0.075 },
  right: { left: 0.6, top: 0.93, width: 0.38, height: 0.05 },
};
let ocrWorker: Worker | null = null;
async function getOcrWorker(): Promise<Worker> {
  if (!ocrWorker) {
    ocrWorker = await createWorker('eng');
    await ocrWorker.setParameters({ tessedit_char_whitelist: '0123456789/', tessedit_pageseg_mode: PSM.SINGLE_LINE, user_defined_dpi: '300' });
  }
  return ocrWorker;
}
const DEBUG_OCR = !!(process.env.DEBUG_B || process.env.DEBUG_C || process.env.DEBUG_OCR);
const ocrStats = { calls: 0, fraction: 0, lone: 0, textOnly: 0, none: 0 };
const resetOcrStats = () => Object.assign(ocrStats, { calls: 0, fraction: 0, lone: 0, textOnly: 0, none: 0 });
async function readNumberNode(rect: RGBA): Promise<NumberReading | null> {
  const worker = await getOcrWorker();
  const raw = Buffer.from(rect.data.buffer, rect.data.byteOffset, rect.width * rect.height * 4);
  ocrStats.calls++;
  const texts: string[] = [];
  let fraction: ParsedNumber | null = null, lone: ParsedNumber | null = null;
  for (const [box, b] of Object.entries(NUM_BOXES)) {
    const left = Math.round(rect.width * b.left), top = Math.round(rect.height * b.top);
    const width = Math.max(3, Math.round(rect.width * b.width)), height = Math.max(3, Math.round(rect.height * b.height));
    const g = sharp(raw, { raw: { width: rect.width, height: rect.height, channels: 4 } }).extract({ left, top, width, height }).resize({ width: width * 4, kernel: 'lanczos3' }).grayscale();
    // threshold+negate foi medido morto (0 leituras em 65 frames) e saiu; sharpen lê o que normalize perde.
    for (const [pipeName, pipe] of [['norm', g.clone().normalize()], ['sharp', g.clone().normalize().sharpen({ sigma: 1.2 })]] as const) {
      const { data } = await worker.recognize(await pipe.png().toBuffer());
      const txt = data.text.replace(/\s+/g, ' ').trim();
      if (DEBUG_OCR) console.log(`      ocr ${box}/${pipeName} raw="${txt}"`);
      if (!txt) continue;
      texts.push(txt);
      const p = parseCollectorNumber(txt);
      if (p?.denominator) fraction ??= p; else if (p) lone ??= p;
    }
    if (fraction) break;
  }
  const p = fraction ?? lone;
  if (!p && !texts.length) { ocrStats.none++; return null; }
  if (!p) ocrStats.textOnly++; else if (p.denominator) ocrStats.fraction++; else ocrStats.lone++;
  return { number: p?.number ?? '', denominator: p?.denominator, texts };
}
const fmtOcrStats = () => `OCR: ${ocrStats.calls} leituras — N/M ${ocrStats.fraction}, token solto ${ocrStats.lone}, só texto ${ocrStats.textOnly}, ilegível ${ocrStats.none}`;

const INDEX = process.argv[2] ?? 'public/index/tcgdex-pt.json';
const OUT_DIR = '/private/tmp/claude-501/-Users-felipelima-work-tcg/c0526f15-27a7-4577-907a-724b2fba15da/scratchpad/e2e-frames';
const N_SINGLE = Number(process.env.N_SINGLE ?? 160);
const N_TEMPORAL = Number(process.env.N_TEMPORAL ?? 60);
const FRAMES_PER = 9; // folga extra: o gate de número consome 1+ frames "candidate" esperando o OCR

// frame retrato de celular
const FW = 720, FH = 960;
const GH = FH * 0.78, GW = GH * (CARD_W / CARD_H);
export const GUIDE: Rect = { x: (FW - GW) / 2, y: (FH - GH) / 2, w: GW, h: GH };

function mulberry32(seed: number) {
  return () => { seed |= 0; seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
// RNG determinístico, re-semeado por (seção, carta): os frames de cada carta
// não dependem de N_SINGLE nem do que aconteceu nas seções anteriores.
let rnd = mulberry32(20260907);
const U = (a: number, b: number) => a + (b - a) * rnd();
function fnv1a(s: string): number { let h = 0x811c9dc5; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 0x01000193); } return h >>> 0; }
const reseed = (tag: string) => { rnd = mulberry32(20260907 ^ fnv1a(tag)); };

function bilinear(img: RGBA, x: number, y: number, c: number): number {
  const xc = Math.max(0, Math.min(img.width - 1.001, x)), yc = Math.max(0, Math.min(img.height - 1.001, y));
  const x0 = xc | 0, y0 = yc | 0, fx = xc - x0, fy = yc - y0;
  const i = (y0 * img.width + x0) * 4 + c, W = img.width * 4;
  const d = img.data;
  return (d[i] * (1 - fx) + d[i + 4] * fx) * (1 - fy) + (d[i + W] * (1 - fx) + d[i + W + 4] * fx) * fy;
}

/** Renderiza a carta num frame "de celular" com todas as degradações. */
export async function renderFrame(card: RGBA, withCard = true): Promise<{ frame: RGBA; quad: Quad }> {
  const px = new Float32Array(FW * FH * 3);
  // fundo: mesa com gradiente + ruído
  const base = [U(40, 200), U(40, 180), U(30, 160)];
  const gdir = U(0, Math.PI * 2);
  for (let y = 0; y < FH; y++) for (let x = 0; x < FW; x++) {
    const g = 1 + 0.25 * Math.cos(gdir) * (x / FW - 0.5) + 0.25 * Math.sin(gdir) * (y / FH - 0.5);
    const o = (y * FW + x) * 3;
    for (let c = 0; c < 3; c++) px[o + c] = base[c] * g + U(-8, 8);
  }
  // quadrilátero da carta: guia × escala, deslocado, rotacionado, perspectiva
  const s = U(0.84, 1.04), cx = GUIDE.x + GUIDE.w / 2 + U(-0.05, 0.05) * GUIDE.w, cy = GUIDE.y + GUIDE.h / 2 + U(-0.05, 0.05) * GUIDE.h;
  const th = U(-7, 7) * Math.PI / 180, hw = (GUIDE.w * s) / 2, hh = (GUIDE.h * s) / 2;
  const rot = (x: number, y: number): Pt => ({ x: cx + x * Math.cos(th) - y * Math.sin(th), y: cy + x * Math.sin(th) + y * Math.cos(th) });
  const j = () => U(-0.04, 0.04);
  const quad: Quad = [rot(-hw * (1 + j()), -hh * (1 + j())), rot(hw * (1 + j()), -hh * (1 + j())), rot(hw * (1 + j()), hh * (1 + j())), rot(-hw * (1 + j()), hh * (1 + j()))];

  if (withCard) {
    const H = homography(quad, [{ x: 0, y: 0 }, { x: card.width, y: 0 }, { x: card.width, y: card.height }, { x: 0, y: card.height }]);
    const xs = quad.map((p) => p.x), ys = quad.map((p) => p.y);
    const x0 = Math.max(0, Math.floor(Math.min(...xs))), x1 = Math.min(FW - 1, Math.ceil(Math.max(...xs)));
    const y0 = Math.max(0, Math.floor(Math.min(...ys))), y1 = Math.min(FH - 1, Math.ceil(Math.max(...ys)));
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const p = applyH(H, x + 0.5, y + 0.5);
      if (p.x < 0 || p.y < 0 || p.x >= card.width || p.y >= card.height) continue;
      const o = (y * FW + x) * 3;
      for (let c = 0; c < 3; c++) px[o + c] = bilinear(card, p.x - 0.5, p.y - 0.5, c);
    }
  }
  // glare (reflexo de holo/sleeve)
  if (rnd() < 0.75) {
    const gx = cx + U(-0.4, 0.4) * hw * 2, gy = cy + U(-0.4, 0.4) * hh * 2, sig = U(0.1, 0.3) * hh * 2, A = U(60, 170);
    for (let y = 0; y < FH; y++) for (let x = 0; x < FW; x++) {
      const d2 = (x - gx) ** 2 + (y - gy) ** 2;
      if (d2 > 9 * sig * sig) continue;
      const a = A * Math.exp(-d2 / (2 * sig * sig));
      const o = (y * FW + x) * 3;
      px[o] += a; px[o + 1] += a; px[o + 2] += a;
    }
  }
  const bright = U(0.7, 1.25);
  const raw = Buffer.alloc(FW * FH * 3);
  for (let i = 0; i < px.length; i++) raw[i] = Math.max(0, Math.min(255, px[i] * bright));
  const out = await sharp(raw, { raw: { width: FW, height: FH, channels: 3 } })
    .blur(U(0.4, 1.3)).jpeg({ quality: Math.round(U(40, 75)) }).toBuffer();
  const dec = await sharp(out).ensureAlpha().raw().toBuffer();
  return { frame: { data: new Uint8ClampedArray(dec.buffer, dec.byteOffset, FW * FH * 4), width: FW, height: FH }, quad };
}

const pct = (arr: number[], p: number) => { const s = [...arr].sort((a, b) => a - b); return s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))]; };

/** Erro médio dos cantos detectados vs. o quadrilátero verdadeiro, em fração da altura da carta. */
function cornerError(det: Quad, truth: Quad): number {
  const H = (Math.hypot(truth[0].x - truth[3].x, truth[0].y - truth[3].y) + Math.hypot(truth[1].x - truth[2].x, truth[1].y - truth[2].y)) / 2;
  let e = 0;
  for (let i = 0; i < 4; i++) e += Math.hypot(det[i].x - truth[i].x, det[i].y - truth[i].y);
  return e / 4 / H;
}
// relógio sintético pros testes temporais: cada frame avança mais que
// OCR_MIN_INTERVAL_MS, então o gate pode disparar em todo frame (determinístico,
// independente da velocidade da máquina)
const tick = (f: number) => f * (THRESHOLDS.OCR_MIN_INTERVAL_MS + 1);

/** Espera até o veredito parar de depender de uma verificação de número em voo. */
async function settle(rec: Recognizer, maxMs = 4000): Promise<void> {
  const t0 = Date.now();
  while (rec.verifying && Date.now() - t0 < maxMs) await new Promise((r) => setTimeout(r, 40));
}

async function main() {
  const json = JSON.parse(await readFile(INDEX, 'utf8')) as IndexJSON;
  const index = CardIndex.fromJSON(json);
  console.log(`Índice: ${index.size} cartas, ${index.sets.length} sets (${index.source}).\n`);
  await mkdir(OUT_DIR, { recursive: true });
  console.log('Pré-aquecendo worker de OCR (Tesseract)…');
  await getOcrWorker();

  const pick = (n: number, offset = 0): IndexCard[] => {
    const step = Math.max(1, Math.floor(index.cards.length / n));
    return index.cards.filter((_, i) => (i + offset) % step === 0).slice(0, n);
  };
  const load = async (c: IndexCard) => { const b = await fetchCardImage(c, 'high'); return b ? toRGBA(b, SRC_W, SRC_H) : null; };

  // ---------- A) frame único ----------
  let r1g = 0, r1s = 0, fallback = 0, confident = 0, confidentWrong = 0;
  const trueD: number[] = [], impD: number[] = [], detConf: number[] = [], cornerErr: number[] = [];
  const sample = pick(N_SINGLE);
  let saved = 0;
  for (const c of sample) {
    const img = await load(c); if (!img) continue;
    reseed(`A:${c.id}`);
    const { frame, quad } = await renderFrame(img);
    const r = recognizeOnce(index, frame, GUIDE);
    cornerErr.push(cornerError(r.detection.corners, quad));
    const desc = describe(r.detection.rectified);
    trueD.push(index.distanceTo(desc, c.id)!);
    impD.push(index.search(desc, { exclude: new Set([c.id]), k: 1 })[0].dist);
    detConf.push(r.detection.confidence);
    if (r.detection.usedFallback) fallback++;
    if (r.hits[0]?.card.id === c.id) r1g++;
    const inSet = index.search(desc, { setIds: new Set([c.setId]), k: 1 })[0];
    if (inSet?.card.id === c.id) r1s++;
    if (r.verdict === 'confident') { confident++; if (r.hits[0].card.id !== c.id) confidentWrong++; }
    if (saved < 4) {
      await sharp(Buffer.from(frame.data.buffer, frame.data.byteOffset, frame.data.length), { raw: { width: FW, height: FH, channels: 4 } })
        .png().toFile(join(OUT_DIR, `frame-${c.id}.png`));
      saved++;
    }
  }
  const n = trueD.length;
  console.log(`== A) FRAME ÚNICO (${n} cartas, câmera sintética: perspectiva+glare+blur+jpeg) ==`);
  console.log(`  rank-1 GLOBAL (sem set):  ${r1g}/${n} (${((100 * r1g) / n).toFixed(1)}%)`);
  console.log(`  rank-1 DENTRO DO SET:     ${r1s}/${n} (${((100 * r1s) / n).toFixed(1)}%)`);
  console.log(`  verdict "confident":      ${confident}/${n}, dos quais ERRADOS: ${confidentWrong}`);
  console.log(`  dist. até a carta certa:  p50=${pct(trueD, 50).toFixed(0)} p90=${pct(trueD, 90).toFixed(0)} p97=${pct(trueD, 97).toFixed(0)}`);
  console.log(`  dist. do melhor impostor: p3=${pct(impD, 3).toFixed(0)} p10=${pct(impD, 10).toFixed(0)} p50=${pct(impD, 50).toFixed(0)}`);
  console.log(`  detecção: confiança p50=${pct(detConf, 50).toFixed(2)}, fallback pro guia: ${fallback}/${n}`);
  console.log(`  erro dos cantos vs. verdade: p50=${(100 * pct(cornerErr, 50)).toFixed(1)}% p90=${(100 * pct(cornerErr, 90)).toFixed(1)}% da altura da carta\n`);

  // ---------- B) temporal (carta no catálogo) ----------
  let confirmed = 0, confirmedWrong = 0;
  const byMode: Record<string, number> = {};
  const framesTo: number[] = [];
  const tsample = pick(N_TEMPORAL, 3);
  const dbgB = process.env.DEBUG_B ? (m: string) => console.log('      ' + m) : undefined;
  let withTwins = 0, withTwinsConfirmed = 0;
  for (const c of tsample) {
    const img = await load(c); if (!img) continue;
    reseed(`B:${c.id}`);
    const rec = new Recognizer(index, { readNumber: readNumberNode, debug: dbgB });
    const twins = rec.twinsOf(c.id);
    if (twins.length) withTwins++;
    let done = false;
    if (process.env.DEBUG_B) console.log(`\n# B ${c.id} "${c.name}" nº=${c.number}/${c.printedTotal}${twins.length ? ` gêmeas: ${twins.map((t) => t.id).join(',')}` : ''}`);
    for (let f = 0; f < FRAMES_PER && !done; f++) {
      const { frame } = await renderFrame(img);
      const r = rec.feed(frame, GUIDE, tick(f));
      if (process.env.DEBUG_B) console.log(`  f${f + 1} ${r.state.padEnd(9)} best=${r.best?.card.id}(${r.best?.dist.toFixed(0)}) votes=${r.votes.slice(0, 2).map((v) => `${v.card.id}:${v.score.toFixed(2)}`).join(' ')} | ${r.reason}`);
      if (rec.verifying) await settle(rec); // dá tempo real ao OCR terminar
      if (r.state === 'confirmed') {
        done = true; confirmed++; framesTo.push(f + 1);
        byMode[rec.lockedVerification] = (byMode[rec.lockedVerification] ?? 0) + 1;
        if (rec.locked !== c.id) confirmedWrong++;
        else if (twins.length) withTwinsConfirmed++;
      }
    }
  }
  console.log(`== B) TEMPORAL — carta NO catálogo (${tsample.length} cartas × ${FRAMES_PER} frames) ==`);
  console.log(`  confirmou: ${confirmed}/${tsample.length} (${((100 * confirmed) / tsample.length).toFixed(1)}%)  ERRADAS: ${confirmedWrong}`);
  console.log(`  verificação da confirmada: ${JSON.stringify(byMode)}   ${fmtOcrStats()}`);
  console.log(`  cartas COM gêmea (reprint no índice): ${withTwins}, confirmadas certas: ${withTwinsConfirmed}`);
  console.log(`  frames até confirmar: p50=${pct(framesTo, 50)} p90=${pct(framesTo, 90)}\n`);
  resetOcrStats();

  // ---------- C) temporal (carta FORA do catálogo) ----------
  // C1) a ARTE está ausente: exclui a carta E as gêmeas (reprints). É o caso
  //     "Joel escaneou algo que a base não tem" de verdade: o motor precisa
  //     dizer "desconhecida" só pelo visual.
  // C2) só a IMPRESSÃO está ausente (reprint fora da base, a gêmea está): a
  //     arte casa perfeitamente com a gêmea e só o número impresso separa — é
  //     o gate de número que tem que barrar. Métrica original do handoff.
  const runC = async (label: string, excludeFor: (c: IndexCard, rec: Recognizer) => Set<string>) => {
    let falseAccept = 0, unknownFrames = 0, totalFrames = 0, twinCases = 0;
    const fpByMode: Record<string, number> = {}, finalStates: Record<string, number> = {};
    const dbgC = process.env.DEBUG_C ? (m: string) => console.log('      ' + m) : undefined;
    for (const c of tsample) {
      const img = await load(c); if (!img) continue;
      reseed(`${label}:${c.id}`);
      const probe = new Recognizer(index, { exclude: new Set([c.id]) });
      const exclude = excludeFor(c, probe);
      const rec = new Recognizer(index, { exclude, readNumber: readNumberNode, debug: dbgC });
      const hasTwin = index.twinsOf(c.id, { maxDist: THRESHOLDS.TWIN_MAX_DIST, exclude }).length > 0;
      if (hasTwin) twinCases++;
      if (process.env.DEBUG_C) console.log(`\n# ${label} ${c.id} "${c.name}" nº=${c.number}/${c.printedTotal} (excluídas: ${[...exclude].join(',')})`);
      let last = 'idle';
      for (let f = 0; f < FRAMES_PER; f++) {
        const { frame } = await renderFrame(img);
        const r = rec.feed(frame, GUIDE, tick(f));
        if (process.env.DEBUG_C) console.log(`  f${f + 1} ${r.state.padEnd(9)} best=${r.best?.card.id}(${r.best?.dist.toFixed(0)}) votes=${r.votes.slice(0, 2).map((v) => `${v.card.id}:${v.score.toFixed(2)}`).join(' ')} | ${r.reason}`);
        if (rec.verifying) await settle(rec);
        totalFrames++; last = r.state;
        if (r.state === 'unknown' || r.state === 'no_card') unknownFrames++;
        if (r.state === 'confirmed') {
          falseAccept++;
          fpByMode[rec.lockedVerification] = (fpByMode[rec.lockedVerification] ?? 0) + 1;
          const wrong = index.get(rec.locked!);
          console.log(`  FALSO POSITIVO: real=${c.id} "${c.name}" nº=${c.number} -> confundiu com ${rec.locked} "${wrong?.name}" nº=${wrong?.number} (${wrong?.setName}) [verificação=${rec.lockedVerification}]`);
          break;
        }
      }
      finalStates[last] = (finalStates[last] ?? 0) + 1;
    }
    console.log(`== ${label} ==`);
    console.log(`  FALSA ACEITAÇÃO (confirmou outra carta): ${falseAccept}/${tsample.length}   por verificação: ${JSON.stringify(fpByMode)}   ${fmtOcrStats()}`);
    console.log(`  casos com gêmea no índice pesquisável: ${twinCases}   estado final: ${JSON.stringify(finalStates)}`);
    console.log(`  frames marcados unknown/no_card: ${unknownFrames}/${totalFrames}\n`);
    resetOcrStats();
  };
  await runC(`C1) TEMPORAL — ARTE fora do catálogo (${tsample.length} cartas, excluídas com suas gêmeas)`,
    (c, probe) => new Set([c.id, ...probe.twinsOf(c.id).map((t) => t.id)]));
  await runC(`C2) TEMPORAL — REPRINT fora do catálogo (${tsample.length} cartas, só a impressão excluída; a gêmea fica)`,
    (c) => new Set([c.id]));

  // ---------- D) sem carta ----------
  let noCardAccept = 0; const states: Record<string, number> = {};
  reseed('D');
  const rec = new Recognizer(index);
  for (let f = 0; f < 30; f++) {
    const { frame } = await renderFrame(await load(index.cards[0]) as RGBA, false);
    const r = rec.feed(frame, GUIDE, f * 150);
    states[r.state] = (states[r.state] ?? 0) + 1;
    if (r.state === 'confirmed') noCardAccept++;
  }
  console.log(`== D) SEM CARTA no quadro (30 frames de mesa+glare) ==`);
  console.log(`  confirmações indevidas: ${noCardAccept}   estados: ${JSON.stringify(states)}\n`);

  console.log(`Limiares em uso: ${JSON.stringify(THRESHOLDS)}`);
  console.log(`Frames de exemplo salvos em ${OUT_DIR}`);
  await writeFile(join(OUT_DIR, 'guide.json'), JSON.stringify(GUIDE));
  if (ocrWorker) await ocrWorker.terminate();
}

// só roda quando invocado diretamente (os helpers acima são importados por scripts de experimento)
if (process.argv[1]?.endsWith('e2e-validate.ts')) main().catch((e) => { console.error('Erro:', e); process.exitCode = 1; });
