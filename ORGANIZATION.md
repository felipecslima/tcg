# ORGANIZATION — Guia Visual do Projeto

## Estrutura de pastas

```
pokecardex/
│
├── 📄 README.md                    ← COMECE AQUI (overview rápido)
├── 📄 SETUP.md                     ← Como rodar o projeto
├── 📄 DEBUG.md                     ← Troubleshooting detalhado
├── 📄 CHECKLIST.md                 ← Validação fase por fase
├── 📄 ARCHITECTURE.md              ← Design & componentes
├── 📄 HANDOFF.md                   ← Estado atual & roadmap
├── 📄 ORGANIZATION.md              ← Este arquivo
│
├── 📄 pubspec.yaml                 ← Dependências Flutter
├── 📄 .gitignore                   ← Ignora build/ etc
│
├── 📝 example_scan_output.json      ← Exemplo de saída (referência)
│
├── lib/
│   │
│   ├── 📄 main.dart                ← Entry point
│   │
│   ├── models/
│   │   ├── 📄 tcg_card.dart                 ← Modelo de carta
│   │   └── 📄 scan_session_models.dart      ← Sessão + pendências
│   │
│   ├── services/
│   │   ├── 📄 tcgdex_api_service.dart       ← Cliente TCGdex (HTTP)
│   │   ├── 📄 card_matcher.dart             ← Matching fuzzy
│   │   └── 📄 camera_image_converter.dart   ← Frame → InputImage
│   │
│   └── screens/
│       ├── 📄 set_selection_screen.dart     ← Tela 1: Idioma + Set
│       ├── 📄 scanner_screen.dart           ← Tela 2: Câmera ao vivo
│       └── 📄 review_screen.dart            ← Tela 3: Resultado
│
└── android/                        ← Será gerado (Flutter)
    ios/                            ← Será gerado (Flutter)
    build/                          ← Será gerado (compilação)
```

## Fluxo de navegação

```
[SetSelectionScreen]
    ↓ (clica em set)
    ├─ carrega cartas da TCGdex
    ↓
[ScannerScreen]
    ├─ câmera ao vivo
    ├─ OCR 600ms ticks
    ├─ matching fuzzy
    ├─ acumula em ScanSession
    ↓ (clica Revisar)
[ReviewScreen]
    ├─ exibe matches + pendências
    ↓ (clica Salvar)
    └─ Documents/scan_*.json
```

## O que ler primeiro (ordem)

1. **README.md** (2 min)  
   → O que é, quick start

2. **SETUP.md** (10 min)  
   → Como colocar pra rodar

3. **CHECKLIST.md** (5 min)  
   → Validação após primeira execução

4. **DEBUG.md** (quando quebrar)  
   → Troubleshooting específico

5. **ARCHITECTURE.md** (15 min)  
   → Entender o design completo

6. **HANDOFF.md** (10 min)  
   → Estado atual & próximas fases

## Arquivos principais por responsabilidade

### Setup & Config
- `pubspec.yaml` — dependências
- `.gitignore` — git ignore

### Documentação
- `README.md` — overview
- `SETUP.md` — setup completo
- `DEBUG.md` — troubleshooting
- `ARCHITECTURE.md` — design
- `CHECKLIST.md` — validação
- `HANDOFF.md` — estado & roadmap
- `ORGANIZATION.md` — este arquivo

### Código: Modelos de dados
- `lib/models/tcg_card.dart` — representa uma carta
- `lib/models/scan_session_models.dart` — estado da sessão

### Código: Serviços (lógica de negócio)
- `lib/services/tcgdex_api_service.dart` — requisições HTTP
- `lib/services/card_matcher.dart` — fuzzy matching
- `lib/services/camera_image_converter.dart` — conversão de frames

### Código: UI (telas)
- `lib/screens/set_selection_screen.dart` — seleção set/idioma
- `lib/screens/scanner_screen.dart` — câmera + OCR
- `lib/screens/review_screen.dart` — resultado final
- `lib/main.dart` — entry point

### Exemplos & Referência
- `example_scan_output.json` — JSON de saída esperado

## Tamanhos aproximados

```
lib/services/card_matcher.dart              ~125 linhas (core matching logic)
lib/services/camera_image_converter.dart    ~120 linhas (tricky converters)
lib/screens/scanner_screen.dart             ~250 linhas (camera + OCR loop)
lib/screens/set_selection_screen.dart       ~160 linhas (UI + API)
lib/screens/review_screen.dart              ~115 linhas (UI + file I/O)
lib/services/tcgdex_api_service.dart        ~90 linhas (HTTP client)
lib/models/tcg_card.dart                    ~55 linhas (data class)
lib/models/scan_session_models.dart         ~65 linhas (state management)
lib/main.dart                               ~25 linhas (entry)
─────────────────────────────────────────────────
Total:                                      ~1000 linhas (limpo)
```

## Qual arquivo editar para...

| Objetivo | Arquivo |
|----------|---------|
| Mudar threshold de matching | `lib/services/card_matcher.dart` (linha 19) |
| Mudar intervalo de OCR (600ms) | `lib/screens/scanner_screen.dart` (linha 58) |
| Adicionar novo idioma | `lib/screens/set_selection_screen.dart` (linha 105-109) |
| Mudar fonte de dados | `lib/services/tcgdex_api_service.dart` |
| Mudar formato JSON | `lib/screens/review_screen.dart` (linhas 31-50) |
| Adicionar logging | Procurar `developer.log` e adicionar em outro lugar |
| Mudar UI das telas | Procurar `Widget build(BuildContext context)` |

## Dependências explicadas

```yaml
http: ^1.2.1
  → Requisições pra TCGdex API

camera: ^0.11.0+2
  → Câmera ao vivo, stream contínuo

google_mlkit_text_recognition: ^0.14.0
  → OCR on-device, detecta texto em imagens

path_provider: ^2.1.3
  → Acessa Documents/ pra salvar JSON

flutter:
  → Framework base

cupertino_icons: ^1.0.8
  → Ícones (não crítico)
```

## Ciclo de vida da app

```
main.dart
  ↓
PokeCardexScannerApp (MaterialApp)
  ↓
SetSelectionScreen (primeiro estado)
  ├─ initState() — carrega lista de sets
  ├─ _language — idioma selecionado
  ├─ _sets — lista de sets carregados
  └─ onTap(set) → push ScannerScreen
      ↓
      ScannerScreen
        ├─ initState() — inicia câmera
        ├─ _controller — controle da câmera
        ├─ _textRecognizer — ML Kit
        ├─ _session — acumula matches
        ├─ _processingTimer — tick 600ms
        └─ onPressed("Revisar") → push ReviewScreen
            ↓
            ReviewScreen
              ├─ exibe _session.scannedEntries
              ├─ exibe _session.pending
              └─ onPressed("Salvar") → writeAsString(JSON)
```

## Commits sugeridos (quando tiver Flutter rodando)

```bash
# 1. Após setup completo
git add pokecardex/
git commit -m "MVP PokeCardex Scanner: estrutura Flutter completa"

# 2. Após validação básica
git commit -m "Validação de câmera + OCR no dispositivo real"

# 3. Após teste com cartas
git commit -m "Calibração de threshold pós-teste em produção"

# 4. Antes de Fase 2
git tag -a v0.1.0-mvp -m "Scanner MVP validado"
```

## Próximos passos

1. **Criar estrutura nativa:**
   ```bash
   flutter create --org com.joel.pokecardex pokecardex_scaffold
   cp -r pokecardex_scaffold/{android,ios} pokecardex/
   ```

2. **Adicionar permissões** (ver SETUP.md)

3. **Rodar primeira vez:**
   ```bash
   flutter run
   ```

4. **Validar** com CHECKLIST.md

5. **Calibrar** conforme DEBUG.md

6. **Documentar achados** em um arquivo chamado `VALIDATION_RESULTS.md`

---

**Dúvida sobre organização?** Procure em [ARCHITECTURE.md](./ARCHITECTURE.md) ou [DEBUG.md](./DEBUG.md).
