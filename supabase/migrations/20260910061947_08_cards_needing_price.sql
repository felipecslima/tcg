-- Cartas "quentes" (em coleção ou wishlist) cujo preço mais recente venceu.
create or replace function public.cards_needing_price(
  lim int default 60,
  max_age interval default '24 hours'
)
returns table(card_id text)
language sql
stable
security definer
set search_path = public
as $$
  with hot as (
    select card_id from public.collection_cards
    union
    select card_id from public.wishlist
  ),
  latest as (
    select card_id, max(fetched_at) as last_at
    from public.card_prices
    group by card_id
  )
  select h.card_id
  from hot h
  left join latest l on l.card_id = h.card_id
  where l.last_at is null or l.last_at < now() - max_age
  order by l.last_at asc nulls first
  limit lim
$$;

revoke all on function public.cards_needing_price(int, interval) from anon, authenticated;
