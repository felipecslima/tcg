import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../app_shell.dart';
import 'login_screen.dart';

/// Decide a rota no boot e reage a login/logout.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ?? auth.currentSession;
        if (session != null) return const AppShell();
        return const LoginScreen();
      },
    );
  }
}
