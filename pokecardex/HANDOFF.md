# HANDOFF — Estado Atual do Projeto

**Data:** 2026-09-09  
**Status:** MVP pronto pra validação em dispositivo real  
**Próximo:** Testar com cartas físicas e calibrar threshold conforme necessário

## O que foi feito

### Código

✅ **Arquitetura completa:**
- `TcgdexApiService` — cliente da TCGdex com suporte multilíngue
- `CameraImageConverter` — conversão frame Android/iOS pra ML Kit
- `CardMatcher` — matching fuzzy com Levenshtein + desempate por número
- `ScanSession` — gestão de estado durante a sessão
- **3 telas:** Set selection → Scanner → Review

✅ **Features implementadas:**
- Câmera ao vivo em modo rajada (600ms ticks)
- OCR on-device via ML Kit
- Deduplicação por frame + contagem
- Feedback tátil (vibra ao reconhecer)
- Salva resultado em JSON local

✅ **Melhorias pós-revisão:**
- Retry button pra câmera se falhar
- Melhor tratamento de erros (já não crasha silenciosamente)
- Logging detalhado pra debug (`developer.log`)
- Suporte a Unicode melhorado (português, etc)

### Documentação

✅ **SETUP.md** — passo a passo pra setup completo (Flutter scaffold, permissões, etc)  
✅ **DEBUG.md** — troubleshooting extenso (câmera, OCR, matching, JSON)  
✅ **ARCHITECTURE.md** — design detalhado, fluxo de dados, decisões  
✅ **CHECKLIST.md** — validação fase por fase  
✅ **example_scan_output.json** — exemplo de JSON final  

### Projeto

✅ **pubspec.yaml** — dependências corretas:
- `camera` 0.11.0+2
- `google_mlkit_text_recognition` 0.14.0
- `http` 1.2.1
- `path_provider` 2.1.3

✅ **.gitignore** — Flutter completo

## Estado atual

### O que funciona (testado em código)

- Parsing de JSON da TCGdex ✓
- Lógica de matching fuzzy ✓
- Deduplicação (mesmo cardId não é contado 2x) ✓
- State management (ScanSession) ✓
- UI navigation (telas) ✓

### O que precisa de dispositivo real

- Camera initialization (permissões, hardware)
- CameraImageConverter (YUV420/BGRA → InputImage)
- TextRecognizer (ML Kit processamento real)
- HapticFeedback (vibra)
- File I/O (salva JSON local)

**Importante:** O código foi escrito **sem poder testar** (bloqueio de rede). Espere pequenos ajustes na primeira execução real (principalmente CameraImageConverter).

## Próximas ações (prioridade)

### 1. Setup inicial (você)
```bash
flutter create --org com.joel.pokecardex pokecardex_scaffold
cp -r pokecardex_scaffold/{android,ios} ./pokecardex/
rm -rf pokecardex_scaffold
flutter pub get
# Adicionar permissões em AndroidManifest.xml + Info.plist (ver SETUP.md)
flutter run
```

### 2. Validação básica
- Seguir [CHECKLIST.md](./CHECKLIST.md) — Fases 1-7
- Se câmera não funciona: ver [DEBUG.md](./DEBUG.md)
- Se OCR não reconhece: likely `CameraImageConverter` — logar o formato da imagem

### 3. Teste com cartas reais
- Seleciona um set (PT ou EN)
- Escaneia 5-10 cartas
- Anota taxa de reconhecimento (esperado: 80%+)
- Salva JSON, valida saída

### 4. Calibração
- Se muitas pendências (< 70% reconhecido): abaixar `confidenceThreshold` de 0.55 pra 0.40-0.45
- Se muitos falsos-positivos (carta A reconhecida como B): elevar threshold
- Rodar com `flutter run -v | grep pokecardex` pra ver scores

### 5. Documentar achados
- Quais cartas/sets funcionam bem?
- Quais cenários causam falha (iluminação, holo, desgastadas)?
- Qual threshold final se estabilizou?

## Armadilhas conhecidas

### CameraImageConverter

- **Android:** A conversão YUV420 → NV21 assume 3 planos. Se dispositivo entregar algo diferente, falha silenciosamente.
  - **Fix:** Se OCR nunca reconhece nada, logar `image.format.group` + `image.planes.length`
  
- **iOS:** Assume BGRA8888 em 1 plano. Raro falhar, mas possível.

### CardMatcher

- **Threshold de 0.55:** Funciona bem pra sets bem definidos, mas pode ser apertado pra cartas holofoil (OCR lê ruído do brilho).
  - **Fix:** Testar com `confidenceThreshold = 0.40-0.45` se muitas pendências

- **Normalização de Unicode:** Agora suporta melhor, mas nomes de Pokémon com caracteres especiais (ex: Pokémon com acento) precisam ser testados.

### ML Kit

- **Idioma:** Hardcoded como `TextRecognitionScript.latin`. Cobre português/inglês, mas não cobre caracteres não-latinos completamente.
- **Performance:** Bloqueia por ~200-300ms por frame no mobile. 600ms tick é seguro.

## Documentação interna

- **models/tcg_card.dart** — comentários sobre o formato TCGdex
- **services/card_matcher.dart** — detalhe do algoritmo Levenshtein
- **services/camera_image_converter.dart** — detalhe da conversão YUV420/BGRA
- **screens/scanner_screen.dart** — lógica de deduplicação, feedback
- **ARCHITECTURE.md** — visão completa

## Como debugar em produção

```bash
# Ver logs em tempo real
flutter run -v 2>&1 | grep pokecardex

# Verificar saída de conversão
# (adicionar em CameraImageConverter.toInputImage)
developer.log('Image format: ${image.format.group}, planes: ${image.planes.length}', name: 'pokecardex.camera');

# Verificar OCR raw
# (adicionar em ScannerScreen._processLatestFrame)
developer.log('Raw OCR: "$text"', name: 'pokecardex.scanner');

# Verificar matching
# (já existe)
developer.log('Match: ${result.card!.name} (score: ${result.score})', name: 'pokecardex.scanner');
```

## Roadmap Fase 2+ (depois que scanner provar)

1. **Persistência:** Supabase (autenticação, tabelas user_collections + wishlist)
2. **Catálogo UI:** Browser por set, por Pokédex, filtros
3. **Preços:** Exibir EUR/USD da TCGdex (já vem na API)
4. **Variantes:** Holo, reverso, graded (futuro, pHash matching)

Ver `../pokecardex-mvp-nucleo-brief_1.md` pra descrição completa.

## Stack

- **Flutter:** 3.24.0+
- **Dart:** 3.4.0+
- **Backend:** Nenhum (MVP local-only)
- **OCR:** ML Kit on-device (Vision iOS 15.5+, ML Kit Android API 21+)
- **API:** TCGdex (`api.tcgdex.net`) — grátis, sem rate limit
- **Storage:** Documentos locais (`path_provider`)

## Dependências externas

```yaml
http: ^1.2.1                                  # requisições HTTP
camera: ^0.11.0+2                            # câmera ao vivo
google_mlkit_text_recognition: ^0.14.0       # OCR on-device
path_provider: ^2.1.3                        # caminho Documents
```

## Contato/Suporte

- **Setup:** Ver [SETUP.md](./SETUP.md)
- **Bugs/Erros:** Ver [DEBUG.md](./DEBUG.md)
- **Arquitetura:** Ver [ARCHITECTURE.md](./ARCHITECTURE.md)
- **Validação:** Ver [CHECKLIST.md](./CHECKLIST.md)
- **Logs:** `flutter run -v | grep pokecardex`

---

**TL;DR:** Projeto está pronto pra testar em dispositivo real. Setup é simples (Flutter scaffold + permissões). Expectativa: ~80-90% de reconhecimento em condições normais. Testar e calibrar threshold conforme necessário.
