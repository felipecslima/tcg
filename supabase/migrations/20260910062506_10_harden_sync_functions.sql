-- Tira EXECUTE do pseudo-role PUBLIC (revogar de anon/authenticated não basta).
revoke execute on function private_sync_invoke(text) from public;
revoke execute on function private_sync_invoke(text, text) from public;
revoke execute on function public.cards_needing_price(int, interval) from public;

-- sync_config guarda segredo: nega qualquer acesso além de service role.
revoke all on table public.sync_config from anon, authenticated;

-- cards_needing_price só precisa rodar como service role (edge function).
revoke execute on function public.cards_needing_price(int, interval) from anon, authenticated;
