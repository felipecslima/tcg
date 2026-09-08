/**
 * Cliente mínimo da TCGdex (https://tcgdex.dev) — base com nomes em
 * PORTUGUÊS nativo, 17k+ cartas em 123 sets (inclui 2026) e imagens por
 * carta. Substitui a pokemontcg.io como fonte do catálogo do scanner.
 *
 * No browser passa pelo proxy do Vite (/tcgdex); no node bate direto.
 */
import type { IndexCard, IndexSet } from './catalog.js';

const BASE = typeof window !== 'undefined' ? '/tcgdex/v2' : 'https://api.tcgdex.net/v2';

async function getJson<T>(url: string, retries = 6): Promise<T> {
  let lastErr: unknown;
  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const res = await fetch(url, { headers: { accept: 'application/json' } });
      const text = await res.text();
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return JSON.parse(text) as T;
    } catch (e) {
      lastErr = e;
      await new Promise((r) => setTimeout(r, 400 * (attempt + 1)));
    }
  }
  throw new Error(`tcgdex falhou (${url}): ${String(lastErr)}`);
}

interface TdxSetBrief { id: string; name: string; cardCount?: { official?: number; total?: number } }
interface TdxSet extends TdxSetBrief {
  serie?: { id: string; name: string };
  cards: { id: string; localId: string; name: string; image?: string }[];
}

export async function fetchSets(lang = 'pt'): Promise<IndexSet[]> {
  const sets = await getJson<TdxSetBrief[]>(`${BASE}/${lang}/sets`);
  return sets.map((s) => ({ id: s.id, name: s.name, series: s.id.replace(/[\d.].*$/, ''), count: s.cardCount?.total ?? 0 }));
}

export async function fetchSeries(lang = 'pt'): Promise<{ id: string; name: string }[]> {
  return getJson<{ id: string; name: string }[]>(`${BASE}/${lang}/series`);
}

/** Ids dos sets de uma série (ex. "sv" → sv01, sv02, …). */
export async function fetchSeriesSetIds(seriesId: string, lang = 'pt'): Promise<string[]> {
  const s = await getJson<{ sets: { id: string }[] }>(`${BASE}/${lang}/series/${encodeURIComponent(seriesId)}`);
  return s.sets.map((x) => x.id);
}

/** Cartas de um set com URL-base da imagem. Cartas sem imagem são descartadas. */
export async function fetchSetCards(setId: string, lang = 'pt'): Promise<{ set: IndexSet; cards: IndexCard[] }> {
  const s = await getJson<TdxSet>(`${BASE}/${lang}/sets/${encodeURIComponent(setId)}`);
  const series = s.serie?.id ?? setId.replace(/[\d.].*$/, '');
  const printedTotal = s.cardCount?.official ?? s.cardCount?.total ?? 0;
  const cards: IndexCard[] = s.cards
    .filter((c) => !!c.image)
    .map((c) => ({
      id: c.id, name: c.name, number: c.localId, setId: s.id, setName: s.name,
      printedTotal, series, image: c.image!,
    }));
  return { set: { id: s.id, name: s.name, series, count: cards.length }, cards };
}
