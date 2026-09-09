import 'tcg_card.dart';

/// Uma carta reconhecida com sucesso durante a sessão de scan, com quantas
/// vezes ela foi vista (você pode escanear a mesma carta 2x se tiver 2
/// cópias físicas).
class ScannedEntry {
  final TcgCard card;
  int count;

  ScannedEntry({required this.card, this.count = 1});
}

/// Uma tentativa de reconhecimento que não bateu com confiança suficiente
/// em nenhuma carta do set carregado. Fica na pilha de pendências pra
/// revisão manual, sem travar o fluxo de scan.
class PendingEntry {
  final String rawRecognizedText;
  final DateTime scannedAt;

  PendingEntry({required this.rawRecognizedText, required this.scannedAt});
}

/// Estado acumulado de uma sessão de scan em modo rajada: o que já foi
/// reconhecido (com contagem) e o que ficou pendente.
class ScanSession {
  final String setId;
  final String setName;
  final String language;

  final Map<String, ScannedEntry> _scanned = {}; // cardId -> entry
  final List<PendingEntry> pending = [];

  ScanSession({required this.setId, required this.setName, required this.language});

  List<ScannedEntry> get scannedEntries => _scanned.values.toList();

  int get totalScannedCount => _scanned.values.fold(0, (sum, e) => sum + e.count);

  void addMatch(TcgCard card) {
    final existing = _scanned[card.id];
    if (existing != null) {
      existing.count++;
    } else {
      _scanned[card.id] = ScannedEntry(card: card);
    }
  }

  void addPending(String rawText) {
    pending.add(PendingEntry(rawRecognizedText: rawText, scannedAt: DateTime.now()));
  }

  void removePending(PendingEntry entry) {
    pending.remove(entry);
  }

  /// Resolve manualmente uma pendência pra uma carta específica (usado na
  /// tela de revisão, busca por nome).
  void resolvePending(PendingEntry entry, TcgCard card) {
    removePending(entry);
    addMatch(card);
  }
}
