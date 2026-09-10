# CLAUDE.md — PokeCardex

Scanner de cartas Pokémon TCG + gerenciador de coleção.
Flutter/Dart · Supabase (sa-east-1) · TCGdex API · ML Kit OCR.

> Detalhes completos em `HANDOFF.md`. Design spec em
> `design_handoff_pokedex_tcg_atualizado/README.md`.

## Comandos

```bash
flutter run --dart-define-from-file=env.json   # sem isso abre _MissingConfig
flutter test
flutter analyze
```

`env.json` (gitignored) tem `SUPABASE_URL` e `SUPABASE_ANON_KEY`.
Template em `env.example.json`.

## Estrutura

```
lib/
  config.dart              # String.fromEnvironment (build-time)
  main.dart                # Supabase.initialize + Provider + AuthGate
  models/                  # Card, CardDetail, TcgCard
  repositories/            # DB-first: abstract Store → SupabaseStore
  services/                # auth, tcgdex API, card_matcher, camera
  state/                   # AppShellController (ChangeNotifier)
  screens/                 # auth/, scan/, collection, detail, app_shell
  theme/                   # AppColors, AppType, AppRadii, AppShadows
  widgets/                 # FloatingTabBar, PrimaryButton, AppWidgets
```

## Arquitetura

- **State:** `provider` + `ChangeNotifier`. Controllers via `ChangeNotifierProvider` no root.
- **Navegação:** Navigator 1.0 imperativo, `IndexedStack` no `AppShell` (5 abas). Sem go_router.
- **Repositórios:** interface abstrata (`CollectionStore`) → impl Supabase. Construtor recebe store (injeção). Testes usam fakes manuais (sem mockito).
- **Tema:** light mode. Tokens em `lib/theme/` — `abstract final class` com getters/constantes estáticas. Fontes: Sora (headings), DM Sans (body), DM Mono (mono) via `google_fonts`.

## Regra de dados (FORTE)

Toda resposta de API externa (TCGdex, PokéAPI) DEVE ser gravada no Supabase ANTES de ir pra UI. Nenhuma tela chama API direto — sempre via repositório com TTL:
- Catálogo: 30 dias
- Preço: 24 horas
- Pokédex: ~infinito

Se a API cair, serve dado vencido.

## Convenções

- **Idioma:** português (BR) em UI, comentários, nomes de teste, strings. Código Dart (classes, variáveis) em inglês.
- **Arquivos:** snake_case (`collection_repository.dart`)
- **Tokens visuais:** `abstract final class` (AppColors, AppRadii, etc.) — zero valor hardcoded fora de `lib/theme/`
- **Modelos:** `const` constructors, factories `fromSupabaseRow` pra hidratar do banco
- **Testes:** `flutter_test`, fakes manuais que implementam a interface Store, descrições em português

## Gotchas

- `print()` pra debug no iOS — `developer.log()` não aparece de forma confiável
- Câmera: `ImageFormatGroup.bgra8888` no iOS, `yuv420` no Android (branch por plataforma)
- ML Kit exige iOS deployment target ≥ 16.0 (Podfile E pbxproj)
- SPM desabilitado (`flutter config --no-enable-swift-package-manager`) — usa CocoaPods
- `google_fonts` baixa em runtime (bundled .ttf pendente)
- Todo conteúdo rolável: `padding-bottom: 120` pra não ficar atrás da FloatingTabBar
- `AppShell` usa `IndexedStack` — abas não visíveis continuam montadas (dispose não roda ao trocar aba)

## Decisões travadas (NÃO reabrir)

- Preço de-emphasizado (sem gráfico, sem verde/vermelho, total aparece 1x)
- Reconhecimento nunca finge certeza — sempre candidatos com %
- Auth: email/senha only (sem social, sem anônimo)
- Sem telemetria/escala/monetização — 6 usuários, é presente
- Condição da carta não é pedida no salvamento, só editável no detalhe
- Região e Set coexistem (Jornadas por região, catálogo por set)

## Definition of done (por tela)

- `flutter analyze` limpo, `flutter test` verde
- Tokens do design system, zero hardcode fora de `lib/theme/`
- Dados via repositório (nunca API direto), funciona offline com cache
- Estados vazio / carregando / erro tratados
- Tab bar oculta em: candidates, confirm, detail
