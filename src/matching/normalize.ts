/**
 * Normalização de número de coletor e nome. O número é a âncora
 * language-agnostic do matching, então precisa ser robusto a ruído de OCR.
 */

/**
 * Normaliza o número de coletor pra uma chave estável.
 * Exemplos:
 *   "004"        -> "4"
 *   "4/102"      -> "4"        (descarta o denominador)
 *   " 4 "        -> "4"
 *   "SWSH039"    -> "SWSH39"   (preserva prefixo alfabético, zera padding)
 *   "TG12/TG30"  -> "TG12"
 *   "H4"         -> "H4"
 * OCR costuma confundir O<->0, l/I<->1, S<->5 — tratamos os casos comuns
 * no segmento numérico apenas.
 */
export function normalizeNumber(raw: string): string {
  if (!raw) return '';
  // fica com a parte antes da barra (numerador)
  let s = raw.trim().toUpperCase().split('/')[0].trim();
  // remove tudo que não for alfanumérico
  s = s.replace(/[^A-Z0-9]/g, '');
  // separa prefixo alfabético (ex. "SWSH", "TG", "H") do miolo numérico
  const m = s.match(/^([A-Z]*)(\d+)([A-Z]*)$/);
  if (!m) return s; // formato inesperado: devolve como está
  const [, prefix, digits, suffix] = m;
  const noPad = String(parseInt(digits, 10)); // remove zeros à esquerda
  return `${prefix}${noPad}${suffix}`;
}

/**
 * Correções de OCR comuns aplicadas SÓ quando a leitura crua falhar o
 * match exato — trocamos letras que costumam ser confundidas com dígitos.
 * Retorna variantes candidatas da leitura numérica (inclui a original).
 */
export function numberOcrVariants(raw: string): string[] {
  const base = normalizeNumber(raw);
  const variants = new Set<string>([base]);
  const swaps: Record<string, string> = { O: '0', Q: '0', I: '1', L: '1', S: '5', B: '8', Z: '2', G: '6' };
  // aplica trocas no segmento inteiro (número é curto, custo desprezível)
  const swapped = raw
    .toUpperCase()
    .split('')
    .map((c) => swaps[c] ?? c)
    .join('');
  variants.add(normalizeNumber(swapped));
  return [...variants].filter(Boolean);
}

/** Remove acentos (NFD) — ajuda no casamento parcial de nomes romanizados. */
export function stripAccents(s: string): string {
  return s.normalize('NFD').replace(/[̀-ͯ]/g, '');
}

/**
 * Normaliza nome pra comparação: minúsculo, sem acento, sem pontuação,
 * espaços colapsados. Não remove sufixos (V/VMAX/ex/GX) — fazem parte do
 * nome e ajudam a distinguir impressões.
 */
export function normalizeName(raw: string): string {
  return stripAccents(raw)
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}
