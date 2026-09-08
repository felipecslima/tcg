/**
 * Extrai o número de coletor de um texto bruto de OCR. O número impresso
 * costuma aparecer como "N/M" (ex. "4/102", "004/198"), mas também como
 * token solto ou com prefixo de promo (SWSH039, TG12/TG30, GG01/GG70, H4).
 *
 * Devolvemos o NUMERADOR normalizado (a parte que casa com `card.number`
 * na pokemontcg.io) e, quando houver, o denominador — que confirma o set.
 */
import { normalizeNumber } from '../matching/normalize.js';

export interface ParsedNumber {
  number: string; // numerador normalizado, ex. "4", "SWSH39"
  denominator?: string; // ex. "102", "198" — bate com set.printedTotal
  raw: string; // trecho cru que casou
}

// "N/M" com prefixo alfabético opcional em cada lado (promos/trainer gallery).
// O denominador aceita até 4 dígitos: o OCR costuma colar um dígito espúrio
// nele ("154/7217", "010/7094"); quem consome decide se confia num total de
// 4 dígitos (o Recognizer não confia — usa o texto cru contra o impresso).
const FRACTION = /([A-Za-z]{0,4}\d{1,3})\s*[/／]\s*([A-Za-z]{0,4}\d{1,4})/;
// token com dígitos e prefixo opcional, quando não há barra visível.
const LONE = /\b([A-Za-z]{0,4}\d{1,3}[A-Za-z]?)\b/g;

export function parseCollectorNumber(rawText: string): ParsedNumber | null {
  const text = rawText.replace(/\s+/g, ' ').trim();

  const frac = text.match(FRACTION);
  if (frac) {
    return {
      number: normalizeNumber(frac[1]),
      denominator: normalizeNumber(frac[2]),
      raw: frac[0],
    };
  }

  // Sem barra: escolhe o token numérico mais "número-de-carta" (curto, poucos dígitos).
  const candidates = [...text.matchAll(LONE)]
    .map((m) => m[1])
    .filter((t) => /\d/.test(t) && t.replace(/\D/g, '').length <= 3);
  if (candidates.length) {
    // prefere o menor (números de carta raramente passam de 3 dígitos)
    candidates.sort((a, b) => a.replace(/\D/g, '').length - b.replace(/\D/g, '').length);
    return { number: normalizeNumber(candidates[0]), raw: candidates[0] };
  }
  return null;
}
