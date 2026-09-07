// No browser passamos pelo proxy do Vite (/pokeapi) pra evitar CORS; no node
// (scripts de validação) batemos direto na API, que não tem CORS.
const BASE = typeof window !== 'undefined' ? '/pokeapi/v2' : 'https://api.pokemontcg.io/v2';
async function getJson(url, opts, retries = 8) {
    const f = opts.fetchImpl ?? fetch;
    const headers = {};
    if (opts.apiKey)
        headers['X-Api-Key'] = opts.apiKey;
    let lastErr;
    for (let attempt = 0; attempt < retries; attempt++) {
        try {
            const res = await f(url, { headers });
            const text = await res.text();
            if (!res.ok)
                throw new Error(`HTTP ${res.status}`);
            return JSON.parse(text);
        }
        catch (e) {
            lastErr = e;
            await new Promise((r) => setTimeout(r, 400 * (attempt + 1)));
        }
    }
    throw new Error(`pokemontcg.io falhou após ${retries} tentativas: ${String(lastErr)}`);
}
function toRecord(c) {
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
/** Lista todos os sets (pro dropdown do pré-filtro). */
export async function fetchSets(opts = {}) {
    const json = await getJson(`${BASE}/sets?pageSize=250&orderBy=-releaseDate`, opts);
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
export async function fetchSetCards(setId, opts = {}) {
    const out = [];
    let page = 1;
    const pageSize = 250;
    for (;;) {
        const url = `${BASE}/cards?q=set.id:${encodeURIComponent(setId)}&page=${page}&pageSize=${pageSize}&orderBy=number`;
        const json = await getJson(url, opts);
        out.push(...json.data.map(toRecord));
        if (json.data.length < pageSize || out.length >= json.totalCount)
            break;
        page++;
    }
    return out;
}
