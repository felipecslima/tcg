/// Configuração injetada em build via `--dart-define-from-file=env.json`.
///
/// Rodar:
///   flutter run --dart-define-from-file=env.json
///
/// `env.json` é gitignored. Ver `env.example.json` para o formato.
class Config {
  const Config._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
