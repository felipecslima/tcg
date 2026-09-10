# Pokédex TCG — Design System

Sistema visual do app de coleção de cartas de TCG. Modo claro, base lilás/violeta (inspiração: a evolução psíquica do Eevee), tom lúdico mas organizado — a usuária é uma pré-adolescente colecionadora, não uma criança pequena nem um investidor.

**Fonte:** este sistema foi extraído do protótipo `Pokedex TCG.dc.html` deste mesmo projeto (9 telas, navegação funcional). Não houve codebase, Figma ou design system anterior — tudo aqui nasceu do protótipo. Não existe logo: onde uma marca entraria, use o nome em Sora 700.

## Índice

- `styles.css` — ponto de entrada; só imports.
- `tokens/` — `fonts`, `colors`, `typography`, `spacing`, `radius`, `shadows`.
- `components/core/` — Button, Chip, Card, SectionLabel, ProgressBar, CardArt, ListRow, RarityPill, StatTile, RadioRow.
- `guidelines/` — cards de especificação (cores, tipo, espaçamento, arte de carta).
- `SKILL.md` — para uso como Agent Skill no Claude Code.

## Content fundamentals

**Português do Brasil, segunda pessoa implícita.** Fala-se com ela, não sobre ela: "Enquadre a carta inteira", "Escolha a coleção". Nunca "o usuário deve".

- **Frases curtas e concretas.** "De qual coleção são as cartas?" em vez de "Selecione a coleção de origem".
- **Perguntas como títulos** nos momentos de decisão: "É alguma dessas?", "De qual coleção são as cartas?". Isso baixa o custo de errar.
- **Sempre uma saída.** Todo passo obrigatório tem um escape em texto: "Nenhuma — escanear de novo", "Não sei a coleção — escanear mesmo assim". Escritos como fala, com travessão.
- **Números com unidade e contexto.** "88 de 151 · faltam 63", nunca "88/151" sozinho. Preços em reais com vírgula.
- **Rótulos de seção em maiúsculas mono**, 1–2 palavras: GUARDAR EM, ATAQUES, CONQUISTAS.
- **Metadados separados por " · "** na ordem coleção · número · atributo · quantidade.
- **Sem emoji.** Sem exclamação. Sem gamificação forçada ("Uau!", "Parabéns!!"). As conquistas descrevem o feito em voz neutra: "Registrou uma carta ultra rara".
- **Confirmação é discreta:** um toast de 2,2s com o resultado ("Lumivee ex → Deck Eevee"), não uma tela de celebração.

## Visual foundations

**Papel.** Fundo lilás claríssimo (`--ds-bg` #FBF9FD; o fora-do-app é #EFEAF6). Superfícies são **branco puro** com borda roxa a 12% — o contraste entre os dois é o que separa conteúdo de fundo, não sombra.

**Cor.** Um único roxo de marca em escala; `--ds-purple-600` é a cor de ação. Roxo cheio é raro e caro: só o botão de ação principal, os itens ativos da tab bar, os nós já iniciados da trilha e **no máximo um card hero por tela**. Todo o resto usa tinta roxa translúcida (6–18%). Dourado é exclusivo de raridade, HP e valor; verde e vermelho só para variação de preço. Nada de segunda cor de marca.

**Tipo.** Três famílias com papéis rígidos: **Sora** só em títulos e nomes próprios (com `letter-spacing: -.02em` acima de 24px); **DM Sans** em todo texto corrido, legenda e botão; **DM Mono** em tudo que é dado — preços, porcentagens, numeração de carta, HP e rótulos de seção em maiúsculas com tracking .14em. Um número nunca aparece em DM Sans.

**Contraste.** Todo texto abaixo de 24px passa 4.5:1 sobre o fundo onde vive. Por isso o dourado é #8A5C10 e não amarelo, e o verde é #1F7346 e não menta. Sobre superfície roxa, texto é branco puro — nunca lilás a 80%.

**Fundos.** Chapados. Sem imagem de fundo, sem textura, sem padrão decorativo. Duas exceções: o **véu roxo** (`--ds-grad-veil`) que desce do topo dos heros de carta e perfil, e o **listrado a 115°** (`--ds-placeholder`), que significa exatamente uma coisa — "aqui entra uma imagem que ainda não existe". Nunca use o listrado como decoração.

**Cards.** Raio 20px, padding 18px, borda 1px roxa a 12%, sem sombra. A elevação vem do branco sobre lilás. Sombra é reservada a coisas que flutuam de verdade: arte de carta (`--ds-shadow-card` / `--ds-shadow-hero`), o bottom sheet, o botão de ação. Todas são difusas e arroxeadas (rgba(60,40,100,·)) — nunca preto puro.

**Raios.** 6px mini-thumb · 10px arte em grade · 13px chips e rádios · 16px botões e linhas · 20px cards · 26px tab bar e sheet · 99px pílulas.

**Bordas.** Sempre roxo translúcido, nunca cinza. 12% em repouso, 22% em elementos interativos, cor cheia quando selecionado. Borda **tracejada** tem significado próprio: algo ausente ou opcional (slot de carta não registrada, ação de adicionar manualmente).

**Transparência e blur.** Só na tab bar: `rgba(255,255,255,.88)` com `backdrop-filter: blur(22px)`. Nenhum outro elemento usa vidro.

**Estados.** Hover: botão primário clareia para `--ds-action-hover`; superfícies ganham `border-color: var(--ds-action)`; linhas de lista escurecem para a tinta roxa. Selecionado é sempre a mesma receita — borda cheia + fundo `--ds-tint-strong` + texto `--ds-purple-900`. Nada muda de tamanho ao ser pressionado.

**Animação.** Mínima e funcional. `floatUp` 0,25–0,28s ease-out (translateY 14px + fade) para sheet e toast; `scanline` 1,1s ease-in-out infinita só durante a leitura da câmera. Sem bounce, sem spring, sem parallax. Se um elemento não está comunicando um estado do sistema, ele não anima.

**Layout.** Gutter 22px, topo 66px (status bar), rodapé 120px em toda tela rolável — a tab bar flutua a 22px do fundo e não empurra conteúdo. Listas em coluna com gap 9px; grades de carta em 3 colunas com gap 11px. Nunca use margens soltas entre irmãos: flex/grid com `gap`.

**Imagens.** Arte de carta sempre na proporção .72 (63×88mm). Sem imagem real, o listrado com rótulo mono minúsculo dizendo o que entra ali. **Nunca desenhe uma carta, um mascote ou um logo.**

## Iconography

Não existe icon set definido. O protótipo usa **glifos Unicode como placeholders declarados**: ▤ coleção · ◈ jornadas · ⦿ escanear · ⌕ busca · ☺ perfil · ★ ✦ conquistas · ⚡ flash · ‹ › navegação · ✓ seleção · − + stepper · ✕ limpar.

**Substituir por um set real antes de implementar.** Recomendação: SF Symbols no iOS (nativo, combina com o peso do texto) ou Lucide via CDN em web/React Native — traço fino, cantos arredondados, coerente com o desenho. Ícones herdam a cor do texto ao redor; nunca ganham cor própria. Tamanhos: 19px na tab bar, 16px inline em campos, 15–18px em botões-círculo.

**Sem emoji em nenhuma superfície.**

## Intentional additions

Nenhuma. Todos os dez componentes existem literalmente no protótipo; nada foi acrescentado por convenção.

## Caveats

- **Sem logo e sem mascote** — nada foi desenhado e nada deve ser desenhado sem material da usuária.
- **Fontes por CDN.** Sora, DM Sans e DM Mono vêm do Google Fonts (SIL OFL). Empacote os arquivos no app nativo.
- **Nomes de cartas, coleções e artes são fictícios.** Nenhuma marca, arte ou nome oficial de TCG é usado, e nenhum deve ser sem licença.
- **Modo escuro existe** em `Pokedex TCG Dark.dc.html`, mas não está tokenizado aqui. Se virar requisito, o caminho é um escopo `[data-theme="dark"]` sobre os mesmos nomes semânticos.
- Este projeto é o **app**, não um projeto de design system: o compilador que gera o bundle de componentes espera `styles.css` na raiz do projeto. Para usar como sistema anexável, mova o conteúdo de `design_system/` para a raiz de um projeto novo e marque o tipo como Design System em Compartilhar.
