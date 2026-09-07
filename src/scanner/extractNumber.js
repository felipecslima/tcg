/**
 * Extração do número de coletor com VALIDAÇÃO CRUZADA contra o set.
 *
 * Como o set já está escolhido (pré-filtro), conhecemos todos os números
 * válidos. Então rodamos OCR em várias regiões/pré-processamentos e aceitamos
 * a primeira leitura cujo número EXISTE no set (e cujo denominador, se lido,
 * bate com o printedTotal). Isso transforma OCR ruidoso em decisão confiável
 * sem depender de uma única leitura perfeita.
 *
 * Este módulo é agnóstico de plataforma: recebe uma função `ocr(region)` que
 * já sabe recortar+pré-processar+ler. No browser vem do canvas; no node, do sharp.
 */
import { parseCollectorNumber } from './numberParse.js';
import { normalizeNumber } from '../matching/normalize.js';
/** Números válidos do set, normalizados, pra validação cruzada rápida. */
export function validNumberSet(cards) {
    return new Set(cards.map((c) => normalizeNumber(c.number)));
}
/**
 * Percorre as variantes de OCR (cada uma já devolve texto cru), parseia e
 * escolhe a melhor. Preferência: existe-no-set + denominador-bate > existe-no-set
 * > qualquer parse. `printedTotal` valida o denominador.
 */
export function pickBestNumber(ocrResults, valid, printedTotal) {
    const tried = [];
    let inSet = null;
    let inSetDenom = null;
    let anyParse = null;
    for (const r of ocrResults) {
        const p = parseCollectorNumber(r.rawText);
        if (!p)
            continue;
        const cand = { number: p.number, denominator: p.denominator, source: r.source, rawText: r.rawText };
        tried.push(cand);
        anyParse ??= cand;
        if (valid.has(p.number)) {
            inSet ??= cand;
            // AUTO exige denominador PRESENTE e igual ao total do set — sem isso um
            // número solto mal-lido que por acaso existe no set vira falso-positivo.
            const denomOk = !!p.denominator && normalizeNumber(p.denominator) === String(printedTotal);
            if (denomOk)
                inSetDenom ??= cand;
        }
    }
    const best = inSetDenom ?? inSet ?? anyParse;
    return {
        best,
        validatedInSet: !!(inSetDenom ?? inSet),
        denomMatches: !!inSetDenom,
        tried,
    };
}
