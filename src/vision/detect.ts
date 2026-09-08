/**
 * Detecção GUIADA da carta + retificação de perspectiva.
 *
 * A UI mostra um quadro-guia com a proporção da carta; o usuário alinha
 * "mais ou menos". Este módulo refina: pra cada um dos 4 lados, procura a
 * borda real da carta numa faixa em torno da borda do guia (o pico de
 * gradiente perpendicular ao lado), ajusta uma reta robusta (poda por MAD),
 * intersecta as 4 retas → cantos exatos → warp perspectivo pra carta frontal.
 *
 * Quando um lado não tem borda confiável, cai na borda do guia. Quando o
 * quadrilátero resultante não faz sentido (côncavo, proporção errada), cai
 * no guia inteiro. Nunca falha: sempre devolve um retificado + confiança.
 *
 * Isso é o que separa "pHash funciona em imagem de catálogo" de "funciona
 * apontando o celular pra carta na mesa".
 */
import {
  type RGBA, type Rect, type Pt, type Quad,
  toGray, boxBlur3, sobel, downscaleRGBA, warpQuad, quadArea, isConvex,
} from './image.js';
import { CARD_W, CARD_H } from './descriptor.js';

export interface Detection {
  corners: Quad; // em coordenadas do frame original
  confidence: number; // 0..1 — fração de bordas encontradas com consistência
  edgeStrength: number; // força média das bordas (baixa = provavelmente sem carta)
  usedFallback: boolean; // true = nenhuma borda confiável, usou o guia
  rectified: RGBA; // carta frontal CARD_W×CARD_H
}

const CARD_ASPECT = CARD_W / CARD_H; // ≈ 0.715
const MAX_WORK_DIM = 640; // detecção roda numa versão reduzida do frame
const SAMPLES = 28; // varreduras por lado
const BAND = 0.14; // faixa de busca em torno da borda do guia (fração do guia)
const MIN_EDGE = 9; // gradiente mínimo (0..255) pra contar como borda
const MIN_INLIERS = 0.5; // fração mínima de amostras coerentes pra aceitar o lado

/**
 * Ajustes finos expostos pra calibração (scripts/). A borda carta×mesa é a
 * transição MAIS EXTERNA da faixa; as linhas internas da moldura (nome, a
 * divisória de Fraqueza/Resistência, o filete da moldura) costumam ter MAIS
 * contraste que a borda externa e ficam 3–6% pra dentro. Pegar o pico máximo
 * escolhia essas linhas internas e encolhia o retificado — o que empurrava o
 * número de coletor pra fora do recorte do OCR e inflava a distância do hash.
 * Regra: entre os picos locais com força ≥ REL_PEAK × máximo da varredura,
 * fica o mais externo. Calibrado em scripts/e2e-validate.ts (câmera sintética):
 * 0.4 → dist. mediana até a carta certa 21; 0.25 → 19; 0.15 → 18 (o teto com o
 * quadrilátero perfeito é 14). Valores baixos são mais sensíveis a textura de
 * mesa real (que o harness não simula), por isso o meio-termo.
 */
export const DETECT_TUNING = { REL_PEAK: 0.25 };

/** Guia padrão quando a UI não fornece: imagem inteira se já tem proporção de carta, senão retângulo central. */
export function defaultGuide(w: number, h: number): Rect {
  const asp = w / h;
  if (asp > 0.6 && asp < 0.85) {
    const m = 0.015;
    return { x: w * m, y: h * m, w: w * (1 - 2 * m), h: h * (1 - 2 * m) };
  }
  let gh = h * 0.9, gw = gh * CARD_ASPECT;
  if (gw > w * 0.94) { gw = w * 0.94; gh = gw / CARD_ASPECT; }
  return { x: (w - gw) / 2, y: (h - gh) / 2, w: gw, h: gh };
}

interface Line { a: number; b: number; c: number } // a·x + b·y + c = 0

interface SideFit { line: Line | null; inliers: number; strength: number }

/**
 * Ajusta reta robusta a pontos ~verticais (x = m·y + k) ou ~horizontais (y = m·x + k).
 * Duas rodadas: mínimos quadrados → poda por resíduo > 2.5·MAD → refit.
 */
function fitLine(pts: Pt[], vertical: boolean): { line: Line; inliers: number } | null {
  if (pts.length < 4) return null;
  const xs = pts.map((p) => (vertical ? p.y : p.x));
  const ys = pts.map((p) => (vertical ? p.x : p.y));
  let idx = xs.map((_, i) => i);
  let m = 0, k = 0;
  for (let round = 0; round < 3; round++) {
    let sx = 0, sy = 0, sxx = 0, sxy = 0;
    const n = idx.length;
    for (const i of idx) { sx += xs[i]; sy += ys[i]; sxx += xs[i] * xs[i]; sxy += xs[i] * ys[i]; }
    const den = n * sxx - sx * sx;
    if (Math.abs(den) < 1e-9) return null;
    m = (n * sxy - sx * sy) / den;
    k = (sy - m * sx) / n;
    const res = idx.map((i) => Math.abs(ys[i] - (m * xs[i] + k)));
    const sorted = [...res].sort((a, b) => a - b);
    const med = sorted[sorted.length >> 1];
    const mad = [...res.map((r) => Math.abs(r - med))].sort((a, b) => a - b)[res.length >> 1] || 0.5;
    const thr = Math.max(1.5, 2.5 * mad + med);
    const keep = idx.filter((_, j) => res[j] <= thr);
    if (keep.length === idx.length) break;
    if (keep.length < 4) break;
    idx = keep;
  }
  // converte pra forma geral
  const line: Line = vertical ? { a: 1, b: -m, c: -k } : { a: -m, b: 1, c: -k };
  return { line, inliers: idx.length / pts.length };
}

function intersect(l1: Line, l2: Line): Pt | null {
  const det = l1.a * l2.b - l2.a * l1.b;
  if (Math.abs(det) < 1e-9) return null;
  return { x: (l1.b * l2.c - l2.b * l1.c) / det, y: (l2.a * l1.c - l1.a * l2.c) / det };
}

/** Varre um lado: pra cada scanline, pega o pico de gradiente perpendicular dentro da faixa. */
function scanSide(
  grad: Float32Array, w: number, h: number, g: Rect, side: 'left' | 'right' | 'top' | 'bottom',
): SideFit {
  const vertical = side === 'left' || side === 'right';
  const edgePos = side === 'left' ? g.x : side === 'right' ? g.x + g.w : side === 'top' ? g.y : g.y + g.h;
  const band = (vertical ? g.w : g.h) * BAND;
  const lo = Math.max(1, Math.floor(edgePos - band)), hi = Math.min((vertical ? w : h) - 2, Math.ceil(edgePos + band));
  const along0 = vertical ? g.y + g.h * 0.1 : g.x + g.w * 0.1;
  const along1 = vertical ? g.y + g.h * 0.9 : g.x + g.w * 0.9;
  const pts: Pt[] = [];
  const peaks: number[] = [];
  const outerFirst = side === 'left' || side === 'top'; // "fora" = índice menor
  for (let s = 0; s < SAMPLES; s++) {
    const t = Math.round(along0 + ((along1 - along0) * s) / (SAMPLES - 1));
    if (t < 1 || t >= (vertical ? h : w) - 1) continue;
    const at = (p: number) => (vertical ? Math.abs(grad[t * w + p]) : Math.abs(grad[p * w + t]));
    let best = -1;
    for (let p = lo; p <= hi; p++) { const v = at(p); if (v > best) best = v; }
    if (best < MIN_EDGE) continue;
    // pico local mais externo que seja forte o bastante (ver DETECT_TUNING)
    const thr = Math.max(MIN_EDGE, DETECT_TUNING.REL_PEAK * best);
    let pos = -1, val = 0;
    if (outerFirst) {
      for (let p = lo; p <= hi; p++) { const v = at(p); if (v >= thr && v >= at(p - 1) && v >= at(p + 1)) { pos = p; val = v; break; } }
    } else {
      for (let p = hi; p >= lo; p--) { const v = at(p); if (v >= thr && v >= at(p - 1) && v >= at(p + 1)) { pos = p; val = v; break; } }
    }
    if (pos < 0) continue;
    pts.push(vertical ? { x: pos, y: t } : { x: t, y: pos });
    peaks.push(val);
  }
  const strength = peaks.length ? [...peaks].sort((a, b) => a - b)[peaks.length >> 1] : 0;
  const fit = fitLine(pts, vertical);
  if (!fit || pts.length < SAMPLES * MIN_INLIERS) return { line: null, inliers: 0, strength };
  return { line: fit.line, inliers: fit.inliers * (pts.length / SAMPLES), strength };
}

function guideQuad(g: Rect): Quad {
  return [{ x: g.x, y: g.y }, { x: g.x + g.w, y: g.y }, { x: g.x + g.w, y: g.y + g.h }, { x: g.x, y: g.y + g.h }];
}

function lineFromEdge(g: Rect, side: 'left' | 'right' | 'top' | 'bottom'): Line {
  switch (side) {
    case 'left': return { a: 1, b: 0, c: -g.x };
    case 'right': return { a: 1, b: 0, c: -(g.x + g.w) };
    case 'top': return { a: 0, b: 1, c: -g.y };
    case 'bottom': return { a: 0, b: 1, c: -(g.y + g.h) };
  }
}

/** Quadrilátero plausível de carta? (convexo, proporção e área perto do guia, dentro do frame) */
function plausible(q: Quad, g: Rect, w: number, h: number): boolean {
  if (!isConvex(q)) return false;
  const dist = (a: Pt, b: Pt) => Math.hypot(a.x - b.x, a.y - b.y);
  const wid = (dist(q[0], q[1]) + dist(q[3], q[2])) / 2;
  const hei = (dist(q[0], q[3]) + dist(q[1], q[2])) / 2;
  if (hei < 1) return false;
  const asp = wid / hei;
  if (asp < 0.55 || asp > 0.92) return false;
  const ar = quadArea(q) / (g.w * g.h);
  if (ar < 0.45 || ar > 1.7) return false;
  for (const p of q) if (p.x < -w * 0.1 || p.x > w * 1.1 || p.y < -h * 0.1 || p.y > h * 1.1) return false;
  return true;
}

/**
 * Detecta a carta no frame em torno do guia e devolve os cantos + retificado.
 * `guide` em pixels do frame; omitido → `defaultGuide`.
 */
export function detectCard(frame: RGBA, guide?: Rect): Detection {
  const g0 = guide ?? defaultGuide(frame.width, frame.height);

  // trabalha reduzido
  const scale = Math.min(1, MAX_WORK_DIM / Math.max(frame.width, frame.height));
  const w = Math.max(8, Math.round(frame.width * scale)), h = Math.max(8, Math.round(frame.height * scale));
  const small = scale < 1 ? downscaleRGBA(frame, w, h) : frame;
  const g: Rect = { x: g0.x * scale, y: g0.y * scale, w: g0.w * scale, h: g0.h * scale };

  const gray = boxBlur3(toGray(small), w, h);
  const { gx, gy } = sobel(gray, w, h);

  const sides = {
    left: scanSide(gx, w, h, g, 'left'),
    right: scanSide(gx, w, h, g, 'right'),
    top: scanSide(gy, w, h, g, 'top'),
    bottom: scanSide(gy, w, h, g, 'bottom'),
  };
  const L = sides.left.line ?? lineFromEdge(g, 'left');
  const R = sides.right.line ?? lineFromEdge(g, 'right');
  const T = sides.top.line ?? lineFromEdge(g, 'top');
  const B = sides.bottom.line ?? lineFromEdge(g, 'bottom');

  const tl = intersect(L, T), tr = intersect(R, T), br = intersect(R, B), bl = intersect(L, B);
  const found = [sides.left, sides.right, sides.top, sides.bottom].filter((s) => s.line).length;
  const edgeStrength = (sides.left.strength + sides.right.strength + sides.top.strength + sides.bottom.strength) / 4;

  let quad: Quad;
  let usedFallback = false;
  let confidence: number;
  if (tl && tr && br && bl && found > 0 && plausible([tl, tr, br, bl], g, w, h)) {
    quad = [tl, tr, br, bl];
    confidence = (sides.left.inliers + sides.right.inliers + sides.top.inliers + sides.bottom.inliers) / 4;
  } else {
    quad = guideQuad(g);
    usedFallback = true;
    confidence = 0;
  }

  const inv = 1 / scale;
  const corners: Quad = [
    { x: quad[0].x * inv, y: quad[0].y * inv }, { x: quad[1].x * inv, y: quad[1].y * inv },
    { x: quad[2].x * inv, y: quad[2].y * inv }, { x: quad[3].x * inv, y: quad[3].y * inv },
  ];
  const rectified = warpQuad(frame, corners, CARD_W, CARD_H);
  return { corners, confidence, edgeStrength, usedFallback, rectified };
}
