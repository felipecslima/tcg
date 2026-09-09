# CHECKLIST — Validação de Funcionamento

Use este checklist **após rodar o app pela primeira vez** para garantir que tudo está funcionando.

## Fase 1: Setup Básico

- [ ] `flutter doctor` mostra tudo ✓ (exceto web/analytics)
- [ ] `flutter run` compila sem erros
- [ ] App abre na tela "PokeCardex Scanner — MVP"
- [ ] Tela tem botão de idioma (Inglês/Português)
- [ ] Dispositivo não pede permissão de câmera (se pedir, clica Allow)

## Fase 2: Carregamento de Sets

- [ ] Clica em "Inglês" → lista de sets carrega
- [ ] Lista tem logos dos sets (ou ícones genéricos)
- [ ] Consegue scrollar a lista inteira
- [ ] Troca pro "Português" → lista carrega novamente
- [ ] Testa um idioma que não funciona (ex: "Japonês") → app não crasha

## Fase 3: Câmera

**Seleciona um set pequeno (< 100 cartas pra teste rápido)**

- [ ] Câmera abre sem erro
- [ ] Preview ao vivo apareça na tela
- [ ] Vê a câmera rotaciona (landscape ou portrait)
- [ ] Botão pause/play funciona
- [ ] Pausa congela a câmera, play retoma

**Se câmera não abrir:**
- [ ] Verifica [DEBUG.md](./DEBUG.md) — seção "Câmera não abre"
- [ ] Permissões concedidas em Settings → Apps
- [ ] Nenhum outro app usando câmera

## Fase 4: OCR

**Aponta pra uma carta Pokémon em boa iluminação**

- [ ] "Lendo: ..." aparece no topo da câmera
- [ ] Texto muda quando move a câmera
- [ ] Se não aparece: [DEBUG.md](./DEBUG.md) — "Câmera não reconhece texto"

## Fase 5: Matching

**Testa com cartas do set selecionado**

- [ ] Aponta pra Pikachu (primeira carta típica) → reconhece e vibra
- [ ] Na revisão, Pikachu aparece em "Reconhecidas"
- [ ] Aponta novamente pra mesma carta → counts de 1 pra 2
- [ ] Tira a carta, aponta pra outra → nova carta é adicionada
- [ ] Muitos matches sendo perdidos? → [DEBUG.md](./DEBUG.md) — "Pendências acumulando"

## Fase 6: Pendências

**Testa com cartas que o OCR pode ter lido ruim**

- [ ] Aponta pra uma carta com logo/brilho → pode virar pendência
- [ ] "Pendentes: X" conta no rodapé
- [ ] Revisão mostra "Reconhecidas" + "Pendentes (resolver manualmente depois)"

## Fase 7: Revisão e Salva

- [ ] Clica "Revisar (X)" → tela muda pra resultado
- [ ] Vê lista de "Reconhecidas" com nome, número, thumbnail, contagem
- [ ] Vê lista de "Pendentes" com texto bruto reconhecido
- [ ] Clica "Salvar sessão (JSON local)" → mensagem "Salvo em: ..."
- [ ] Arquivo JSON é criado em `Documents/` (ou verifica [DEBUG.md](./DEBUG.md) se não encontrar)

## Fase 8: Validação do JSON

**Conecta dispositivo ao PC e busca o arquivo `scan_*.json`**

- [ ] Campo `setId` = set que escaneou
- [ ] Campo `language` = idioma selecionado
- [ ] Array `scanned` tem suas cartas com nome + número + contagem
- [ ] Array `pending` tem entradas que não casaram (se houver)
- [ ] JSON é válido (consegue abrir em VS Code sem erro)

## Teste fim-a-fim: Sessão real

**Com 3-5 cartas físicas da coleção**

- [ ] Seleciona set português (se tiver cartas PT) ou inglês
- [ ] Aponta pra cada carta (com boa iluminação)
- [ ] ~80% das cartas são reconhecidas automaticamente
- [ ] Restante vai pra pendências (aceitável pra MVP)
- [ ] Revisão mostra resultado esperado
- [ ] JSON é salvo sem erro

### Taxa de reconhecimento esperada

| Cenário | Taxa esperada |
|---------|------------------|
| Cartas em bom estado, boa iluminação | 85-95% |
| Cartas holofoil (brilho) | 70-80% |
| Cartas desgastadas/antigas | 60-70% |
| Iluminação fraca | 50-60% |
| Cartas muito pequenas na câmera | < 50% |

**Se taxa for muito abaixo do esperado:** [DEBUG.md](./DEBUG.md) → ajustar `confidenceThreshold`.

## Troubleshooting Rápido

| Problema | Checklist |
|----------|-----------|
| Câmera não abre | [DEBUG.md](./DEBUG.md) — "Câmera não abre" |
| OCR não reconhece nada | [DEBUG.md](./DEBUG.md) — "Câmera não reconhece texto" |
| Cartas não casam | [DEBUG.md](./DEBUG.md) — "Câmera reconhece texto, mas cartas não casam" |
| Muitas pendências | Abaixar `confidenceThreshold` em `lib/services/card_matcher.dart` |
| JSON não é criado | Verificar permissões em Settings → Apps → PokeCardex → Files |
| App crasha | Rodar `flutter run -v` e procurar por stack trace |

## Próximos passos após validação

1. **Testar com mais sets** (diferentes idiomas, raridades)
2. **Calirar threshold** conforme seus cartas/iluminação
3. **Coletar JSONs** de várias sessões pra análise
4. **Documentar falsos-positivos/negativos** pra Fase 2
5. **Começar Fase 2:** Persistência Supabase

## Feedback

Se encontrou algo que não funciona:

1. Nota exatamente qual passo falhou
2. Compartilha output de `flutter run -v`
3. Procura por logs `pokecardex` (ver [DEBUG.md](./DEBUG.md))
4. Compartilha a carta específica (nome, set) que falhou
5. Descreve iluminação/ângulo da câmera

Com essas infos fica fácil debugar!
