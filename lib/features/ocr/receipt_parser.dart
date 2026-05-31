import 'package:flutter/foundation.dart';

import '../expenses/models/receipt_item.dart';

class ParsedReceipt {
  final String? merchant;
  final List<ReceiptItem> items;
  final double? total;

  /// Raw ML Kit recognized text, kept so the review UI can show it in a
  /// debug panel when item-name extraction fails. Pasting this back lets us
  /// figure out which receipt format we're missing.
  final String rawText;

  const ParsedReceipt({
    this.merchant,
    required this.items,
    this.total,
    this.rawText = '',
  });

  /// How many items came out with a useful name vs the "Item" fallback.
  /// 0 means total fallback — likely a parser bug for this receipt format.
  int get namedItemCount =>
      items.where((i) => i.name.toLowerCase() != 'item').length;
}

/// Parses raw OCR text from a receipt into structured data.
///
/// Handles:
///   - European (comma decimal) and US (dot decimal) prices
///   - Items with quantity prefixes ("2x", "3 @")
///   - Receipts where the price is on a separate line from the item name
///     (common in Catalan/Spanish thermal-printed receipts)
///   - Multilingual keywords for total/skip detection
///     (English, Spanish, Catalan, French, German, Italian, Portuguese)
class ReceiptParser {
  // Matches prices like: 1.99  12,50  1,234.56  €4.00  $3.50
  // The price must have a decimal portion to avoid matching dates ("23/05/2024")
  // or quantities ("2") as prices.
  static final _pricePattern = RegExp(
    r'(?:[$€£¥])?\s*(\d{1,4}(?:[.,]\d{3})*[.,]\d{2})\s*(?:[$€£¥]|EUR|USD|GBP)?',
    caseSensitive: false,
  );

  /// True if a line contains ONLY a price (and optional currency symbol).
  /// On Catalan/Spanish receipts, items often look like:
  ///   Pa amb tomàquet
  ///   4,50 €
  /// — so we pair these with the previous text-only line.
  static final _priceOnlyLine = RegExp(
    r'^\s*(?:[$€£¥])?\s*\d{1,4}(?:[.,]\d{3})*[.,]\d{2}\s*(?:[$€£¥]|EUR|USD|GBP)?\s*$',
    caseSensitive: false,
  );

  // Total / subtotal indicators across languages.
  //   en: total, subtotal, amount due, to pay
  //   es: total, subtotal, importe, total a pagar
  //   ca: total, subtotal, import, import total, a pagar
  //   fr: total, montant, à payer
  //   de: gesamt, gesamtbetrag, summe, zu zahlen
  //   it: totale, subtotale, importo
  //   pt: total, importância
  static final _totalPattern = RegExp(
    r'\b('
    r'total|subtotal|sub-total|grand\s*total|'
    r'amount\s*due|to\s*pay|a\s*pagar|à\s*payer|zu\s*zahlen|'
    r'importe|importo|import|imp\.|'
    r'totale|subtotale|montant|gesamtbetrag|gesamt|summe|importancia'
    r')\b',
    caseSensitive: false,
    unicode: true,
  );

  // Lines to skip entirely — taxes, payment methods, store metadata, footers.
  //   en: tax, vat, tip, gratuity, service, change, cash, card, thank you, receipt
  //   es: iva, efectivo, tarjeta, cambio, propina, gracias, factura, recibo
  //   ca: iva, efectiu, targeta, canvi, propina, gràcies, factura, rebut
  //   fr: tva, espèces, carte, monnaie, merci
  //   de: mwst, bar, karte, wechselgeld, danke
  //   it: iva, contanti, carta, resto, grazie
  // Plus contact info, dates, times, table numbers.
  static final _skipPattern = RegExp(
    r'\b('
    // Taxes & tips
    r'tax|tva|iva|mwst|vat|tip|gratuity|propina|service\s*charge|servei|'
    // Payment
    r'change|cash|card|efectiu|efectivo|targeta|tarjeta|carta|bar|espèces|contanti|monnaie|wechselgeld|resto|canvi|cambio|'
    r'visa|mastercard|amex|paypal|bizum|'
    // Store metadata / footer
    r'tel\.?|phone|fax|www\.|http|email|table|taula|mesa|order|comanda|server|cashier|caja|caixa|'
    r'thank|thanks|gracias|gràcies|merci|danke|grazie|obrigado|'
    r'receipt|invoice|factura|rebut|ticket|tique?t|'
    // CIF / NIF / tax IDs
    r'cif|nif|nie|c\.?i\.?f\.?|n\.?i\.?f\.?|'
    // Operator / employee
    r'operador|operadora|cajero|cajera|cambrer|cambrera|empleado'
    r')\b',
    caseSensitive: false,
    unicode: true,
  );

  // Quantity prefix: "2x", "3 x", "2 @", "2 ud"
  static final _qtyPattern = RegExp(
    r'^\s*(\d+)\s*(?:[x@×]|ud\.?|uds\.?|u\.?)\s*',
    caseSensitive: false,
  );

  /// Looks like a date / time / phone number / id rather than a useful item.
  static final _isNoisyMetadata = RegExp(
    r'^\s*[\d/:.\-\s]+\s*$|^\s*\d{2}[/.\-]\d{2}[/.\-]\d{2,4}\s*$',
  );

  static ParsedReceipt parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return ParsedReceipt(items: const [], rawText: rawText);
    }
    debugPrint('[ReceiptParser] === RAW OCR TEXT ===\n$rawText\n=== END ===');

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? merchant;
    double? total;
    final items = <ReceiptItem>[];

    // Merchant: first non-empty line that has no price and is reasonably short.
    // Allow accented chars (à, ñ, ü, etc.) since merchant names commonly include them.
    for (final line in lines) {
      if (!_pricePattern.hasMatch(line) && line.length < 60) {
        final cleaned = line
            .replaceAll(RegExp(r"[^\p{L}\p{N}\s&'\-]", unicode: true), '')
            .trim();
        if (cleaned.isNotEmpty && cleaned.length >= 2) {
          merchant = cleaned;
          break;
        }
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Skip noise lines
      if (_skipPattern.hasMatch(line)) continue;
      if (line.length < 2) continue;
      if (_isNoisyMetadata.hasMatch(line)) continue;

      final priceMatch = _pricePattern.firstMatch(line);
      if (priceMatch == null) continue;

      final raw = priceMatch.group(1)!;
      final price = _parsePrice(raw);
      if (price == null || price <= 0 || price > 9999) continue;

      // Check if this line is a total / subtotal marker
      if (_totalPattern.hasMatch(line)) {
        if (total == null || price > total) total = price;
        continue;
      }

      // Extract item name. Try in order:
      //   1. Text before the price on the same line ("BAGUETTE 2,50").
      //   2. Text after the price on the same line ("2,50 BAGUETTE").
      //   3. If the line is JUST a price, look at neighbouring lines —
      //      backward first (most common: name above its price), then
      //      forward (some receipts put price BEFORE the name on the next line).
      String name = '';
      final beforeText = line.substring(0, priceMatch.start).trim();
      final afterText = line.substring(priceMatch.end).trim();

      if (_priceOnlyLine.hasMatch(line)) {
        name = _findItemNameNearby(lines, i, items, merchant);
      } else if (beforeText.length >= 2 && !_isJustQty(beforeText)) {
        name = beforeText;
      } else if (afterText.length >= 2 && !_isJustQty(afterText)) {
        // Price-before-name layout. Some Spanish thermal printers do this.
        name = afterText;
      } else {
        // Single character or qty marker on the same line — fall back to
        // neighbouring lines too. Better than emitting "Item".
        name = _findItemNameNearby(lines, i, items, merchant);
      }

      name = _cleanItemName(name);

      // Final fallback only if we genuinely have nothing.
      if (name.isEmpty || name.length < 2) name = 'Item';
      if (name.length > 50) name = name.substring(0, 50).trim();

      debugPrint(
          '[ReceiptParser] line="$line" price=$price name="$name"');

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

    debugPrint(
        '[ReceiptParser] DONE — ${items.length} items, ${items.where((i) => i.name.toLowerCase() != "item").length} named, total=$total');
    return ParsedReceipt(
        merchant: merchant, items: items, total: total, rawText: rawText);
  }

  /// True if the line is just a number / quantity marker like "1", "2 ud",
  /// "3x" — should NOT be used as an item name.
  static bool _isJustQty(String s) {
    final t = s.trim();
    if (RegExp(r'^\d+\s*(x|ud\.?|uds\.?|u\.?)?$', caseSensitive: false)
        .hasMatch(t)) {
      return true;
    }
    return false;
  }

  /// Searches both directions from [priceLineIndex] looking for a line
  /// that looks like an item description (text, no price, not noise, not
  /// the merchant, not already consumed). Backward is preferred (the most
  /// common multi-line receipt layout puts the price under its item name).
  static String _findItemNameNearby(
    List<String> lines,
    int priceLineIndex,
    List<ReceiptItem> existingItems,
    String? merchant,
  ) {
    bool isCandidate(String candidate) {
      if (candidate.isEmpty) return false;
      if (_pricePattern.hasMatch(candidate)) return false;
      if (_skipPattern.hasMatch(candidate)) return false;
      if (_isNoisyMetadata.hasMatch(candidate)) return false;
      if (_isJustQty(candidate)) return false;
      if (merchant != null &&
          candidate.toLowerCase() == merchant.toLowerCase()) {
        return false;
      }
      if (existingItems.any((e) =>
          e.name.toLowerCase() == _cleanItemName(candidate).toLowerCase())) {
        return false;
      }
      return true;
    }

    // Backward — up to 3 lines back.
    for (int j = priceLineIndex - 1;
        j >= 0 && j >= priceLineIndex - 3;
        j--) {
      final candidate = lines[j].trim();
      if (isCandidate(candidate)) return candidate;
    }
    // Forward — up to 2 lines ahead, for receipts where the price prints
    // before the item description on the next line.
    for (int j = priceLineIndex + 1;
        j < lines.length && j <= priceLineIndex + 2;
        j++) {
      final candidate = lines[j].trim();
      if (isCandidate(candidate)) return candidate;
    }
    return '';
  }

  static String _cleanItemName(String raw) {
    var name = raw.trim();
    name = name.replaceAll(RegExp(r'[.\-_*·•]+$'), '').trim(); // trailing dots
    name = name.replaceAll(_qtyPattern, '').trim(); // "2x " prefix
    name = name.replaceAll(RegExp(r'\s{2,}'), ' '); // collapse spaces
    return name;
  }

  /// Parse a price string that may use comma or dot as decimal separator.
  static double? _parsePrice(String raw) {
    final s = raw.trim();
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
      normalized = s.replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }
}
