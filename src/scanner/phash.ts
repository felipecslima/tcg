/**
 * Perceptual hash (pHash) baseado em DCT — a assinatura de arte que casa a
 * carta sem depender de ler texto (logo, idioma- e holo-agnóstico).
 *
 * Módulo PURO: recebe pixels em cinza 32x32 e devolve o hash. O mesmo código
 * roda no node (catálogo) e no browser (câmera) — consistência é tudo.
 *
 *   1) 32x32 cinza (feito fora)  2) DCT-II 2D  3) bloco 8x8 de baixa freq
 *   4) descarta DC (0,0)          5) bit = coef > mediana  -> 64 bits
 *
 * Representação rápida: par [hi, lo] de uint32 (Hamming via popcount sem
 * BigInt). A API em bigint é mantida pros scripts antigos.
 */

const N = 32;
const K = 8;

function makeDctBasis(n: number): Float64Array[] {
  const basis: Float64Array[] = [];
  for (let u = 0; u < n; u++) {
    const row = new Float64Array(n);
    const cu = u === 0 ? Math.SQRT1_2 : 1;
    for (let x = 0; x < n; x++) row[x] = cu * Math.cos(((2 * x + 1) * u * Math.PI) / (2 * n));
    basis.push(row);
  }
  return basis;
}
const BASIS = makeDctBasis(N);

/** DCT-II 2D separável de `gray` 32x32; devolve só o bloco 8x8 de baixa freq. */
export function dctLowFreq32(gray: ArrayLike<number>): Float64Array {
  const rows = new Float64Array(N * K);
  for (let y = 0; y < N; y++) {
    const base = y * N;
    for (let u = 0; u < K; u++) {
      let sum = 0;
      const b = BASIS[u];
      for (let x = 0; x < N; x++) sum += gray[base + x] * b[x];
      rows[y * K + u] = sum;
    }
  }
  const out = new Float64Array(K * K);
  for (let u = 0; u < K; u++) {
    for (let v = 0; v < K; v++) {
      let sum = 0;
      const b = BASIS[v];
      for (let y = 0; y < N; y++) sum += rows[y * K + u] * b[y];
      out[v * K + u] = sum;
    }
  }
  return out;
}

export type HashPair = [number, number]; // [hi, lo] uint32

/** 64 bits a partir dos 64 coeficientes (bit i = coef_i > mediana, DC = 0). */
export function bitsFromCoeffs(block: Float64Array): HashPair {
  const sorted = Array.from(block.subarray(1)).sort((a, b) => a - b);
  const median = (sorted[31] + sorted[32]) / 2;
  let hi = 0, lo = 0;
  for (let i = 1; i < 64; i++) {
    if (block[i] > median) {
      if (i < 32) lo |= 1 << i; else hi |= 1 << (i - 32);
    }
  }
  return [hi >>> 0, lo >>> 0];
}

/** pHash como par uint32 — o formato usado pelo motor de visão. */
export function phashPair(gray32: ArrayLike<number>): HashPair {
  if (gray32.length !== N * N) throw new Error(`phash: esperado ${N * N} pixels, recebi ${gray32.length}`);
  return bitsFromCoeffs(dctLowFreq32(gray32));
}

export function popcnt32(x: number): number {
  x = x - ((x >>> 1) & 0x55555555);
  x = (x & 0x33333333) + ((x >>> 2) & 0x33333333);
  return (((x + (x >>> 4)) & 0x0f0f0f0f) * 0x01010101) >>> 24;
}

export function hammingPair(a: HashPair, b: HashPair): number {
  return popcnt32((a[0] ^ b[0]) >>> 0) + popcnt32((a[1] ^ b[1]) >>> 0);
}

// ---- API em bigint (compatibilidade com scripts/phash-validate.ts) ----

export function phashFromGray32(gray: Uint8Array | Float64Array): bigint {
  const [hi, lo] = phashPair(gray);
  return (BigInt(hi) << 32n) | BigInt(lo);
}

export function hamming(a: bigint, b: bigint): number {
  let x = a ^ b;
  let count = 0;
  while (x) { x &= x - 1n; count++; }
  return count;
}

export const PHASH_INPUT_SIZE = N;
