import 'package:intl/intl.dart';

class CurrencyUtils {
  static String format(double amount, {String currency = 'EUR'}) {
    final formatter = NumberFormat.currency(
      symbol: _symbol(currency),
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String _symbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'CHF':
        return 'CHF ';
      default:
        return '$currency ';
    }
  }

  static List<String> get supportedCurrencies =>
      ['EUR', 'USD', 'GBP', 'CHF', 'JPY', 'CAD', 'AUD'];
}
