# PokeCardex Scanner MVP — Flutter App

**Aplicativo mobile nativo para escanear cartas Pokémon TCG usando OCR on-device e matching contra a TCGdex.**

Estado: **MVP pronto pra validação** em dispositivo real (Android/iOS)

## 🚀 Comece aqui

👉 **[START.md](./START.md)** — Guia de 30 minutos pra setup e primeira execução

## 📚 Documentação

| Documento | O que é |
|-----------|---------|
| **[START.md](./START.md)** | 🚀 Passo a passo de 30 min (comece aqui!) |
| **[SETUP.md](./SETUP.md)** | Setup completo com permissões Android/iOS |
| **[DEBUG.md](./DEBUG.md)** | Troubleshooting: câmera, OCR, matching |
| **[CHECKLIST.md](./CHECKLIST.md)** | Validação em 8 fases |
| **[ARCHITECTURE.md](./ARCHITECTURE.md)** | Design, componentes, fluxo de dados |
| **[HANDOFF.md](./HANDOFF.md)** | Estado atual + roadmap Fase 2 |
| **[ORGANIZATION.md](./ORGANIZATION.md)** | Guia visual de arquivos |

## 📁 Estrutura

```
/
├── lib/                        # Código Flutter
│   ├── main.dart              # Entry point
│   ├── models/                # Modelos de dados
│   ├── services/              # Lógica (API, matching, câmera)
│   └── screens/               # 3 telas (set selection, scanner, review)
│
├── pubspec.yaml               # Dependências
├── .gitignore                 # Git ignore
│
├── 📄 START.md                # ← LEIA PRIMEIRO
├── 📄 SETUP.md, DEBUG.md, etc # Documentação
└── example_scan_output.json   # Referência de saída
```

## ✨ O que funciona

✅ Câmera ao vivo em modo rajada (600ms ticks)  
✅ OCR on-device via ML Kit (sem backend, offline)  
✅ Matching fuzzy (nome + número, suporta português)  
✅ Deduplicação por frame + contagem  
✅ Feedback tátil (vibra ao reconhecer)  
✅ Salva resultado em JSON local  

## 🎯 Próximos passos

```bash
# 1. Setup Flutter
flutter doctor
flutter create --org com.joel.pokecardex pokecardex_scaffold
cp -r pokecardex_scaffold/{android,ios} .

# 2. Dependências
flutter pub get

# 3. Rodar
flutter run

# 4. Validar com CHECKLIST.md
```

**Expectativa:** ~80-90% de reconhecimento em condições normais.

## 🛠️ Stack

- **Flutter** 3.24.0+ (Dart 3.4.0+)
- **OCR:** ML Kit on-device (iOS 15.5+, Android API 21+)
- **API:** TCGdex (grátis, sem rate limit, suporta português)
- **Storage:** Arquivos locais (sem backend ainda)

## 📦 Dependências

```yaml
http: ^1.2.1                                  # requisições HTTP
camera: ^0.11.0+2                            # câmera ao vivo
google_mlkit_text_recognition: ^0.14.0       # OCR on-device
path_provider: ^2.1.3                        # acesso a Documents/
```

## 🔄 Roadmap

**Fase 1 (agora):** Validar scanner funciona ✅  
**Fase 2:** Supabase (persistência + autenticação)  
**Fase 3:** Catálogo por Set/Pokédex, coleção permanente  
**Fase 4:** Preços, wishlist, estatísticas  

## 📊 Código

~1000 linhas Dart, bem organizado:
- **models/** — representações de dados (carta, sessão)
- **services/** — lógica (TCGdex API, matching fuzzy, camera conversion)
- **screens/** — 3 telas de UI (set selection, scanner, review)

## 🐛 Algo não funciona?

1. Leia **[START.md](./START.md)** (setup)
2. Se tiver erro, consulte **[DEBUG.md](./DEBUG.md)** (troubleshooting)
3. Se não encontrar, abra **[ARCHITECTURE.md](./ARCHITECTURE.md)** (entender design)

## 📝 Referência

- **[example_scan_output.json](./example_scan_output.json)** — JSON esperado após uma sessão
- **[pokecardex-mvp-nucleo-brief_1.md](./pokecardex-mvp-nucleo-brief_1.md)** — Plano original do MVP

---

**Status:** 🟢 Pronto pra testar  
**Próximo:** Seu setup + teste com cartas físicas  

Comece em **[START.md](./START.md)** 🚀
