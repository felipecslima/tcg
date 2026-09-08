/**
 * Captura de frame ao vivo e geração das variantes de recorte/pré-processamento
 * pro OCR — espelha, no canvas, o mesmo sweep validado no node (2 cantos ×
 * normalize/threshold/negate). Sem shutter: o chamador roda em loop.
 */

export interface OcrVariant {
  source: string; // ex. "left/thNeg"
  canvas: HTMLCanvasElement;
}

/** Caixas onde o número costuma estar (fração da fonte). Igual ao node. */
const BOXES: Record<'right' | 'left', { left: number; top: number; width: number; height: number }> = {
  right: { left: 0.78, top: 0.95, width: 0.21, height: 0.05 },
  left: { left: 0.03, top: 0.9, width: 0.36, height: 0.075 },
};

/** Abre a câmera traseira (quando houver) num <video>. */
export async function startCamera(video: HTMLVideoElement): Promise<MediaStream> {
  const stream = await navigator.mediaDevices.getUserMedia({
    video: { facingMode: { ideal: 'environment' }, width: { ideal: 1280 }, height: { ideal: 720 } },
    audio: false,
  });
  video.srcObject = stream;
  await video.play();
  return stream;
}

type Src = HTMLVideoElement | HTMLImageElement | HTMLCanvasElement;

function srcSize(src: Src): { w: number; h: number } {
  if (src instanceof HTMLVideoElement) return { w: src.videoWidth, h: src.videoHeight };
  if (src instanceof HTMLImageElement) return { w: src.naturalWidth, h: src.naturalHeight };
  return { w: src.width, h: src.height };
}

/**
 * Gera as variantes de OCR a partir de uma fonte (vídeo/imagem/canvas).
 * `area` opcional restringe a fonte à caixa-guia (quando a carta está
 * enquadrada num retângulo na tela); por padrão usa o frame inteiro.
 */
export function makeOcrVariants(src: Src, area?: { x: number; y: number; w: number; h: number }): OcrVariant[] {
  const { w: sw, h: sh } = srcSize(src);
  const base = area ?? { x: 0, y: 0, w: sw, h: sh };
  const out: OcrVariant[] = [];
  const SCALE = 5;

  for (const [corner, b] of Object.entries(BOXES) as [keyof typeof BOXES, (typeof BOXES)['left']][]) {
    const rx = base.x + base.w * b.left;
    const ry = base.y + base.h * b.top;
    const rw = base.w * b.width;
    const rh = base.h * b.height;

    // recorta + escala em tons de cinza com contraste (equivale a grayscale+normalize)
    const gray = document.createElement('canvas');
    gray.width = Math.max(3, Math.round(rw * SCALE));
    gray.height = Math.max(3, Math.round(rh * SCALE));
    const gctx = gray.getContext('2d')!;
    gctx.filter = 'grayscale(1) contrast(1.5) brightness(1.05)';
    gctx.drawImage(src, rx, ry, rw, rh, 0, 0, gray.width, gray.height);

    out.push({ source: `${corner}/norm`, canvas: gray });
    out.push({ source: `${corner}/th`, canvas: threshold(gray, 120, false) });
    out.push({ source: `${corner}/thNeg`, canvas: threshold(gray, 150, true) });
    out.push({ source: `${corner}/hiNeg`, canvas: threshold(gray, 185, true) });
  }
  return out;
}

/**
 * Caixas do NÚMERO DE COLETOR, em fração de uma carta RETIFICADA (frontal).
 * Iguais às de scripts/e2e-validate.ts — o harness calibra, o browser segue.
 *   num   — SÓ os dígitos do número no layout moderno (SV/ME: "[G] [PAF PT] 028/091 ◆",
 *           linha em y≈0.938–0.966, dígitos em x≈0.17–0.29). Sem os selos à
 *           esquerda o Tesseract lê 3× mais frações certas (medido no harness).
 *   left  — faixa larga (fallback pra layouts SWSH e anteriores).
 *   right — layouts antigos (XY e antes) com o número à direita.
 */
export const NUMBER_BOXES = {
  num: { left: 0.14, top: 0.937, width: 0.24, height: 0.033 },
  left: { left: 0.03, top: 0.9, width: 0.36, height: 0.075 },
  right: { left: 0.6, top: 0.93, width: 0.38, height: 0.05 },
} as const;

export interface NumberVariant extends OcrVariant { box: keyof typeof NUMBER_BOXES }

/**
 * Variantes de OCR do rodapé de uma carta RETIFICADA (canvas em alta
 * resolução), pro gate de número do Recognizer. Só pré-processamentos que leem
 * de verdade: cinza+contraste em duas intensidades (threshold+negate foi
 * medido morto — 0 leituras em 65 frames — e saiu). Ordenadas por caixa; o
 * chamador para na primeira caixa que produz uma fração.
 */
export function makeNumberVariants(src: HTMLCanvasElement): NumberVariant[] {
  const out: NumberVariant[] = [];
  const SCALE = 4;
  for (const [box, b] of Object.entries(NUMBER_BOXES) as [keyof typeof NUMBER_BOXES, (typeof NUMBER_BOXES)['num']][]) {
    const rx = src.width * b.left, ry = src.height * b.top, rw = src.width * b.width, rh = src.height * b.height;
    for (const [pipe, filter] of [['norm', 'grayscale(1) contrast(1.5) brightness(1.05)'], ['hard', 'grayscale(1) contrast(2.2) brightness(1.1)']] as const) {
      const c = document.createElement('canvas');
      c.width = Math.max(3, Math.round(rw * SCALE));
      c.height = Math.max(3, Math.round(rh * SCALE));
      const ctx = c.getContext('2d')!;
      ctx.imageSmoothingEnabled = true; ctx.imageSmoothingQuality = 'high';
      ctx.filter = filter;
      ctx.drawImage(src, rx, ry, rw, rh, 0, 0, c.width, c.height);
      out.push({ source: `${box}/${pipe}`, canvas: c, box });
    }
  }
  return out;
}

/** Binariza (e opcionalmente inverte) um canvas em tons de cinza. */
function threshold(srcCanvas: HTMLCanvasElement, level: number, negate: boolean): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = srcCanvas.width;
  c.height = srcCanvas.height;
  const ctx = c.getContext('2d')!;
  ctx.drawImage(srcCanvas, 0, 0);
  const img = ctx.getImageData(0, 0, c.width, c.height);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    let v = d[i] >= level ? 255 : 0;
    if (negate) v = 255 - v;
    d[i] = d[i + 1] = d[i + 2] = v;
  }
  ctx.putImageData(img, 0, 0);
  return c;
}
