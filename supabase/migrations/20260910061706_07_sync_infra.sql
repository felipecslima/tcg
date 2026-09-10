-- Guarda o segredo compartilhado que autoriza chamadas às Edge Functions de sync.
-- RLS ligado sem policy => só service role (padrão do resto da infra de cache).
create table if not exists public.sync_config (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);
alter table public.sync_config enable row level security;

insert into public.sync_config (key, value)
values ('sync_key', encode(extensions.gen_random_bytes(24), 'hex'))
on conflict (key) do nothing;

-- Chamada HTTP para uma Edge Function de sync, com o header de autorização
-- montado a partir do segredo. Usada pelos jobs do pg_cron.
create or replace function private_sync_invoke(fn text)
returns bigint
language plpgsql
security definer
set search_path = public, net
as $$
declare
  req_id bigint;
begin
  select net.http_post(
    url := 'https://muprvxukzvgyywftjbwu.supabase.co/functions/v1/' || fn,
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
revoke all on function private_sync_invoke(text) from anon, authenticated;

-- Agendamentos (horários em UTC; sa-east-1 = UTC-3).
select cron.schedule('sync-sets',      '0 6 * * *',  $$select private_sync_invoke('sync-sets')$$);       -- 03:00 BRT
select cron.schedule('sync-set-cards', '15 6 * * *', $$select private_sync_invoke('sync-set-cards')$$);   -- 03:15 BRT
select cron.schedule('refresh-prices', '30 6 * * *', $$select private_sync_invoke('refresh-prices')$$);   -- 03:30 BRT
