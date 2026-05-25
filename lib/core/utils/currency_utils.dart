import 'package:intl/intl.dart';

class CurrencyUtils {
  CurrencyUtils._();

  static const Map<String, String> _symbols = {
    'EUR': '€',
    'USD': '\$',
    'GBP': '£',
    'CHF': 'Fr.',
    'JPY': '¥',
  };

  /// Returns the symbol for [currency], e.g. '€' for 'EUR'.
  static String symbol(String currency) =>
      _symbols[currency.toUpperCase()] ?? currency;

  /// Formats [amount] as a human-readable currency string.
  /// Example: formatAmount(12.5, 'EUR') → '€ 12.50'
  static String formatAmount(double amount, String currency) {
    final sym = symbol(currency);
    final formatted = NumberFormat('#,##0.00').format(amount.abs());
    final prefix = amount < 0 ? '-' : '';
    return '$prefix$sym $formatted';
  }

  /// Formats a compact amount (no decimals when whole number).
  static String formatCompact(double amount, String currency) {
    final sym = symbol(currency);
    final isWhole = amount == amount.truncate();
    final formatted = isWhole
        ? NumberFormat('#,##0').format(amount.abs())
        : NumberFormat('#,##0.00').format(amount.abs());
    final prefix = amount < 0 ? '-' : '';
    return '$prefix$sym$formatted';
  }

  /// Tries to parse a string as a double, returning null on failure.
  static double? tryParse(String value) {
    // Accept both comma and dot as decimal separator
    final normalized = value.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  /// Returns a color hex int for a balance amount.
  /// Positive → green, negative → red, zero → grey.
  static int balanceColor(double amount) {
    if (amount > 0) return 0xFF2E7D32;
    if (amount < 0) return 0xFFC62828;
    return 0xFF757575;
  }
}
