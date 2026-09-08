/**
 * Descritor multi-hash de uma carta RETIFICADA (frontal, W×H canônico).
 *
 * Um pHash de 64 bits sozinho confunde reprints e cede sob glare. O descritor
 * combina 4 sinais com modos de falha diferentes:
 *   artP  — pHash (DCT) da REGIÃO DA ARTE: o sinal mais distintivo e o único
 *           que não muda entre idiomas (o texto muda, a ilustração não).
 *   fullP — pHash da carta inteira: layout, moldura, tipo (cobre full-art).
 *   artD  — dHash da arte (gradientes locais): falha diferente do DCT.
 *   color — histograma de matiz da arte ponderado por saturação: quebra
 *           empates entre artes de composição parecida e ignora brilho.
 *
 * Contraste é normalizado por percentil antes dos hashes (brilho/glare).
 * Este módulo é puro: o MESMO código gera o índice (node) e lê a câmera.
 */
import { type RGBA, toGray, resampleArea, contrastStretch, cropGray, cropRGBA } from './image.js';
import { phashPair, hammingPair, type HashPair } from '../scanner/phash.js';

/** Tamanho canônico da carta retificada (razão 63×88 mm ≈ 0.716). */
export const CARD_W = 256;
export const CARD_H = 358;

/** Janela da ilustração em fração da carta (vale pro layout padrão e full-art). */
const ART = { x0: 0.07, y0: 0.10, x1: 0.93, y1: 0.50 };
const COLOR_BINS = 12;

/** Pesos da distância combinada (calibrados por scripts/e2e-validate.ts). */
export const W_FULL = 0.6;
export const W_ARTD = 0.6;
export const W_COLOR = 8; // L1 do histograma (0..2) × 8 → até 16 "bits" equivalentes

export interface Descriptor {
  artP: HashPair;
  fullP: HashPair;
  artD: HashPair;
  color: Uint8Array; // 12 bins, soma ≈ 255
}

function dhash9x8(g: Float32Array): HashPair {
  let hi = 0, lo = 0, bit = 0;
  for (let y = 0; y < 8; y++) {
    for (let x = 0; x < 8; x++, bit++) {
      if (g[y * 9 + x] > g[y * 9 + x + 1]) {
        if (bit < 32) lo |= 1 << bit; else hi |= 1 << (bit - 32);
      }
    }
  }
  return [hi >>> 0, lo >>> 0];
}

/** Histograma de matiz (12 bins) da arte, peso = saturação×valor. */
function hueHistogram(art: RGBA): Uint8Array {
  const small = resampleArea(art.data, art.width, art.height, 4, 24, 24);
  const bins = new Float64Array(COLOR_BINS);
  let total = 0;
  for (let i = 0; i < 24 * 24; i++) {
    const r = small[i * 4] / 255, g = small[i * 4 + 1] / 255, b = small[i * 4 + 2] / 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
    if (max <= 0) continue;
    const s = d / max, v = max;
    const w = s * v;
    if (w < 0.02) continue;
    let h: number;
    if (d === 0) h = 0;
    else if (max === r) h = ((g - b) / d) % 6;
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h = ((h * 60) + 360) % 360;
    bins[Math.min(COLOR_BINS - 1, Math.floor(h / (360 / COLOR_BINS)))] += w;
    total += w;
  }
  const out = new Uint8Array(COLOR_BINS);
  if (total < 1) return out; // carta sem cor (cinza) → histograma neutro
  for (let i = 0; i < COLOR_BINS; i++) out[i] = Math.round((255 * bins[i]) / total);
  return out;
}

/** Calcula o descritor de uma carta retificada (qualquer tamanho; ideal W×H canônico). */
export function describe(img: RGBA): Descriptor {
  const { width: w, height: h } = img;
  const gray = contrastStretch(toGray(img));

  const full32 = resampleArea(gray, w, h, 1, 32, 32);
  const fullP = phashPair(full32);

  const ax = Math.round(ART.x0 * w), ay = Math.round(ART.y0 * h);
  const aw = Math.round((ART.x1 - ART.x0) * w), ah = Math.round((ART.y1 - ART.y0) * h);
  const artGray = cropGray(gray, w, ax, ay, aw, ah);
  const artP = phashPair(resampleArea(artGray, aw, ah, 1, 32, 32));
  const artD = dhash9x8(resampleArea(artGray, aw, ah, 1, 9, 8));
  const color = hueHistogram(cropRGBA(img, ax, ay, aw, ah));

  return { artP, fullP, artD, color };
}

export function colorL1(a: Uint8Array, b: Uint8Array): number {
  let s = 0;
  for (let i = 0; i < COLOR_BINS; i++) s += Math.abs(a[i] - b[i]);
  return s / 255; // 0..2
}

/** Distância combinada (menor = mais parecido). ~0 idêntico; >60 outra carta. */
export function distance(a: Descriptor, b: Descriptor): number {
  return (
    hammingPair(a.artP, b.artP) +
    W_FULL * hammingPair(a.fullP, b.fullP) +
    W_ARTD * hammingPair(a.artD, b.artD) +
    W_COLOR * colorL1(a.color, b.color)
  );
}

// ---- serialização compacta pro índice ----

const hex8 = (n: number) => (n >>> 0).toString(16).padStart(8, '0');

/** 48 hex chars: artP.hi artP.lo fullP.hi fullP.lo artD.hi artD.lo */
export function packHashes(d: Descriptor): string {
  return hex8(d.artP[0]) + hex8(d.artP[1]) + hex8(d.fullP[0]) + hex8(d.fullP[1]) + hex8(d.artD[0]) + hex8(d.artD[1]);
}

export function unpackHashes(hex: string, into: Uint32Array, offset: number): void {
  for (let i = 0; i < 6; i++) into[offset + i] = parseInt(hex.slice(i * 8, i * 8 + 8), 16) >>> 0;
}
