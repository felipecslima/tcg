import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Moldura comum das telas de auth: fundo com brilho lilás no topo, título + subtítulo.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x38C08FE8), AppColors.bgScreen],
            stops: [0, 0.4],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 48, 22, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppType.screenTitle),
                const SizedBox(height: 8),
                Text(subtitle, style: AppType.body),
                const SizedBox(height: 32),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showAuthError(BuildContext context, Object error) {
  final msg = switch (error) {
    _ when error.toString().contains('Invalid login') =>
      'Email ou senha incorretos.',
    _ when error.toString().contains('already registered') =>
      'Esse email já tem conta.',
    _ => 'Algo deu errado. Tente de novo.',
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
