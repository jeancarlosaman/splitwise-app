import '../expenses/models/receipt_item.dart';

class ParsedReceipt {
  final String? merchant;
  final List<ReceiptItem> items;
  final double? total;

  const ParsedReceipt({
    this.merchant,
    required this.items,
    this.total,
  });
}

/// Parses raw OCR text from a receipt into structured data.
class ReceiptParser {
  static final _pricePattern =
      RegExp(r'(\d{1,4}[.,]\d{2})', caseSensitive: false);
  static final _totalPattern =
      RegExp(r'(total|sum|subtotal|amount due|to pay)', caseSensitive: false);
  static final _ignoredLines =
      RegExp(r'(tax|vat|iva|tva|tip|gratuity|change|cash|card|visa|master)',
          caseSensitive: false);

  static ParsedReceipt parse(String rawText) {
    final lines =
        rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String? merchant;
    double? total;
    final items = <ReceiptItem>[];

    // Heuristic: merchant is usually the first non-empty line before any prices appear
    for (final line in lines) {
      if (!_pricePattern.hasMatch(line)) {
        merchant = line;
        break;
      }
    }

    for (final line in lines) {
      if (_ignoredLines.hasMatch(line)) continue;

      final priceMatch = _pricePattern.firstMatch(line);
      if (priceMatch == null) continue;

      final priceStr =
          priceMatch.group(1)!.replaceAll(',', '.');
      final price = double.tryParse(priceStr);
      if (price == null || price <= 0 || price > 9999) continue;

      if (_totalPattern.hasMatch(line)) {
        // This line looks like a total
        total = price;
        continue;
      }

      // Extract item name: everything before the price match
      var name = line.substring(0, priceMatch.start).trim();
      // Remove trailing special characters
      name = name.replaceAll(RegExp(r'[.\-_*]+$'), '').trim();
      if (name.isEmpty) name = 'Item';

      items.add(ReceiptItem(name: name, price: price));
    }

    // If no explicit total found, sum items
    if (total == null && items.isNotEmpty) {
      total = items.fold<double>(0.0, (sum, item) => sum + item.price);
    }

    return ParsedReceipt(merchant: merchant, items: items, total: total);
  }
}
