# Restaurar informações completas na tela de detalhe da carta

## Contexto

A tela de detalhe (`CardDetailScreen`) foi reescrita no commit `5f54715` com o novo design system, mas perdeu seções de informação que existiam na versão original (`dac8ce4`):

1. **Chips de metadados** — tipo de energia, estágio, categoria, HP, marca de regulação
2. **Bloco completo de preços de mercado** — Cardmarket (tendência, média, mín, 7d, 30d, holo) + TCGplayer (por variante) com conversão BRL
3. **Número da Pokédex Nacional**

## Abordagem

Restaurar as três seções perdidas integrando-as na estrutura atual da tela. Para os campos que não existem no modelo `Card` (`stage`, `regulationMark`), adicioná-los ao modelo e à persistência. Para pricing completo (`MarketPricing`), carregar como campo transiente no `Card` — disponível quando a API responde, graceful degradation para o BRL único quando vem do cache DB.

## Arquivos a modificar

### 1. `lib/models/card.dart` — Modify
Adicionar campos `stage` (String?), `regulationMark` (String?), `pricing` (MarketPricing?, transiente):
- Construtor, `copyWith`, `fromSupabaseRow`, `toUpsertRow`, `fromDetail`

### 2. `lib/repositories/card_repository.dart` — Modify
Em `fetchCardDetail`, preservar `detail.pricing` e aplicar via `copyWith` no Card retornado após o round-trip pelo DB.

### 3. `lib/screens/card_detail_screen.dart` — Modify
- Adicionar `FxRates?` ao state, carregar no `initState`
- Novo widget `_ChipsRow`: Wrap de chips para types, stage, category, HP, regulationMark (tokens: `AppColors.tint`, `AppRadii.chip`, `AppType.caption`)
- Novo widget `_NationalDexBadge`: linha com nº Pokédex
- Novo widget `_PricingCard`: bloco completo Cardmarket + TCGplayer com conversão BRL via FxService, fallback para moeda original ou valor único do cache

### 4. Supabase — colunas `stage` e `regulation_mark` (manual, dashboard)

## Verificação

1. `flutter analyze` limpo
2. `flutter test` verde
3. Rodar app → abrir detalhe → verificar chips, preços, Pokédex, scroll, fallbacks