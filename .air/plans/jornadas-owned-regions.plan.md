# Plano: Jornadas por região — mostrar apenas regiões com Pokémon na coleção

## Contexto

A tela Jornadas depende da tabela `regions` no Supabase estar populada por uma seed function. Se a tabela está vazia, nenhuma região aparece — mesmo o usuário tendo cartas com `national_dex_id` preenchido. O usuário quer:
1. Que as regiões apareçam automaticamente quando ele tem pelo menos 1 Pokémon daquela região
2. Ao clicar num Pokémon na grade da região, ver as outras variações (cartas diferentes do mesmo Pokémon)

## Abordagem

Hardcodar as 9 regiões como fallback em Dart (são dados estáticos que nunca mudam). Mostrar **todas as 9 regiões** sempre, mas as que não têm Pokémon ficam com visual desabilitado/cinza (não clicáveis). Na grade da região, ao tocar num Pokémon, abrir um **bottom sheet** listando todas as variações (cartas de diferentes sets).

---

## Mudanças por arquivo

### 1. `lib/repositories/pokedex_repository.dart` — Modificar

Adicionar fallback estático de regiões no `RegionBrief` e helper `regionForDex`. Alterar `fetchRegions()` para usar o fallback quando a tabela está vazia.

### 2. `lib/repositories/collection_repository.dart` — Modificar

Adicionar `fetchOwnedNationalDexIds()` — join `collection_cards` → `cards` para obter os dex IDs que o usuário possui. Uma única query substitui o fluxo atual de N+1 queries.

### 3. `lib/repositories/card_repository.dart` — Modificar

Adicionar `fetchCardsForPokemon(int nationalDexId)` — busca todas as cartas com aquele dex ID (variações de diferentes sets).

### 4. `lib/screens/journeys_screen.dart` — Modificar

Reescrever `_load()` para usar apenas 2 queries (regiões + dex IDs owned). Mostra todas as 9 regiões; as vazias ficam cinza/desabilitadas (sem gradiente, sem onTap).

### 5. `lib/widgets/pokemon_variations_sheet.dart` — Criar

Bottom sheet modal que mostra todas as cartas de um Pokémon (grade 2 colunas, thumbnail + set + raridade). Destaque nas cartas que o usuário possui. Tap → CardDetailScreen.

### 6. `lib/screens/region_cards_screen.dart` — Modificar

Alterar `_DexSlot` para guardar todas as cartas do dex ID. No onTap de um slot owned, abrir o bottom sheet de variações.

## Verificação

1. `flutter analyze` limpo
2. `flutter test` verde (atualizar fakes dos stores com os novos métodos)
3. Todas as 9 regiões visíveis; as com Pokémon têm gradiente, as sem ficam cinza
4. Regiões sem Pokémon não são clicáveis
5. Bottom sheet de variações ao tocar num Pokémon na grade
6. Do bottom sheet, tocar numa carta abre o detalhe