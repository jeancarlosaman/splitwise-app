/// App-wide constants.
/// ⚠️  Replace the two placeholder values before running.
class AppConstants {
  AppConstants._();

  /// Your Supabase project URL — found in Project Settings → API
  static const String supabaseUrl = 'https://phsoxljxawzupfrjmgkr.supabase.co';

  /// Your Supabase anon/public key — found in Project Settings → API
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBoc294bGp4YXd6dXBmcmptZ2tyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1NTIxNjgsImV4cCI6MjA5NTEyODE2OH0.lePpm_Vd5OSKWzMBtDutpF0sFALyQr3Wt9rKuRPpWHw';

  /// Storage bucket name for receipt images
  static const String receiptsBucket = 'receipts';

  /// Supported currencies
  static const List<String> currencies = ['EUR', 'USD', 'GBP', 'CHF', 'JPY'];

  /// Default currency
  static const String defaultCurrency = 'EUR';

  /// Split type identifiers
  static const String splitEqual  = 'equal';
  static const String splitByItem = 'by_item';
  static const String splitCustom = 'custom';
}
