-- Versão do helper que aceita querystring (ex.: 'limit=50', 'card=base1-4').
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
revoke all on function private_sync_invoke(text, text) from anon, authenticated;
