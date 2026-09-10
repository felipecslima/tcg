import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/floating_tab_bar.dart';
import '../widgets/primary_button.dart';
import 'set_selection_screen.dart';

/// Shell do app: 5 abas + tab bar flutuante (README § Navegação).
/// As telas reais do design entram nas próximas rodadas — por ora, placeholders
/// navegáveis, exceto Escanear (fluxo do scanner que já existe) e Perfil (logout).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    TabItem(Icons.grid_view_rounded, 'Coleção'),
    TabItem(Icons.explore_outlined, 'Jornadas'),
    TabItem(Icons.qr_code_scanner_rounded, 'Escanear'),
    TabItem(Icons.search_rounded, 'Busca'),
    TabItem(Icons.person_outline_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _Placeholder('Minhas cartas'),
      const _Placeholder('Jornadas'),
      const _ScanTab(),
      const _Placeholder('Busca'),
      const _ProfileTab(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: FloatingTabBar(
        items: _tabs,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 66, 22, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.screenTitle),
          const SizedBox(height: 12),
          Text('Tela em construção.', style: AppType.body),
        ],
      ),
    );
  }
}

class _ScanTab extends StatelessWidget {
  const _ScanTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 66, 22, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Escanear', style: AppType.scanTitle),
          const SizedBox(height: 12),
          Text('Enquadre a carta inteira.', style: AppType.body),
          const Spacer(),
          PrimaryButton(
            label: 'Abrir scanner',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SetSelectionScreen()),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 66, 22, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Perfil', style: AppType.screenTitle),
          const SizedBox(height: 12),
          Text(user?.email ?? '—',
              style: AppType.body.copyWith(color: AppColors.text3)),
          const Spacer(),
          SecondaryButton(
            label: 'Sair',
            onPressed: () => AuthService.instance.signOut(),
          ),
        ],
      ),
    );
  }
}
