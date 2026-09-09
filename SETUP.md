# PokeCardex Scanner MVP — Setup Completo

Este documento guia você pelo setup do projeto Flutter do zero até rodar no seu dispositivo.

## Pré-requisitos

- **macOS, Windows ou Linux** com 10GB de espaço livre
- **Flutter SDK 3.24.0+** (download: https://flutter.dev/docs/get-started/install)
- **Dispositivo físico** Android (mín. API 21) ou iOS (mín. 15.5) conectado via USB
- **Android Studio** (para Android) ou **Xcode** (para iOS)

## Passo 1: Instalar Flutter

Se você ainda não tem Flutter instalado:

```bash
# Baixar Flutter (macOS/Linux/Windows)
git clone https://github.com/flutter/flutter.git -b stable

# Adicionar Flutter ao PATH (consulte https://flutter.dev/docs/get-started/install)
```

Validar:
```bash
flutter doctor
```

Todos os itens marcados com ✓ (menos talvez web/analytics, que podemos ignorar).

## Passo 2: Gerar estrutura nativa do projeto

Este arquivo só contém `lib/` e `pubspec.yaml`. Você precisa das pastas nativas (`android/` e `ios/`) geradas pelo Flutter.

**Primeira vez, num diretório NOVO:**

```bash
# Crie um projeto scaffold temporário (só pra pegar as pastas nativas)
flutter create --org com.joel.pokecardex pokecardex_scaffold

# Copie as pastas android/ e ios/ para este diretório
cp -r pokecardex_scaffold/android ./pokecardex/
cp -r pokecardex_scaffold/ios ./pokecardex/

# Limpe o temporário
rm -rf pokecardex_scaffold

# Entre no diretório final
cd pokecardex
```

## Passo 3: Dependências e permissões

### Baixar dependências
```bash
flutter pub get
```

### Permissões Android

Abra `android/app/src/main/AndroidManifest.xml` e procure pela tag `<manifest>`. Antes de `<application>`, adicione:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

Confirme também em `android/app/build.gradle` (dentro de `defaultConfig`):
```gradle
minSdkVersion 21
```

### Permissões iOS

Abra `ios/Runner/Info.plist` e procure pela tag `<dict>` principal. Adicione:

```xml
<key>NSCameraUsageDescription</key>
<string>Usado para escanear suas cartas físicas de Pokémon TCG.</string>
```

Abra `ios/Podfile` e confirme:
```ruby
platform :ios, '15.5'
```

## Passo 4: Conectar dispositivo

**Android:**
```bash
flutter devices  # deve listar seu Android
adb devices      # verifica se adb vê o dispositivo
```

**iOS:**
```bash
flutter devices  # deve listar seu iPhone/iPad
# Certifique-se de que o dispositivo está desbloqueado e confia no computador
```

## Passo 5: Rodar o app

```bash
flutter run
```

Ou, se houver múltiplos dispositivos:
```bash
flutter run -d <device-id>
```

Na primeira execução, vai compilar (pode levar 2-3 minutos). Depois é mais rápido.

## Checklist de funcionamento

Assim que o app abrir:

1. ✓ Aparece a tela "PokeCardex Scanner — MVP"
2. ✓ Botão de idioma (Inglês/Português) funciona
3. ✓ Lista de sets carrega (se houver rede)
4. ✓ Seleciona um set pequeno (< 200 cartas pra teste rápido)
5. ✓ Câmera abre sem travar
6. ✓ Aponta para uma carta e vê "Lendo: ..." na tela
7. ✓ Carta é reconhecida e feedback tátil dispara (vibra)
8. ✓ Botão "Revisar" navega pra tela de resultado
9. ✓ "Salvar sessão (JSON local)" cria um arquivo

Se **qualquer um desses passos falhar**, consulte [DEBUG.md](./DEBUG.md).

## Estrutura do projeto

```
pokecardex/
├── lib/
│   ├── main.dart                    # entry point
│   ├── models/
│   │   ├── tcg_card.dart
│   │   └── scan_session_models.dart
│   ├── services/
│   │   ├── tcgdex_api_service.dart
│   │   ├── card_matcher.dart
│   │   └── camera_image_converter.dart
│   └── screens/
│       ├── set_selection_screen.dart
│       ├── scanner_screen.dart
│       └── review_screen.dart
├── android/                         # gerado, não edite manualmente
├── ios/                             # gerado, não edite manualmente
├── pubspec.yaml
├── README.md
├── SETUP.md (este arquivo)
├── DEBUG.md
└── ARCHITECTURE.md
```

## Próximos passos após validação

1. Escanear uma sessão real com 5-10 cartas
2. Revisar `DEBUG.md` e ajustar `confidenceThreshold` conforme necessário
3. Conferir a saída JSON em `Documents/` do dispositivo
4. Uma vez estável, adicionar persistência Supabase (Fase 2)

## Troubleshooting rápido

| Erro | Solução |
|------|---------|
| `flutter: command not found` | Flutter não está no PATH — rodar `flutter doctor` e seguir instruções |
| `No connected devices` | Plugar dispositivo, ativar USB Debug (Android) ou confiar em computador (iOS) |
| Câmera não abre | Verificar permissões em Settings → Apps → PokeCardex |
| Nenhum texto sendo lido | Ver [DEBUG.md](./DEBUG.md) — seção "Câmera não reconhece texto" |
| App crasha ao selecionar set | Conexão TCGdex falhou — verificar wifi/dados móveis |

## Suporte

Se estiver preso:
1. Rodar `flutter doctor -v` e compartilhar output
2. Verificar logs: `flutter run -v`
3. Consultar [DEBUG.md](./DEBUG.md) — detalhes completos lá
