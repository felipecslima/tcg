import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/set_repository.dart';

/// Estado compartilhado entre as abas do [AppShell] — troca de aba, toast
/// cruzando `IndexedStack`, e o set escolhido pro scan (persiste entre
/// trocas de aba e navegações internas).
class AppShellController extends ChangeNotifier {
  static const scanTabIndex = 2;

  int tabIndex = 0;
  String? toastMessage;
  Timer? _toastTimer;

  // --- Set selecionado para scan ---
  CardSetBrief? selectedSet;
  bool openUniverse = false;

  void selectSet(CardSetBrief set) {
    selectedSet = set;
    openUniverse = false;
    notifyListeners();
  }

  void skipToOpenScan() {
    selectedSet = null;
    openUniverse = true;
    notifyListeners();
  }

  void backToSetpick() {
    selectedSet = null;
    openUniverse = false;
    notifyListeners();
  }

  static const _toastDuration = Duration(milliseconds: 2200);

  void switchToTab(int index) {
    tabIndex = index;
    notifyListeners();
  }

  /// Troca pra aba Coleção (índice 0) e mostra o toast "{nome} → {coleção}".
  void goToCollectionWithToast(String message) {
    tabIndex = 0;
    toastMessage = message;
    notifyListeners();
    _toastTimer?.cancel();
    _toastTimer = Timer(_toastDuration, () {
      toastMessage = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }
}
