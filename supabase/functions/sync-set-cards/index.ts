// sync-set-cards — drena a fila de sets "vencidos" (fetch_log, entity_type=set),
// baixa o detalhe de cada set (/v2/en/sets/:id) e faz upsert das cartas na
// versão "brief" (id, set, número, nome, imagem). HP/ataques/preço são
// enriquecidos depois por refresh-prices / abertura da carta.
//
// Agendado: diário 03:15 BRT, `limit` sets por execução. Carga inicial: chamar
// manualmente com ?limit=50 algumas vezes (são ~218 sets no total).

import {
  admin, authorized, bumpRefresh, cardBriefRow, conditionalGet, finishRun, json,
  setRow, startRun,
} from "./sync.ts";

const MONTH = 30 * 24 * 3600;

Deno.serve(async (req: Request) => {
  const sb = admin();
  if (!(await authorized(req, sb))) return json({ error: "forbidden" }, 403);

  const url = new URL(req.url);
  const limit = Math.min(50, Math.max(1, Number(url.searchParams.get("limit") ?? 3)));
  const only = url.searchParams.get("set");

  const run = await startRun(sb, "sync-set-cards");
  try {
    let setIds: string[];
    if (only) {
      setIds = [only];
    } else {
      const { data: due } = await sb.from("fetch_log")
        .select("entity_id")
        .eq("source", "tcgdex").eq("entity_type", "set")
        .lte("next_refresh_at", new Date().toISOString())
        .order("next_refresh_at", { ascending: true })
        .limit(limit);
      setIds = (due ?? []).map((r: any) => r.entity_id);
    }

    const processed: string[] = [];
    for (const setId of setIds) {
      const got = await conditionalGet(sb, {
        entityType: "set-detail", entityId: setId,
        path: `/en/sets/${setId}`, endpoint: "/en/sets/:id",
      });

      if (got.changed && got.body) {
        const b = got.body;
        const { error: setErr } = await sb.from("sets").upsert(setRow(b), { onConflict: "id" });
        if (setErr) throw setErr;

        const cards = (b.cards ?? []).map((c: any) => cardBriefRow(c, b.id));
        for (let i = 0; i < cards.length; i += 500) {
          const { error } = await sb.from("cards")
            .upsert(cards.slice(i, i + 500), { onConflict: "id" });
          if (error) throw error;
        }
        run.rows += cards.length;
      }

      await bumpRefresh(sb, "set", setId, MONTH);
      processed.push(setId);
    }

    await finishRun(run, { sets: processed });
    return json({ processed, count: processed.length });
  } catch (e) {
    run.errors++;
    await finishRun(run, { error: String(e) });
    return json({ error: String(e) }, 500);
  }
});
