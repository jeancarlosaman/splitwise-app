import '../expenses/models/receipt_item.dart';

/// Result of parsing a raw OCR receipt string.
class ParsedReceipt {
  const ParsedReceipt({
    this.merchant,
    required this.items,
    this.total,
    // After the user reviews and approves:
    this.selectedItems = const [],
  });

  final String? merchant;
  final List<ReceiptItem> items;
  final double? total;

  /// Items the user chose to keep (set after ReceiptReviewScreen).
  final List<ReceiptItem> selectedItems;

  ParsedReceipt copyWith({
    String? merchant,
    List<ReceiptItem>? items,
    double? total,
    List<ReceiptItem>? selectedItems,
  }) {
    return ParsedReceipt(
      merchant:      merchant      ?? this.merchant,
      items:         items         ?? this.items,
      total:         total         ?? this.total,
      selectedItems: selectedItems ?? this.selectedItems,
    );
  }
}

/// Parses raw OCR text from a receipt into structured data.
///
/// Strategy:
///   1. Split text into lines.
///   2. Skip lines that look like headers/footers (date, address, etc.).
///   3. For each line, try to find a price pattern at the end.
///      A price-like token is defined as: optional currency symbol + digits
///      with an optional decimal part, e.g. "12.50", "€4.00", "3,90".
///   4. Extract total from lines containing "total", "sum", "subtotal", etc.
///   5. Heuristically detect merchant name from the first non-empty line.
class ReceiptParser {
  ReceiptParser._();

  // Matches prices like: 12.50  3,90  €4.00  $15  £2.99  CHF 5.00
  static final _pricePattern = RegExp(
    r'(?:€|\$|£|CHF\s*)?(\d{1,6}[.,]\d{2}|\d{1,6})\s*(?:€|\$|£)?$',
    caseSensitive: false,
  );

  // Lines containing these keywords are treated as total candidates
  static final _totalKeywords = RegExp(
    r'\b(total|totale|subtotal|sum|summe|gesamtbetrag|gesamt|montant|amount due|to pay)\b',
    caseSensitive: false,
  );

  // Lines to skip (likely not items)
  static final _skipPatterns = RegExp(
    r'^\s*(?:'
    r'\d{1,2}[./-]\d{1,2}[./-]\d{2,4}'       // dates
    r'|\d{2}:\d{2}'                             // times
    r'|tel[ephone]*\s*[:\d]'                    // phone
    r'|www\.'                                   // URLs
    r'|vat|mwst|ust|tva|tax\s*\d'              // VAT lines
    r'|thank\s+you'                             // thank-you lines
    r'|receipt\s*#'                             // receipt number
    r')\s*$',
    caseSensitive: false,
  );

  static ParsedReceipt parse(String rawText) {
    final lines   = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const ParsedReceipt(items: []);
    }

    String? merchant;
    double? total;
    final items = <ReceiptItem>[];

    // First non-skip line is treated as merchant name (heuristic)
    for (final line in lines) {
      if (!_skipPatterns.hasMatch(line) && !_pricePattern.hasMatch(line)) {
        merchant = _cleanMerchantName(line);
        break;
      }
    }

    for (final line in lines) {
      if (_skipPatterns.hasMatch(line)) continue;

      final priceMatch = _pricePattern.firstMatch(line);
      if (priceMatch == null) continue;

      final priceStr = priceMatch.group(1)!.replaceAll(',', '.');
      final price    = double.tryParse(priceStr);
      if (price == null || price <= 0 || price > 99999) continue;

      // Extract item name: everything before the price match
      final nameRaw = line
          .substring(0, priceMatch.start)
          .trim()
          .replaceAll(RegExp(r'[\.\-_]{2,}'), ' ') // remove dot leaders
          .trim();

      if (nameRaw.isEmpty) continue;

      // Is this a total line?
      if (_totalKeywords.hasMatch(line)) {
        // Keep the higher total (some receipts have subtotal then total)
        if (total == null || price > total) {
          total = price;
        }
        continue; // Don't add totals as items
      }

      // Skip lines that are almost certainly not items
      // (very short names that are just digits or single letters)
      if (nameRaw.length < 2 || RegExp(r'^\d+$').hasMatch(nameRaw)) continue;

      items.add(ReceiptItem.parsed(
        name:  _cleanItemName(nameRaw),
        price: price,
      ));
    }

    // If no explicit total found, sum items
    final computedTotal = items.fold<double>(0, (acc, i) => acc + i.price);
    final resolvedTotal = total ?? (computedTotal > 0 ? computedTotal : null);

    return ParsedReceipt(
      merchant: merchant,
      items:    items,
      total:    resolvedTotal,
    );
  }

  static String _cleanMerchantName(String raw) {
    // Remove non-letter characters from edges, collapse whitespace
    return raw
        .replaceAll(RegExp(r'^[^a-zA-Z]+'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9 &\-]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _cleanItemName(String raw) {
    // Normalize spacing, remove trailing digits that might be quantity codes
    return raw
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'\s+\d{4,}\s*$'), '') // trailing barcodes
        .trim();
  }
}
