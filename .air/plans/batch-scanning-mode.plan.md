# Plano: Scanner em Lote (Batch Mode)

## Contexto

O scanner atual processa uma carta por vez: câmera → candidatos (bottom sheet) → confirmar (tela cheia) → salvar → volta pra câmera. Para quem quer catalogar muitas cartas de uma vez, esse fluxo é lento demais — cada carta exige 3 interações. O modo lote já existe como toggle visual (`_batchMode` em `scan_view.dart:57`), mas não faz nada. Este plano implementa o lote de verdade: captura contínua com bandeja acumulando cartas, e uma tela de revisão/salvamento em lote no final.

## Abordagem

Criar um `BatchSession` (ChangeNotifier) que acumula cartas escaneadas em memória. Quando batch mode está ON, o `ScanView` não abre modal nem navega pro `ConfirmScreen` — em vez disso, adiciona silenciosamente à sessão (alta confiança) ou mostra um mini-picker inline (baixa confiança). Uma bandeja flutuante mostra o progresso e leva à tela de revisão em lote, onde a usuária configura coleção destino e acabamento pra todo o lote e salva de uma vez. O fluxo individual (batch OFF) continua idêntico.

## Arquivos

| Arquivo | Ação | Responsabilidade |
|---|---|---|
| `lib/state/batch_session.dart` | **Criar** | ChangeNotifier com lista de BatchEntry, add/remove/update/clear, dedup por card.id |
| `lib/screens/scan/inline_picker.dart` | **Criar** | Widget overlay com thumbnails lado a lado pra desambiguação rápida |
| `lib/screens/scan/batch_tray.dart` | **Criar** | Pill flutuante "N cartas · Revisar" com mini-stack de thumbnails |
| `lib/screens/scan/batch_review_screen.dart` | **Criar** | Tela de revisão em lote: lista de cartas, config global, salvar todas |
| `lib/screens/scan/scan_view.dart` | **Modificar** | Fork no `_showCandidates`: batch ON → auto-add ou inline picker; batch OFF → fluxo atual |
| `lib/state/app_shell_controller.dart` | **Modificar** | Expor `batchMode` bool (persiste entre trocas de aba) |
| `lib/screens/scan/escanear_tab.dart` | **Modificar** | Prover `BatchSession` via Provider |
| `lib/repositories/collection_repository.dart` | **Modificar** | Método `addCardsBatch` (loop sobre upsert existente) |

## Modelo de Dados

```dart
// lib/state/batch_session.dart
class BatchEntry {
  final Card card;
  String finish;    // 'normal' | 'reverse' | 'holo'
  int quantity;     // default 1
}

class BatchSession extends ChangeNotifier {
  List<BatchEntry> entries;
  void add(Card card, {String finish = 'normal'});  // dedup: mesma carta incrementa qty
  void removeAt(int index);
  void updateEntry(int index, {String? finish, int? quantity});
  void clear();
}
```

## Tarefas

### 1. BatchSession (modelo + estado)
Criar `lib/state/batch_session.dart`. Dedup por `card.id`: mesma carta escaneada 2x incrementa quantity. Prover via `ChangeNotifierProvider` no `EscanearTab`.

### 2. Mover batchMode pro AppShellController
Hoje `_batchMode` é estado local de `_ScanViewState` (scan_view.dart:57). Mover pra `AppShellController` como campo persistente entre trocas de aba.

### 3. Fork do fluxo no ScanView
Modificar `_showCandidates` em `scan_view.dart`:
- **Batch OFF**: idêntico ao atual (CandidatesSheet modal → ConfirmScreen)
- **Batch ON, 1 candidato**: auto-add ao `BatchSession`, haptic leve, hint temporário "✓ {nome}"
- **Batch ON, 2-3 candidatos**: mostra `InlinePicker` overlay, câmera pausa brevemente
- **Batch ON, 0 candidatos**: vibração + hint "Não reconhecida"

### 4. InlinePicker (widget overlay)
Criar `lib/screens/scan/inline_picker.dart`. Posicionado sobre o viewfinder no Stack. 2-3 thumbnails lado a lado com nome. Fundo semi-transparente. Tap escolhe, tap fora descarta. Sem modal, sem navegação.

### 5. Batch Tray (pill flutuante)
Criar `lib/screens/scan/batch_tray.dart`. Posicionada acima dos controles. Mostra contagem + "Revisar" + mini-stack das últimas 3 thumbnails. Aparece quando `batchSession.count > 0`. Tap navega pra `BatchReviewScreen`.

### 6. BatchReviewScreen
Rota full-screen via `rootNavigator: true`. Layout:
- AppBar: "Revisar N cartas" + voltar
- Config global: dropdown coleção destino + chips acabamento padrão
- Lista com `Dismissible` (swipe remove) + tap (edita finish/qty via mini sheet)
- Footer: "Salvar todas (N)" como PrimaryButton

### 7. Salvamento em lote
`addCardsBatch` em `CollectionRepository`: loop sequencial chamando `addCardToCollection` existente. Sem migration. Após salvar: limpa BatchSession, navega pra coleção com toast "N cartas adicionadas à {coleção}".

### 8. Limpeza e edge cases
- Limpar `BatchSession` após salvar
- Desligar batch com cartas na bandeja: dialog confirmando descarte
- Trocar set com cartas na bandeja: dialog confirmando descarte
- Bandeja persiste ao trocar de aba (IndexedStack mantém montado)

### 9. Feedback visual
- Hint text muda pro nome da carta em verde por 1.5s após captura
- Thumbnail com scale-down animation saindo pro tray
- Counter bounce no tray ao incrementar

## Critérios de Aceite

- `flutter analyze` limpo, `flutter test` verde
- Batch OFF: fluxo idêntico ao atual
- Batch ON: câmera não para pra match de 1 candidato
- Batch ON: inline picker pra 2-3 candidatos (sem modal)
- Bandeja com contagem correta, navega pra revisão
- Dedup: mesma carta 2x → incrementa qty, não duplica
- BatchReviewScreen: swipe remove, tap edita
- Salvar todas grava no Supabase via repositório
- Toast: "N cartas adicionadas à {coleção}"
- Zero valores hardcoded fora de lib/theme/

## Verificação

1. `flutter analyze` sem warnings
2. `flutter test` passando
3. Manual: ligar batch → escanear 3+ cartas → bandeja incrementa → revisar → salvar → checar coleção
4. Manual: batch OFF → fluxo individual funciona igual
5. Manual: mesma carta 2x → não duplica
6. Testes novos: `BatchSession` (add, dedup, remove, clear), `addCardsBatch`

## Riscos

| Risco | Mitigação |
|---|---|
| Provider inacessível via rootNavigator | `ChangeNotifierProvider.value` envolvendo a rota (padrão do ConfirmScreen) |
| Falha no meio do salvamento | Cada upsert é atômico — salvas ficam salvas, mostrar progresso + retry |
| Muitas cartas na bandeja | Limite de 50 por sessão |
| Re-scan da mesma carta física | Reutilizar `_resolvedKey` existente |
