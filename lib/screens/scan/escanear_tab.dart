import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_shell_controller.dart';
import '../../state/batch_session.dart';
import 'scan_view.dart';
import 'setpick_view.dart';

class EscanearTab extends StatefulWidget {
  const EscanearTab({super.key});

  @override
  State<EscanearTab> createState() => _EscanearTabState();
}

class _EscanearTabState extends State<EscanearTab> {
  final _batchSession = BatchSession();

  @override
  void dispose() {
    _batchSession.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _batchSession,
      child: _EscanearTabContent(),
    );
  }
}

class _EscanearTabContent extends StatelessWidget {
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
