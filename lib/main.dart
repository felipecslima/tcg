import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'constants/eevee_assets.dart';
import 'screens/splash_screen.dart';
import 'state/app_shell_controller.dart';
import 'state/avatar_controller.dart';
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

  runApp(const TieDexApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = WidgetsBinding.instance.rootElement;
    if (context != null) {
      for (final name in EeveeAssets.all) {
        precacheImage(AssetImage(EeveeAssets.path(name)), context);
      }
    }
  });
}

class TieDexApp extends StatelessWidget {
  const TieDexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppShellController()),
        ChangeNotifierProvider(create: (_) => AvatarController()),
      ],
      child: MaterialApp(
        title: 'TieDex',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Config.isConfigured ? const SplashScreen() : const _MissingConfig(),
      ),
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
