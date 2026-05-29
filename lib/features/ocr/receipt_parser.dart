import '../expenses/models/receipt_item.dart';

class ParsedReceipt {
  final String? merchant;
  final List<ReceiptItem> items;
  final double? total;

  const ParsedReceipt({this.merchant, required this.items, this.total});
}

/// Parses raw OCR text from a receipt into structured data.
/// Handles various receipt formats: European (comma decimal), US (dot decimal),
/// items with quantity prefixes, and various total line formats.
class ReceiptParser {
  // Matches prices like: 1.99  12,50  1,234.56  €4.00  $3.50
  static final _pricePattern = RegExp(
    r'(?:[$€£¥])?\s*(\d{1,4}(?:[.,]\d{3})*[.,]\d{2})',
    caseSensitive: false,
  );

  static final _totalPattern = RegExp(
    r'\b(total|sum|subtotal|sub-total|amount\s*due|to\s*pay|zu\s*zahlen|'
    r'totale|montant|importe|gesamtbetrag|gesamt|summe)\b',
    caseSensitive: false,
  );

  static final _skipPattern = RegExp(
    r'\b(tax|tva|iva|mwst|vat|tip|gratuity|service\s*charge|'
    r'change|cash|card|visa|mastercard|amex|paypal|'
    r'tel|phone|fax|www|http|email|table|order|server|cashier|'
    r'thank\s*you|receipt|invoice)\b',
    caseSensitive: false,
  );

  // Quantity prefix: "2x", "3 x", "2 @"
  static final _qtyPattern = RegExp(r'^\s*(\d+)\s*[x@×]\s*', caseSensitive: false);

  static ParsedReceipt parse(String rawText) {
    if (rawText.trim().isEmpty) return const ParsedReceipt(items: []);

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? merchant;
    double? total;
    final items = <ReceiptItem>[];

    // Merchant: first non-empty line that has no price and is reasonably short
    for (final line in lines) {
      if (!_pricePattern.hasMatch(line) && line.length < 60) {
        merchant = line.replaceAll(RegExp(r'[^a-zA-Z0-9\s&\'\-]'), '').trim();
        if (merchant.isNotEmpty) break;
      }
    }

    for (final line in lines) {
      // Skip noise lines
      if (_skipPattern.hasMatch(line)) continue;
      if (line.length < 3) continue;

      final priceMatch = _pricePattern.firstMatch(line);
      if (priceMatch == null) continue;

      // Parse the price value — handle both comma and dot as decimal separator
      final raw = priceMatch.group(1)!;
      final price = _parsePrice(raw);
      if (price == null || price <= 0 || price > 9999) continue;

      // Check if this looks like a total line
      if (_totalPattern.hasMatch(line)) {
        // Keep highest total found (in case running total appears multiple times)
        if (total == null || price > total) total = price;
        continue;
      }

      // Extract item name: everything before the price match, strip qty prefix
      var name = line.substring(0, priceMatch.start).trim();
      name = name.replaceAll(RegExp(r'[.\-_*·•]+$'), '').trim(); // trailing dots
      name = name.replaceAll(_qtyPattern, '').trim();             // "2x " prefix
      name = name.replaceAll(RegExp(r'\s{2,}'), ' ');             // collapse spaces

      if (name.length < 2) name = 'Item';
      if (name.length > 50) name = name.substring(0, 50).trim();

      // Avoid adding the same line twice (some OCR engines duplicate)
      final alreadyAdded = items.any((e) =>
          e.name.toLowerCase() == name.toLowerCase() &&
          (e.price - price).abs() < 0.01);
      if (!alreadyAdded) {
        items.add(ReceiptItem(name: name, price: price));
      }
    }

    // Fallback: sum items if no explicit total
    if (total == null && items.isNotEmpty) {
      total = items.fold<double>(0.0, (s, e) => s + e.price);
    }

    return ParsedReceipt(merchant: merchant, items: items, total: total);
  }

  /// Parse a price string that may use comma or dot as decimal separator.
  static double? _parsePrice(String raw) {
    final s = raw.trim();
    // If both separators present: whichever comes last is the decimal
    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');

    String normalized;
    if (lastDot > lastComma) {
      // dot is decimal: remove commas (thousands), keep dot
      normalized = s.replaceAll(',', '');
    } else if (lastComma > lastDot) {
      // comma is decimal: remove dots (thousands), replace comma with dot
      normalized = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // only one separator type or none
      normalized = s.replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }
}
