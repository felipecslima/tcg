/**
 * Motor de matching. Ancora em NÚMERO + SET (language-agnostic) e usa o
 * NOME apenas como confirmação/desempate secundário — o que torna cartas
 * em português automaticamente reconhecíveis quando o número é legível.
 *
 * Uso no lote:
 *   const index = SetIndex.from(await fetchSetCards('base1'));
 *   const result = index.match({ setId: 'base1', number: '4' });
 */
import type { CardRecord, ScanInput, MatchResult } from './types.js';
import { normalizeNumber, numberOcrVariants, normalizeName } from './normalize.js';
import { similarityRatio } from './similarity.js';

export interface MatchOptions {
  /** Confiança mínima pra 'matched'. Abaixo disso vira pendência. */
  minConfidence?: number;
  /** Diferença mínima de score entre 1º e 2º nome pra não ser 'ambiguous'. */
  nameMargin?: number;
}

const DEFAULTS: Required<MatchOptions> = { minConfidence: 0.7, nameMargin: 0.12 };

export class SetIndex {
  readonly setId: string;
  private readonly byNumber = new Map<string, CardRecord[]>();
  private readonly cards: CardRecord[];
  private readonly normNames: string[];

  private constructor(cards: CardRecord[]) {
    this.cards = cards;
    this.setId = cards[0]?.setId ?? '';
    this.normNames = cards.map((c) => normalizeName(c.name));
    for (const c of cards) {
      const key = normalizeNumber(c.number);
      const arr = this.byNumber.get(key);
      if (arr) arr.push(c);
      else this.byNumber.set(key, [c]);
    }
  }

  static from(cards: CardRecord[]): SetIndex {
    if (!cards.length) throw new Error('SetIndex.from: lista de cartas vazia');
    return new SetIndex(cards);
  }

  get size(): number {
    return this.cards.length;
  }

  /** Casa uma leitura de scan contra o set indexado. */
  match(input: ScanInput, options: MatchOptions = {}): MatchResult {
    const opt = { ...DEFAULTS, ...options };

    // 1) Caminho primário: número (tentando variantes de OCR).
    if (input.number && input.number.trim()) {
      for (const variant of numberOcrVariants(input.number)) {
        const hits = this.byNumber.get(variant);
        if (hits && hits.length) {
          return this.resolveByNumber(hits, input, opt, variant !== normalizeNumber(input.number));
        }
      }
      // número lido mas não existe no set → tenta nome antes de desistir
    }

    // 2) Caminho secundário: nome (só funciona bem em cartas inglesas).
    if (input.name && input.name.trim()) {
      return this.resolveByName(input, opt);
    }

    return {
      status: 'unmatched',
      confidence: 0,
      alternatives: [],
      reason: input.number
        ? `Número "${input.number}" não existe no set ${this.setId} e nenhum nome legível.`
        : 'Sem número nem nome legíveis.',
    };
  }

  /** Um ou mais candidatos compartilham o número. */
  private resolveByNumber(
    hits: CardRecord[],
    input: ScanInput,
    opt: Required<MatchOptions>,
    usedOcrVariant: boolean,
  ): MatchResult {
    // Único candidato: match forte. Número é âncora confiável.
    if (hits.length === 1) {
      const card = hits[0];
      let confidence = usedOcrVariant ? 0.85 : 0.92;
      let reason = `Número ${card.number} único no set ${this.setId}.`;

      if (input.name && input.name.trim()) {
        const ratio = similarityRatio(normalizeName(input.name), normalizeName(card.name));
        if (ratio >= 0.6) {
          confidence = Math.min(0.99, confidence + 0.07);
          reason += ` Nome confirma (sim=${ratio.toFixed(2)}).`;
        } else {
          // nome diverge: esperado em cartas PT (nome impresso ≠ inglês).
          // Não penalizamos forte — o número manda.
          reason += ` Nome diverge (sim=${ratio.toFixed(2)}); provável carta não-inglesa.`;
        }
      }
      return { status: 'matched', confidence, card, alternatives: [], reason };
    }

    // Colisão de número (variantes/promos): desempata por nome se houver.
    if (input.name && input.name.trim()) {
      const scored = hits
        .map((c) => ({ c, r: similarityRatio(normalizeName(input.name!), normalizeName(c.name)) }))
        .sort((a, b) => b.r - a.r);
      const [best, second] = scored;
      if (best.r >= 0.6 && (!second || best.r - second.r >= opt.nameMargin)) {
        return {
          status: 'matched',
          confidence: Math.min(0.95, 0.75 + best.r * 0.2),
          card: best.c,
          alternatives: scored.slice(1).map((s) => s.c),
          reason: `Número compartilhado por ${hits.length}; nome desempatou (sim=${best.r.toFixed(2)}).`,
        };
      }
    }
    return {
      status: 'ambiguous',
      confidence: 0.5,
      card: hits[0],
      alternatives: hits.slice(1),
      reason: `Número ${normalizeNumber(hits[0].number)} tem ${hits.length} candidatos e o nome não desempatou.`,
    };
  }

  /** Sem número legível: fuzzy no nome sobre o set inteiro. */
  private resolveByName(input: ScanInput, opt: Required<MatchOptions>): MatchResult {
    const q = normalizeName(input.name!);
    const scored = this.cards
      .map((c, i) => ({ c, r: similarityRatio(q, this.normNames[i]) }))
      .sort((a, b) => b.r - a.r);
    const [best, second] = scored;
    if (best.r >= opt.minConfidence && (!second || best.r - second.r >= opt.nameMargin)) {
      return {
        status: 'matched',
        confidence: best.r,
        card: best.c,
        alternatives: scored.slice(1, 4).map((s) => s.c),
        reason: `Sem número; nome casou (sim=${best.r.toFixed(2)}).`,
      };
    }
    if (best.r >= 0.5) {
      return {
        status: 'ambiguous',
        confidence: best.r,
        card: best.c,
        alternatives: scored.slice(1, 4).map((s) => s.c),
        reason: `Sem número; melhor nome sim=${best.r.toFixed(2)}, sem margem clara.`,
      };
    }
    return {
      status: 'unmatched',
      confidence: best.r,
      alternatives: scored.slice(0, 3).map((s) => s.c),
      reason: `Sem número e nenhum nome próximo (melhor sim=${best.r.toFixed(2)}).`,
    };
  }
}
