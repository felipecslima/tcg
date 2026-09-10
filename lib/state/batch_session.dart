import 'package:flutter/foundation.dart';

import '../models/card.dart';

class BatchEntry {
  BatchEntry({required this.card, this.finish = 'normal', this.quantity = 1, this.language = 'pt'});

  final Card card;
  String finish;
  int quantity;
  final String language;
}

class BatchSession extends ChangeNotifier {
  static const maxEntries = 50;

  final List<BatchEntry> _entries = [];

  List<BatchEntry> get entries => List.unmodifiable(_entries);
  int get count => _entries.fold(0, (sum, e) => sum + e.quantity);
  int get distinctCount => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isFull => _entries.length >= maxEntries;

  void add(Card card, {String finish = 'normal', String language = 'pt'}) {
    final idx = _entries.indexWhere(
        (e) => e.card.id == card.id && e.finish == finish && e.language == language);
    if (idx >= 0) {
      _entries[idx].quantity = (_entries[idx].quantity + 1).clamp(1, 99);
    } else if (!isFull) {
      _entries.add(BatchEntry(card: card, finish: finish, language: language));
    }
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _entries.length) return;
    _entries.removeAt(index);
    notifyListeners();
  }

  void updateEntry(int index, {String? finish, int? quantity}) {
    if (index < 0 || index >= _entries.length) return;
    final e = _entries[index];
    if (finish != null) e.finish = finish;
    if (quantity != null) e.quantity = quantity.clamp(1, 99);
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
