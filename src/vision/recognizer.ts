/**
 * Motor de reconhecimento TEMPORAL — o que faz a câmera "devolver a carta
 * certa" como os apps de referência, em vez de chutar frame a frame.
 *
 * Por frame: detecta+retifica → descritor → top-k no índice → VOTA.
 * Os votos decaem exponencialmente; a carta vira CANDIDATA quando:
 *   - lidera por N frames seguidos (estabilidade temporal),
 *   - com razão de votos folgada sobre o 2º (não é empate),
 *   - e já chegou perto o bastante em algum frame da sequência.
 *
 * GATE DE NÚMERO antes de confirmar de vez. A arte sozinha não distingue
 * REPRINTS (mesma ilustração em sets diferentes): medido no catálogo, ~10%
 * das cartas têm uma "gêmea" a distância ≤5 — indistinguível por hash — e só
 * o número de coletor impresso as separa. Por isso, antes de travar a
 * candidata, o motor lê o rodapé por OCR num warp em alta resolução e compara
 * o texto lido com o número IMPRESSO esperado da candidata E das gêmeas
 * ("028/091" vs "085/198"), tolerando um dígito errado. O OCR erra de forma
 * previsível (perde o 1º dígito do numerador, cola um dígito no denominador),
 * então o denominador — o total do set, poucos valores distintos — funciona
 * como checksum: total certo + numerador parcial, duas vezes, confirma; total
 * de OUTRO set, duas vezes, rejeita (é uma gêmea, ou um reprint fora da base).
 *
 * Regra central (precisão > recall): carta COM gêmea só confirma com número
 * lido. Carta SEM gêmea (arte única no catálogo) pode confirmar só pelo
 * visual quando o número é ilegível — holo/full-art sem número legível é
 * exatamente o caso que o art-matching existe pra cobrir — e a confirmação
 * sai marcada como 'inconclusive' pra UI poder sinalizar.
 *
 * Quando a carta NÃO está no catálogo, a distância fica alta e o motor diz
 * "desconhecida" em vez de devolver a carta errada.
 */
import { warpQuad, type RGBA, type Rect } from './image.js';
import { detectCard, type Detection } from './detect.js';
import { describe, CARD_W, CARD_H } from './descriptor.js';
import { CardIndex, type SearchHit, type IndexCard } from './catalog.js';
import { normalizeNumber } from '../matching/normalize.js';

/**
 * Leitura do número de coletor. `number`/`denominator` vêm de um parse
 * genérico; `texts` são os textos CRUS do OCR (uma entrada por variante de
 * recorte/pré-processamento que produziu algo). O motor compara os textos
 * crus com o impresso esperado das candidatas — bem mais robusto que confiar
 * no parse. Sem `texts`, o motor reconstrói um texto a partir do parse.
 */
export interface NumberReading { number: string; denominator?: string; texts?: string[] }

/** Resolução do warp dedicado ao OCR (o de 256×358 do hash é pequeno demais pra ler dígitos). */
const OCR_W = CARD_W * 2, OCR_H = CARD_H * 2;

/** Limiares calibrados por scripts/e2e-validate.ts (frames sintéticos de câmera). */
export const THRESHOLDS = {
  VOTE_MAX_DIST: 58, // acima disso o frame não vota (provável não-carta/fora do catálogo)
  CONFIRM_MAX_DIST: 42, // a menor distância da sequência precisa estar assim perto (número LIDO e batendo)
  // Sem número lido, o visual sozinho decide — e aí o limiar é mais rígido:
  // medido com a detecção corrigida, a carta certa fica a p50=13 p90=30 p97=37
  // e o impostor mais próximo (fora reprints) a p10=43; os falsos-positivos de
  // "arte fora do catálogo" confirmavam com dist. mínima 38–42.
  CONFIRM_MAX_DIST_VISUAL: 32,
  CONFIRM_STREAK: 3, // frames seguidos liderando
  // votos acumulados mínimos. Com DECAY 0.78 o score satura em ~4.5× o peso
  // médio por frame (peso ≈ 0.25 a dist 43) → teto ≈ 1.1; 0.6 ≈ 3 frames bons.
  CONFIRM_MIN_SCORE: 0.6,
  CONFIRM_RATIO: 2.0, // líder ≥ 2× o 2º — prioriza precisão sobre recall
  DECAY: 0.78,
  NO_CARD_EDGE: 7, // força de borda abaixo disso + distância alta = sem carta
  OCR_EARLY_STREAK: 2, // começa a conferir o número assim que há um líder plausível
  OCR_MIN_INTERVAL_MS: 250, // intervalo mínimo entre tentativas de verificação
  OCR_MAX_ATTEMPTS: 3, // carta SEM gêmea: leituras inconclusivas antes de aceitar só o visual
  OCR_MAX_ATTEMPTS_TWIN: 8, // carta COM gêmea: nunca aceita só o visual; para de gastar OCR depois disto
  OCR_BOOST: 2.5, // reforço de votos pra gêmea cujo número bateu com a leitura
  TWIN_MAX_DIST: 20, // índice×índice: abaixo disso é a mesma arte (medido: reprints ≤5, o resto ≥35)
  RELEASE_FRAMES: 4, // frames sem carta pra liberar após confirmação
};

export type RecogState = 'idle' | 'no_card' | 'searching' | 'candidate' | 'confirmed' | 'unknown';

/** Como uma candidata passou o gate: número lido e batendo, ou só o visual (número ilegível, arte sem gêmea). */
export type VerificationMode = 'number' | 'inconclusive';

export interface Vote { card: SearchHit['card']; score: number }

export interface RecogResult {
  state: RecogState;
  best?: SearchHit; // melhor do frame atual
  hits: SearchHit[]; // top-k do frame atual
  votes: Vote[]; // acumulado, ordenado
  detection: Detection;
  streak: number;
  reason: string;
  /** Outras impressões da mesma arte (reprints) que só o número distingue — pra UI oferecer a escolha. */
  alternatives?: IndexCard[];
  /** Como a carta confirmada passou o gate (só em 'confirmed'). */
  verification?: VerificationMode;
}

export interface RecognizerOptions {
  setIds?: Set<string>;
  /** Só pra testes: finge que estas cartas não existem no catálogo. */
  exclude?: Set<string>;
  /** Lê o número de coletor numa carta retificada em alta resolução (OCR). Chamado antes de confirmar. */
  readNumber?: (rectifiedHiRes: RGBA) => Promise<NumberReading | null>;
  onConfirmed?: (hit: SearchHit, result: RecogResult) => void;
  /** Rastreio (testes/depuração): uma linha por decisão do gate de número. */
  debug?: (msg: string) => void;
  k?: number;
}

// ---------------------------------------------------------------------------
// Comparação de texto de OCR com o número impresso esperado
// ---------------------------------------------------------------------------

/** Formas como o número pode estar impresso: "028/091" (moderno, com zeros) e "28/91". */
export function printedForms(card: IndexCard): string[] {
  const n = card.number.trim(), m = String(card.printedTotal || '');
  const forms = new Set<string>();
  if (/^\d+$/.test(n) && m) {
    forms.add(`${n.padStart(3, '0')}/${m.padStart(3, '0')}`);
    forms.add(`${String(parseInt(n, 10))}/${m}`);
  } else if (m) forms.add(`${n}/${m}`); // promos/trainer gallery com prefixo
  else forms.add(/^\d+$/.test(n) ? n.padStart(3, '0') : n);
  return [...forms];
}

/** Só dígitos, barras e espaços simples — o que o OCR do rodapé devolve. */
function cleanOcrText(t: string): string {
  return t.toUpperCase().replace(/[^0-9A-Z/]+/g, ' ').replace(/\s*\/\s*/g, '/').trim();
}

/**
 * Distância de edição mínima entre `pattern` e QUALQUER trecho de `text`
 * (casamento aproximado de substring, algoritmo de Sellers). "6 84 87 028/091"
 * contém "028/091" → 0; "154/7217" vs "154/217" → 1; "3/198" vs "083/198" → 2.
 */
export function approxSubstringDistance(pattern: string, text: string): number {
  const m = pattern.length, n = text.length;
  if (!m) return 0;
  if (!n) return m;
  let prev = new Array<number>(n + 1).fill(0); // linha 0: casar padrão vazio custa 0 em qualquer posição
  let cur = new Array<number>(n + 1);
  for (let i = 1; i <= m; i++) {
    cur[0] = i;
    for (let j = 1; j <= n; j++) {
      const sub = prev[j - 1] + (pattern[i - 1] === text[j - 1] ? 0 : 1);
      cur[j] = Math.min(sub, prev[j] + 1, cur[j - 1] + 1);
    }
    [prev, cur] = [cur, prev];
  }
  return Math.min(...prev);
}

/** Menor distância entre as formas impressas da carta e os textos lidos. */
export function printedDistance(card: IndexCard, texts: string[]): number {
  let best = Infinity;
  for (const f of printedForms(card)) for (const t of texts) best = Math.min(best, approxSubstringDistance(f, t));
  return best;
}

export class Recognizer {
  private votes = new Map<string, number>();
  private cardOf = new Map<string, SearchHit['card']>();
  private leaderId = '';
  private streak = 0;
  private leaderMinDist = Infinity;
  private noCardFrames = 0;
  private ocrPending = false;
  private lastOcrAt = 0;
  private pendingCheckId: string | null = null; // candidata sendo verificada agora
  private boostId: string | null = null; // gêmea cujo número bateu com a leitura: reforçada no próximo frame
  private verified = new Set<string>(); // candidatas que passaram o gate
  private verifiedBy = new Map<string, VerificationMode>();
  private rejected = new Set<string>(); // candidatas cujo número CONTRADISSE a leitura (revogável por leitura exata)
  private attempts = new Map<string, number>(); // leituras inconclusivas por candidata
  private support = new Map<string, number>(); // leituras "total certo + numerador parcial" por candidata
  private foreign = new Map<string, number>(); // totais bem-formados lidos que não são da candidata (por total)
  private twinCache = new Map<string, IndexCard[]>();
  private totalsCache: Set<string> | null = null;
  private lockedId: string | null = null;

  constructor(private readonly index: CardIndex, public opts: RecognizerOptions = {}) {}

  get locked(): string | null { return this.lockedId; }
  /** Verificação de número em andamento — UI pode mostrar "conferindo…" e o
   * chamador (testes, ou o loop da câmera) pode aguardar antes do próximo frame. */
  get verifying(): boolean { return this.ocrPending; }
  /** Como a carta travada foi verificada ('none' = sem gate ou ainda não travou). */
  get lockedVerification(): VerificationMode | 'none' {
    return this.lockedId ? (this.verifiedBy.get(this.lockedId) ?? 'none') : 'none';
  }

  reset(): void {
    this.votes.clear(); this.cardOf.clear();
    this.leaderId = ''; this.streak = 0; this.leaderMinDist = Infinity; this.noCardFrames = 0;
    this.verified.clear(); this.verifiedBy.clear(); this.rejected.clear(); this.attempts.clear();
    this.support.clear(); this.foreign.clear(); this.twinCache.clear(); this.totalsCache = null;
    this.pendingCheckId = null; this.boostId = null; this.lockedId = null;
  }

  /** Gêmeas visuais (reprints) da carta no catálogo pesquisável. */
  twinsOf(id: string): IndexCard[] {
    let t = this.twinCache.get(id);
    if (!t) {
      t = this.index.twinsOf(id, { maxDist: THRESHOLDS.TWIN_MAX_DIST, exclude: this.opts.exclude, setIds: this.opts.setIds });
      this.twinCache.set(id, t);
    }
    return t;
  }

  /** Totais impressos (denominadores) existentes no catálogo pesquisável — checksum de leitura. */
  private knownTotals(): Set<string> {
    if (!this.totalsCache) {
      this.totalsCache = new Set<string>();
      for (const c of this.index.cards) {
        if (this.opts.setIds && !this.opts.setIds.has(c.setId)) continue;
        if (this.opts.exclude?.has(c.id)) continue;
        if (c.printedTotal) this.totalsCache.add(String(c.printedTotal));
      }
    }
    return this.totalsCache;
  }

  /** Processa um frame. Barato o bastante pra ~8 fps no celular. */
  feed(frame: RGBA, guide?: Rect, now = Date.now()): RecogResult {
    const T = THRESHOLDS;
    const detection = detectCard(frame, guide);
    const desc = describe(detection.rectified);
    const hits = this.index.search(desc, { setIds: this.opts.setIds, exclude: this.opts.exclude, k: this.opts.k ?? 5 });
    const best = hits[0];

    // ---- sem carta no quadro? ----
    const noCard = !best || (detection.edgeStrength < T.NO_CARD_EDGE && best.dist > T.VOTE_MAX_DIST);
    if (noCard) {
      this.noCardFrames++;
      this.decay(T.DECAY * 0.6);
      if (this.noCardFrames >= T.RELEASE_FRAMES && this.lockedId) this.reset();
      return this.result('no_card', hits, detection, 'Sem carta no quadro (borda fraca).');
    }
    this.noCardFrames = 0;

    // ---- votação ----
    this.decay(T.DECAY);
    for (const h of hits) {
      if (h.dist > T.VOTE_MAX_DIST) continue;
      const w = (T.VOTE_MAX_DIST - h.dist) / T.VOTE_MAX_DIST; // 0..1
      this.votes.set(h.card.id, (this.votes.get(h.card.id) ?? 0) + w);
      this.cardOf.set(h.card.id, h.card);
    }
    if (this.boostId) this.applyBoost();

    const ranked = this.ranked();
    const leader = ranked[0], runner = ranked[1];
    if (!leader || leader.score <= 0) {
      this.leaderId = ''; this.streak = 0;
      return this.result('unknown', hits, detection,
        `Nada perto no catálogo (melhor dist=${best.dist.toFixed(0)}). Carta fora da base?`);
    }
    if (leader.card.id === this.leaderId) this.streak++;
    else { this.leaderId = leader.card.id; this.streak = 1; this.leaderMinDist = Infinity; }
    // menor distância que o líder atingiu na sequência atual: um frame bom
    // basta pra provar proximidade; exigir isso DO frame atual era loteria.
    const leaderHit = hits.find((h) => h.card.id === leader.card.id);
    if (leaderHit) this.leaderMinDist = Math.min(this.leaderMinDist, leaderHit.dist);

    // ---- já confirmada: segura até a carta sair ----
    if (this.lockedId) {
      if (leader.card.id !== this.lockedId && this.streak >= T.CONFIRM_STREAK) this.reset();
      else return this.result('confirmed', hits, detection, 'Confirmada; retire a carta pra próxima.');
    }

    // ---- gate de número, disparado CEDO (streak ≥ 2) pra já estar
    // resolvido quando a candidata ficar elegível. ----
    const readNumber = this.opts.readNumber;
    const twins = readNumber ? this.twinsOf(leader.card.id) : [];
    const cap = twins.length ? T.OCR_MAX_ATTEMPTS_TWIN : T.OCR_MAX_ATTEMPTS;
    const tries = this.attempts.get(leader.card.id) ?? 0;
    const needsNumber = !!readNumber && !this.verified.has(leader.card.id);
    if (readNumber && needsNumber && tries < cap && this.streak >= T.OCR_EARLY_STREAK && !this.ocrPending && now - this.lastOcrAt > T.OCR_MIN_INTERVAL_MS) {
      this.ocrPending = true; this.lastOcrAt = now; this.pendingCheckId = leader.card.id;
      // warp dedicado em alta resolução: dígitos de ~10px no retificado do
      // hash viram leituras erradas-com-confiança; em 2× o OCR lê de verdade.
      const hi = warpQuad(frame, detection.corners, OCR_W, OCR_H);
      readNumber(hi)
        .then((r) => this.resolveVerification(r))
        .catch(() => this.resolveVerification(null))
        .finally(() => { this.ocrPending = false; });
    }

    // ---- elegível pra confirmar? (estável, sem empate, já chegou perto) ----
    const ratio = runner ? runner.score / leader.score : 0;
    const streakOk = this.streak >= T.CONFIRM_STREAK;
    const scoreOk = leader.score >= T.CONFIRM_MIN_SCORE;
    const clear = !runner || leader.score >= T.CONFIRM_RATIO * runner.score;
    // número lido e batendo: o visual só precisa estar razoavelmente perto;
    // sem número (ilegível, ou sem OCR disponível): o visual decide sozinho e
    // precisa estar bem mais perto.
    const maxDist = this.verifiedBy.get(leader.card.id) === 'number' ? T.CONFIRM_MAX_DIST : T.CONFIRM_MAX_DIST_VISUAL;
    const close = this.leaderMinDist <= maxDist;
    const eligible = streakOk && scoreOk && clear && close;

    if (eligible && needsNumber) {
      const why = this.ocrPending ? 'Conferindo número antes de confirmar…'
        : tries >= cap ? `Reprint ambíguo (nº ${[leader.card, ...twins].map((c) => c.number).join(' ou ')}): número ilegível — aproxime a câmera do rodapé`
        : 'Conferindo número antes de confirmar (aguardando)';
      return this.result('candidate', hits, detection, why, twins);
    }
    if (eligible && this.ocrPending) {
      // verificação de outra candidata ainda em voo: uma contradição pode aterrissar
      return this.result('candidate', hits, detection, 'Aguardando verificação em andamento…', twins);
    }
    if (eligible) {
      this.lockedId = leader.card.id;
      const mode = this.verifiedBy.get(leader.card.id);
      const hit: SearchHit = { card: leader.card, dist: this.leaderMinDist };
      const r = this.result('confirmed', hits, detection,
        `Confirmada (${mode ?? 'sem gate'}): ${this.streak} frames, votos ${leader.score.toFixed(2)} vs ${(runner?.score ?? 0).toFixed(2)}, dist mín=${this.leaderMinDist.toFixed(0)}.`,
        twins, mode);
      this.opts.onConfirmed?.(hit, r);
      return r;
    }
    const state: RecogState = leader.score >= 0.35 ? 'candidate' : 'searching';
    const why = !streakOk ? `estabilizando (${this.streak}/${T.CONFIRM_STREAK})`
      : !scoreOk ? `votos fracos (${leader.score.toFixed(2)} < ${T.CONFIRM_MIN_SCORE})`
      : !clear ? `empate com ${runner!.card.name} (${ratio.toFixed(2)})`
      : `ainda longe (dist mín=${this.leaderMinDist.toFixed(0)} > ${maxDist})`;
    return this.result(state, hits, detection, why);
  }

  /**
   * Resolve a verificação pendente comparando o texto lido com o número
   * impresso esperado da candidata (Y) e das gêmeas (Z). Política:
   *   - texto casa Y exato (ou a 1 edição, com Z ≥2 longe)   → VERIFICADA.
   *   - texto casa uma gêmea Z exato (ou a 1, com Y ≥2 longe) → REJEITA Y, reforça Z.
   *   - total (denominador) de Y certo + numerador parcial      → apoio; 2 apoios verificam
   *     (só se nenhuma gêmea tiver o mesmo total — senão não separa).
   *   - total bem-formado que NÃO é o de Y                      → estranho; o mesmo total
   *     2 vezes rejeita Y (é uma gêmea, ou um reprint fora da base).
   *   - o resto (ilegível, token solto, numerador trocado)      → inconclusivo: tenta de novo.
   *     Carta SEM gêmea: após OCR_MAX_ATTEMPTS aceita o visual ('inconclusive').
   *     Carta COM gêmea: nunca aceita só o visual.
   * Rejeição não é definitiva: uma leitura exata posterior revoga (um total
   * lido errado duas vezes não pode derrubar a carta certa pra sempre).
   */
  private resolveVerification(reading: NumberReading | null): void {
    const id = this.pendingCheckId;
    this.pendingCheckId = null;
    if (!id) return;
    const card = this.cardOf.get(id);
    if (!card) return; // já decaiu do pool; nada a decidir
    const dbg = this.opts.debug;
    const tag = `gate ${id} nº=${card.number}/${card.printedTotal}`;
    const twins = this.twinsOf(id);

    const texts = (reading?.texts?.length ? reading.texts : reading ? [`${reading.number}${reading.denominator ? '/' + reading.denominator : ''}`] : [])
      .map(cleanOcrText).filter(Boolean);
    const shown = texts.length ? texts.map((t) => `"${t}"`).join(' ') : 'ilegível';

    const dY = texts.length ? printedDistance(card, texts) : Infinity;
    let bestZ: IndexCard | null = null, dZ = Infinity;
    for (const z of twins) {
      const d = texts.length ? printedDistance(z, texts) : Infinity;
      if (d < dZ) { dZ = d; bestZ = z; }
    }

    if (dY === 0 || (dY === 1 && dZ >= 2)) {
      this.verify(id, 'number');
      dbg?.(`${tag}: leu ${shown} → VERIFICADA (casa o impresso, d=${dY}${twins.length ? `, gêmea d=${dZ}` : ''})`);
      return;
    }
    if (bestZ && (dZ === 0 || (dZ === 1 && dY >= 2))) {
      this.reject(id, bestZ);
      dbg?.(`${tag}: leu ${shown} → REJEITADA: casa a gêmea ${bestZ.id} nº=${bestZ.number}/${bestZ.printedTotal} (d=${dZ} vs ${dY})`);
      return;
    }

    // denominador como checksum (o OCR acerta o total bem mais que o numerador)
    const denom = reading?.denominator ? normalizeNumber(reading.denominator) : '';
    if (denom.length >= 2 && denom.length <= 3) {
      const mine = String(card.printedTotal);
      const twinTotals = new Set(twins.map((z) => String(z.printedTotal)));
      if (denom === mine && !twinTotals.has(denom) && dY <= 3) {
        const n = (this.support.get(id) ?? 0) + 1;
        this.support.set(id, n);
        if (n >= 2) { this.verify(id, 'number'); dbg?.(`${tag}: leu ${shown} → VERIFICADA (total certo + numerador parcial, ${n}×)`); }
        else dbg?.(`${tag}: leu ${shown} → apoio ${n}/2 (total certo, numerador parcial d=${dY})`);
        return;
      }
      if (denom !== mine) {
        // total de OUTRO set. Se é um total que existe no catálogo, uma leitura
        // basta (um erro de OCR raramente cai num total real: 19 valores em
        // ~900); se é desconhecido (set fora da base), exige duas iguais.
        const n = (this.foreign.get(denom) ?? 0) + 1;
        this.foreign.set(denom, n);
        const z = twins.find((t) => String(t.printedTotal) === denom) ?? null;
        const known = this.knownTotals().has(denom);
        if (n >= 2 || known) { this.reject(id, z); dbg?.(`${tag}: leu ${shown} → REJEITADA: total /${denom} de outro set${known ? ' (existe no catálogo)' : ''} lido ${n}× (${z ? `gêmea ${z.id}` : 'reprint fora da base?'})`); }
        else dbg?.(`${tag}: leu ${shown} → total estranho /${denom} (${n}/2)`);
        return;
      }
    }

    const n = (this.attempts.get(id) ?? 0) + 1;
    this.attempts.set(id, n);
    if (!twins.length && n >= THRESHOLDS.OCR_MAX_ATTEMPTS) {
      this.verify(id, 'inconclusive'); // arte única no catálogo: o visual decide
      dbg?.(`${tag}: leu ${shown} → inconclusiva ${n}/${THRESHOLDS.OCR_MAX_ATTEMPTS}, sem gêmea: ACEITA PELO VISUAL`);
    } else {
      dbg?.(`${tag}: leu ${shown} → inconclusiva ${n}/${twins.length ? THRESHOLDS.OCR_MAX_ATTEMPTS_TWIN + ' (tem gêmea: exige número)' : THRESHOLDS.OCR_MAX_ATTEMPTS}`);
    }
  }

  private verify(id: string, mode: VerificationMode): void {
    this.verified.add(id); this.verifiedBy.set(id, mode); this.rejected.delete(id);
  }

  private reject(id: string, twin: IndexCard | null): void {
    this.rejected.add(id); this.verified.delete(id); this.verifiedBy.delete(id);
    if (twin) this.boostId = twin.id;
  }

  /** Reforça a gêmea cujo número bateu com a leitura (entra no pool se não estiver). */
  private applyBoost(): void {
    const id = this.boostId!;
    this.boostId = null;
    const card = this.cardOf.get(id) ?? this.index.get(id);
    if (!card) return;
    this.cardOf.set(id, card);
    this.votes.set(id, (this.votes.get(id) ?? 0) + THRESHOLDS.OCR_BOOST);
  }

  private decay(f: number): void {
    for (const [id, s] of this.votes) {
      const v = s * f;
      if (v < 0.02) { this.votes.delete(id); this.cardOf.delete(id); } else this.votes.set(id, v);
    }
  }

  private ranked(): Vote[] {
    return [...this.votes.entries()]
      .filter(([id]) => !this.rejected.has(id))
      .map(([id, score]) => ({ card: this.cardOf.get(id)!, score }))
      .sort((a, b) => b.score - a.score);
  }

  private result(state: RecogState, hits: SearchHit[], detection: Detection, reason: string, alternatives?: IndexCard[], verification?: VerificationMode): RecogResult {
    const r: RecogResult = { state, best: hits[0], hits, votes: this.ranked().slice(0, 5), detection, streak: this.streak, reason };
    if (alternatives?.length) r.alternatives = alternatives;
    if (verification) r.verification = verification;
    return r;
  }
}

/** Reconhecimento de UMA imagem (modo foto): sem votação, veredito direto. */
export function recognizeOnce(index: CardIndex, frame: RGBA, guide?: Rect, opts: { setIds?: Set<string>; k?: number } = {}) {
  const detection = detectCard(frame, guide);
  const hits = index.search(describe(detection.rectified), { setIds: opts.setIds, k: opts.k ?? 5 });
  const T = THRESHOLDS;
  const best = hits[0];
  const margin = hits.length > 1 ? hits[1].dist - hits[0].dist : 99;
  const verdict: 'confident' | 'ambiguous' | 'unknown' =
    !best || best.dist > T.VOTE_MAX_DIST ? 'unknown'
    : best.dist <= T.CONFIRM_MAX_DIST && margin >= 6 ? 'confident'
    : 'ambiguous';
  return { detection, hits, verdict, margin };
}
