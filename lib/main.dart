import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/auth/auth_gate.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/app_typography.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Config.isConfigured) {
    await Supabase.initialize(
      url: Config.supabaseUrl,
      publishableKey: Config.supabaseAnonKey,
    );
  }

  runApp(const PokeCardexApp());
}

class PokeCardexApp extends StatelessWidget {
  const PokeCardexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PokéCardex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Config.isConfigured ? const AuthGate() : const _MissingConfig(),
    );
  }
}

class _MissingConfig extends StatelessWidget {
  const _MissingConfig();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Configuração faltando', style: AppType.screenTitle),
              const SizedBox(height: 12),
              Text(
                'Rode com:\n\n'
                'flutter run --dart-define-from-file=env.json\n\n'
                'Copie env.example.json para env.json e preencha as chaves do Supabase.',
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: AppColors.text3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
