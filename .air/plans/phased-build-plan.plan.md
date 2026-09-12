# Plano: Construir as telas que faltam do PokeCardex

## Contexto

O app tem a infraestrutura pronta (auth, repositórios DB-first, tema light, scan flow com 5 telas, coleção tab 0) mas 4 das 5 abas estão incompletas: Jornadas (placeholder), Busca (placeholder), Perfil (stub com email+logout) e o CardDetail ainda usa modelos legados com layout antigo. Este plano cobre todas as telas restantes em ordem que maximiza reuso.

## Abordagem

Construir de dentro pra fora: primeiro o CardDetail (tela de destino de todas as outras), depois Busca (simples, reusa repos existentes), Perfil (dados agregados), e por último Jornadas + Cartas da Região (dados mais complexos com regiões → dex → cartas). Cada fase produz um incremento testável. Widgets e métodos compartilhados são extraídos conforme necessários em cada fase, não antecipadamente.

---

## Fase 1 — Card Detail (reescrita)

**Objetivo:** Substituir `card_detail_screen.dart` pelo layout do design spec, usando o modelo unificado `Card` e `CardRepository.fetchCardDetail()` em vez de chamar API direto.

### Mudanças

**Modificar `lib/screens/card_detail_screen.dart`** — reescrita completa:
- Receber `Card` (não `TcgCard`) + `origin` string (pra texto do botão Voltar)
- Se `card.isBrief`, chamar `CardRepository().fetchCardDetail(card.id)` no `initState`
- Layout: zona hero com `AppColors.gradVeil`, arte 190×265 com `AppShadows.hero`, botão "< Voltar" pill
- Card de ataques: container `AppRadii.xl`, header "ATAQUES" (`AppType.sectionLabel`) + HP badge em dourado, lista de ataques com círculos de energia coloridos (roxo/cinza) e dano em `DM Mono`
- Grid 2×2 stats: "Você tem" (qty do `CollectionCardEntry`), "Estado" (condition), "Acabamento" (finish), "Valor estimado" (priceBrl)
- Linha de metadata: "{set} · {num} · {rarity}" com raridade em `AppColors.gold`
- Nome em `AppType.cardTitle` (27px Sora 700)
- Sem tab bar (push completo)
- Remover `_PricingCard` (bloco de mercado detalhado não existe mais no design)

**Modificar `lib/screens/collection_screen.dart`** — atualizar navegação:
- Passar `Card` diretamente em vez de converter pra `TcgCard`
- Passar `CollectionCardEntry` (qty/condition/finish) junto

### Reuso existente
- `AppColors.gradVeil`, `AppShadows.hero`, `AppRadii.xl` — já existem em `lib/theme/`
- `AppType.cardTitle`, `AppType.sectionLabel`, `AppType.mono` — já existem
- `CardRepository.fetchCardDetail()` — já existe
- `RarityPill` — já existe em `lib/widgets/app_widgets.dart`

---

## Fase 2 — Busca (tab 3)

**Objetivo:** Substituir o placeholder de "Busca" por tela funcional com campo de busca, chips de atalho, lista de resultados com indicador de posse, e CTA de adicionar manualmente.

### Mudanças

**Criar `lib/screens/search_screen.dart`**:
- `TextField` com ícone de busca e botão limpar, borda muda de cor com texto
- Chips horizontais (reusar `AppChip`)
- Debounce de 400ms na busca
- Lista de resultados: thumbnail 44×61, nome+set+número, indicador de posse (verde/cinza)
- Seção label dinâmica: "SUGESTÕES PARA VOCÊ" / "{n} RESULTADO(S)"
- CTA tracejada "+ Adicionar carta manualmente" → `ConfirmScreen` sem câmera
- Tap em resultado → `CardDetailScreen`

**Adicionar em `lib/repositories/card_repository.dart`**:
- `searchCards(String query, {int limit = 6})` — busca textual via `ilike`

**Adicionar em `lib/repositories/collection_repository.dart`**:
- `ownedQuantityByCardId(List<String> cardIds)` → `Map<String, int>`

**Modificar `lib/screens/app_shell.dart`** — substituir placeholder tab 3

---

## Fase 3 — Perfil (tab 4)

**Objetivo:** Substituir o stub de email+logout pela tela completa com hero, XP, stats e conquistas.

### Mudanças

**Criar `lib/screens/profile_screen.dart`**:
- Hero zone com `AppColors.gradVeil`, avatar placeholder, nome + nível
- Barra de XP: track `AppColors.tint`, fill `AppColors.gradProgress`
- Grid 2×2 stats: cartas registradas, valor total, regiões iniciadas, sequência
- Conquistas (4 fixas): earned vs locked styling
- Botão de logout

**Criar `lib/services/collection_stats.dart`**:
- Extrair cálculo de stats da `CollectionScreen` pra reusar

**Modificar `lib/screens/app_shell.dart`** — substituir `_ProfileTab`

### Sistema de XP/Nível (hardcoded)
- 10 XP por carta, níveis progressivos
- 4 conquistas fixas checadas contra dados reais

---

## Fase 4 — Jornadas (tab 1) + Cartas da Região

**Objetivo:** Construir a trilha de regiões com progresso e a grade de cartas por região.

### Mudanças

**Criar `lib/screens/journeys_screen.dart`**:
- Toggle trilha/lista
- Trilha: linha tracejada (CustomPainter), nós circulares com progresso %
- Lista: cards com `ProgressBar`, porcentagem colorida

**Criar `lib/screens/region_cards_screen.dart`**:
- Grid 3 colunas, slots owned (arte) vs missing (silhueta com "?")
- Botão "< Jornadas", tab bar visível

**Adicionar em repositórios**:
- `CollectionRepository.fetchAllOwnedCardIds()`
- `CardRepository.fetchCardsByDexRange(int start, int end)`

**Modificar `lib/screens/app_shell.dart`** — substituir placeholder tab 1

### Fluxo de dados
regions → dexRange → cards do catálogo → cruzar com owned → progresso

---

## Fase 5 — Edge cases e polish

- Coleção vazia: ilustração + "Escaneie sua primeira carta!" + botão pra tab scan
- Busca sem resultados: mensagem + sugestão
- Preço indisponível: "—" (já funciona com null)
- Erro de rede: widget `ErrorRetryView` reutilizável
- Câmera sem permissão: tela com instrução + botão settings

---

## Verificação

Após cada fase:
1. `flutter analyze` limpo
2. `flutter test` verde
3. Teste manual no simulador

## Riscos

- `national_dex_id` null em treinadores/energias — Jornadas só conta Pokémon com dex ID
- Performance `ilike` em 23.5k cartas — começar simples, migrar pra `textSearch` se necessário
- Conquistas hardcoded — 4 fixas bastam pra 6 usuários