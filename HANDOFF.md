# Handoff — PokeCardex Scanner (Flutter MVP)

> Escrito em 2026-09-09 pra outra sessão/IA continuar. O app está **rodando
> de ponta a ponta num iPhone físico** (câmera → OCR → match → salvar JSON).
> Leia isto antes de mexer — a maior parte do tempo dessa sessão foi gasta
> destravando o pipeline iOS (Xcode/CocoaPods/assinatura/câmera), não no
> produto em si. Não repita esse trabalho.

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
