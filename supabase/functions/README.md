# Edge Functions — sync do catálogo

Todas gravam o payload cru em `api_cache_raw` antes de tocar nas tabelas de
domínio, atualizam `fetch_log` (ETag + `next_refresh_at`) e registram cada
execução em `sync_runs`. Regra do projeto: **nenhuma tela chama API externa
direto** — o catálogo sai sempre da nossa base.

| Função | O que faz | Schedule (pg_cron, UTC) |
|---|---|---|
| `seed-pokedex` | Popula `pokedex` (1..1025) via PokéAPI. Roda 1×. `?start=&end=` pra faixa. `verify_jwt=true`. | — |
| `sync-sets` | `GET /v2/en/sets` (com ETag). Upsert em `sets`. Sets novos/alterados → `fetch_log` vencido. | `0 6 * * *` (03:00 BRT) |
| `sync-set-cards` | Drena a fila de sets vencidos, baixa `/v2/en/sets/:id`, upsert das cartas "brief" (id, número, nome, imagem). `?limit=N` (máx 50), `?set=<id>`. | `15 6 * * *` |
| `refresh-prices` | Cartas "quentes" (`cards_needing_price`: em coleção/wishlist, preço > 24h). Baixa `/v2/en/cards/:id`, grava `card_prices` + enriquece a carta (hp/ataques/raridade/variantes). `?limit=N`, `?card=<id>`. | `30 6 * * *` |

## Auth

`sync-sets` / `sync-set-cards` / `refresh-prices` rodam com `verify_jwt=false` e
exigem o header `x-sync-key`, cujo valor está em `public.sync_config` (RLS sem
policy → só service role lê). O pg_cron chama via
`private_sync_invoke('<fn>', '<querystring>')`, que monta o header a partir do
segredo. Pra chamar manualmente do SQL editor:

```sql
select private_sync_invoke('sync-set-cards', 'limit=50');
select (select status_code from net._http_response order by id desc limit 1),
       (select content::text from net._http_response order by id desc limit 1);
```

## Carga inicial do catálogo

`sync-sets` já rodou (218 sets em `sets`, todos na fila). Falta baixar as
cartas — rodar algumas vezes:

```sql
select private_sync_invoke('sync-set-cards', 'limit=50');  -- repetir ~5x, esperar cada uma
```

## Deploy

Feito via MCP `deploy_edge_function` (layout achatado: `sync.ts` copiado em cada
pasta). Com a CLI seria `supabase functions deploy <nome>` — nesse caso
convém voltar a um `_shared/` e imports `../_shared/sync.ts`.
