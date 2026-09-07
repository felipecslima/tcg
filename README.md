# PokeCardex Core — protótipo do núcleo (scanner + matching)

Valida a peça de **maior risco técnico** do projeto: identificar automaticamente
uma carta física via reconhecimento de imagem e casá-la contra a base da
[pokemontcg.io](https://pokemontcg.io). Sem isso, cadastrar 1000+ cartas na mão é
inviável. Ainda **não** usa Lovable/Supabase — é um protótipo Vite + TS descartável.

## O que já está validado (motor de matching)

Rode a bateria de casos contra dados reais:

```bash
npm install
npm run validate
```

Resultado atual: **8/8 casos** contra o Base Set real.

### Achados que definem a estratégia

1. **Casar por `número + set` funciona e é idioma-agnóstico.** O número de coletor
   (ex. `4/102`) é impresso igual em qualquer idioma. Com o set já escolhido no
   pré-filtro, o número sozinho identifica a carta.
2. **Cartas em português NÃO precisam cair em pendência.** A API só traz `name`
   em inglês, então casar por *nome* falharia em PT — mas casar por *número*
   não. O OCR pode focar só no numerozinho do canto (região fixa, fonte limpa,
   sem holo por cima) em vez de ler o nome inteiro na arte. Isso **derruba o
   risco do OCR** e reordena a prioridade: **número é a âncora, nome é desempate.**
3. **O pré-filtro de set é arquitetura, não só otimização.** Buscamos todas as
   cartas do set **uma vez** no início do lote e casamos cada frame localmente
   (zero chamada de API por scan → instantâneo, funciona offline no lote).

## Estrutura

```
src/matching/        # motor puro, sem framework — portável pro Angular depois
  types.ts           # CardRecord, ScanInput, MatchResult
  normalize.ts       # normalização de número (âncora) + nome, variantes de OCR
  similarity.ts      # Levenshtein / razão de similaridade (desempate por nome)
  pokemontcg.ts      # cliente da API com retry (busca cartas do set, lista sets)
  engine.ts          # SetIndex + match(): número→nome, thresholds, pendências
scripts/validate.ts  # bateria de casos contra dados reais
src/main.ts          # demo interativo no browser (casca do futuro scanner)
index.html
```

## Demo interativo

```bash
npm run dev
```

Escolhe o set, digita número e/ou nome (como sairiam do OCR) e mostra o match
com confiança. É a mesma casca onde o loop de câmera vai plugar.

## Modelo de confiança

- `número único no set` → **0.92** (nome confirma → até 0.99; nome diverge, típico
  de carta PT, não derruba — só anota).
- `número via variante de OCR` (ex. `O04`→`4`) → **0.85** base.
- `sem número, só nome` (fuzzy) → razão de similaridade, exige margem sobre o 2º.
- abaixo do mínimo (0.7) ou número inexistente → **pendência** (não trava o lote).

## OCR do número — validado, com veredito honesto

Pipeline pronto (`src/scanner/`): captura de frame → recorte dos cantos (WOTC=
direita, moderno=esquerda) → pré-processa (grayscale/threshold/negate, 4 variantes
× 2 cantos) → Tesseract.js → parseia `N/M` → **valida cruzado contra o set**.

Rode a medição de hit-rate contra imagens reais:

```bash
npm run ocr:validate
```

### Regra de aceite (crítica)

**AUTO só quando lê `N/M` E o denominador `M` bate com o total do set.** Sem
isso, um número solto mal-lido que por acaso existe no set entra como
**falso-positivo** — foi o que aconteceu na primeira versão (4/8 falsos). Com a
regra endurecida: **0 falso-positivo**. Numa coleção que você confia, evitar
carta errada vale mais que recall.

### Hit-rate honesto (8 cartas, imagens limpas da API)

| resultado | contagem |
|---|---|
| AUTO correto | 2/8 |
| **AUTO falso-positivo** | **0/8** ✅ |
| Pendência (confirmação manual) | 6/8 |

- Lê bem: cartas com o número em borda **limpa/não-foil** (era WOTC, comuns antigas).
- Falha/pendência: **cartas modernas holo/full-art** — número branco sobre fundo
  holográfico derrota OCR ingênuo. Todas as modernas do teste caíram em pendência.
- ⚠️ Isto é o **teto otimista**: são imagens digitais perfeitas. Foto real de carta
  física (reflexo, ângulo, desfoque) tende a ser **pior**, não melhor.

### Veredito

OCR client-side (grátis) é **seguro mas de baixo rendimento**: serve como assist
que captura sozinho as cartas fáceis e manda o resto pra pendência (confirmação
manual rápida, já com a lista do set filtrada). Não resolve a coleção moderna
sozinho — que é exatamente por que os apps de referência cobram crédito por scan
(usam visão paga).

**A maior alavanca de cobertura NÃO é afinar mais o OCR** — é trocar de modalidade:
casar a **arte da carta** (perceptual hash / feature matching) contra as imagens do
set pré-filtrado, que já baixamos. É idioma- e holo-agnóstico, roda client-side e
de graça. Esse é o próximo experimento de maior valor.

## Próximos passos (fora do que já foi feito)

1. **Loop de câmera + OCR** — `getUserMedia` → `<canvas>` a cada ~400ms →
   OCR **só da região do número** (recorte do canto inferior). Decidir motor:
   Tesseract.js (grátis, client-side) provavelmente basta pra um número curto.
   **Precisa de fotos reais das cartas do Joel pra medir precisão.**
2. **Modo rajada** — fila de matches + feedback (beep/vibração), sem modal por carta.
3. **Pilha de pendências** — UI de resolução manual (busca por nome/número).
4. Migração do produto completo pra Lovable + Supabase (fases 1–3 do brief).

### Pergunta ainda aberta

- Confirmar com **cartas reais** que o número é sempre legível o suficiente pro
  OCR (holo/desgaste). É o que decide se o motor de reconhecimento pode ser 100%
  client-side e grátis.
