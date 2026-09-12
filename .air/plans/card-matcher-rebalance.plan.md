# Plano: Rebalancear o scoring do CardMatcher

## Contexto

O scanner sugere cartas aleatórias porque o número do rodapé (collector number) sozinho vale 0.55 — exatamente o `confidenceThreshold` — e basta para auto-confirmar uma carta sem nenhuma evidência de nome. Números de dano, HP ou texto aleatório no ambiente disparam o matcher mesmo sem carta na imagem. O usuário espera que a carta sugerida ao menos tenha o nome certo.

## Abordagem

Rebalancear os pesos para que **número sozinho nunca auto-confirme** e adicionar um "portão de nome" (`_nameEvidenceMin`) que exige alguma evidência do nome da carta antes de mostrar resultados. Quando o nome não sai no OCR (full art/holo), número+denominador ainda aparece como opção — mas em modo multi-escolha, nunca como "carta clara" de 1 toque.

## Alterações em `lib/services/card_matcher.dart`

### 1. Novos pesos em `_scoreCard`

| Sinal | Atual | Novo | Motivo |
|---|---|---|---|
| Numerador exato | +0.55 | **+0.40** | Não ultrapassa confidence sozinho |
| Numerador + denominador | +0.20 (total 0.75) | **+0.20** (total 0.60) | Cai junto com numerador |
| 1 dígito errado | +0.34 | **+0.25** | Proporcional à redução |
| Número cru no texto | +0.30 | **+0.15** | Mata phantom triggers de HP/dano |
| Nome exato (substring) | +0.60 | **+0.55** | Leve redução |
| Nome fuzzy (sim >= 0.72) | 0.55 × sim | **0.50 × sim** | Proporcional |
| Nome fuzzy (sim < 0.72) | 0.60 × sim | **0.55 × sim** | Proporcional |

### 2. Nova função `_nameScore` e portão de nome

Extrair score do nome numa função separada. Nova constante `_nameEvidenceMin = 0.10`.

No `match()`, após ranking:
- Se melhor candidato tem `_nameScore < _nameEvidenceMin`:
  - Com número+denominador (score >= 0.50): **multi-choice** (nunca auto-confirma)
  - Só número sem denominador: **suprime** resultado

### 3. Ajuste de thresholds

| Threshold | Atual | Novo |
|---|---|---|
| `_showMinScore` | 0.40 | **0.35** |
| `_candidateMinScore` | 0.34 | **0.28** |
| `_clearMargin` | 0.18 | **0.15** |
| `confidenceThreshold` | 0.55 | **0.55** (mantém) |

### 4. `matchGlobal()` — set-code path

Linha 144 hoje confia cegamente no set code. Adicionar: exigir `_nameScore >= 0.10` OU score >= 0.50 para aceitar.

## Arquivos

- **`lib/services/card_matcher.dart`** — pesos, portão de nome, thresholds, matchGlobal
- **`test/widget_test.dart`** — ajustar teste "full art: número decide" e adicionar cenários novos

## Testes existentes — impacto

- "full art: número decide mesmo sem o nome sair" — **muda intencionalmente**: input `'ruído 149 / 132 mais ruído'` sem nome → não deve mais auto-confirmar. Ajustar para incluir traço de nome ou aceitar multi-choice.
- Demais testes continuam passando.

## Novos cenários de teste

1. Número sozinho sem nome → nunca single-choice
2. Texto aleatório sem carta → choices vazio
3. Nome garbled + número → sugere carta certa
4. Global com set code mas sem nome → validação extra

## Verificação

1. `flutter test` verde
2. `flutter analyze` limpo
3. Manual: sem carta na imagem → sem sugestão
4. Manual: carta com nome legível → carta correta
5. Manual: holo com nome ilegível + número claro → multi-choice