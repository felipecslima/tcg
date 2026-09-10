// sync-sets — lista /v2/en/sets (1 request barato, com ETag) e faz upsert em
// `sets`. Sets novos ou com contagem de cartas diferente são marcados como
// "vencidos" no fetch_log para o sync-set-cards baixar as cartas.
//
// Agendado: diário 03:00 BRT. Manual: POST com header x-sync-key.

import {
  admin, authorized, bumpRefresh, conditionalGet, finishRun, json, startRun,
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
    const { data: existing } = await sb.from("sets").select("id,total");
    const known = new Map((existing ?? []).map((s: any) => [s.id, s.total]));

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

    const stale = list.filter(
      (s) => !known.has(s.id) || known.get(s.id) !== (s.cardCount?.total ?? null),
    );
    for (const s of stale) await bumpRefresh(sb, "set", s.id, 0);

    await finishRun(run, { sets: rows.length, queued: stale.map((s) => s.id) });
    return json({ changed: true, sets: rows.length, queued: stale.length });
  } catch (e) {
    run.errors++;
    await finishRun(run, { error: String(e) });
    return json({ error: String(e) }, 500);
  }
});
