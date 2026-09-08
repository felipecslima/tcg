/**
 * Primitivas de imagem PURAS (sem canvas, sem sharp) — rodam idênticas no
 * browser e no node. Tudo que o motor de visão precisa: cinza, reamostragem
 * por média de área, contraste, Sobel, homografia e warp perspectivo.
 *
 * A regra de ouro do motor é: o MESMO código gera o hash do catálogo (node) e
 * o hash do frame da câmera (browser). Qualquer diferença de pipeline entre os
 * dois lados vira distância espúria — por isso nada aqui depende de ambiente.
 */

export interface RGBA {
  data: Uint8ClampedArray | Uint8Array;
  width: number;
  height: number;
}
export interface Pt { x: number; y: number }
export interface Rect { x: number; y: number; w: number; h: number }
/** Cantos no sentido horário a partir do topo-esquerdo: TL, TR, BR, BL. */
export type Quad = [Pt, Pt, Pt, Pt];

/** Luminância 0..255 (Rec.601). */
export function toGray(img: RGBA): Float32Array {
  const { data, width, height } = img;
  const n = width * height;
  const g = new Float32Array(n);
  for (let i = 0, j = 0; i < n; i++, j += 4) g[i] = 0.299 * data[j] + 0.587 * data[j + 1] + 0.114 * data[j + 2];
  return g;
}

/**
 * Reamostragem por média de área (box filter separável) pra `ch` canais.
 * Reduzir com anti-alias correto é o que deixa o hash estável entre uma
 * imagem de catálogo e um frame de câmera de resolução diferente.
 */
export function resampleArea(
  src: ArrayLike<number>, sw: number, sh: number, ch: number, dw: number, dh: number,
): Float32Array {
  const tmp = new Float32Array(dw * sh * ch);
  const sx = sw / dw;
  for (let dx = 0; dx < dw; dx++) {
    const s0 = dx * sx, s1 = s0 + sx;
    const i0 = Math.floor(s0), i1 = Math.min(sw - 1, Math.ceil(s1) - 1);
    for (let y = 0; y < sh; y++) {
      for (let c = 0; c < ch; c++) {
        let acc = 0, wsum = 0;
        for (let i = i0; i <= i1; i++) {
          const w = Math.min(s1, i + 1) - Math.max(s0, i);
          if (w <= 0) continue;
          acc += src[(y * sw + i) * ch + c] * w; wsum += w;
        }
        tmp[(y * dw + dx) * ch + c] = wsum > 0 ? acc / wsum : 0;
      }
    }
  }
  const out = new Float32Array(dw * dh * ch);
  const sy = sh / dh;
  for (let dy = 0; dy < dh; dy++) {
    const s0 = dy * sy, s1 = s0 + sy;
    const j0 = Math.floor(s0), j1 = Math.min(sh - 1, Math.ceil(s1) - 1);
    for (let x = 0; x < dw; x++) {
      for (let c = 0; c < ch; c++) {
        let acc = 0, wsum = 0;
        for (let j = j0; j <= j1; j++) {
          const w = Math.min(s1, j + 1) - Math.max(s0, j);
          if (w <= 0) continue;
          acc += tmp[(j * dw + x) * ch + c] * w; wsum += w;
        }
        out[(dy * dw + x) * ch + c] = wsum > 0 ? acc / wsum : 0;
      }
    }
  }
  return out;
}

export function cropGray(src: ArrayLike<number>, sw: number, x: number, y: number, w: number, h: number): Float32Array {
  const out = new Float32Array(w * h);
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) out[j * w + i] = src[(y + j) * sw + (x + i)];
  return out;
}

export function cropRGBA(img: RGBA, x: number, y: number, w: number, h: number): RGBA {
  const out = new Uint8ClampedArray(w * h * 4);
  for (let j = 0; j < h; j++) {
    const srow = ((y + j) * img.width + x) * 4;
    out.set(img.data.subarray(srow, srow + w * 4), j * w * 4);
  }
  return { data: out, width: w, height: h };
}

/** Estica o contraste entre os percentis lo..hi — normaliza brilho/glare antes do hash. */
export function contrastStretch(g: Float32Array, lo = 0.02, hi = 0.98): Float32Array {
  const hist = new Uint32Array(256);
  for (let i = 0; i < g.length; i++) hist[Math.max(0, Math.min(255, g[i] | 0))]++;
  const n = g.length;
  let acc = 0, vlo = 0, vhi = 255;
  for (let v = 0; v < 256; v++) { acc += hist[v]; if (acc >= n * lo) { vlo = v; break; } }
  acc = 0;
  for (let v = 255; v >= 0; v--) { acc += hist[v]; if (acc >= n * (1 - hi)) { vhi = v; break; } }
  const out = new Float32Array(n);
  if (vhi - vlo < 8) { out.set(g); return out; }
  const k = 255 / (vhi - vlo);
  for (let i = 0; i < n; i++) out[i] = Math.max(0, Math.min(255, (g[i] - vlo) * k));
  return out;
}

/**
 * Amostra `g` em (x,y) com índices grampeados na borda (clamp-to-edge).
 * Sem isso, ler fora de [0,w)×[0,h) "vê" zero — e como o fundo da carta
 * quase nunca é preto, isso cria um degrau de gradiente FALSO bem na
 * margem do frame, que a detecção de borda confundia com a moldura da
 * carta. Clampar replica o pixel de borda em vez de inventar preto.
 */
function clampAt(g: Float32Array, w: number, h: number, x: number, y: number): number {
  const cx = x < 0 ? 0 : x >= w ? w - 1 : x;
  const cy = y < 0 ? 0 : y >= h ? h - 1 : y;
  return g[cy * w + cx];
}

export function boxBlur3(g: Float32Array, w: number, h: number): Float32Array {
  const out = new Float32Array(w * h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let s = 0;
      for (let j = -1; j <= 1; j++) for (let i = -1; i <= 1; i++) s += clampAt(g, w, h, x + i, y + j);
      out[y * w + x] = s / 9;
    }
  }
  return out;
}

/** Sobel: gradientes normalizados pra ~0..255, incluindo a borda (clamp-to-edge). */
export function sobel(g: Float32Array, w: number, h: number): { gx: Float32Array; gy: Float32Array } {
  const gx = new Float32Array(w * h), gy = new Float32Array(w * h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = y * w + x;
      const a = clampAt(g, w, h, x - 1, y - 1), b = clampAt(g, w, h, x, y - 1), c = clampAt(g, w, h, x + 1, y - 1);
      const d = clampAt(g, w, h, x - 1, y), f = clampAt(g, w, h, x + 1, y);
      const gg = clampAt(g, w, h, x - 1, y + 1), hh = clampAt(g, w, h, x, y + 1), k = clampAt(g, w, h, x + 1, y + 1);
      gx[i] = (c + 2 * f + k - a - 2 * d - gg) / 4;
      gy[i] = (gg + 2 * hh + k - a - 2 * b - c) / 4;
    }
  }
  return { gx, gy };
}

/** Homografia 3x3 (row-major) que leva os 4 pontos `src` nos 4 `dst` (DLT). */
export function homography(src: Quad, dst: Quad): Float64Array {
  const A: number[][] = [];
  for (let i = 0; i < 4; i++) {
    const { x, y } = src[i], { x: u, y: v } = dst[i];
    A.push([x, y, 1, 0, 0, 0, -u * x, -u * y, u]);
    A.push([0, 0, 0, x, y, 1, -v * x, -v * y, v]);
  }
  // eliminação de Gauss com pivô parcial, 8 incógnitas
  for (let c = 0; c < 8; c++) {
    let p = c;
    for (let r = c + 1; r < 8; r++) if (Math.abs(A[r][c]) > Math.abs(A[p][c])) p = r;
    [A[c], A[p]] = [A[p], A[c]];
    const piv = A[c][c] || 1e-12;
    for (let k = c; k < 9; k++) A[c][k] /= piv;
    for (let r = 0; r < 8; r++) {
      if (r === c) continue;
      const f = A[r][c];
      if (f === 0) continue;
      for (let k = c; k < 9; k++) A[r][k] -= f * A[c][k];
    }
  }
  const H = new Float64Array(9);
  for (let i = 0; i < 8; i++) H[i] = A[i][8];
  H[8] = 1;
  return H;
}

export function applyH(H: Float64Array, x: number, y: number): Pt {
  const w = H[6] * x + H[7] * y + H[8];
  return { x: (H[0] * x + H[1] * y + H[2]) / w, y: (H[3] * x + H[4] * y + H[5]) / w };
}

/** Amostra bilinear de um canal RGBA em (x,y) contínuo; fora da imagem satura na borda. */
function sampleBilinear(img: RGBA, x: number, y: number, out: Uint8ClampedArray, o: number): void {
  const { data, width, height } = img;
  const xc = Math.max(0, Math.min(width - 1.001, x)), yc = Math.max(0, Math.min(height - 1.001, y));
  const x0 = xc | 0, y0 = yc | 0, fx = xc - x0, fy = yc - y0;
  const i00 = (y0 * width + x0) * 4, i10 = i00 + 4, i01 = i00 + width * 4, i11 = i01 + 4;
  for (let c = 0; c < 3; c++) {
    const top = data[i00 + c] * (1 - fx) + data[i10 + c] * fx;
    const bot = data[i01 + c] * (1 - fx) + data[i11 + c] * fx;
    out[o + c] = top * (1 - fy) + bot * fy;
  }
  out[o + 3] = 255;
}

/**
 * Retifica: tira o quadrilátero `corners` da imagem e devolve-o como um
 * retângulo W×H frontal. É o que transforma "carta torta na mesa" em
 * "carta de catálogo" — sem isso nenhum hash global funciona em câmera.
 */
export function warpQuad(img: RGBA, corners: Quad, W: number, H: number): RGBA {
  const dst: Quad = [{ x: 0, y: 0 }, { x: W, y: 0 }, { x: W, y: H }, { x: 0, y: H }];
  const Hm = homography(dst, corners); // destino -> origem
  const out = new Uint8ClampedArray(W * H * 4);
  for (let v = 0; v < H; v++) {
    for (let u = 0; u < W; u++) {
      const p = applyH(Hm, u + 0.5, v + 0.5);
      sampleBilinear(img, p.x - 0.5, p.y - 0.5, out, (v * W + u) * 4);
    }
  }
  return { data: out, width: W, height: H };
}

/** Reduz um RGBA por média de área (usado pra baratear a detecção). */
export function downscaleRGBA(img: RGBA, dw: number, dh: number): RGBA {
  const f = resampleArea(img.data, img.width, img.height, 4, dw, dh);
  const out = new Uint8ClampedArray(f.length);
  for (let i = 0; i < f.length; i++) out[i] = f[i];
  return { data: out, width: dw, height: dh };
}

export function quadArea(q: Quad): number {
  let a = 0;
  for (let i = 0; i < 4; i++) { const p = q[i], n = q[(i + 1) % 4]; a += p.x * n.y - n.x * p.y; }
  return Math.abs(a) / 2;
}

export function isConvex(q: Quad): boolean {
  let sign = 0;
  for (let i = 0; i < 4; i++) {
    const a = q[i], b = q[(i + 1) % 4], c = q[(i + 2) % 4];
    const cr = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
    const s = Math.sign(cr);
    if (s === 0) continue;
    if (sign === 0) sign = s; else if (s !== sign) return false;
  }
  return true;
}
