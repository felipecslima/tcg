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
