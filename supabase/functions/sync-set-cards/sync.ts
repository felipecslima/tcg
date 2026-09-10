// Utilitários compartilhados pelas Edge Functions de sync (sync-sets,
// sync-set-cards, refresh-prices).
//
// Regra de ouro do projeto: toda resposta de API externa é gravada na base
// ANTES de virar dado de UI. `api_cache_raw` guarda o payload cru (append-only),
// `fetch_log` guarda ETag/Last-Modified + `next_refresh_at` (fila de sync),
// `sync_runs` registra cada execução.

import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const TCGDEX = "https://api.tcgdex.net/v2";
export const LANG = "en"; // catálogo canônico; camada PT vem depois

export function admin(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

/** As Edge Functions de sync rodam com verify_jwt=false e se autenticam por
 *  este header, cujo valor mora em `public.sync_config` (RLS => só service role). */
export async function authorized(req: Request, sb: SupabaseClient): Promise<boolean> {
  const key = req.headers.get("x-sync-key");
  if (!key) return false;
  const { data } = await sb
    .from("sync_config").select("value").eq("key", "sync_key").maybeSingle();
  return !!data && data.value === key;
}

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

// ---- sync_runs ----

export interface Run {
  id: number | null;
  sb: SupabaseClient;
  job: string;
  rows: number;
  errors: number;
  detail: Record<string, unknown>;
}

export async function startRun(
  sb: SupabaseClient,
  job: string,
  detail: Record<string, unknown> = {},
): Promise<Run> {
  const { data } = await sb.from("sync_runs").insert({ job, detail }).select("id").single();
  return { id: data?.id ?? null, sb, job, rows: 0, errors: 0, detail };
}

export async function finishRun(run: Run, extra: Record<string, unknown> = {}) {
  if (run.id == null) return;
  await run.sb.from("sync_runs").update({
    finished_at: new Date().toISOString(),
    rows_upserted: run.rows,
    errors: run.errors,
    detail: { ...run.detail, ...extra },
  }).eq("id", run.id);
}

// ---- fetch com cache ----

const upsertLog = "source,entity_type,entity_id";

/** GET condicional (If-None-Match / If-Modified-Since via fetch_log). Grava
 *  api_cache_raw + atualiza fetch_log quando vem corpo novo. */
export async function conditionalGet(
  sb: SupabaseClient,
  opts: { entityType: string; entityId: string; path: string; endpoint: string },
): Promise<{ status: number; body: any | null; changed: boolean }> {
  const { data: log } = await sb.from("fetch_log")
    .select("etag,last_modified")
    .eq("source", "tcgdex").eq("entity_type", opts.entityType).eq("entity_id", opts.entityId)
    .maybeSingle();

  const headers: Record<string, string> = { Accept: "application/json" };
  if (log?.etag) headers["If-None-Match"] = log.etag;
  if (log?.last_modified) headers["If-Modified-Since"] = log.last_modified;

  const res = await fetch(`${TCGDEX}${opts.path}`, { headers });
  if (res.status === 304) return { status: 304, body: null, changed: false };
  if (!res.ok) throw new Error(`tcgdex ${opts.path} -> ${res.status}`);

  const body = await res.json();
  const etag = res.headers.get("etag");
  const lastMod = res.headers.get("last-modified");

  await sb.from("api_cache_raw").insert({
    source: "tcgdex", endpoint: opts.endpoint,
    params: { entity: opts.entityId }, status: res.status, etag, body,
  });
  await sb.from("fetch_log").upsert({
    source: "tcgdex", entity_type: opts.entityType, entity_id: opts.entityId,
    etag, last_modified: lastMod, fetched_at: new Date().toISOString(),
  }, { onConflict: upsertLog });

  return { status: res.status, body, changed: true };
}

/** GET simples + grava api_cache_raw (para dados que mudam sempre, ex. preço). */
export async function plainGet(
  sb: SupabaseClient,
  opts: { path: string; endpoint: string; entityId: string },
): Promise<any> {
  const res = await fetch(`${TCGDEX}${opts.path}`, { headers: { Accept: "application/json" } });
  if (!res.ok) throw new Error(`tcgdex ${opts.path} -> ${res.status}`);
  const body = await res.json();
  await sb.from("api_cache_raw").insert({
    source: "tcgdex", endpoint: opts.endpoint,
    params: { entity: opts.entityId }, status: res.status,
    etag: res.headers.get("etag"), body,
  });
  return body;
}

/** Marca uma entidade como devendo ser re-sincronizada em `seconds` (0 = já). */
export async function bumpRefresh(
  sb: SupabaseClient,
  entityType: string,
  entityId: string,
  seconds: number,
) {
  await sb.from("fetch_log").upsert({
    source: "tcgdex", entity_type: entityType, entity_id: entityId,
    ttl_seconds: seconds,
    next_refresh_at: new Date(Date.now() + seconds * 1000).toISOString(),
  }, { onConflict: upsertLog });
}

// ---- mapeamentos TCGdex -> nossas tabelas ----

export function setRow(b: any) {
  const row: Record<string, unknown> = {
    id: b.id,
    name: b.name,
    printed_total: b.cardCount?.official ?? null,
    total: b.cardCount?.total ?? null,
    logo_url: b.logo ?? null,
    symbol_url: b.symbol ?? null,
    updated_at: new Date().toISOString(),
  };
  if (b.serie?.name) row.series = b.serie.name;
  if (b.releaseDate) row.release_date = b.releaseDate;
  return row;
}

export function cardBriefRow(c: any, setId: string) {
  return {
    id: c.id,
    set_id: setId,
    local_id: c.localId ?? null,
    name: c.name,
    image_url: c.image ?? null,
    updated_at: new Date().toISOString(),
  };
}

export function cardDetailRow(b: any) {
  const dex = Array.isArray(b.dexId) ? b.dexId[0] : null;
  const row: Record<string, unknown> = {
    id: b.id,
    local_id: b.localId ?? null,
    name: b.name,
    rarity: b.rarity ?? null,
    image_url: b.image ?? null,
    category: b.category ?? null,
    hp: b.hp ?? null,
    types: b.types ?? [],
    attacks: b.attacks ?? null,
    weaknesses: b.weaknesses ?? null,
    resistances: b.resistances ?? null,
    retreat: b.retreat ?? null,
    national_dex_id: typeof dex === "number" && dex >= 1 && dex <= 1025 ? dex : null,
    illustrator: b.illustrator ?? null,
    variants: b.variants ?? null,
    raw: b,
    updated_at: new Date().toISOString(),
  };
  if (b.set?.id) row.set_id = b.set.id;
  return row;
}

/** pricing do TCGdex -> linhas de card_prices (append-only, 1 por source+variant). */
export function priceRows(cardId: string, pricing: any): any[] {
  const rows: any[] = [];
  if (!pricing) return rows;

  const tp = pricing.tcgplayer;
  if (tp) {
    for (const [variant, v] of Object.entries<any>(tp)) {
      if (variant === "unit" || variant === "updated" || v == null || typeof v !== "object") continue;
      rows.push({
        card_id: cardId, source: "tcgplayer", currency: tp.unit ?? "USD", variant,
        market: v.marketPrice ?? null, low: v.lowPrice ?? null,
        mid: v.midPrice ?? null, high: v.highPrice ?? null, raw: v,
      });
    }
  }

  const cm = pricing.cardmarket;
  if (cm) {
    // cardmarket vem "achatado": campos base = variante normal, sufixo -holo = holo.
    for (const [suf, variant] of Object.entries({ "": "normal", "-holo": "holo" })) {
      const trend = cm[`trend${suf}`], low = cm[`low${suf}`];
      const avg = cm[`avg${suf}`], avg30 = cm[`avg30${suf}`];
      if (trend == null && low == null && avg == null) continue;
      rows.push({
        card_id: cardId, source: "cardmarket", currency: cm.unit ?? "EUR", variant,
        market: trend ?? avg ?? null, low: low ?? null,
        mid: avg30 ?? avg ?? null, high: null,
        raw: { trend, low, avg, avg30 },
      });
    }
  }
  return rows;
}
