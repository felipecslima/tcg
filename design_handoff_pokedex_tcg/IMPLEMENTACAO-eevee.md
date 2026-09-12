# TieDex — aplicação dos assets Eevee e dos loadings

Complemento do handoff. Cobre o que entrou no protótipo (`prototype/Pokedex TCG.dc.html`) nesta rodada.

## 1. Assets

Nove PNGs com fundo transparente em `assets/eevee/`:

`eevee`, `espeon`, `umbreon`, `vaporeon`, `jolteon`, `flareon`, `leafeon`, `glaceon`, `sylveon`

Helper único no código:

```js
const EEVEE = n => `assets/eevee/${n}.png`;
```

Regras: sempre `object-fit: contain`, nunca `cover`. Nunca esticar. Tamanho mínimo legível: 20px.

## 2. Papéis fixos

| Papel | Eeveelution | Onde |
|---|---|---|
| Marca / ícone do app | **Sylveon** | splash, ícone, logo |
| Avatar padrão | **Sylveon** | perfil (a usuária troca) |
| Guardião Kanto | Flareon | trilha de jornadas |
| Guardião Johto | Umbreon | trilha |
| Guardião Hoenn | Vaporeon | trilha |
| Guardião Sinnoh | Glaceon | trilha |
| Guardião Unova | Leafeon | trilha |

```js
const GUARDIANS = { Kanto:'flareon', Johto:'umbreon', Hoenn:'vaporeon', Sinnoh:'glaceon', Unova:'leafeon' };
```

Região não iniciada: `filter: grayscale(1) opacity(.45)` no guardião, nó sem gradiente.

## 3. Avatar

Lista completa das nove opções, ordem: Sylveon primeiro, depois Eevee e as demais.
Selecionado: fundo `#E4D9F4`, borda `3px solid #7A4BC4`, opacidade 1.
Não selecionado: fundo `#FFFFFF`, borda `2px solid rgba(122,75,196,.16)`, opacidade `.7`.
Toque de 52px (mínimo 44px).

## 4. Loadings

Nenhum spinner genérico no app. Cinco variantes, cada uma com um uso.

### Keyframes (uma vez, global)

```css
@keyframes swap9{0%{opacity:0;transform:scale(.86)}2%{opacity:1;transform:scale(1)}9.5%{opacity:1;transform:scale(1)}11.2%{opacity:0;transform:scale(1.06)}100%{opacity:0;transform:scale(.86)}}
@keyframes swap4{0%{opacity:1}25%{opacity:0}100%{opacity:0}}
@keyframes swap3{0%{opacity:1}33.34%{opacity:0}100%{opacity:0}}
@keyframes hop{0%,100%{transform:translateY(0) scaleY(1)}18%{transform:translateY(0) scaleY(.86)}45%{transform:translateY(-22px) scaleY(1.04)}72%{transform:translateY(0) scaleY(.92)}86%{transform:translateY(0) scaleY(1)}}
@keyframes orbit{from{transform:rotate(0)}to{transform:rotate(360deg)}}
@keyframes orbitFix{from{transform:rotate(0)}to{transform:rotate(-360deg)}}
@keyframes glow8{0%{opacity:.28;transform:scale(.82)}6%{opacity:1;transform:scale(1.12)}14%{opacity:.28;transform:scale(.82)}100%{opacity:.28;transform:scale(.82)}}
@keyframes walk{0%{left:0}100%{left:100%}}
@keyframes fill{0%{width:4%}100%{width:100%}}
@keyframes sway{0%,100%{transform:rotate(-5deg)}50%{transform:rotate(5deg)}}
@keyframes ripple{0%{transform:scale(.7);opacity:.45}100%{transform:scale(1.7);opacity:0}}
@keyframes dots{0%,20%{opacity:.2}50%{opacity:1}80%,100%{opacity:.2}}
```

### Como funciona a troca

Todas as imagens ficam empilhadas em `position:absolute` dentro de um pai `position:relative`, todas com a mesma animação e `animation-delay` escalonado. A animação é `infinite both`. O ciclo = nº de imagens × tempo de cada uma.

| # | Nome | Onde usar | Duração do ciclo | Imagens |
|---|---|---|---|---|
| 1 | Medalhão | scan lendo a carta, esperas curtas | 4.5s (9 × .5s) | 9, medalhão 112px + `ripple` |
| 2 | Roda de evoluções | sincronização, tela cheia | 14s orbit + 3.2s `glow8` | 8 em órbita + Eevee central com `sway` |
| 3 | Pulinho | salvar, 1–3s | 4.4s (4 × 1.1s), `hop` 1.1s | 4 |
| 4 | Barra com progresso | scan em lote | 5s (`walk` + `fill`) | 3 sobre a barra |
| 5 | Miúdo | botões e linhas inline, 20–24px | 2.4s (3 × .8s) | 3 |

Mapeamento no app: **1** no scan, **3** ou **5** ao salvar, **4** no lote, **5** nos botões, **2** só na sincronização.

Referência viva de todos: `Loadings Eevee.dc.html`.

## 5. O que mudou no protótipo

- Splash: o círculo `⦿` virou o Sylveon.
- Scan: enquanto `scanning === true`, overlay com fundo `rgba(239,234,246,.55)` + blur 2px e o loader 1 centralizado sobre a moldura.
- Jornadas (trilha): o nó de 58px mostra o guardião da região; a porcentagem virou um badge branco no canto inferior direito.
- Confirmar: o botão de salvar entra em estado `saving` por 1.1s com o loader 5 inline e o texto "Salvando…", depois navega para a coleção e dispara o toast.
- Perfil: avatar é imagem do parceiro escolhido; abaixo da barra de XP, a fileira "Seu parceiro" com as nove opções.

## 6. Estado novo a portar

```js
avatar: 'sylveon'   // string, persistir por usuária
saving: false       // local da tela de confirmação
```

## 7. Pendências para o app real

- Os PNGs são artes de referência. Para produção, confirmar a origem dos arquivos ou substituir por arte própria.
- Definir cache/preload dos nove PNGs no boot — os loadings dependem deles estarem em memória, senão a primeira volta pisca.
- `prefers-reduced-motion`: trocar os loadings animados por uma imagem única estática do parceiro escolhido.
