# Handoff — PokeCardex

> ⬇️ **Fase atual (2026-09-10): Backend Supabase + design foundation + auth.**
> A seção logo abaixo é o estado mais recente. O handoff do scanner MVP
> (2026-09-09) continua válido e vem depois — o pipeline câmera→OCR→match
> não foi tocado nesta fase.

---

# Fase 2 — Backend + Design (2026-09-10)

## Contexto da virada
O app deixou de ser "só o scanner MVP". Chegou um **design hi-fi completo**
(`design_handoff_pokedex_tcg/` — 9 telas, tema dark lilás, tab bar
flutuante, README com todos os tokens) e a decisão de montar um **backend
Supabase** com auth, catálogo persistido e a coleção do usuário.

Escopo desta rodada (feito): **design foundation + Supabase + auth**.
Telas reais do design ficam pra próxima.

## Supabase — projeto `pokecardex`
- ref `muprvxukzvgyywftjbwu` · região `sa-east-1` · org `osupjgakavjsnrotpxne`
- URL `https://muprvxukzvgyywftjbwu.supabase.co`
- publishable key `sb_publishable_0hBB8glL5IhQ9MBT9s3P1w_Kj0NkGp7` (em `env.json`, gitignored)
- free tier ($0/mês)
- Painel: https://supabase.com/dashboard/project/muprvxukzvgyywftjbwu

### Schema aplicado (migrations 00–06, via MCP `apply_migration`)
| Grupo | Tabelas |
|---|---|
| Catálogo (RLS: leitura pública, escrita só service role) | `regions` (**já populada** Kanto→Paldea por faixa de national dex), `pokedex` (1..1025, FK `region_id`), `sets`, `cards` (com `hp`, `attacks` jsonb, `types`, `national_dex_id`, `variants`), `card_prices` (**append-only** — cada fetch é uma linha, alimenta variação %) |
| Infra de cache / fallback (RLS on, sem policy = service role) | `api_cache_raw` (payload cru append-only, nunca perde original), `fetch_log` (`next_refresh_at` por entidade → dirige sync incremental), `sync_runs` (observabilidade dos jobs) |
| Por usuário (RLS `auth.uid()`) | `profiles` (1:1 auth.users — nome, avatar, level, xp, streak), `collections`, `collection_cards` (finish/condition/quantity 1–99), `wishlist` |

Trigger `handle_new_user` (SECURITY DEFINER, não exposto como RPC): no
signup cria `profiles` + 3 `collections` default (Minhas cartas / Deck /
Para trocar).

### Requisito de dados FORTE do usuário (não esquecer ao construir repositórios)
> Toda resposta de API externa (TCGdex cartas/preço, PokéAPI pokédex/região)
> DEVE ser gravada na nossa base ANTES de ir pra UI. A base é fonte primária
> e fallback offline. Nenhuma tela chama API direto — sempre via repositório
> com TTL (catálogo 30d, preço 24h, pokédex ~infinito). Se a API cair, serve
> o dado da base mesmo vencido.

### Estratégia de atualização (planejada, não implementada)
- `pg_cron` + `pg_net` já habilitados.
- Jobs: `sync-sets` (diário, detecta set novo — 1 request barato), `sync-set-cards` (fila, baixa cartas do set novo), `refresh-prices` (diário, madrugada, só cartas "quentes": em `collection_cards` ou vistas recentemente), `revalidate-stale-cards` (semanal, `updated_at` > 30d, lotes pequenos).
- Incremental sempre: `fetch_log` + `If-None-Match`/`If-Modified-Since`, backoff em 429.
- Sob demanda: abrir carta com preço > 24h dispara refresh em background, mostra valor antigo enquanto isso.

## Flutter — o que foi criado nesta rodada
`flutter analyze` limpo, `flutter test` 19/19 passando.

| Arquivo | Papel |
|---|---|
| `pubspec.yaml` | + `supabase_flutter: ^2.8.0`, `google_fonts: ^6.2.1` |
| `env.json` (gitignored) / `env.example.json` | chaves Supabase via `--dart-define-from-file` |
| `.gitignore` | + `/env.json` |
| `lib/config.dart` | `Config.supabaseUrl` / `.supabaseAnonKey` de `String.fromEnvironment`; `isConfigured` |
| `lib/theme/app_colors.dart` | todos os tokens de cor do README + `artGradient` |
| `lib/theme/app_typography.dart` | escala Sora / DM Sans / DM Mono (via google_fonts) |
| `lib/theme/app_theme.dart` | `AppTheme.dark` (ThemeData), `AppRadii`, `AppShadows`, `AppTheme.screenPadding` |
| `lib/widgets/primary_button.dart` | `PrimaryButton` (sombra, loading), `SecondaryButton` |
| `lib/widgets/app_widgets.dart` | `AppChip`, `ProgressBar`, `ArtPlaceholder`, `RarityPill`, `QtyStepper` |
| `lib/widgets/floating_tab_bar.dart` | `FloatingTabBar` + `TabItem` (blur 22, raio 26, translúcido) |
| `lib/services/auth_service.dart` | wrapper email/senha sobre `Supabase.instance.client.auth` |
| `lib/screens/auth/auth_gate.dart` | `StreamBuilder<AuthState>` → `AppShell` ou `LoginScreen` |
| `lib/screens/auth/auth_scaffold.dart` | moldura comum + `showAuthError` (mensagens PT) |
| `lib/screens/auth/login_screen.dart` | login + links p/ signup e reset |
| `lib/screens/auth/sign_up_screen.dart` | nome + email + senha (`display_name` vai no metadata → trigger) |
| `lib/screens/auth/forgot_password_screen.dart` | `resetPasswordForEmail` |
| `lib/screens/app_shell.dart` | 5 abas (`IndexedStack` + `FloatingTabBar`). **Placeholders** exceto: Escanear → push `SetSelectionScreen` (scanner atual), Perfil → mostra email + logout |
| `lib/main.dart` | `Supabase.initialize` (se `isConfigured`) + `AuthGate`; tela `_MissingConfig` se faltar env |

### Rodar
```bash
flutter run --dart-define-from-file=env.json
```
Sem o `--dart-define-from-file`, o app abre em `_MissingConfig`.

## Pendências desta fase (ordem sugerida p/ a próxima aba)
1. **Passo manual no painel Supabase:** Authentication → Providers → Email →
   **desligar "Confirm email"**. Sem isso o signup não gera sessão (espera
   confirmação por email) e o AuthGate não avança. MCP não expõe esse toggle.
2. ~~**`seed-pokedex`**~~ ✅ **FEITO (2026-09-10).** Edge Function em
   `supabase/functions/seed-pokedex/` (deployada, `verify_jwt=true`, aceita
   `?start=&end=` pra rodar por faixa). A tabela `pokedex` **já está populada**
   com as 1025 linhas (nome, tipos, sprite official-artwork, `region_id` +
   `generation` via faixa de dex) — feito via MCP batch, não pela função;
   contagem por região confere com os totais canônicos (Kanto 151 … Paldea 120).
   `sync_runs` tem a linha do job. Nomes vêm da PokéAPI em minúsculo com hífen
   (`mr-mime`, `deoxys-normal`) — normalizar pra display fica pendente.
3. ~~**Edge Functions de sync**~~ ✅ **FEITO (2026-09-10).** `sync-sets`,
   `sync-set-cards`, `refresh-prices` deployadas (`verify_jwt=false` + header
   `x-sync-key` em `public.sync_config`), schedules `pg_cron` ativos (03:00/03:15/
   03:30 BRT via `private_sync_invoke`). Código em `supabase/functions/`,
   migrations 07–10 em `supabase/migrations/`, doc em
   `supabase/functions/README.md`. Testadas de ponta a ponta: `sets` tem os
   218 sets + fila; `sync-set-cards` baixou 3 sets de teste (167 cartas brief);
   `refresh-prices` puxou preço da Charizard base1-4 (3 linhas em `card_prices`,
   carta enriquecida com hp/ataques/raridade).
   **Falta:** rodar a carga inicial das cartas —
   `select private_sync_invoke('sync-set-cards','limit=50')` ~5× no SQL editor
   (só 3 dos 218 sets têm cartas). `refresh-prices` no cron só age em cartas de
   coleção/wishlist; catálogo completo de preço vem sob demanda / lote manual.
4. **Camada de repositório "DB-first"** no Flutter: `CardRepository`,
   `SetRepository`, `PriceRepository`, `PokedexRepository` — leem da base,
   só chamam API no miss/stale, fazem upsert + gravam `api_cache_raw`.
   Adaptar `TcgdexApiService` (hoje bate direto na TCGdex) pra passar por aí.
5. **Telas reais do design** (README §Screens), sugestão: Coleção → Detalhe
   novo → Jornadas → Região → Busca → Perfil → Candidatos (sheet) → Confirmar.
   Reaproveitar `CardDetailScreen`/`ScannerScreen` adaptando ao tema novo.
6. **Fontes:** hoje via `google_fonts` (download runtime). README pede
   empacotar `.ttf` em `assets/fonts/` antes do release (uso offline).
7. Ataques/HP: vêm do TCGdex no endpoint de carta individual (`card.attacks`,
   `card.hp`) — o modelo `cards.attacks` (jsonb) já está pronto pra receber.

## Decisões já tomadas nesta fase (não reabrir)
- Auth: email/senha comum (sem social, sem anônimo).
- Região E Set coexistem (Jornadas por região, catálogo por set). Mapa
  Pokémon→região é por geração/faixa de national dex (fixo, já em `regions`).
- Pokédex/região: fonte é PokéAPI.
- Supabase do zero, `sa-east-1`.
- Chaves via `--dart-define-from-file`, não `lib/config.dart` versionado.

---

# Fase 1 — Handoff do Scanner MVP (2026-09-09)

> O app está **rodando de ponta a ponta num iPhone físico** (câmera → OCR →
> match → salvar JSON). Leia isto antes de mexer no scanner — a maior parte
> do tempo daquela sessão foi gasta destravando o pipeline iOS
> (Xcode/CocoaPods/assinatura/câmera), não no produto. Não repita esse trabalho.

## Estado agora

Funciona: seleciona idioma + set (com busca) → aponta câmera pra carta →
OCR reconhece nome + número → casa contra as cartas do set escolhido →
carta confirmada entra na sessão → tela de revisão → salva JSON local em
`Documents/`.

Testado no dispositivo físico do Joel (iPhone 17, iOS 26.6) via `flutter
run`. Várias cartas em sequência, incluindo sair da tela de scan e voltar —
sem travar.

**Nada disso está commitado ainda.** `git status` mostra os arquivos
modificados/novos (ver lista no fim). Revisar e commitar é o primeiro passo
de qualquer sessão nova.

## Arquitetura atual

```
lib/
├── main.dart                       # entry point, abre SetSelectionScreen
├── models/
│   ├── tcg_card.dart                # carta "brief": id, nome, número, imagem, dexIds
│   │                                 # SEM raridade/variante (holo/reverse/normal) — ver "Próximos passos"
│   └── scan_session_models.dart     # sessão de scan: matches + pendências
├── services/
│   ├── tcgdex_api_service.dart      # busca sets + cartas na TCGdex (api.tcgdex.net)
│   ├── card_matcher.dart            # OCR text → melhor carta candidata (Levenshtein + número)
│   └── camera_image_converter.dart  # CameraImage → InputImage do ML Kit (Android YUV420 / iOS BGRA8888)
└── screens/
    ├── set_selection_screen.dart    # idioma + busca de set (TextField filtra por nome)
    ├── scanner_screen.dart          # câmera ao vivo, processa 1 frame a cada 600ms
    └── review_screen.dart           # resultado da sessão + salvar JSON
```

**Matching é 100% texto (OCR)**, não visão computacional. `CardMatcher`
(lib/services/card_matcher.dart) normaliza o texto reconhecido e o nome de
cada carta candidata, mede similaridade por Levenshtein + bônus se o número
de coletor aparece no texto, e aceita se `score >= 0.55`. Fica restrito às
cartas do **set escolhido na tela anterior** — isso é o que o Joel quer
tirar (ver "Decisão pendente" abaixo).

## Bugs resolvidos nesta sessão (não repita o diagnóstico)

Ordem cronológica, do setup até o app rodando:

1. **Xcode incompleto + CocoaPods não instalado** — `sudo xcodebuild
   -runFirstLaunch` + `brew install cocoapods` (Ruby do sistema é 2.6, não
   dá pra usar `gem install` direto).
2. **Projeto iOS gerado com Swift Package Manager travando o build.** O
   `flutter create` moderno gera `ios/` com uma referência local de SPM
   (`XCLocalSwiftPackageReference` no `project.pbxproj`) mesmo quando os
   plugins (`google_mlkit_*`) só suportam CocoaPods. Isso trava o
   `xcodebuild -showBuildSettings` em "Resolve Package Graph" por 60s+.
   **Correção**: `flutter config --no-enable-swift-package-manager` +
   regenerar `ios/` do zero (`rm -rf ios && flutter create --platforms=ios
   --org com.joel.pokecardex .`), reaplicar `NSCameraUsageDescription` no
   Info.plist e `platform :ios, '16.0'` no Podfile (ML Kit exige
   `IPHONEOS_DEPLOYMENT_TARGET >= 16.0`, mudar no Podfile E no pbxproj).
3. **Modo Desenvolvedor desativado no iPhone** — sem isso, `xcrun devicectl`
   mostra `developerModeStatus: disabled` e o dispositivo fica preso em
   `connected (no DDI)` (Developer Disk Image nunca monta, `xcodebuild`
   trava tentando preparar o device). Ativa em Settings → Privacy &
   Security → Developer Mode, reinicia o iPhone.
4. **Conta Apple + Team de assinatura não configurados.** Não precisa da
   GUI do Xcode pra isso: o Team ID já fica em
   `~/Library/Preferences/com.apple.dt.Xcode.plist` (chave
   `IDEProvisioningTeamByIdentifier`) depois de logar a conta uma vez.
   Adicionar `CODE_SIGN_STYLE = Automatic;` e `DEVELOPMENT_TEAM =
   <TEAM_ID>;` direto nas 3 configs (Debug/Release/Profile) do target
   Runner no `project.pbxproj` evita ter que navegar Signing &
   Capabilities na UI.
5. **Confiar no certificado no iPhone** — Settings → General → VPN & Device
   Management, depois do primeiro install.
6. **Dois bugs reais no Dart**: `Icons.camera_off` não existe
   (era `Icons.videocam_off`); `List<int>` vs `Uint8List` no retorno de
   `_yuv420ToNv21` (Android).
7. **Permissão de rede local faltando no Info.plist** — sem
   `NSLocalNetworkUsageDescription` + `NSBonjourServices`
   (`_dartobservatory._tcp`), o app nem aparece em Settings → Privacy →
   Local Network no iPhone, e o `flutter run` nunca descobre o Dart VM
   Service (timeout de 60s, "not discovered").
8. **Câmera esticada/distorcida** — `CameraPreview` dentro de
   `Stack(fit: StackFit.expand)` ignora o `AspectRatio` interno. Correção:
   `Center(child: AspectRatio(aspectRatio: 1 / controller.value.aspectRatio,
   child: CameraPreview(controller)))` — o `1 /` é necessário porque o
   pacote `camera` devolve o aspect ratio no eixo do sensor (paisagem), não
   da tela (retrato).
9. **O bug que mais custou tempo: OCR nunca reconhecia nada no iOS.**
   `CameraController` pedia `imageFormatGroup: ImageFormatGroup.yuv420`
   (comentário no código dizia "YUV420 no Android / BGRA8888 no iOS", mas o
   controller não tinha branch por plataforma). No iOS, pedir `yuv420`
   **não cai pra bgra8888 — o plugin `camera_avfoundation` entrega YUV420
   bi-planar de verdade** (2 planos: Y + CbCr intercalado), formato
   diferente do planar de 3 planos do Android. O conversor
   (`camera_image_converter.dart`, função `_fromIosBgra`) só sabia lidar
   com 1 plano (BGRA8888) e retornava `null` sempre, silenciosamente (sem
   exception, só log que nem aparecia no console). **Correção**:
   `imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 :
   ImageFormatGroup.yuv420` no `CameraController` de
   `scanner_screen.dart`. Diagnosticado só depois de reintroduzir `print()`
   (debug via `developer.log` não aparecia nem no `flutter run -v`
   redirecionado nem no `flutter logs` — usar `print()` pra debug real).
10. **Câmera não se recuperava depois que o app saía de foreground.** iOS
    suspende a `AVCaptureSession` quando o app perde foreground (tela
    apaga, troca de app). `_ScannerScreenState` já tinha
    `WidgetsBindingObserver` registrado mas nunca implementava
    `didChangeAppLifecycleState` — corrigido: dispose do controller em
    `inactive`/`paused`, `_initCamera()` de novo em `resumed`.
11. **Câmera não retomava ao voltar da tela de Revisão.** `_finishSession`
    para o stream de propósito (assumindo fim da sessão), mas se o usuário
    aperta voltar em vez de fechar, nada reativava. Corrigido: `await
    Navigator.push(...)` (em vez de fire-and-forget) e reinicia
    `startImageStream` + o timer quando o `push` resolve (usuário voltou).
12. **Resolução da câmera baixa (`ResolutionPreset.medium`)** deixava a
    preview borrada em tela cheia e prejudicava o OCR de texto pequeno —
    trocado pra `ResolutionPreset.high`.

## Decisão pendente (é onde a próxima sessão deveria começar)

O Joel não quer escolher o set antes de escanear — quer apontar a câmera
pra qualquer carta e o app achar sozinho. Isso é fundamentalmente diferente
do MVP atual (que restringe o candidate pool a um set escolhido na tela
anterior pra reduzir ambiguidade do matching por texto).

**Duas opções discutidas, nenhuma implementada ainda:**

**A) Continuar com OCR de texto, tirar o pré-filtro de set.** Buscar
TODAS as cartas de todos os sets da TCGdex (não só um set), e casar contra
o catálogo inteiro. Mudança contida (troca a fonte de candidatos em
`TcgdexApiService`/`SetSelectionScreen`→`ScannerScreen`), mas: (1)
ambiguidade sobe — sem saber o set, "091/132" pode bater com cartas de
sets diferentes que só coincidem no número local; teria que confiar mais
no par número+denominador como âncora (a maior parte dos sets tem
contagem total diferente, mas não é único — ver ponto 3 do histórico do
motor de arte abaixo, "19 valores distintos" de denominador no índice); (2)
carregar 4000+ cartas de uma vez deixa o load inicial mais pesado
(paginação ou cache local viraria necessário).

**B) Portar o motor de reconhecimento por ARTE (pHash) pro Flutter.**
Existe um protótipo **browser/TypeScript** anterior (não faz parte deste
repo Flutter — está no histórico do git deste MESMO repositório, commits
`5e913a1` "Motor de reconhecimento por arte" e `9645ea5` "UI usa o motor de
arte") que resolveu EXATAMENTE isso: reconhece a carta pela imagem
(pHash multi-sinal + retificação de perspectiva + gate de número via OCR
só pra desambiguar as ~10% de cartas com "gêmeas visuais" / reprints),
buscando o catálogo inteiro sem pré-filtro de set. Validado em câmera
sintética: **97,5% de acerto em 1º lugar sem pré-filtro de set, 100% com,
0 falsos-positivos** em 80 casos adversariais. Recuperar esse código:

```bash
git show 5e913a1 --stat   # lista os arquivos do motor
git show 5e913a1:src/vision/recognizer.ts   # ver um arquivo específico
```

O detalhe técnico completo (por que a detecção de borda falhava, como o
gate de número foi corrigido, calibrações medidas) estava num
`HANDOFF.md` anterior que foi removido do working tree na "organização
final" (commit `9d84151`) — ainda está no histórico:

```bash
git show f2cb8c5~1:HANDOFF.md   # o handoff completo do motor de arte
```

**Recomendação dada ao Joel**: começar pela opção A (mudança pequena,
reaproveita o pipeline OCR que já está validado e funcionando) pra
verificar se a ambiguidade é um problema real na prática, e migrar pra B
(reescrever o motor de arte em Dart — é esforço de dias, não de uma
sessão) se A não for confiável o suficiente. **Ele ainda não decidiu.**

## Outro pedido em aberto: variante da carta (normal/reverse/holo)

O Joel perguntou se dava pra saber se uma carta escaneada é holo ou normal
— relevante porque muda o preço da coleção. Resposta dada: **não dá hoje**,
por dois motivos:

1. `TcgCard` (o modelo) não guarda raridade/variante — só nome, número,
   imagem, dexIds. O comentário no arquivo já avisa que isso foi deixado de
   fora de propósito nesse MVP.
2. Mesmo que o modelo guardasse "essa carta existe em holo no set" (dado
   que a TCGdex provavelmente tem no endpoint de carta individual, não no
   endpoint "brief" de set que o app usa hoje), isso é sobre a carta
   GENÉRICA, não sobre a cópia FÍSICA específica na mão do usuário — pra
   saber isso, ou é seleção manual (usuário toca "Normal/Reverse/Holo"
   depois do match) ou é visão computacional de verdade (analisar o
   brilho/textura da carta na foto — não implementado, não trivial).

**Não implementado ainda.** Se for pra frente, a rota mais rápida é seleção
manual na tela de review — foi isso que ficou sugerido, sem confirmação do
Joel ainda.

## Como rodar

```bash
cd /Users/felipelima/work/tcg
flutter run          # dispositivo físico precisa estar plugado e confiado
```

Pra reiniciar depois de mudar código nativo (não hot-reloadable):
```bash
pkill -f "flutter_tools.snapshot run"
flutter run
```

Debug real em iOS: `developer.log()` **não aparece** nem em `flutter run -v
> arquivo.log` nem em `flutter logs` de forma confiável nessa sessão — usar
`print()` temporário e ler direto do arquivo de log redirecionado do
`flutter run`.

## Arquivos modificados/novos nesta sessão (não commitados)

```
 M .gitignore
 M ios/Runner.xcodeproj/project.pbxproj        # SPM removido, DEVELOPMENT_TEAM, deployment target 16.0
 M ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
 M ios/Runner/Info.plist                        # câmera + rede local
 M lib/screens/scanner_screen.dart              # ver bugs 6,8,9,10,11,12 acima
 M lib/screens/set_selection_screen.dart        # campo de busca de set
 M lib/services/camera_image_converter.dart     # Uint8List fix
 M pubspec.lock
?? .metadata            # gerado pelo flutter create, ok manter
?? analysis_options.yaml # gerado pelo flutter create, ok manter
?? ios/Podfile           # gerado do zero (SPM-free), platform 16.0
?? test/                 # gerado pelo flutter create, widget_test.dart padrão (não adaptado ao app real)
```

`ios/` inteiro foi regenerado do zero — comparar com o commit anterior vai
mostrar um diff enorme nesse diretório, é esperado (é justamente a correção
do bug 2).
