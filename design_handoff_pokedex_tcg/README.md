# Pokédex TCG — protótipo e especificação

Pacote completo para implementar o app. Três partes:

1. `prototype/` — o protótipo interativo, abre no navegador, todas as 10 telas navegáveis.
2. `design_system/` — tokens CSS, componentes React, cards de especificação e o guia visual//de conteúdo.
3. Este arquivo — o que o app faz, tela a tela, e como se comporta.

**Os arquivos HTML são referência de design, não código de produção.** A tarefa é recriar estas telas no ambiente do app (SwiftUI, React Native, Flutter) usando os padrões daquele codebase. Se ainda não existe codebase, escolher o framework e implementar lá.

**Fidelidade: alta.** Cores, tipografia, espaçamentos e estados são finais e estão tokenizados em `design_system/tokens/`. Duas ressalvas: nomes de cartas/coleções e artes são **placeholders** (nenhuma marca ou arte oficial de TCG), e os ícones são **glifos Unicode** a serem trocados por SF Symbols ou Lucide.

---

## O que é o app

Uma pokédex de TCG pessoal. A dona do app fotografa as cartas que tem, o app reconhece, ela confirma e guarda numa coleção. Com o tempo isso vira um inventário com valor de mercado e um mapa de progresso por região.

**Contexto:** é um presente. A dona tem 11 anos; o app será usado por ela, pelo pai e por umas quatro amigas — seis pessoas, não vai para a loja. Não precisa de contas, telemetria, escala ou monetização. Tom lúdico mas organizado.

**Dinheiro fica fora do centro, de propósito.** O valor total da coleção existe porque chama atenção e faz a coleção parecer importante, mas nunca é a informação principal, e não há acompanhamento de mercado: sem gráfico de preço, sem variação percentual em verde e vermelho, sem preço na navegação. A carta é carta; o valor é curiosidade.

**A decisão de produto central:** o reconhecimento por imagem nunca é perfeito, então o app nunca finge certeza. Ela escolhe a coleção antes de escanear (reduz o universo de busca), o app propõe 2–3 candidatos com percentual de confiança, e ela decide. Todo passo obrigatório tem uma saída ("não sei a coleção", "nenhuma dessas", "adicionar manualmente").

---

## Fundações visuais

Estão em `design_system/readme.md` (cor, tipo, espaçamento, sombras, bordas, animação, layout, iconografia, tom de voz) e em `design_system/tokens/*.css`. **Leia esse arquivo antes de implementar qualquer tela.** Resumo de uma linha: modo claro, fundo lilás claríssimo, superfícies brancas, um roxo de marca usado com parcimônia, Sora + DM Sans + DM Mono com papéis rígidos.

---

## Telas

### 1. Escolher coleção (`setpick`) — entrada do fluxo de scan
Primeira coisa antes da câmera. Reduz o universo de reconhecimento e é o que faz os candidatos serem confiáveis.

- Rótulo "ANTES DE ESCANEAR", título "De qual coleção são as cartas?", subtítulo explicando o porquê.
- **Continuar de onde parou** — card hero roxo com a última coleção usada: arte, nome, "região · X de Y · Z% completa" e barra de progresso branca. Um toque leva direto à câmera.
- Campo **Buscar coleção** + faixa de chips por região (Todas, Kanto, Johto, Hoenn, Sinnoh).
- **Lista de coleções**: arte 44px, nome, "região · ano · N cartas", barra de progresso e a porcentagem à direita (verde >50%, dourado >0, cinza em 0).
- Rodapé: botão tracejado **"Não sei a coleção — escanear mesmo assim"** → vai para o scan com o universo aberto.

### 2. Escanear (`scan`)
- Título "Escanear" + botão de flash à direita.
- **Pílula da coleção ativa** logo abaixo: mini-arte, nome e um badge **trocar** que volta ao passo 1.
- "Enquadre a carta inteira dentro das marcas".
- **Viewfinder** 250×350 (placeholder listrado no protótipo; feed real na implementação), com 4 cantos em L de 40px, borda 3px roxa, sobre um quadro de 274×374.
- **Linha de varredura** durante a leitura: faixa de 80px com gradiente roxo, `scanline` 1,1s infinita.
- Dica de estado: "Toque para capturar" / "Lendo a carta…" (roxo) / "Modo lote ativo — escaneie várias".
- Controles, gap 34px: **⌕** (52px → Busca) · **captura** (84px, roxo cheio, borda branca 4px, sombra colorida) · **lote** (52px, toggle).
- Captura → estado de leitura → candidatos. No protótipo são 1300ms fixos; na implementação é o retorno do reconhecimento, com mínimo de ~600ms para a animação não piscar.

### 3. Candidatos (`candidates`) — bottom sheet
Sheet branco sobre a câmera desfocada, raio 28px no topo, entra com `floatUp` 0,28s.

- "É alguma dessas?" + "**Buscando em {coleção}** · toque na carta certa".
- 2–3 linhas: mini-arte 52×72, nome, "coleção · número", e o **match %** à direita (verde >85%, dourado 60–85%, cinza abaixo). O candidato mais provável tem borda e fundo destacados.
- **Os candidatos vêm da coleção escolhida.** Se ela pulou a escolha, o app busca em todas e o cabeçalho diz isso.
- Saída: "Nenhuma — escanear de novo".

### 4. Confirmar carta (`confirm`)
Sem tab bar. "‹ Voltar" no topo.

- Cabeçalho: arte 126×176 com sombra · nome (Sora 25/700) · "coleção · número" · pílula de raridade dourada · uma linha discreta em mono 12px "valor estimado R$ …".
- **Guardar em** — rádios em lista: Minhas cartas (142) · Deck Eevee (38) · Para trocar (11).
- **Acabamento** — 3 chips: Normal · Reverse · Holo.
- **Quantas cópias** — stepper − / + em bloco tingido, limites 1–99.
- CTA roxo **Salvar na coleção** → insere no topo da coleção, navega para Minhas cartas e mostra toast `"{nome} → {coleção}"` por 2,2s.

Nota: o estado de conservação **não** é pedido no salvamento (decisão explícita — é fricção demais no momento do scan); aparece no detalhe e pode ser editado depois.

### 5. Jornadas (`journeys`)
Título + "{X} de {Y} cartas registradas" + alternador **Trilha / Lista**.

- **Trilha** (padrão): linha vertical tracejada com nós circulares de 58px por região, a porcentagem dentro. Região iniciada = nó roxo cheio; não iniciada = nó vazio com borda; acima de 50% ganha glow. Ao lado: nome e "88 de 151 · faltam 63" ou "ainda não começou".
- **Lista**: cards com nome, porcentagem colorida, contagem e barra de progresso.
- Mock: Kanto 88/151 · Johto 41/100 · Hoenn 22/135 · Sinnoh 9/107 · Unova 0/156.

### 6. Cartas da região (`region`)
"‹ Jornadas" · nome da região · "{owned} de {total} · faltam {missing}".
Grade de 3 colunas, gap 11px, proporção .72. Registrada = arte + nome, clicável. Faltando = listrado com borda tracejada, "?" e "não registrada", não clicável.

### 7. Minhas cartas (`collection`)
- **Card hero roxo** com "SUA COLEÇÃO" e **a contagem de cartas** em Sora 36/700, seguida de "{n} coleções · {n} regiões". Abaixo de um divisor branco a 28%, uma linha discreta em mono 12px: "valor estimado R$ …". Essa é a única aparição do valor total no app.
- Chips de filtro: Todas · Holo · Ultra raras · Repetidas.
- Lista de linhas: mini-arte 46×64, nome, "coleção · estado", e à direita **quantidade** ("3x") com a **raridade** em dourado abaixo. Sem preço. Clique → detalhe.

### 8. Detalhe da carta (`detail`)
Sem tab bar; "‹ Voltar" volta à tela de origem (coleção, região ou busca).

- Hero com véu roxo e a arte 190×265 centralizada com sombra forte.
- Nome · "coleção · número · raridade" (raridade em dourado).
- **Ataques**: header "ATAQUES" + "{HP} HP" em dourado. Cada ataque: custo de energia como círculos de 15px, nome, texto do efeito e dano à direita em mono 18/700.
- **Grade 2×2**: Você tem · Estado · Acabamento · **Valor estimado**. O valor é uma célula entre as outras, no mesmo peso.

Sem bloco de valor de mercado, sem gráfico de preço, sem variação percentual e sem nota pessoal — todos cortados de propósito.

### 9. Busca (`search`)
Campo com ⌕ e limpar, chips de atalho (Aurora Prisma, Ultra raras, Falta na Kanto, Holo), rótulo dinâmico ("Sugestões para você" / "{n} resultado(s)"), resultados com indicador de posse ("2x na coleção" em verde / "não tem"), e CTA tracejado **"+ Adicionar carta manualmente"** que abre a tela Confirmar sem passar pela câmera. Busca por nome, coleção e número.

### 10. Perfil (`profile`)
Hero com véu roxo: avatar 74px (placeholder), "Treinadora", "Nível 12 · Colecionadora", barra de XP com "1.240 / 2.000 XP". Grade 2×2 (cartas registradas, valor total, regiões iniciadas, sequência) e lista de conquistas — conquistadas com ícone roxo cheio, bloqueadas apagadas.

---

## Navegação

Tab bar flutuante: `left/right 14px, bottom 22px, height 66px`, raio 26px, branco a 88% com `backdrop-filter: blur(22px)`. 5 itens: **Coleção ▤ · Jornadas ◈ · Escanear ⦿ · Busca ⌕ · Perfil ☺**. Ativo em roxo. Jornadas continua ativa em "Região"; Escanear continua ativa em "Escolher coleção".

Visível em: setpick, scan, journeys, region, collection, search, profile.
Oculta em: candidates, confirm, detail.

Todo conteúdo rolável precisa de `padding-bottom: 120px`.

```
setpick ──coleção──▶ scan ──capturar──▶ candidates ──escolher──▶ confirm ──salvar──▶ collection (+toast)
setpick ──"não sei"──▶ scan (universo aberto)
scan ──"trocar"──▶ setpick
scan ──⌕──▶ search ──"adicionar manualmente"──▶ confirm
candidates ──"nenhuma"──▶ scan
journeys ──região──▶ region ──carta registrada──▶ detail
collection | search ──item──▶ detail ──"‹ Voltar"──▶ tela de origem
```

---

## Estado

| Variável | Tipo | Papel |
|---|---|---|
| `screen` | enum | Tela atual (10 valores, ver acima) |
| `prev` | enum | Origem, usada pelo "Voltar" do detalhe |
| `activeSet` | objeto coleção | Coleção escolhida; filtra os candidatos |
| `setQuery` / `setRegion` | string | Busca e filtro na tela de escolher coleção |
| `scanning` | bool | Anima a varredura e bloqueia recaptura |
| `batch` | bool | Modo lote |
| `picked` | objeto carta | Candidato escolhido |
| `dest` | string | Coleção de destino ao salvar |
| `finish` | enum | Normal / Reverse / Holo |
| `qty` | int 1–99 | Cópias |
| `region` / `detail` | objeto | Região aberta / carta aberta |
| `filter` | string | Filtro da coleção |
| `journeyView` | enum | Trilha / Lista |
| `query` | string | Busca de cartas |
| `owned` | array | Coleção da usuária |
| `toast` | string | Mensagem transitória (2,2s) |

Modelo de carta: `{ id, name, set, num, rarity, price, delta, art, cond, finish, qty, region }`.
Modelo de coleção: `{ name, region, year, total, owned, art }`.

---

## O que precisa vir de backend

- **Reconhecimento de imagem** → lista de candidatos com score, **filtrável por coleção**. É o requisito que sustenta o fluxo inteiro.
- **Catálogo** de coleções e cartas por região (para a grade com silhuetas e os totais).
- **Preço de mercado** atual + variação — normalmente uma API separada do catálogo.
- **Ataques, HP e custo de energia** por carta.
- **Coleção da usuária**, persistida. **Offline-first é desejável**: ela vai usar isso em loja e em encontros com amigas, onde a rede é ruim.

## Estados ainda não desenhados

Definir antes de implementar: sem permissão de câmera · nenhuma carta reconhecida · offline / falha de rede · coleção vazia (primeiro uso) · busca sem resultado · preço indisponível · revisão do modo lote (hoje o lote é só um toggle visual).

## Ordem de construção

1. **Testar o reconhecimento antes de qualquer tela.** Fotografar ~50 cartas reais, em casa, com sleeve, luz de quarto, e medir se a carta certa aparece entre as três primeiras. Se não aparecer, o app muda de forma (busca por nome com a câmera como atalho) — e continua sendo um bom app.
2. **Resolver a origem dos dados.** Existem APIs públicas e gratuitas de catálogo de TCG que resolvem catálogo, artes, ataques e HP para uso pessoal. A estrutura da escolhida define o modelo de dados.
3. **Só o caminho principal:** escolher coleção → escanear → candidatos → confirmar → coleção. O app já é útil sem o resto.
4. **Os casos chatos:** sem permissão de câmera, nada reconhecido, sem internet, coleção vazia no primeiro uso.
5. **Jornadas, busca e perfil.**

Depois disso, a coisa que mais agrega: **ver a coleção das amigas e descobrir quem tem a repetida que a outra quer.** Vale mais que perfil, conquistas e níveis.

Backlog: modo lote de verdade · edição do estado de conservação depois do scan · modo escuro tokenizado.

## Legal

Design original. Nomes de cartas, coleções e artes são inventados. Não use logos, artes ou marcas oficiais de TCG sem licença. Os nomes de região aparecem como dado fornecido pela usuária.

## Arquivos

- `prototype/Pokedex TCG.dc.html` — o protótipo. Abra no navegador (mantenha `support.js` na mesma pasta); funciona offline.
- `prototype/Pokedex TCG Dark.dc.html` — variante em modo escuro (anterior à mudança para light).
- `design_system/` — tokens, componentes, cards de especificação, guia e `SKILL.md`.
- `Revisão de Produto.dc.html` — memo de produto: o que construir primeiro, o que deixar para depois e o que não construir.
