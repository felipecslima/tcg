// sync-sets — lista /v2/en/sets (1 request barato, com ETag) e faz upsert em
// `sets`. Sets novos ou com contagem de cartas diferente são marcados como
// "vencidos" no fetch_log para o sync-set-cards baixar as cartas.
//
// Agendado: diário 03:00 BRT. Manual: POST com header x-sync-key.

import {
  admin, authorized, bumpRefresh, conditionalGet, finishRun, json, startRun,
  TCGDEX, LANG,
} from "./sync.ts";

Deno.serve(async (req: Request) => {
  const sb = admin();
  if (!(await authorized(req, sb))) return json({ error: "forbidden" }, 403);

  const run = await startRun(sb, "sync-sets");
  try {
    const got = await conditionalGet(sb, {
      entityType: "sets", entityId: "all", path: "/en/sets", endpoint: "/en/sets",
    });
    if (!got.changed) {
      await finishRun(run, { status: 304 });
      return json({ changed: false });
    }

    const list = got.body as any[];
    const { data: existing } = await sb.from("sets").select("id,total,abbreviation");
    const known = new Map((existing ?? []).map((s: any) => [s.id, { total: s.total, abbreviation: s.abbreviation }]));

    const rows = list.map((s) => ({
      id: s.id,
      name: s.name,
      printed_total: s.cardCount?.official ?? null,
      total: s.cardCount?.total ?? null,
      logo_url: s.logo ?? null,
      symbol_url: s.symbol ?? null,
      updated_at: new Date().toISOString(),
    }));
    const { error } = await sb.from("sets").upsert(rows, { onConflict: "id" });
    if (error) throw error;
    run.rows = rows.length;

    // Sets sem abbreviation: busca endpoint detalhado (throttled, 5 em paralelo)
    const missing = list.filter((s) => !known.get(s.id)?.abbreviation);
    let abbrCount = 0;
    for (let i = 0; i < missing.length; i += 5) {
      const batch = missing.slice(i, i + 5);
      const results = await Promise.allSettled(
        batch.map(async (s: any) => {
          const res = await fetch(`${TCGDEX}/${LANG}/sets/${s.id}`, {
            headers: { Accept: "application/json" },
          });
          if (!res.ok) return null;
          const detail = await res.json();
          const abbr = detail?.abbreviation?.official;
          if (abbr) {
            await sb.from("sets").update({ abbreviation: abbr }).eq("id", s.id);
            return abbr;
          }
          return null;
        }),
      );
      abbrCount += results.filter((r) => r.status === "fulfilled" && r.value).length;
    }

    const stale = list.filter(
      (s) => !known.has(s.id) || known.get(s.id)?.total !== (s.cardCount?.total ?? null),
    );
    for (const s of stale) await bumpRefresh(sb, "set", s.id, 0);

    await finishRun(run, { sets: rows.length, queued: stale.map((s) => s.id), abbreviations: abbrCount });
    return json({ changed: true, sets: rows.length, queued: stale.length, abbreviations: abbrCount });
  } catch (e) {
    run.errors++;
    await finishRun(run, { error: String(e) });
    return json({ error: String(e) }, 500);
  }
});
