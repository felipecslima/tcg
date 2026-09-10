// refresh-prices — atualiza preço das cartas "quentes" (nas coleções dos
// usuários ou na wishlist) cujo preço mais recente tem > 24h. Baixa o detalhe
// da carta (/v2/en/cards/:id — único endpoint com pricing), grava linhas em
// `card_prices` (append-only, alimenta a variação %) e de quebra enriquece a
// carta (hp, ataques, raridade, variantes...).
//
// Agendado: diário 03:30 BRT. Manual: ?limit=N (default 60).

import {
  admin, authorized, cardDetailRow, finishRun, json, plainGet, priceRows, startRun,
} from "./sync.ts";

Deno.serve(async (req: Request) => {
  const sb = admin();
  if (!(await authorized(req, sb))) return json({ error: "forbidden" }, 403);

  const url = new URL(req.url);
  const limit = Math.min(200, Math.max(1, Number(url.searchParams.get("limit") ?? 60)));
  const only = url.searchParams.get("card");

  const run = await startRun(sb, "refresh-prices");
  try {
    let cardIds: string[];
    if (only) {
      cardIds = [only];
    } else {
      const { data, error } = await sb.rpc("cards_needing_price", { lim: limit });
      if (error) throw error;
      cardIds = (data ?? []).map((r: any) => r.card_id);
    }

    let priceCount = 0;
    const failed: string[] = [];
    for (const cardId of cardIds) {
      try {
        const b = await plainGet(sb, {
          path: `/en/cards/${cardId}`, endpoint: "/en/cards/:id", entityId: cardId,
        });

        // garante o set (FK) antes de mexer na carta
        if (b.set?.id) {
          await sb.from("sets").upsert(
            { id: b.set.id, name: b.set.name ?? b.set.id },
            { onConflict: "id", ignoreDuplicates: true },
          );
        }
        await sb.from("cards").upsert(cardDetailRow(b), { onConflict: "id" });

        const rows = priceRows(cardId, b.pricing);
        if (rows.length) {
          const { error } = await sb.from("card_prices").insert(rows);
          if (error) throw error;
          priceCount += rows.length;
        }
        run.rows++;
      } catch (e) {
        run.errors++;
        failed.push(`${cardId}: ${e}`);
      }
    }

    await finishRun(run, { cards: run.rows, price_rows: priceCount, failed });
    return json({ cards: run.rows, price_rows: priceCount, failed: failed.length });
  } catch (e) {
    run.errors++;
    await finishRun(run, { error: String(e) });
    return json({ error: String(e) }, 500);
  }
});
