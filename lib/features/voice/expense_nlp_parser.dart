/// Parses a voice transcript into expense field suggestions.
class ParsedVoiceExpense {
  final double? amount;
  final String? description;
  final String? payerName; // display name hint, not ID
  final List<String> splitWithNames;

  const ParsedVoiceExpense({
    this.amount,
    this.description,
    this.payerName,
    this.splitWithNames = const [],
  });

  bool get hasData => amount != null || description != null;
}

class ExpenseNlpParser {
  // ── Amount extraction ─────────────────────────────────────────────────────
  static final _numericAmount = RegExp(
    r'(€|\$|£|EUR|USD|GBP)?\s*(\d{1,5}(?:[.,]\d{1,2})?)\s*(euros?|dollars?|pounds?|bucks?)?',
    caseSensitive: false,
  );

  static final _wordNumbers = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
    'nineteen': 19, 'twenty': 20, 'thirty': 30, 'forty': 40,
    'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80,
    'ninety': 90, 'hundred': 100,
  };

  // ── Payer patterns ────────────────────────────────────────────────────────
  static final _iPayedPattern =
      RegExp(r'\b(i|me)\s+(paid|spent|bought)', caseSensitive: false);
  static final _namePayedPattern =
      RegExp(r'\b(\w+)\s+paid\b', caseSensitive: false);
  static final _paidByPattern =
      RegExp(r'paid\s+by\s+(\w+)', caseSensitive: false);

  // ── Split patterns ────────────────────────────────────────────────────────
  static final _splitPattern = RegExp(
    r'split\s+with\s+([\w,\s]+)|between\s+([\w,\s]+)|for\s+([\w,\s]+)',
    caseSensitive: false,
  );

  // ── Noise words ──────────────────────────────────────────────────────────
  static final _noiseWords = {
    'i', 'me', 'we', 'paid', 'spent', 'bought', 'cost', 'costs',
    'for', 'at', 'the', 'a', 'an', 'and', 'with', 'split', 'between',
    'euros', 'euro', 'dollars', 'dollar', 'pounds', 'pound', 'bucks',
    'by', 'was', 'is', 'it',
  };

  static ParsedVoiceExpense parse(String transcript) {
    final lower = transcript.toLowerCase();
    final words = lower.split(RegExp(r'\s+'));

    // 1. Try numeric amount first
    double? amount;
    int? amountStart;
    int? amountEnd;

    final numMatch = _numericAmount.firstMatch(transcript);
    if (numMatch != null) {
      final raw = numMatch.group(2)!.replaceAll(',', '.');
      amount = double.tryParse(raw);
      amountStart = numMatch.start;
      amountEnd = numMatch.end;
    }

    // 2. Fallback: word-to-number (e.g. "thirty five euros")
    if (amount == null) {
      amount = _extractWordAmount(words);
    }

    // 3. Payer
    String? payerName;
    if (_iPayedPattern.hasMatch(lower)) {
      payerName = 'me'; // caller resolves to current user
    } else {
      final nameMatch = _namePayedPattern.firstMatch(lower) ??
          _paidByPattern.firstMatch(lower);
      if (nameMatch != null) {
        payerName = nameMatch.group(1);
      }
    }

    // 4. Split participants
    final splitNames = <String>[];
    final splitMatch = _splitPattern.firstMatch(lower);
    if (splitMatch != null) {
      final rawNames =
          (splitMatch.group(1) ?? splitMatch.group(2) ?? splitMatch.group(3) ?? '')
              .split(RegExp(r'[,\s]+'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty && !_noiseWords.contains(s))
              .toList();
      splitNames.addAll(rawNames);
    }

    // 5. Description: leftover words after removing amount/payer/split tokens
    final descWords = <String>[];
    for (final word in words) {
      if (_noiseWords.contains(word)) continue;
      if (_wordNumbers.containsKey(word)) continue;
      if (word == payerName?.toLowerCase()) continue;
      if (splitNames.contains(word)) continue;
      if (RegExp(r'^\d').hasMatch(word)) continue;
      descWords.add(word);
    }
    final description = descWords.take(5).join(' ');

    return ParsedVoiceExpense(
      amount: amount,
      description: description.isEmpty ? null : _capitalize(description),
      payerName: payerName,
      splitWithNames: splitNames,
    );
  }

  static double? _extractWordAmount(List<String> words) {
    double total = 0;
    bool found = false;
    for (int i = 0; i < words.length; i++) {
      final val = _wordNumbers[words[i]];
      if (val != null) {
        found = true;
        if (val == 100 && total > 0) {
          total *= 100;
        } else {
          total += val;
        }
      }
    }
    return found ? total : null;
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
