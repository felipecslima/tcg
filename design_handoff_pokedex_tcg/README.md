# Handoff: Pokédex TCG — app mobile de coleção de cartas

## Overview
App iOS para uma colecionadora pré-adolescente registrar cartas de TCG. O fluxo central é **escanear uma carta com a câmera → escolher entre candidatos reconhecidos → confirmar e guardar numa coleção**. Em volta disso existem: progresso por região ("Jornadas"), grade de cartas de cada região com silhuetas para as que faltam, lista da coleção com valor de mercado, detalhe da carta, busca e perfil.

Identidade visual original em tons de lilás/violeta (inspiração: evolução psíquica do Eevee), com dourado usado só para raridade e valor.

## About the Design Files
Os arquivos deste pacote são **referências de design feitas em HTML** — protótipos que mostram aparência e comportamento pretendidos, **não código de produção para copiar**. A tarefa é **recriar estas telas no ambiente já existente do codebase** (React Native, SwiftUI, Flutter, etc.), usando seus padrões, componentes e bibliotecas. Se ainda não existe codebase, escolha o framework mais adequado (para iOS: SwiftUI ou React Native) e implemente lá.

`Pokedex TCG.dc.html` é um único arquivo que abre direto no navegador. A moldura de iPhone e a máquina de estados de navegação são apenas andaimes do protótipo — descarte-os e use a navegação nativa da plataforma.

## Fidelity
**Alta fidelidade (hifi).** Cores, tipografia, espaçamentos, raios e estados finais estão definidos abaixo e devem ser reproduzidos fielmente. Duas ressalvas:

- **Nomes de cartas, coleções e artes são placeholders.** Nada de marcas ou artes oficiais. As artes são gradientes lineares que representam onde entra a imagem real da carta. Substituir por dados reais da API de cartas.
- **Ícones são glifos de texto** (`▤ ◈ ⦿ ⌕ ☺ ★ ✦`). Substituir por um icon set real (SF Symbols na Apple, ou o set do codebase).

## Design Tokens

### Cores
| Token | Hex | Uso |
|---|---|---|
| `bg/root` | `#0d0a14` | Fundo fora do device / raiz |
| `bg/screen` | `#120e1e` | Fundo padrão das telas |
| `bg/scan-top` | `#191228` | Topo do gradiente da tela de scan |
| `bg/sheet` | `#171128` | Bottom sheet de candidatos |
| `bg/tabbar` | `rgba(28,20,45,.86)` + blur 22px | Tab bar flutuante |
| `surface/1` | `rgba(255,255,255,.03)` | Cards, linhas de lista |
| `surface/2` | `rgba(255,255,255,.025)` | Linhas de lista da coleção |
| `surface/accent` | `rgba(192,143,232,.07)` | Blocos com destaque lilás |
| `surface/accent-strong` | `rgba(192,143,232,.18)` | Chip selecionado |
| `primary` | `#C08FE8` | Cor primária (lilás Espeon) |
| `primary/hover` | `#D3A7F0` | Hover de botões primários |
| `primary/deep` | `#7A4BC4` | Ponta escura dos gradientes |
| `on-primary` | `#1a1029` | Texto sobre botão primário |
| `text/1` | `#ffffff` | Títulos |
| `text/2` | `#cdc4dd` | Corpo claro |
| `text/3` | `#a89cbd` | Corpo secundário |
| `text/4` | `#8d81a8` | Legendas |
| `text/5` | `#6f6489` | Rótulos, ícones inativos |
| `text/6` | `#5c5375` / `#4a4260` | Estados vazios / desabilitados |
| `accent/gold` | `#F0C36B` | Raridade, HP, progresso parcial |
| `accent/green` | `#8CD9A8` | Valorização, alto match, progresso >50% |
| `accent/red` | `#E08A8A` | Desvalorização |
| `border/1` | `rgba(192,143,232,.1)` – `.16` | Bordas padrão |
| `border/2` | `rgba(192,143,232,.25)` – `.3` | Bordas de botões secundários |
| `border/focus` | `#C08FE8` | Selecionado / foco |

### Tipografia
- **Display / títulos:** `Sora` — 700 para títulos e 600 para subtítulos, `letter-spacing: -0.02em` nos títulos grandes.
- **Corpo / UI:** `DM Sans` — 400, 500, 700.
- **Números, rótulos e códigos:** `DM Mono` — 400/500, `letter-spacing: .1em–.16em` e `uppercase` nos rótulos de seção.

Escala usada:
| Papel | Fonte / tamanho / peso |
|---|---|
| Título de tela | Sora 30px/1.1 700 |
| Título de tela (scan) | Sora 24px/1.1 700 |
| Título de card / carta | Sora 25–27px/1.1 700 |
| Título de item de lista | Sora 15–19px/1.2 600 |
| Valor destaque (coleção) | Sora 36px/1.05 700 |
| Valor destaque (detalhe) | Sora 30px/1.05 700 |
| Corpo | DM Sans 14–15px/1.5 400 |
| Legenda | DM Sans 12–13px/1.4 400 |
| Botão | DM Sans 14px 500–600 / Sora 16px 700 (primário) |
| Rótulo de seção | DM Mono 11px 600, uppercase, ls .14em |
| Número / preço | DM Mono 14–20px 500–700 |

### Espaçamento
Padding horizontal de tela: **22px** (scan usa 24px). Padding superior: **66px** (abaixo da status bar). Padding inferior das telas com tab bar: **120px**. Gaps de lista: **9–12px**. Gap de grade: **11px**.

### Raio de borda
`6px` mini-arte · `10–11px` arte de carta na grade · `13–14px` chips e botões secundários · `16–17px` botões e linhas de lista · `18–22px` cards · `26px` tab bar · `28px 28px 0 0` bottom sheet · `48px` device · `99px` pílulas e círculos.

### Sombras
- Botão primário: `0 10px 30px rgba(192,143,232,.28)`
- Toast: `0 14px 34px rgba(192,143,232,.35)`
- Carta em destaque (confirmar): `0 14px 34px rgba(0,0,0,.5)`
- Carta grande (detalhe): `0 22px 50px rgba(0,0,0,.6)`
- Bottom sheet: `0 -20px 60px rgba(0,0,0,.6)`
- Nó de trilha ativo (>50%): `0 0 26px rgba(192,143,232,.4)`
- Botão de captura: `0 0 40px rgba(192,143,232,.5)`

### Padrões reutilizados
- **Placeholder de arte:** `linear-gradient(150deg, <corA>, <corB>)`. Variantes usadas: `#7A4BC4→#C08FE8 55%→#F0C36B`, `#2f5fa8→#6fb6d9`, `#a8452f→#e0955c`, `#2f7a58→#8fd9a8`, `#4a3a70→#9b8fc7`, `#8a2f6a→#e08cc0`. **Trocar por `<Image>` da carta real.**
- **Placeholder "vazio"/câmera:** `repeating-linear-gradient(115deg, rgba(192,143,232,.09) 0 9px, rgba(192,143,232,.03) 9px 18px)`.
- **Barra de progresso:** trilho `rgba(255,255,255,.07)`, altura 6–8px, raio 99px; preenchimento `linear-gradient(90deg,#7A4BC4,#C08FE8)`.
- **Proporção de carta:** `aspect-ratio: .72` (≈ 63×88mm).

---

## Screens / Views

### 1. Escanear (`scan`) — tela inicial
**Propósito:** capturar a carta física pela câmera.

Coluna flex ocupando a tela, fundo `linear-gradient(180deg,#191228,#120e1e→#0d0a14)`.

- **Header** (padding `66px 24px 0`, linha flex space-between): título "Escanear" (Sora 24 700) + subtítulo "Enquadre a carta inteira" (DM Sans 13, `text/4`). À direita, botão-círculo 38px, borda `rgba(192,143,232,.3)`, glifo de flash em `primary`.
- **Viewfinder** (centralizado, `flex:1`): retângulo 250×350, raio 18px, com o padrão listrado de placeholder e o texto mono 11px "visão da câmera / carta física". Por cima, sobreposto e centralizado, um quadro de 274×374 com **4 cantos em L**: 40×40px, borda 3px `primary`, raio 14px no canto externo de cada um. `pointer-events:none`.
- **Linha de varredura** (só enquanto `scanning`): faixa de 80px de altura, `linear-gradient(180deg, rgba(192,143,232,0), rgba(192,143,232,.45))`, animação `scanline` 1.1s ease-in-out infinita — `translateY(0→230px)`, opacidade 0→1 (12%) →1 (88%) →0.
- **Rodapé** (padding `0 24px 112px`, centralizado):
  - Dica de estado, DM Sans 14 500, `min-height:20px`: `"Toque para capturar"` (cor `text/4`) · `"Lendo a carta…"` durante o scan (cor `primary`) · `"Modo lote ativo — escaneie várias"` com lote ligado.
  - Linha de 3 controles com `gap:34px`: botão ⌕ (52px, círculo, vai para Busca) · **botão de captura** (84px, círculo, fundo `primary`, borda 4px `rgba(255,255,255,.9)`, glow) · botão "lote" (52px, círculo, DM Mono 12 600, alterna estado — borda e fundo passam a `primary`/`rgba(192,143,232,.2)` quando ligado).

**Comportamento:** tocar em capturar → `scanning = true` → 1300ms → navega para Candidatos. Toques repetidos durante o scan são ignorados. *Nota de implementação:* na versão real, o delay é o retorno do reconhecimento; manter o mínimo de ~600ms para a animação não piscar.

### 2. Candidatos (`candidates`) — bottom sheet
**Propósito:** o reconhecimento nunca é 100%; ela escolhe qual das cartas é a certa.

Fundo: a tela de câmera desfocada (`blur(1px)`). Sheet ancorado embaixo, `#171128`, raio superior 28px, padding `14px 22px 34px`, animação `floatUp` 0.28s ease-out (`translateY(14px)→0`, opacidade 0→1).

- Alça: 40×4px, raio 99px, `rgba(205,196,221,.25)`, centralizada, `margin-bottom:18px`.
- Título "É alguma dessas?" (Sora 20 700) + "Toque na carta certa para confirmar" (DM Sans 13, `text/4`).
- **Lista de 2–3 candidatos**, gap 10px. Cada linha: padding 12px, raio 16px, flex com gap 14px — mini-arte 52×72 (raio 7px, rótulo "arte" mono 7px) · nome (Sora 16 600) e `coleção · número` (DM Sans 12, `text/4`) · à direita a porcentagem de match (DM Mono 15 600) com o rótulo "match" abaixo.
  - **Match > 85%:** texto verde `#8CD9A8`, borda `rgba(192,143,232,.45)`, fundo `rgba(192,143,232,.1)`.
  - **60–85%:** texto dourado `#F0C36B`, borda/fundo padrão.
  - **< 60%:** texto `text/4`.
  - Hover: `border-color: primary`.
- Botão de texto "Nenhuma — escanear de novo" (largura total, `text/4` → `text/2` no hover) volta para o scan.

**Sem tab bar** nesta tela (fluxo modal).

### 3. Confirmar carta (`confirm`)
**Propósito:** revisar a carta reconhecida e registrar onde guardar, acabamento e quantidade.

Rolável, fundo `#120e1e`, padding `66px 22px 40px`. **Sem tab bar.**

- Botão "‹ Voltar" (DM Sans 14 500, `text/4`).
- **Cabeçalho da carta** (flex, gap 18px): arte 126×176 (raio 11px, sombra) · à direita nome (Sora 25 700), `coleção · número` (DM Sans 13, `text/4`), pílula de raridade (padding `5px 11px`, raio 99, fundo `rgba(240,195,107,.14)`, texto `#F0C36B` DM Mono 11 600 ls .08em), preço (DM Mono 20 700, branco) e legenda "valor médio de mercado".
- **"Guardar em"** — lista de rádio de coleção, gap 8px. Cada linha: padding `13px 14px`, raio 14px, flex com gap 12px — indicador circular 18px (borda 2px; quando selecionado, preenchido em `primary` com ✓ em `on-primary`) · rótulo · contagem à direita (DM Mono 12, `text/5`). Opções: **Minhas cartas (142)**, **Deck Eevee (38)**, **Para trocar (11)**. Estado selecionado: borda `primary`, fundo `rgba(192,143,232,.18)`, texto branco.
- **"Acabamento"** — 3 chips iguais lado a lado (`flex:1`, padding `12px 4px`, raio 13px): **Normal · Reverse · Holo**. Mesmo par de estados dos chips acima.
- **Quantidade** — linha com fundo `rgba(192,143,232,.07)`, borda `rgba(192,143,232,.15)`, raio 16px, padding `14px 16px`: rótulo "Quantas cópias" + stepper (botões-círculo 34px com − e +, valor DM Mono 18 600 no centro). Limites 1–99.
- **Botão primário** "Salvar na coleção": largura total, padding 17px, raio 17px, fundo `primary`, texto Sora 16 700 `on-primary`, sombra.

**Comportamento:** salvar insere a carta no topo da coleção, navega para Coleção e dispara um toast `"<nome> → <coleção escolhida>"`.

### 4. Jornadas (`journeys`)
**Propósito:** progresso por região.

Padding `66px 22px 120px`. Título "Jornadas" + "{X} de {Y} cartas registradas".

**Alternador de visão** (segmented): container padding 4px, raio 14px, fundo `rgba(255,255,255,.04)`, borda `rgba(192,143,232,.12)`; dois botões `flex:1` padding 10px raio 11px. Ativo: fundo `rgba(192,143,232,.22)`, texto branco. Inativo: transparente, `text/4`. Opções **Trilha** (padrão) e **Lista**.

**Trilha** — coluna com uma linha vertical tracejada atrás dos nós: `position:absolute; left:36px; top:20px; bottom:30px; width:2px`, `repeating-linear-gradient(180deg, rgba(192,143,232,.35) 0 6px, transparent 6px 12px)`. Cada região é uma linha flex (gap 18px, gap vertical 22px): **nó circular 58px** com a porcentagem dentro (DM Mono 14 700) · nome (Sora 19 600) e nota ("88 de 151 · faltam 63" ou "ainda não começou") · chevron ›.
- Região iniciada: nó `linear-gradient(150deg,#7A4BC4,#C08FE8)`, borda `rgba(192,143,232,.6)`, número branco.
- Região não iniciada: nó `rgba(255,255,255,.03)`, borda `rgba(192,143,232,.22)`, número e título em `text/6`/`text/4`.
- Acima de 50%: adiciona o glow.

**Lista** — cards empilhados (gap 12px): padding 18px, raio 20px, borda `rgba(192,143,232,.14)`. Nome (Sora 19 600) + porcentagem à direita (verde >50%, dourado >0, `text/5` em 0); "{owned} / {total} cartas"; barra de progresso. Hover: borda `rgba(192,143,232,.45)`.

Regiões e progresso do mock: Kanto 88/151, Johto 41/100, Hoenn 22/135, Sinnoh 9/107, Unova 0/156.

### 5. Cartas da região (`region`)
Padding `66px 22px 120px`. "‹ Jornadas" · título com o nome da região · "{owned} de {total} · faltam {missing}".

**Grade de 3 colunas**, gap 11px. Cada slot: retângulo `aspect-ratio:.72`, raio 10px, com o nome abaixo (DM Sans 11 500, truncado com ellipsis).
- **Registrada:** gradiente da arte, rótulo "arte" em mono 8px no rodapé, nome em `text/2`, clicável → Detalhe.
- **Faltando (silhueta):** padrão listrado, borda `1px dashed rgba(192,143,232,.22)`, "?" em `#4a4260`, nome "não registrada" em `text/6`, não clicável.

### 6. Minhas cartas (`collection`)
Padding `66px 22px 120px`. Título "Minhas cartas".

- **Card de valor:** padding 20px, raio 22px, `linear-gradient(135deg,#3b2160,#241a3a)`, borda `rgba(192,143,232,.2)`. Rótulo "VALOR DA COLEÇÃO" (DM Mono 12, ls .12em, `#b49fd0`), valor Sora 36 700, e uma linha com "{n} cartas" e "+6.8% este mês" (verde).
- **Filtros:** faixa horizontal rolável de chips-pílula (padding `9px 15px`, raio 99px): **Todas · Holo · Ultra raras · Repetidas**. Mesmos estados de chip selecionado/normal.
- **Lista:** linhas com padding 11px, raio 16px, fundo `rgba(255,255,255,.025)`, borda `rgba(192,143,232,.1)`, hover `rgba(192,143,232,.09)`. Conteúdo: mini-arte 46×64 · nome (Sora 15 600, truncado) e meta `coleção · estado · Nx` · à direita preço (DM Mono 14 600) e variação percentual (verde/vermelho). Clique → Detalhe.

### 7. Detalhe da carta (`detail`)
**Sem tab bar** (empilhada sobre a origem; "‹ Voltar" retorna à tela anterior — Coleção, Região ou Busca).

- **Hero:** padding `66px 22px 30px`, fundo `linear-gradient(180deg, rgba(192,143,232,.22), #120e1e)`. Botão "‹ Voltar" em pílula `rgba(0,0,0,.3)`. Arte 190×265 centralizada, raio 14px, sombra forte.
- **Corpo** (padding `24px 22px 120px`): nome (Sora 27 700), `coleção · número · raridade` (raridade em dourado).
- **Bloco de valor de mercado:** raio 20px, `surface/1`, borda `rgba(192,143,232,.13)`, padding 18px. Rótulo "VALOR DE MERCADO" (mono 11, ls .12em), valor Sora 30 700, variação percentual alinhada à direita (verde/vermelho).
- **Bloco de ataques:** mesmo estilo de card. Header: "ATAQUES" à esquerda, "{HP} HP" em dourado DM Mono 15 600 à direita. Cada ataque (gap 12px): custo de energia como círculos de 15px (`#C08FE8` para psíquica, `#cfc7dd` para incolor) · nome (Sora 15 600) e texto do efeito (DM Sans 12/1.5, `text/4`) · dano à direita (DM Mono 18 700). Mock: "Brilho Lunar / 60" e "Onda Psíquica / 120"; HP 280 em ultra raras, 120 nas demais.
- **Grade de stats 2×2** (gap 10px, cards raio 16px): **Você tem** ({n} cópia(s)) · **Estado** · **Acabamento** · **Região**. Rótulo mono 10px uppercase, valor Sora 17 600.

### 8. Busca (`search`)
Padding `66px 22px 120px`. Título "Busca".

- **Campo:** flex, padding `14px 16px`, raio 16px, fundo `rgba(255,255,255,.04)`, borda `rgba(192,143,232,.14)` → `rgba(192,143,232,.5)` quando há texto. Ícone ⌕, input transparente (texto branco DM Sans 15, placeholder "Nome, coleção ou número"), botão ✕ que aparece só com texto.
- **Chips de atalho** (faixa rolável): "Aurora Prisma", "Ultra raras", "Falta na Kanto", "Holo" — preenchem a busca.
- **Rótulo de seção:** "SUGESTÕES PARA VOCÊ" sem query, "{n} RESULTADO(S)" com query.
- **Resultados:** linhas iguais às da coleção, mas com o indicador de posse à direita: "{n}x na coleção" (verde) ou "não tem" (`text/5`). Clique → Detalhe.
- **CTA tracejado** "+ Adicionar carta manualmente": largura total, padding 15px, raio 16px, borda `1px dashed rgba(192,143,232,.35)`, fundo `rgba(192,143,232,.06)`, texto `primary` 14 600 → abre a tela Confirmar sem passar pela câmera.

Busca filtra por nome, coleção e número (case-insensitive), limitada a 6 resultados no mock.

### 9. Perfil (`profile`)
- **Hero** (padding `66px 22px 30px`, `linear-gradient(180deg, rgba(192,143,232,.2), #120e1e)`): avatar circular 74px (placeholder listrado, borda 2px `rgba(192,143,232,.5)`) · nome "Treinadora" (Sora 25 700) e "Nível 12 · Colecionadora". Abaixo, linha "Nível 12" / "1.240 / 2.000 XP" (DM Mono 11) e barra de progresso 8px em 62%.
- **Grade de stats 2×2** (cards raio 18px): Cartas registradas · Valor total · Regiões iniciadas (4 de 5) · Sequência (9 dias).
- **Conquistas** — lista (gap 9px), cada uma: quadrado 38px raio 12px com o glifo · nome (Sora 15 600) e descrição (DM Sans 12, `text/4`).
  - Conquistada: fundo `rgba(192,143,232,.09)`, borda `rgba(192,143,232,.25)`, ícone com gradiente lilás e glifo branco, título branco.
  - Bloqueada: fundo `rgba(255,255,255,.02)`, borda `rgba(192,143,232,.08)`, ícone `rgba(255,255,255,.04)` com glifo `#5c5375`, título `text/4`.
  - Mock: "Primeira ultra rara" ✓, "Kanto pela metade" ✓, "100 escaneadas" ✓, "Coleção completa" ✗.

---

## Navegação

**Tab bar flutuante** — `position:absolute; left:14px; right:14px; bottom:22px; height:66px`, raio 26px, fundo `rgba(28,20,45,.86)` com `backdrop-filter: blur(22px)`, borda `rgba(192,143,232,.16)`, `z-index` acima do conteúdo. 5 itens `flex:1`, cada um com glifo 19px sobre rótulo DM Sans 10 500, gap 5px. Ativo em `primary`, inativo em `#6f6489`. Itens: **Coleção (▤) · Jornadas (◈) · Escanear (⦿) · Busca (⌕) · Perfil (☺)**. A aba Jornadas continua ativa quando a tela é "Região".

**Visível em:** scan, journeys, region, collection, search, profile.
**Oculta em:** candidates, confirm, detail (fluxos modais/empilhados).

**Importante:** todo conteúdo rolável dessas telas precisa de `padding-bottom` de ~120px para não ficar sob a barra.

### Grafo de navegação
```
scan ──capturar──▶ candidates ──escolher──▶ confirm ──salvar──▶ collection (+ toast)
scan ──⌕──▶ search ──"adicionar manualmente"──▶ confirm
candidates ──"nenhuma"──▶ scan
journeys ──região──▶ region ──carta registrada──▶ detail
collection ──linha──▶ detail
search ──resultado──▶ detail
detail ──"‹ Voltar"──▶ tela anterior (prev)
```

## Interactions & Behavior
- **Scan:** captura → estado `scanning` com a linha de varredura animada → 1300ms → candidatos. Reentrada bloqueada durante o scan.
- **Modo lote:** hoje é só um toggle visual que troca a dica. Na implementação real, deve enfileirar várias capturas e abrir uma tela de revisão em lote no fim (não desenhada).
- **Toast:** pílula largura total (menos 22px de cada lado) a 104px do fundo, fundo `primary`, texto `on-primary` 14 600, raio 16px, entra com `floatUp` 0.25s, some após **2200ms**. Usado ao salvar.
- **Hover** (relevante em web/iPad): botões primários clareiam para `#D3A7F0`; linhas de lista escurecem para `rgba(192,143,232,.09)`; chips ganham borda `primary`.
- **Voltar do detalhe:** guarda a tela de origem em `prev` e volta para ela — não usa uma pilha real. Numa implementação nativa, usar a navegação/stack da plataforma.
- **Estados não desenhados** (definir antes de implementar): sem permissão de câmera, nenhuma carta reconhecida, offline / falha de rede, coleção vazia, busca sem resultado, erro de preço indisponível.

## State Management
Estado do protótipo (todo em memória, sem persistência):

| Variável | Tipo | Papel |
|---|---|---|
| `screen` | enum | Tela atual (`scan`, `candidates`, `confirm`, `journeys`, `region`, `collection`, `detail`, `search`, `profile`) |
| `prev` | enum | Tela de origem, usada pelo "Voltar" do detalhe |
| `scanning` | bool | Anima a varredura e bloqueia recaptura |
| `batch` | bool | Modo lote |
| `picked` | objeto carta | Candidato escolhido, alimenta Confirmar |
| `dest` | string | Coleção de destino ao salvar |
| `finish` | enum | Normal / Reverse / Holo |
| `qty` | int 1–99 | Cópias |
| `region` | objeto região | Região aberta |
| `detail` | objeto carta | Carta aberta no detalhe |
| `filter` | string | Filtro da coleção |
| `journeyView` | enum | Trilha / Lista |
| `query` | string | Texto da busca |
| `owned` | array de cartas | Coleção da usuária |
| `toast` | string | Mensagem transitória |

**Dados que a implementação real precisa buscar:**
- Reconhecimento de imagem → lista de candidatos com score de confiança.
- Catálogo de cartas por região/coleção (para a grade com silhuetas e o total de cada região).
- Preço de mercado atual + variação (a API de preços costuma ser separada do catálogo).
- Ataques, HP e custo de energia por carta.
- Coleção da usuária (persistida; offline-first é desejável, ela vai usar isso em loja e em encontros).

Modelo de carta usado no mock: `{ id, name, set, num, rarity, price, delta, art, cond, finish, qty, region }`.

## Assets
Nenhum asset binário. Tudo é CSS.
- **Artes de carta:** gradientes lineares placeholder → substituir pelas imagens reais da API.
- **Foto de perfil e visão da câmera:** placeholders listrados → substituir por imagem real e pelo preview da câmera.
- **Ícones:** glifos Unicode → substituir por icon set real.
- **Fontes:** Sora, DM Sans e DM Mono (Google Fonts, licença SIL OFL). Empacotar no app em vez de carregar por CDN.

## Legal
O design é original de propósito. Nomes de cartas, coleções e artes são inventados; não use logos, artes ou marcas oficiais do TCG sem licença. Nomes de região aparecem como texto de dados fornecido pela usuária.

## Files
- `Pokedex TCG.dc.html` — protótipo completo, todas as 9 telas com navegação funcionando. Abre direto no navegador.
- `ios-frame.jsx` — moldura de iPhone usada durante o desenho. **Não é usada pelo protótipo final** e não precisa ser portada; incluída só para referência.
