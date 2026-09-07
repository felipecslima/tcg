/**
 * Tipos do núcleo de matching. Puros, sem dependência de framework —
 * portáveis pro Angular (Signals) quando o produto sair do protótipo.
 */

/** Registro mínimo de uma carta, subconjunto do payload da pokemontcg.io. */
export interface CardRecord {
  id: string; // ex. "base1-4"
  name: string; // sempre em inglês na API
  number: string; // número de coletor impresso, ex. "4"
  setId: string; // ex. "base1"
  setName: string; // ex. "Base"
  printedTotal: number; // denominador impresso (o "102" de "4/102")
  rarity?: string;
  imageSmall?: string;
  nationalPokedexNumbers?: number[];
}

/**
 * O que sai do reconhecimento (OCR/visão) de um frame, antes do matching.
 * `setId` vem do PRÉ-FILTRO escolhido pelo usuário no início do lote —
 * é a principal alavanca de precisão.
 */
export interface ScanInput {
  setId: string;
  number?: string; // âncora primária, idêntica em qualquer idioma
  name?: string; // só ajuda em cartas inglesas; desempate secundário
  rawText?: string; // texto bruto do OCR, pra depuração/fallback
}

export type MatchStatus =
  | 'matched' // confiança alta, entra direto na fila do lote
  | 'ambiguous' // vários candidatos plausíveis, precisa de desempate
  | 'unmatched'; // abaixo do mínimo → pilha de pendências (manual)

export interface MatchResult {
  status: MatchStatus;
  confidence: number; // 0..1
  card?: CardRecord; // melhor candidato (se houver)
  alternatives: CardRecord[]; // outros candidatos, ordenados por score
  reason: string; // explicação curta pra UI/depuração
}
