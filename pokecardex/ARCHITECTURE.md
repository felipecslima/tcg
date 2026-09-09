# ARCHITECTURE — Design do Scanner MVP

## Visão geral

O PokeCardex Scanner é um **aplicativo móvel nativo (Flutter)** que identifica cartas Pokémon TCG através de **OCR on-device em modo rajada** (câmera contínua, sem botão de captura). Cada frame é processado, o texto reconhecido é comparado contra um catálogo de cartas, e matches confirmados disparam feedback tátil.

```
┌─────────────┐
│   Câmera    │ (live stream, YUV420/BGRA)
└──────┬──────┘
       │
       ▼
┌──────────────────────┐
│  CameraImageConverter│ (transforma frame pra InputImage)
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Text Recognition     │ (ML Kit on-device)
│ (google_mlkit)       │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  CardMatcher         │ (fuzzy match via Levenshtein)
│  contra lista local  │
└──────┬───────────────┘
       │
       ├─ Match confirmado ─▶ HapticFeedback + addMatch()
       │
       └─ Pendência ─▶ addPending()

┌──────────────────────┐
│  ScanSession         │ (acumula matches + pendências)
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  ReviewScreen        │ (exibe resultado, salva JSON local)
└──────────────────────┘
```

## Fluxo principal

### 1. SetSelectionScreen (primeira tela)

```dart
class SetSelectionScreen extends StatefulWidget
```

**O que faz:**
- Lista todos os **sets da TCGdex** (com paginação possível)
- Permite trocar **idioma** (Inglês, Português, etc)
- Ao selecionar um set, **busca suas cartas** e navega pra câmera

**Por que é importante:**
- O **pré-filtro de set reduz drasticamente o espaço de busca** (de 10k+ cartas pra ~100-200)
- Isso é a **maior alavanca de precisão** do matching — mais importante que o OCR em si

**Dados capturados:**
- `setId`, `setName`, `language` — passados pra ScannerScreen

### 2. ScannerScreen (câmera ao vivo)

```dart
class ScannerScreen extends StatefulWidget
```

**O que faz:**
- Inicializa a câmera traseira em modo **stream contínuo** (não há botão "tirar foto")
- A cada **600ms**, processa o frame mais recente:
  1. Converte `CameraImage` pra `InputImage` (ML Kit)
  2. Roda OCR on-device
  3. Normaliza o texto
  4. Envia pro matcher
  5. Se match: vibra + conta; se pendência: anota na lista
- Exibe em tempo real: quantas cartas únicas, total, pendências
- Botão "Revisar" navega pra tela final

**Deduplicação (evita contar a mesma carta 3x ao apontar):**
```dart
if (card.id == _lastMatchedCardId) return; // mesma carta ainda visível
```

**Pause/Play:** Botão pause congela o stream pra reposicionar sem perder sessão.

### 3. ReviewScreen (resultado final)

```dart
class ReviewScreen extends StatefulWidget
```

**O que faz:**
- Lista cartas **reconhecidas com sucesso** (nome, número, thumbnail, contagem)
- Lista **pendências** (texto bruto que não casou com nada)
- Botão "Salvar sessão (JSON local)" escreve tudo em `Documents/`

**JSON gerado:**
```json
{
  "setId": "sv04.5",
  "setName": "Scarlet & Violet: Temporal Forces",
  "language": "en",
  "scannedAt": "2026-09-09T14:30:00Z",
  "scanned": [
    {
      "cardId": "sv04.5-001",
      "name": "Pikachu",
      "localId": "001",
      "count": 2
    },
    {
      "cardId": "sv04.5-025",
      "name": "Charizard ex",
      "localId": "025",
      "count": 1
    }
  ],
  "pending": [
    {
      "rawText": "Blastoise\nHP 120\nBasic",
      "scannedAt": "2026-09-09T14:31:15Z"
    }
  ]
}
```

## Componentes-chave

### TcgdexApiService

```dart
class TcgdexApiService
```

**Responsabilidade:** Conversa com `api.tcgdex.net`

**Métodos:**
- `fetchAllSets(language)` — lista sets em um idioma
- `fetchCardsForSet(setId, language)` — busca todas as cartas de um set

**Por que:**
- TCGdex é **grátis, sem rate limit, suporta português nativamente**
- Cada call é rápida (cache local possível em Fase 2)
- Se TCGdex cair, há mirror em `tcgdex/cards-database` (banco aberto)

**Isolamento:** Toda conversa com API fica aqui. Se trocarmos fonte depois (pokemontcg.io → outra), só reescrevemos esta classe.

### CameraImageConverter

```dart
class CameraImageConverter
```

**Responsabilidade:** Converter frame bruto da câmera em `InputImage` pronto pro ML Kit

**Por que é crítico:**
- Android entrega **YUV420** (3 planos), mas ML Kit quer **NV21** (Y + VU intercalado)
- iOS entrega **BGRA8888** (1 plano, direto)
- Erro aqui = OCR falha **silenciosamente** (nenhuma exception, só retorna null)

**Implementação:**
```dart
if (Platform.isIOS) {
  return _fromIosBgra(image, rotation);  // simples: 1 plano
}
if (Platform.isAndroid) {
  return _fromAndroidYuv420(image, rotation);  // complexo: 3 planos → NV21
}
```

**Armadilha:** Se o formato não for reconhecido, o matching simplesmente não funciona. Ver [DEBUG.md](./DEBUG.md) pra detalhar como checar.

### CardMatcher

```dart
class CardMatcher
```

**Responsabilidade:** Casar texto reconhecido (bruto, com ruído) contra a lista de cartas do set

**Algoritmo (2 sinais):**

1. **Sinal 1: Nome (70% do peso)**
   - Normaliza entrada e nome (lowercase, remove acentos)
   - Se o nome está contido na entrada: score = 1.0
   - Senão, testa janelas de tamanho similar no OCR
   - Calcula similaridade via **distância de Levenshtein normalizada**
   - Score final = distância normalizada

2. **Sinal 2: Número (30% do peso, desempate)**
   - Busca o número da carta (ex: "025") com regex word-boundary
   - Se encontrado: adiciona 0.3 ao score
   - É o **desempate entre "Charizard" normal vs "Charizard ex"**

**Threshold:** Padrão `0.55`. Abaixo disso → pendência, acima → match automático.

**Normalização:**
```dart
input
  .toLowerCase()
  .replaceAll(RegExp(r'[^\p{L}0-9\s]', unicode: true), ' ')  // remove pontuação, mantém acentos/letras
  .trim()
```

### ScanSession + Models

```dart
class ScanSession {
  Map<String, ScannedEntry> _scanned;  // cardId → entrada
  List<PendingEntry> pending;
}
```

**Gestão de estado durante a sessão:**
- Cada nova carta é deduplicada por `cardId`
- Se mesma carta aparece 2x, incrementa `count`
- Pendências ficam numa lista separada (podem ser resolvidas manualmente depois)

## Fluxo de dados

```
SetSelectionScreen
  ↓ (clica em set)
  └─ fetch cartas da TCGdex → ScannerScreen
                                 ↓
                              câmera ao vivo (600ms tick)
                                 ├─ frame → CameraImageConverter
                                 ├─ InputImage → TextRecognizer.processImage
                                 ├─ texto → CardMatcher.match(texto, candidates)
                                 │
                                 ├─ isConfident? → ScanSession.addMatch(card)
                                 │                    └─ HapticFeedback
                                 │
                                 └─ não? → ScanSession.addPending(rawText)
                                 
                          (clica "Revisar")
                                 ↓
                           ReviewScreen
                                 ├─ exibe matches + pendências
                                 └─ botão "Salvar" → Documents/scan_*.json
```

## Performance e threading

### MainThread (UI)

- Camera preview, UI updates, navigation

### Background (isolate do OCR)

- Não — ML Kit `processImage()` **bloqueia**. Por isso o `_isProcessing` flag evita chamar duas vezes.
- 600ms entre ticks é suficiente pra OCR terminar antes do próximo frame

### Camera streaming

- Contínuo, mas capturamos só o frame mais recente (`_latestFrame`)
- Se processamento atrasar, pulamos frames — não acumula fila

## Decisões de design

### Por que TCGdex e não pokemontcg.io?

- pokemontcg.io está sendo descontinuada (2027)
- TCGdex é mantida pela comunidade, **suporta português nativamente**
- Sem API key obrigatória, sem rate limit publicado
- Risco: sem SLA, mas há mirror aberto (`tcgdex/cards-database`)

### Por que OCR on-device?

- Grátis, sem custo por chamada
- Offline, funciona sem rede (depois que set é carregado)
- Privacidade (nenhuma imagem sai do dispositivo)
- Suporte iOS 15.5+, Android API 21+

### Por que modo rajada, não botão de captura?

- Mais rápido — não precisa alinhar carta, tirar foto, confirmar
- Mais natural — fluxo contínuo, feedback tátil é suficiente

### Por que pré-filtro de set?

- **Reduz de 10k+ cartas pra ~100-200**
- Isso é mais importante que melhorar OCR/matcher
- Threshold de 0.55 pode ser mantido porque o universo é pequeno

### Por que Levenshtein + regex de número?

- Levenshtein captura erros de OCR (Charizard → Cgarizard)
- Regex de número é desempate forte (evita confundir Charizard/Charizard ex)
- Combinação simples e eficaz

## Fase 2 (fora deste MVP)

Quando o scanner provar que funciona:

1. **Persistência Supabase**
   - Tabela `user_collections`: { userId, cardId, count, dateAdded }
   - Tabela `wishlist`: { userId, cardId }
   - Autenticação simples (email/senha ou anon)

2. **Catálogo UI**
   - Browser por set, por Pokédex
   - Estatísticas por tipo/raridade

3. **Preços**
   - TCGdex já retorna preço (EUR/USD)
   - Converter pra BRL, exibir em review screen

4. **Variantes**
   - Holo, reverso, graded
   - Detectar via arte (pHash matching)

Ver `pokecardex-mvp-nucleo-brief_1.md` pra roadmap completo.

## Testing

Não há testes unitários neste MVP porque:
- CameraImageConverter precisa de dispositivo real
- TextRecognizer precisa de dispositivo real
- CardMatcher pode ter testes, mas o resto da cadeia não

Plano: Validação manual em dispositivo real é a first gate — só depois adicionar testes unitários.

## Docs adicionais

- [SETUP.md](./SETUP.md) — como rodar o projeto
- [DEBUG.md](./DEBUG.md) — troubleshooting detalhado
- [README.md](./README.md) — overview rápido
