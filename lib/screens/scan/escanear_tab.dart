import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_shell_controller.dart';
import 'scan_view.dart';
import 'setpick_view.dart';

/// Conteúdo da aba "Escanear" do [AppShell]. Alterna LOCALMENTE entre
/// Escolher coleção e Escanear (README: as duas mostram a tab bar
/// flutuante — não são full-screen routes, por isso são sub-views desta
/// aba, e não `Navigator.push`). Só Candidatos (bottom sheet) e Confirmar
/// (push de verdade) cobrem a tab bar.
class EscanearTab extends StatelessWidget {
  const EscanearTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AppShellController>();
    if (ctrl.selectedSet != null) {
      return ScanView(activeSet: ctrl.selectedSet!, onChangeSet: ctrl.backToSetpick);
    }
    if (ctrl.openUniverse) {
      return ScanView(activeSet: null, onChangeSet: ctrl.backToSetpick);
    }
    return SetpickView(onSelectSet: ctrl.selectSet, onSkip: ctrl.skipToOpenScan);
  }
}
