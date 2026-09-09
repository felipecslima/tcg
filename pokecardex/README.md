# PokeCardex Scanner — MVP

**Aplicativo Flutter para escanear cartas Pokémon TCG usando OCR on-device + matching contra TCGdex.**

Foco: **só no scanner funcionar bem** — sem catálogo, sem coleção permanente, sem Supabase ainda (ver roadmap em `pokecardex-mvp-nucleo-brief_1.md`).

## Quick Start

```bash
# 1. Gerar estrutura nativa (primeira vez)
flutter create --org com.joel.pokecardex pokecardex_scaffold
cp -r pokecardex_scaffold/{android,ios} ./pokecardex/
rm -rf pokecardex_scaffold

# 2. Dependências + permissões (ver SETUP.md)
flutter pub get
# (adicionar permissões em AndroidManifest.xml + Info.plist)

# 3. Rodar
flutter run
```

**Documentação completa:**
- [SETUP.md](./SETUP.md) — passo a passo detalhado pra colocar pra rodar
- [DEBUG.md](./DEBUG.md) — troubleshooting se algo não funcionar
- [ARCHITECTURE.md](./ARCHITECTURE.md) — design e componentes

## O que funciona

✓ Câmera ao vivo em modo rajada (600ms ticks)  
✓ OCR on-device via ML Kit (sem backend)  
✓ Matching fuzzy (nome + número)  
✓ Deduplicação por frame  
✓ Feedback tátil (vibra ao reconhecer)  
✓ Salva resultado em JSON local  

## Estrutura do projeto

```
lib/
  main.dart
  models/
    tcg_card.dart              # modelo de carta
    scan_session_models.dart   # estado da sessão
  services/
    tcgdex_api_service.dart    # cliente TCGdex
    card_matcher.dart          # matching fuzzy
    camera_image_converter.dart # frame → InputImage
  screens/
    set_selection_screen.dart  # escolher set/idioma
    scanner_screen.dart        # câmera + OCR
    review_screen.dart         # resultado final
```

## Próximas fases

1. **Fase 0:** Validar algoritmo com fotos reais (você)
2. **Fase 1:** Testes extensivos no scanner (está aqui agora)
3. **Fase 2:** Persistência Supabase + catálogo/coleção
4. **Fase 3:** Preços, wishlist, estatísticas

Ver `pokecardex-mvp-nucleo-brief_1.md` pra roadmap completo.
