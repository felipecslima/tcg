/**
 * Cliente mínimo da pokemontcg.io. A API é gratuita mas ocasionalmente
 * responde 5xx (Cloudflare) — por isso todo GET tem retry com backoff.
 *
 * Estratégia do scanner em lote: buscar TODAS as cartas do set escolhido
 * UMA vez no início do lote (via `fetchSetCards`) e casar cada frame
 * localmente contra esse índice. Zero chamada de API por scan → instantâneo
 * e funciona offline durante o lote.
 */
import type { CardRecord } from './types.js';

// No browser passamos pelo proxy do Vite (/pokeapi) pra evitar CORS; no node
// (scripts de validação) batemos direto na API, que não tem CORS.
const BASE = typeof window !== 'undefined' ? '/pokeapi/v2' : 'https://api.pokemontcg.io/v2';

/** Chave opcional da pokemontcg.io: aumenta o rate limit. Sem ela também funciona. */
export interface ApiOptions {
  apiKey?: string;
  fetchImpl?: typeof fetch;
}

async function getJson<T>(url: string, opts: ApiOptions, retries = 8): Promise<T> {
  const f = opts.fetchImpl ?? fetch;
  const headers: Record<string, string> = {};
  if (opts.apiKey) headers['X-Api-Key'] = opts.apiKey;
  let lastErr: unknown;
  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const res = await f(url, { headers });
      const text = await res.text();
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return JSON.parse(text) as T;
    } catch (e) {
      lastErr = e;
      await new Promise((r) => setTimeout(r, 400 * (attempt + 1)));
    }
  }
  throw new Error(`pokemontcg.io falhou após ${retries} tentativas: ${String(lastErr)}`);
}

interface ApiCard {
  id: string;
  name: string;
  number: string;
  rarity?: string;
  images?: { small?: string };
  nationalPokedexNumbers?: number[];
  set: { id: string; name: string; printedTotal?: number; total?: number };
}

function toRecord(c: ApiCard): CardRecord {
  return {
    id: c.id,
    name: c.name,
    number: c.number,
    setId: c.set.id,
    setName: c.set.name,
    printedTotal: c.set.printedTotal ?? c.set.total ?? 0,
    rarity: c.rarity,
    imageSmall: c.images?.small,
    nationalPokedexNumbers: c.nationalPokedexNumbers,
  };
}

/** Set no listmodel do pré-filtro. */
export interface SetSummary {
  id: string;
  name: string;
  series: string;
  printedTotal: number;
  total: number;
  releaseDate?: string;
}

/** Lista todos os sets (pro dropdown do pré-filtro). */
export async function fetchSets(opts: ApiOptions = {}): Promise<SetSummary[]> {
  const json = await getJson<{ data: any[] }>(`${BASE}/sets?pageSize=250&orderBy=-releaseDate`, opts);
  return json.data.map((s) => ({
    id: s.id,
    name: s.name,
    series: s.series,
    printedTotal: s.printedTotal ?? 0,
    total: s.total ?? 0,
    releaseDate: s.releaseDate,
  }));
}

/** Busca todas as cartas de um set (paginado), pronto pra indexar localmente. */
export async function fetchSetCards(setId: string, opts: ApiOptions = {}): Promise<CardRecord[]> {
  const out: CardRecord[] = [];
  let page = 1;
  const pageSize = 250;
  for (;;) {
    const url = `${BASE}/cards?q=set.id:${encodeURIComponent(setId)}&page=${page}&pageSize=${pageSize}&orderBy=number`;
    const json = await getJson<{ data: ApiCard[]; totalCount: number }>(url, opts);
    out.push(...json.data.map(toRecord));
    if (json.data.length < pageSize || out.length >= json.totalCount) break;
    page++;
  }
  return out;
}
