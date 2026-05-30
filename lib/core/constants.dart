/// Supabase project credentials.
/// Replace these two values with your project's URL and anon key.
/// Find them at: https://supabase.com/dashboard → your project → Settings → API
class AppConstants {
  static const supabaseUrl = 'https://phsoxljxawzupfrjmgkr.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_J70hEk-sprl7m2suoS4kqw_baLSu_Mj';

  /// Anthropic Claude API key for AI-powered voice parsing.
  /// Get one at https://console.anthropic.com/settings/keys
  ///
  /// SECURITY NOTE: Embedding this key in a mobile app is OK for personal /
  /// internal use, but the key is extractable from the IPA. For public release,
  /// proxy these calls through a Supabase Edge Function instead so the key
  /// stays server-side. See supabase/functions/parse-expense for a template.
  static const claudeApiKey = String.fromEnvironment(
    'CLAUDE_API_KEY',
    defaultValue: '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',
  );

  static const defaultCurrency = 'EUR';
  static const appName = 'SplitWise';
}
