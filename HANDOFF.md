# Handoff — Motor de reconhecimento por arte (art-matching)

> Escrito em 2026-09-07 pra outra sessão/IA continuar. **Atualizado no fim do
> mesmo dia (sessão 2)**: o bug ativo descrito na seção "Onde parei" foi
> diagnosticado e resolvido; a seção **"Resolução"** abaixo conta o que era de
> verdade e o que mudou. O histórico original foi mantido porque explica as
> decisões. Leia "Resolução" + "Estado agora" + "Próximos passos" antes de mexer.

## Estado agora (fim da sessão 2)

Motor de ponta a ponta funcionando e validado em câmera sintética
(`npm run e2e`, `N_SINGLE=120 N_TEMPORAL=40`). Números da última rodada
completa, comparados com a reprodução do estado da manhã:

| Métrica (câmera sintética) | Manhã (reproduzido) | Final |
|---|---|---|
| A) rank-1 global, frame único, sem set | 78,2% | **97,5%** |
| A) rank-1 dentro do set | 90,8% | **100%** |
| A) distância até a carta certa p50 / p90 | 38 / 57 | **13 / 30** |
| A) erro dos cantos detectados vs. verdade p50 / p90 | (não medido; ~3–6% pra dentro) | **0,2% / 2,1%** |
| B) carta NO catálogo: confirmou / erradas | 82,5% / 0 | **92,5% / 0** (24 por número lido, 13 pelo visual; as 3 cartas com gêmea NÃO confirmaram: o motor exige número lido pra reprint e o OCR não leu em 9 frames) |
| C1) ARTE fora do catálogo: falsa aceitação | 3/40 (era a antiga "C") | **0/40** |
| C2) REPRINT fora do catálogo (gêmea fica): falsa aceitação | 3/40 | **0/40** |
| D) sem carta: confirmações indevidas | 0 | **0** |

OCR do gate nesta rodada: fração lida em 30/82 tentativas na B e 73/147 na
C1 (era ~2% de manhã). O que sobra em aberto é RECALL de reprint (B: 0/3
gêmeas confirmadas em 9 frames — bloqueadas, não erradas), não precisão.

**Nada está commitado** (mesma situação da manhã, com mais arquivos). Ver
"Riscos" no fim.

## Resolução do bug ativo (o que era de verdade)

A hipótese do handoff original (corrida/timing do gate, `CONFIRM_MIN_SCORE`
baixo) estava errada. Foram três coisas, em cadeia, e a primeira era a raiz:

1. **A detecção de borda travava na moldura INTERNA da carta.** `detect.ts`
   escolhia o pico MÁXIMO de gradiente na faixa em torno do guia; as linhas
   internas (divisória de Fraqueza/Resistência, filete da moldura) têm mais
   contraste que a borda carta×mesa e ficam 3–6% pra dentro. Medido contra o
   quadrilátero verdadeiro que o renderizador sintético já conhecia: lados
   deslocados −3,5% (esq), −3,2% (dir), −5,7% (topo), −2,7% (base) na mediana.
   Consequências: (a) a distância do hash até a carta certa era p50=46 no
   warp detectado vs 14 no warp perfeito — quase toda a "folga" que faltava
   entre carta certa e impostor; (b) o recorte do OCR (y 0.90–0.975 do
   retificado) caía sobre a linha de Fraqueza/Resistência em vez do número.
   **Correção**: entre os picos locais com força ≥ `REL_PEAK` × máximo da
   varredura, fica o mais EXTERNO (`DETECT_TUNING.REL_PEAK = 0.25`, calibrado:
   0.4→dist 21, 0.25→19, 0.15→18, teto 14). Erro dos cantos caiu pra p50 0,2%.
2. **O gate de número não funcionava, e nunca tinha funcionado.** Instrumentado
   (`verificação da confirmada` na seção B): das 33 confirmações da manhã, 32
   eram "OCR inconclusivo 2× → aceita pelo visual" e 1 era um token solto
   ("72", lido do rodapé direito, onde fica o copyright) que por acaso bateu
   com o número da impostora. O OCR lia a fração certa em ~2% das tentativas.
   Causas: recorte fora do número (item 1), caixa `right` testada primeiro
   com short-circuit no primeiro token parseável, caixa `left` com duas linhas
   de texto + selos em modo SINGLE_LINE, pipe threshold+negate morto (0
   leituras em 65 frames).
3. **Os 3 falsos-positivos eram exatamente as 3 cartas da amostra com uma
   gêmea visual no índice** (reprints: sv04.5-028→sv01-085 Kirlia d=2,7;
   sv08.5-049→sv04-093 Groudon d=0,1; me02.5-082→sv08-072 Togekiss d=4,0).
   Medido no catálogo inteiro: **9,7% das cartas (404/4157) têm uma gêmea a
   distância ≤5**, todas com o mesmo nome, e a carta DIFERENTE mais próxima
   fica ≥35. Estrutura bimodal limpa. Só o número impresso separa gêmeas — e
   o gate (item 2) não lia número.

### O que mudou no código

- `src/vision/detect.ts` — regra do pico mais externo (`DETECT_TUNING`).
- `src/vision/catalog.ts` — `twinsOf(id, {maxDist, exclude, setIds})`: gêmeas
  visuais de uma carta no catálogo pesquisável (varredura linear, ~ms).
- `src/vision/recognizer.ts` — gate reescrito:
  - a leitura devolve os **textos crus** do OCR (`NumberReading.texts`) e o
    motor compara com o número IMPRESSO esperado da candidata e das gêmeas
    ("028/091", "28/91") por distância de edição de substring
    (`printedDistance`), tolerando 1 dígito errado se a gêmea ficar ≥2 longe;
  - o **denominador** (total do set, só 19 valores distintos no índice) é
    checksum: total certo + numerador parcial 2× confirma; total de OUTRO set
    rejeita (1 leitura se o total existe no catálogo, 2 iguais se não);
  - **carta COM gêmea só confirma com número lido** (`OCR_MAX_ATTEMPTS_TWIN`);
    carta SEM gêmea aceita o visual após `OCR_MAX_ATTEMPTS=3` inconclusivas,
    marcada `verification='inconclusive'` pra UI sinalizar;
  - **limiar visual em dois níveis**: `CONFIRM_MAX_DIST=42` com número lido,
    `CONFIRM_MAX_DIST_VISUAL=32` sem (os falsos-positivos de arte ausente
    confirmavam a 38–42; a carta certa fica a p90=30);
  - rejeição revogável por leitura exata; gêmea confirmada pelo número é
    reforçada por id (`boostId`); não trava enquanto há OCR em voo;
  - `RecogResult.alternatives` (gêmeas) e `.verification`; `debug` hook;
    `lockedVerification`.
- `src/scanner/numberParse.ts` — denominador aceita 4 dígitos (o OCR cola um
  dígito espúrio: "154/7217"); quem consome decide se confia.
- `src/scanner/camera.ts` + `src/main.ts` — `NUMBER_BOXES`/`makeNumberVariants`
  e `readNumber` no browser com o MESMO protocolo do harness (caixa só com os
  dígitos, y 0.937–0.970 × x 0.14–0.38; pipes cinza+contraste; devolve textos
  crus; para na primeira caixa com fração). **Ainda não exercitado no browser.**
- `scripts/e2e-validate.ts` — leitor Node com as mesmas caixas; relógio
  sintético (`tick(f)`) e RNG re-semeado por (seção, carta) → B/C
  determinísticas e independentes de `N_SINGLE`; seção C dividida em **C1
  (arte ausente: exclui a carta E as gêmeas)** e **C2 (reprint ausente: só a
  impressão excluída)**; métricas novas: erro dos cantos vs. verdade (A),
  modo de verificação das confirmadas (B/C), estatísticas de OCR, `FALSO
  POSITIVO` com o modo. `DEBUG_C=1` dá trace frame a frame + cada decisão do
  gate. `renderFrame`/`GUIDE`/`SRC_*` exportados pra scripts de experimento.

### Calibrações medidas nesta sessão (pra não repetir)

- Caixa do OCR (frames sintéticos, 13 cartas × 6 frames, frações certas por
  tentativa): só os dígitos (0.14/0.937/0.24/0.033) **45%**; linha inteira com
  selos G/PAF PT 14%; caixa larga antiga 2%. Pipes: `normalize` ≈
  `normalize+sharpen` > `gamma`; `threshold(150).negate()` = 0. PSM
  SINGLE_LINE >> SINGLE_WORD. Frações ERRADAS ~14% das tentativas, quase
  sempre numerador com dígito perdido/8↔0 ou denominador com dígito colado —
  daí o casamento por string e o checksum do denominador.
- `REL_PEAK` da detecção: ver tabela no comentário de `DETECT_TUNING`.

## Contexto do produto (por que isso existe)

Ver [`README.md`](README.md) pro contexto original. Resumo: o Joel quer
catalogar 1000+ cartas físicas de Pokémon TCG (majoritariamente em
português) tirando foto com o celular, sem digitar cada uma na mão. A
abordagem inicial (ler o número de coletor por OCR) tem teto duro: cartas
holo/full-art modernas têm o número impresso sobre fundo brilhante e o OCR
não lê — ver [`pokecardex-ocr-ceiling`](/Users/felipelima/.claude/projects/-Users-felipelima-work-tcg/memory/pokecardex-ocr-ceiling.md)
na memória. A saída é **casar pela ARTE da carta** (idioma- e
holo-agnóstico) em vez de ler texto — esse documento é sobre essa segunda
abordagem, que agora é o motor principal, não mais um experimento.

### Descobertas que mudaram o rumo (nesta ordem cronológica)

1. **pHash sozinho é viável mesmo sem escolher o set** — testado com 1680
   cartas reais de 12 sets: 87,5% de acerto em 1º lugar globalmente (vs
   91,7% escolhendo o set — só 4 pontos de diferença). Ver memória
   [`phash-global-viability`](/Users/felipelima/.claude/projects/-Users-felipelima-work-tcg/memory/phash-global-viability.md).
2. **O gargalo real de cobertura é o CATÁLOGO, não o algoritmo.** Testamos
   3 fotos reais do Joel: duas (Greninja ex e Pikachu, set de 30º
   aniversário ©2026) **não existem em nenhuma base gratuita** (nem
   pokemontcg.io nem TCGdex) — não tem contra o que casar, ponto. A
   terceira (Eevee ex, Prismatic Evolutions) está no catálogo e o
   art-matching a reconheceu em 1º lugar mesmo sendo full-art holo. Ver
   memória [`catalog-coverage-bottleneck`](/Users/felipelima/.claude/projects/-Users-felipelima-work-tcg/memory/catalog-coverage-bottleneck.md).
3. **Trocamos a fonte do catálogo de pokemontcg.io pra TCGdex**
   (`api.tcgdex.net`) — tem nomes em português nativo, 123 sets (inclui os
   de 2026), e imagens por carta. `src/vision/tcgdex.ts`.
4. A partir daqui o usuário pediu pra construir **o motor de produção
   completo** ("estado da arte", "não deixar brechas") — o resto deste
   documento é sobre essa implementação.

## Arquitetura do motor (o que foi construído)

Tudo em `src/vision/` é **puro e isomórfico** — o mesmo código roda no
Node (pra gerar o índice do catálogo) e no browser (pra ler a câmera). Essa
é a decisão de design mais importante: qualquer divergência de pipeline
entre os dois lados vira distância espúria no hash.

```
src/vision/
  image.ts        primitivas: cinza, blur, Sobel, homografia, warp perspectivo
  descriptor.ts    Descriptor de uma carta retificada: 3 hashes + histograma de cor
  detect.ts        acha o quadrilátero da carta no frame + retifica (warpQuad)
  catalog.ts       CardIndex: busca top-k por distância combinada, ~ms em 4k+ cartas
  recognizer.ts    Recognizer: motor TEMPORAL (vota entre frames, gate de número)
  tcgdex.ts        cliente da API TCGdex (fonte do catálogo)

src/scanner/phash.ts   o pHash em si (DCT 64 bits) — usado por descriptor.ts

scripts/
  build-index.ts    baixa imagens da TCGdex + calcula descritores -> public/index/*.json
  e2e-validate.ts   valida o motor INTEIRO com frames sintéticos de câmera (ver abaixo)
  phash-validate.ts, phash-one.ts   scripts de validação mais antigos (pHash isolado, sem
                     o motor completo — mantidos por referência histórica, não essenciais)

src/main.ts + index.html   a UI web (câmera ao vivo, fila do lote, busca manual)
```

### Fluxo de reconhecimento (`Recognizer.feed()`, chamado a cada frame)

1. `detectCard(frame, guide)` — acha os 4 cantos reais da carta perto do
   quadro-guia (varre gradiente perpendicular a cada lado, ajusta reta
   robusta, interseta) e retifica pra um retângulo canônico 256×358
   (`CARD_W × CARD_H` em `descriptor.ts`) via homografia.
2. `describe(rectified)` — calcula 4 sinais: `artP` (pHash da região da
   arte), `fullP` (pHash da carta inteira, cobre layout/full-art), `artD`
   (dHash da arte, falha diferente do DCT), `color` (histograma de matiz
   de 12 bins). Cada um cobre o ponto cego do outro.
3. `index.search(desc)` — top-k por distância combinada (Hamming + L1
   ponderados), varrendo o catálogo inteiro (~4k cartas hoje, ~ms).
4. **Votação temporal**: cada frame deposita voto ponderado por proximidade
   nos hits; os votos decaem exponencialmente (`DECAY=0.78`) a cada frame.
   A carta líder muda conforme os votos evoluem.
5. **Gate de número** (o motor NÃO confia só na arte pra confirmar): antes
   de travar numa candidata, dispara UMA leitura de OCR do número de
   coletor (Tesseract, num warp em alta resolução dedicado — 2× o
   canônico, pois dígitos de ~10px no retificado do hash são ilegíveis).
   Política:
   - número bate → confirma.
   - leitura bem-formada "N/M" com N diferente → **rejeita essa candidata
     pro resto da sessão de scan** (ela nunca mais pode ser líder) e
     reforça qualquer candidato do pool cujo número bata com a leitura.
   - ilegível ou token solto sem barra (ruído típico de holo/OCR) → tenta
     de novo; depois de `OCR_MAX_ATTEMPTS` (2) tentativas inconclusivas,
     **aceita o visual mesmo assim** — esse é exatamente o caso que o
     art-matching existe pra cobrir (número impresso sobre holo).
6. Confirma quando: streak de frames liderando ≥ `CONFIRM_STREAK`, score
   de votos ≥ `CONFIRM_MIN_SCORE`, razão sobre o 2º colocado ≥
   `CONFIRM_RATIO` (não é empate), e a MENOR distância que o líder já
   atingiu na sequência atual (`leaderMinDist`, não a do frame atual) ≤
   `CONFIRM_MAX_DIST`.

### Por que o gate de número existe (achado importante)

Cartas com **arte idêntica reimpressa em sets diferentes** (reprints) são
estruturalmente indistinguíveis por hash visual — medido: `me02.5-082`
"Togekiss" (Heróis Excelsos) e `sv08-072` "Togekiss" (Fagulhas Impetuosas)
têm distância combinada de **3.9** (praticamente hash idêntico). Nenhum
ajuste de limiar de distância resolve isso — é o piso de ambiguidade do
método. A única coisa que distingue as duas é o número de coletor impresso
(`082` vs `072`), daí o gate: sem ele, o motor confirmava a carta errada com
confiança total (não havia nem empate de votos pra detectar — a impostora
vencia limpo). Ver histórico da investigação na conversa original (a
descoberta veio de rodar `scripts/e2e-validate.ts` seção C repetidamente até
achar o par exato via um script de debug ad-hoc, já removido).

## Scripts de validação — como rodar

```bash
npm run index:build -- --series sv,me    # gera public/index/tcgdex-pt.json
                                           # (já gerado: 4157 cartas, 26 sets, 1.1MB)
npm run e2e                               # valida o motor completo (ver abaixo)
```

`scripts/e2e-validate.ts` **renderiza frames sintéticos de câmera**
(perspectiva, rotação, glare/reflexo simulando holo, blur, recompressão
JPEG) a partir das imagens reais do catálogo, roda o pipeline de produção
de ponta a ponta, e mede 4 coisas:

- **A) Frame único**: acerto em 1º lugar, global e dentro do set, sem
  votação temporal — o teto "seco" do descritor visual.
- **B) Temporal, carta NO catálogo**: taxa de confirmação e quantos frames
  até confirmar, rodando o `Recognizer` completo (voto + gate de número).
- **C) Temporal, carta FORA do catálogo**: exclui a carta do índice
  (simula "Joel escaneou algo que a base não tem") e mede **falsa
  aceitação** — quantas vezes o motor confirma outra carta por engano. Este
  é o número mais crítico do projeto (precisão > recall é o valor central).
- **D) Sem carta no quadro**: frames só de mesa/fundo, mede confirmação
  indevida (deve ser sempre 0).

Variáveis de ambiente: `N_SINGLE` e `N_TEMPORAL` controlam o tamanho da
amostra (default 160/60, mais lento). Rodei a maior parte dos testes com
`N_SINGLE=120 N_TEMPORAL=40` pra ciclos de iteração mais rápidos.
`DEBUG_B=1` liga um trace frame-a-frame da seção B (útil pra depurar
confirmação lenta/travada).

O script usa **Tesseract.js real em Node** pra simular o OCR do gate
(`readNumberNode` em `e2e-validate.ts`, reaproveitando o padrão de
`scripts/ocr-validate.ts`) — não é um mock, é o pipeline de verdade rodando
num warp em alta resolução (`SRC_W/SRC_H = CARD_W*2, CARD_H*2`, baixado do
`high.webp` da TCGdex, ~600px) porque a imagem de baixa resolução usada
pro hash (`low.webp`, ~245px) tem dígitos ilegíveis mesmo pra OCR bom.

## Cronologia da calibração nesta sessão (números medidos, em ordem)

| Etapa | rank-1 global (A) | confirma (B) | falso-positivo (C) |
|---|---|---|---|
| 1º e2e (bug de borda não descoberto ainda) | 55.8% | 7.5% (3/40) | 0/40 |
| Após corrigir bug de clamp de borda (ver abaixo) | **88.3%** | 60% (24/40) | 2/40 |
| Após apertar limiares de confirmação (não ajudou) | 88.3% | 60% (24/40) | 2/40 (idêntico — não era calibração, era colisão real) |
| Após implementar gate de número (1ª versão, warp de baixa-res, gate só no momento exato de confirmar) | 88.3% | 10% (4/40) — **regressão grave** | **0/40** |
| Diagnóstico: worker OCR não pré-aquecido + só 80ms de espera | — | — | — |
| Após pré-aquecer worker + esperar direito (`settle()`) | 88.3% | 27.5% (11/40) | 0/40 |
| Diagnóstico: número impresso ilegível no warp de baixa-res (256×358) | — | — | — |
| Após warp dedicado em alta-res pro OCR (512×716) + disparar o gate cedo (streak≥2, não só no instante de confirmar) + `leaderMinDist` (aceita o melhor frame da sequência, não exige que o frame atual esteja perto) + `CONFIRM_MIN_SCORE` recalibrado (1.2→0.6, o valor antigo era alto demais pro teto real do decaimento) | 82-88%* | **82.5% (33/40), 0 erradas** | **3/40 (7.5%) — voltou a piorar** |

\* A oscilação entre 82.1% e 88.3% no teste A entre runs é porque mudei a
fonte da imagem "física simulada" de `low.webp` pra `high.webp` no meio do
caminho (pra dar resolução suficiente ao OCR) — isso muda ligeiramente a
amostra determinística do script (`pick()` usa `index.cards` na mesma
ordem, mas o carregamento de imagem mudou de tamanho/fonte). Não é uma
regressão real do descritor, é uma variação de setup. Vale re-medir limpo
quando isto for retomado.

## Onde parei exatamente (o bug ativo) — RESOLVIDO

Seção histórica: o texto original descrevia a hipótese de corrida/timing e o
comando de debug. A investigação está na seção "Resolução" no topo. O comando
de debug continua útil e ficou mais rico:

```bash
N_SINGLE=120 N_TEMPORAL=40 DEBUG_C=1 npm run e2e 2>&1 | grep -vE "^(Warning|Bottom=|Total count|Min=|Lower|Median=|Upper|Max=|Range=|Mean=|SD=|\s*$)"
```

## Riscos / cuidados antes de mexer

- **Nada está commitado.** `git status` mostra `index.html`, `package.json`,
  `src/main.ts`, `src/scanner/camera.ts`, `src/scanner/numberParse.ts`,
  `vite.config.ts` modificados, e `HANDOFF.md`, `public/`,
  `scripts/build-index.ts`, `scripts/e2e-validate.ts`, `scripts/phash-one.ts`,
  `scripts/phash-validate.ts`, `src/scanner/phash.ts`, `src/vision/` novos.
  `tsc --noEmit` passa.
  Recomendo revisar e commitar em pedaços coerentes (ex.: "motor de visão"
  + "scripts de validação" + "UI") em vez de um commit gigante, mas isso é
  só sugestão de estilo — não há nada perigoso no diff.
- **`public/index/tcgdex-pt.json`** (~1.1MB) foi gerado por
  `npm run index:build -- --series sv,me` e cacheia as imagens baixadas em
  `/private/tmp/claude-501/.../scratchpad/tcgdex-cache/` — esse cache é do
  **scratchpad da sessão** (efêmero, fora do repo) e vai sumir; ao rodar
  `npm run index:build` ou `npm run e2e` de novo numa sessão nova, as
  imagens serão baixadas de novo (mais lento na primeira vez, ~5min pra
  SV+ME completos).
- **Achei (mas não investiguei nem corrigi) dois arquivos `.js` órfãos já
  commitados no repo antes desta sessão**: `scripts/ocr-validate.js` e
  `scripts/validate.js` (irmãos compilados dos `.ts` de mesmo nome,
  aparentemente artefatos de build antigos que foram commitados por
  engano em algum momento anterior). Não mexi neles. Vale limpar depois.
- **`src/main.ts` e `index.html` foram REESCRITOS do zero** (não são um
  patch incremental) pra usar o novo motor (`Recognizer`/`CardIndex`) em
  vez do antigo fluxo `SetIndex`/OCR-só. O antigo pré-filtro de set virou
  um **filtro opcional por série** (dropdown "Filtro (opcional)" na UI) —
  não é mais obrigatório escolher set antes de escanear. **Isto ainda não
  foi testado no navegador de verdade** (nem via `preview_start`, nem no
  celular) — só testado o motor via `scripts/e2e-validate.ts` em Node.
  Antes de considerar a UI pronta, rodar `npm run dev` e testar a câmera
  ao vivo é o próximo passo óbvio depois de fechar o bug acima.
- O módulo `src/matching/` (o motor antigo, número+set via pokemontcg.io)
  **continua no repo intacto** e não foi removido — só não é mais chamado
  pelo `main.ts` novo. Os scripts antigos (`scripts/validate.ts`,
  `scripts/ocr-validate.ts`) ainda funcionam standalone se precisar
  comparar com o motor antigo.

## Próximos passos, em ordem de prioridade

1. **Testar no celular de verdade.** Tudo acima é câmera SINTÉTICA — teto
   otimista. `npm run dev`, apontar pra 10 cartas do Joel (holo, ângulo,
   reflexo reais) e olhar três coisas: a borda detectada (overlay), se o OCR
   lê o rodapé (`readNumber` no browser nunca foi exercitado), e quantas
   confirmam por `number` vs `inconclusive`. Isso decide o produto; mais
   calibração sintética não decide.
2. **Reprints (C2).** O que sobra depende de o OCR ler dígitos de ~12px; em
   frame 720p sintético lê ~45% por tentativa. Se no celular real a leitura
   for pior, a alternativa sem OCR é **casar o rodapé por template**: comparar
   a faixa do número da carta retificada com a mesma faixa das imagens
   `high.webp` da candidata e das gêmeas (NCC/hash) — os dígitos, o código do
   set e o ano diferem entre reprints. Não implementado.
3. **UI das gêmeas.** `RecogResult.alternatives` e `.verification` já saem do
   motor; a UI ainda não mostra "impressão não verificada, pode ser A ou B"
   nem oferece o toque pra escolher. É o que transforma um `candidate` travado
   em reprint numa captura útil.
4. Ampliar o índice além de SV+ME (`npm run index:build -- --series ...`).
5. Produto (fila, rajada, Lovable/Supabase) — ver README.

## Referência rápida de arquivos-chave

- [`src/vision/recognizer.ts`](src/vision/recognizer.ts) — o motor
  temporal + gate de número. **É aqui que o bug ativo mora.**
- [`scripts/e2e-validate.ts`](scripts/e2e-validate.ts) — o harness de
  validação com câmera sintética. **É aqui que o debug já preparado mora**
  (bloco `FALSO POSITIVO` na seção C).
- [`src/vision/descriptor.ts`](src/vision/descriptor.ts) — os 4 sinais do
  descritor visual e os pesos da distância combinada (`W_FULL`, `W_ARTD`,
  `W_COLOR`).
- [`src/vision/detect.ts`](src/vision/detect.ts) — detecção de borda +
  retificação. Já teve um bug sério aqui (clamp de borda ausente em
  `boxBlur3`/`sobel` no `image.ts`, corrigido).
- [`src/vision/catalog.ts`](src/vision/catalog.ts) — formato do índice
  serializado e busca top-k.
- Memórias relevantes (fora do repo,
  `/Users/felipelima/.claude/projects/-Users-felipelima-work-tcg/memory/`):
  `pokecardex-matching-anchor.md`, `pokecardex-ocr-ceiling.md`,
  `phash-global-viability.md`, `catalog-coverage-bottleneck.md`.
