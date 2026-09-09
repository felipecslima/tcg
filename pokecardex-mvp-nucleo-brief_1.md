# PokeCardex Clone — Plano do MVP do Scanner (foco máximo)

Documento vivo do planejamento. Substitui a versão anterior (que ainda citava Lovable/web/pokemontcg.io — tudo isso mudou). Objetivo deste MVP: **provar que o scanner funciona**, e só depois construir o resto do app em cima disso.

## Contexto

Joel coleciona cartas Pokémon TCG (português e inglês), tem **mais de 1000 cartas físicas** pra registrar, e os apps prontos são pagos. Sem um scanner que funcione de verdade, o projeto inteiro não se sustenta — por isso o MVP não é "um pedacinho do app", é a validação do motivo do projeto existir.

## Decisões já fechadas (não reabrir sem motivo forte)

- **Stack:** Flutter + Supabase (abandonado Lovable — decisão do usuário, queria um app em Flutter mesmo).
- **Reconhecimento de texto:** on-device via `google_mlkit_text_recognition` (Vision no iOS, ML Kit no Android) — grátis, offline, sem custo por chamada. iOS min 15.5, Android minSdk 21.
- **Fonte de dados de cartas:** **TCGdex** (`api.tcgdex.net`), não mais pokemontcg.io.
  - Grátis, sem rate limit publicado, sem API key obrigatória.
  - Suporta **português nativamente** (resolve o problema de cartas PT não baterem no matching).
  - Já retorna preço (Cardmarket EUR + TCGplayer USD) embutido em cada carta — Fase 2 sai quase de graça.
  - Risco conhecido: mantida pela comunidade, sem SLA. Mitigação: banco de dados aberto (`tcgdex/cards-database`), dá pra hospedar cópia própria se a API cair.
  - pokemontcg.io está sendo descontinuada (chaves existentes válidas até 1º/mar/2027) — motivo da troca.
- **Modo de scan:** rajada (não trava tela por carta), com fila de reconhecidos + pilha de pendências pra falhas.
- **Pré-filtro antes de escanear:** selecionar set/idioma esperado reduz o universo de busca e é a maior alavanca de precisão — mais importante que o motor de OCR em si.

## Escopo do MVP — SÓ o scanner

Fora do MVP por enquanto (entra depois, de propósito):
- Telas de catálogo (por Set, por Pokédex)
- Tela de "minha coleção" completa, wishlist
- Preços na UI
- Autenticação / Supabase (o MVP pode rodar 100% local no dispositivo, sem backend)
- Design visual polido — funcional é o suficiente pra essa fase

O que **entra**:

1. **Carregar uma base mínima de cartas pra matching.** Não sincroniza o catálogo inteiro — só o(s) set(s) que você vai escanear na sessão (busca na TCGdex sob demanda, cacheado em memória/arquivo local). Tela simples: "qual set você vai escanear agora?".
2. **Câmera ao vivo** (pacote `camera`).
3. **Captura periódica de frame + OCR on-device** (`google_mlkit_text_recognition`), extraindo nome e número da carta.
4. **Matching fuzzy** do texto reconhecido contra as cartas carregadas (nome + número), já restrito ao set/idioma pré-selecionado.
5. **Modo rajada:** cada match confirmado dá feedback tátil (`HapticFeedback`, sem precisar de pacote extra) e entra numa lista de "escaneadas nessa sessão" — sem travar a câmera, sem persistir em banco ainda.
6. **Pilha de pendências:** falhas de matching não travam o fluxo, ficam numa lista separada visível na mesma tela.
7. **Tela de revisão no fim da sessão:** lista do que foi reconhecido (nome, imagem, contagem) + lista de pendências. Confirmar por enquanto pode só salvar num JSON local — Supabase entra só depois que o scanner provar que funciona.

## Fase 0 — validar o algoritmo antes de montar a tela (proposta)

`google_mlkit_text_recognition` só roda em dispositivo real (Android/iOS), não dá pra testar aqui no ambiente de desenvolvimento. Mas a parte mais arriscada não é "a câmera liga" — é "o texto reconhecido bate com a carta certa". Isso dá pra validar **antes** de montar toda a tela do Flutter:

- Usuário manda 2-3 fotos reais de cartas (uma comum, uma holo/rara, uma em português).
- Roda-se um teste rápido (OCR qualquer, ex: Tesseract, só como substituto de teste — não é o motor final) pra ver se nome+número saem legíveis da foto e batem com a busca na TCGdex.
- Se funcionar bem: segue com confiança pra montar a tela de câmera de verdade.
- Se falhar muito: descobre isso agora, sem ter gasto tempo montando UI em cima de um matching que não funciona.

## Passos de construção (ordem)

1. Scaffold do projeto Flutter (`camera`, `google_mlkit_text_recognition`, `http`).
2. Serviço de busca de cartas na TCGdex por set (sem Supabase ainda — direto da API, cacheado localmente).
3. Serviço de matching fuzzy (nome + número).
4. Tela de scanner: câmera ao vivo + processamento periódico de frame.
5. Lógica de fila (reconhecidas + pendências) e feedback tátil.
6. Tela de revisão da sessão.
7. Testar com cartas físicas reais e ajustar o matching conforme os erros aparecerem.

## Depois que o MVP do scanner provar que funciona

Só então entra o resto, na ordem:
- Persistência real (Supabase: schema de `sets`/`cards`/`user_collection`, autenticação).
- Catálogo por Set e por Pokédex.
- Marcar "tenho"/quantidade de forma permanente + wishlist (coração).
- Preços (já vêm da TCGdex, é só exibir).
- Variantes de acabamento, cartas graded, estatísticas — fica pra bem depois.

## Em aberto

- Quer mandar fotos reais de cartas agora pra gente rodar a Fase 0 de validação antes de montar a tela de câmera?
