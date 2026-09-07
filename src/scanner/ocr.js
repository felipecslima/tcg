/**
 * Wrapper do Tesseract.js pro browser. Worker único, reaproveitado entre
 * frames (criar worker é caro). Charset restrito a dígitos + prefixos de
 * promo e modo "linha única" — estamos lendo só o número do canto, não a arte.
 */
import { createWorker, PSM } from 'tesseract.js';
let workerPromise = null;
export function getOcrWorker() {
    if (!workerPromise) {
        workerPromise = (async () => {
            const w = await createWorker('eng');
            await w.setParameters({
                tessedit_char_whitelist: '0123456789/GHSWTGgg',
                tessedit_pageseg_mode: PSM.SINGLE_LINE,
            });
            return w;
        })();
    }
    return workerPromise;
}
/** Roda OCR numa fonte já recortada (canvas) e devolve o texto cru. */
export async function ocrText(source) {
    const w = await getOcrWorker();
    const { data } = await w.recognize(source);
    return data.text;
}
