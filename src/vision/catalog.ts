/**
 * Índice do catálogo: descritores pré-computados de TODAS as cartas,
 * embarcados como JSON compacto (≈200 bytes/carta). Busca global por
 * distância combinada em milissegundos — sem pré-filtro de set obrigatório.
 *
 * Gerado por scripts/build-index.ts a partir da TCGdex (PT).
 */
import { popcnt32 } from '../scanner/phash.js';
import { type Descriptor, unpackHashes, W_FULL, W_ARTD, W_COLOR } from './descriptor.js';
import type { CardRecord } from '../matching/types.js';

export interface IndexCard {
  id: string; // ex. "sv08.5-075"
  name: string; // nome impresso (PT)
  number: string; // localId impresso, ex. "075"
  setId: string;
  setName: string;
  printedTotal: number; // denominador impresso
  series: string;
  image: string; // base URL TCGdex (anexar /low.webp, /high.webp)
}

export interface IndexSet { id: string; name: string; series: string; count: number }

export interface IndexJSON {
  v: 1;
  source: string;
  builtAt: string;
  sets: IndexSet[];
  cards: (IndexCard & { d: string; c: number[] })[];
}

export interface SearchHit { card: IndexCard; dist: number }

export interface SearchOptions {
  setIds?: Set<string>; // filtro opcional (acelerador, não pré-requisito)
  exclude?: Set<string>; // usado nos testes de "carta fora do catálogo"
  k?: number;
}

export function imageUrl(card: IndexCard, size: 'low' | 'high' = 'low'): string {
  return `${card.image}/${size}.webp`;
}

/** Converte pro CardRecord do motor de número (SetIndex), pra desempate. */
export function toCardRecord(c: IndexCard): CardRecord {
  return {
    id: c.id, name: c.name, number: c.number, setId: c.setId, setName: c.setName,
    printedTotal: c.printedTotal, imageSmall: imageUrl(c),
  };
}

export class CardIndex {
  readonly cards: IndexCard[];
  readonly sets: IndexSet[];
  readonly source: string;
  private readonly h: Uint32Array; // 6 palavras por carta
  private readonly col: Uint8Array; // 12 bytes por carta
  private readonly byId = new Map<string, number>();

  private constructor(json: IndexJSON) {
    this.source = json.source;
    this.sets = json.sets;
    this.cards = json.cards.map(({ d: _d, c: _c, ...card }) => card);
    const n = json.cards.length;
    this.h = new Uint32Array(n * 6);
    this.col = new Uint8Array(n * 12);
    json.cards.forEach((c, i) => {
      unpackHashes(c.d, this.h, i * 6);
      for (let j = 0; j < 12; j++) this.col[i * 12 + j] = c.c[j] ?? 0;
      this.byId.set(c.id, i);
    });
  }

  static fromJSON(json: IndexJSON): CardIndex {
    if (json.v !== 1) throw new Error(`índice versão ${json.v} não suportada`);
    return new CardIndex(json);
  }

  get size(): number { return this.cards.length; }

  get(id: string): IndexCard | undefined {
    const i = this.byId.get(id);
    return i === undefined ? undefined : this.cards[i];
  }

  /** Distância combinada entre duas cartas DO ÍNDICE (descritores armazenados). */
  private pairDistance(i: number, j: number): number {
    const h = this.h, oa = i * 6, ob = j * 6;
    let d = popcnt32((h[oa] ^ h[ob]) >>> 0) + popcnt32((h[oa + 1] ^ h[ob + 1]) >>> 0);
    d += W_FULL * (popcnt32((h[oa + 2] ^ h[ob + 2]) >>> 0) + popcnt32((h[oa + 3] ^ h[ob + 3]) >>> 0));
    d += W_ARTD * (popcnt32((h[oa + 4] ^ h[ob + 4]) >>> 0) + popcnt32((h[oa + 5] ^ h[ob + 5]) >>> 0));
    let l1 = 0;
    for (let k = 0; k < 12; k++) l1 += Math.abs(this.col[i * 12 + k] - this.col[j * 12 + k]);
    return d + (W_COLOR * l1) / 255;
  }

  /**
   * "Gêmeas" visuais de uma carta: outras impressões da MESMA arte (reprints),
   * indistinguíveis por hash — medido no catálogo SV+ME: ~10% das cartas têm
   * uma gêmea a distância ≤5 e a carta diferente mais próxima fica ≥35. Só o
   * número de coletor separa gêmeas; o Recognizer usa isto pra exigir o número
   * antes de confirmar uma carta que tem gêmea. Respeita `exclude`/`setIds`
   * (o que não está no catálogo pesquisável não conta como gêmea).
   * Varredura linear: ~ms mesmo com 20k cartas, chamada uma vez por candidata.
   */
  twinsOf(id: string, opts: { maxDist: number; exclude?: Set<string>; setIds?: Set<string> }): IndexCard[] {
    const i = this.byId.get(id);
    if (i === undefined) return [];
    const out: IndexCard[] = [];
    for (let j = 0; j < this.cards.length; j++) {
      if (j === i) continue;
      const c = this.cards[j];
      if (opts.setIds && !opts.setIds.has(c.setId)) continue;
      if (opts.exclude && opts.exclude.has(c.id)) continue;
      if (this.pairDistance(i, j) <= opts.maxDist) out.push(c);
    }
    return out;
  }

  /** Distância do descritor até UMA carta (pra validação). */
  distanceTo(q: Descriptor, id: string): number | null {
    const i = this.byId.get(id);
    if (i === undefined) return null;
    const o = i * 6, h = this.h;
    let d = popcnt32((h[o] ^ q.artP[0]) >>> 0) + popcnt32((h[o + 1] ^ q.artP[1]) >>> 0);
    d += W_FULL * (popcnt32((h[o + 2] ^ q.fullP[0]) >>> 0) + popcnt32((h[o + 3] ^ q.fullP[1]) >>> 0));
    d += W_ARTD * (popcnt32((h[o + 4] ^ q.artD[0]) >>> 0) + popcnt32((h[o + 5] ^ q.artD[1]) >>> 0));
    let l1 = 0;
    for (let j = 0; j < 12; j++) l1 += Math.abs(this.col[i * 12 + j] - q.color[j]);
    return d + (W_COLOR * l1) / 255;
  }

  /** Top-k por distância combinada. Varre tudo: ~20k cartas em poucos ms. */
  search(q: Descriptor, opts: SearchOptions = {}): SearchHit[] {
    const k = opts.k ?? 5;
    const best: { i: number; d: number }[] = [];
    const [aHi, aLo] = q.artP, [fHi, fLo] = q.fullP, [dHi, dLo] = q.artD;
    const qc = q.color;
    const h = this.h, col = this.col;
    for (let i = 0; i < this.cards.length; i++) {
      const c = this.cards[i];
      if (opts.setIds && !opts.setIds.has(c.setId)) continue;
      if (opts.exclude && opts.exclude.has(c.id)) continue;
      const o = i * 6;
      let d = popcnt32((h[o] ^ aHi) >>> 0) + popcnt32((h[o + 1] ^ aLo) >>> 0);
      d += W_FULL * (popcnt32((h[o + 2] ^ fHi) >>> 0) + popcnt32((h[o + 3] ^ fLo) >>> 0));
      d += W_ARTD * (popcnt32((h[o + 4] ^ dHi) >>> 0) + popcnt32((h[o + 5] ^ dLo) >>> 0));
      let l1 = 0;
      const co = i * 12;
      for (let j = 0; j < 12; j++) l1 += Math.abs(col[co + j] - qc[j]);
      d += (W_COLOR * l1) / 255;
      // insere mantendo top-k ordenado
      if (best.length < k || d < best[best.length - 1].d) {
        let p = best.length;
        while (p > 0 && best[p - 1].d > d) p--;
        best.splice(p, 0, { i, d });
        if (best.length > k) best.pop();
      }
    }
    return best.map((b) => ({ card: this.cards[b.i], dist: b.d }));
  }
}
