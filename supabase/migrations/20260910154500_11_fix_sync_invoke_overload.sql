-- O overload de 1 argumento (migration 07) + o de 2 args com default (migration 09)
-- deixavam `private_sync_invoke('x')` ambíguo -> o cron falhou na 1ª execução com
-- "function private_sync_invoke(unknown) is not unique". Fica só o de 2 args.
drop function if exists private_sync_invoke(text);

create or replace function private_sync_invoke(fn text, query text default '')
returns bigint
language plpgsql
security definer
set search_path = public, net
as $$
declare
  req_id bigint;
begin
  select net.http_post(
    url := 'https://muprvxukzvgyywftjbwu.supabase.co/functions/v1/' || fn
           || case when query <> '' then '?' || query else '' end,
    body := '{}'::jsonb,
    params := '{}'::jsonb,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-sync-key', (select value from public.sync_config where key = 'sync_key')
    ),
    timeout_milliseconds := 55000
  ) into req_id;
  return req_id;
end;
$$;
revoke all on function private_sync_invoke(text, text) from public, anon, authenticated;

-- Recria os jobs com chamada explícita (2 args).
select cron.schedule('sync-sets',      '0 6 * * *',  $$select private_sync_invoke('sync-sets', '')$$);
select cron.schedule('sync-set-cards', '15 6 * * *', $$select private_sync_invoke('sync-set-cards', '')$$);
select cron.schedule('refresh-prices', '30 6 * * *', $$select private_sync_invoke('refresh-prices', '')$$);
