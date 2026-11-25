/// Configuration injectée à la compilation :
///
/// ```bash
/// flutter run --dart-define-from-file=env/local.json
/// ```
///
/// Sans configuration, l'app démarre en **mode démo** (données locales),
/// ce qui permet de travailler l'interface et de lancer les tests sans backend.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// `local`, `staging` ou `production` — affiché dans le profil hors production.
  static const name = String.fromEnvironment('APP_ENV', defaultValue: 'demo');

  static bool get hasBackend =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
