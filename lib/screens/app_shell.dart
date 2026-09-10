import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_shell_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/floating_tab_bar.dart';
import 'collection_screen.dart';
import 'journeys_screen.dart';
import 'scan/escanear_tab.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

/// Shell do app: 5 abas + tab bar flutuante (README § Navegação).
/// As telas reais do design entram nas próximas rodadas — por ora, placeholders
/// navegáveis, exceto Escanear (fluxo do scanner que já existe) e Perfil (logout).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _tabs = [
    TabItem(Icons.grid_view_rounded, 'Coleção'),
    TabItem(Icons.explore_outlined, 'Jornadas'),
    TabItem(Icons.qr_code_scanner_rounded, 'Escanear'),
    TabItem(Icons.search_rounded, 'Busca'),
    TabItem(Icons.person_outline_rounded, 'Perfil'),
  ];

  static const _pages = [
    CollectionScreen(),
    JourneysScreen(),
    EscanearTab(),
    SearchScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppShellController>();
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: controller.tabIndex, children: _pages),
          if (controller.toastMessage != null) _Toast(message: controller.toastMessage!),
        ],
      ),
      bottomNavigationBar: FloatingTabBar(
        items: _tabs,
        currentIndex: controller.tabIndex,
        onTap: controller.switchToTab,
      ),
    );
  }
}

/// Toast "{nome} → {coleção}" (README §4 Confirmar), 2,2s, controlado por
/// [AppShellController] pra funcionar cruzando a troca de aba.
class _Toast extends StatelessWidget {
  const _Toast({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 22,
      right: 22,
      bottom: 100,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.purple800,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.toast,
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}


