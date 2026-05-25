import '../groups/models/group_member.dart';

/// Result of parsing a voice transcript into expense fields.
class ParsedExpense {
  const ParsedExpense({
    this.amount,
    this.description,
    this.payerUserId,
    this.participantUserIds = const [],
  });

  final double? amount;
  final String? description;

  /// User ID of the person who paid (if detected).
  final String? payerUserId;

  /// User IDs of people to split with (if detected).
  final List<String> participantUserIds;

  @override
  String toString() => 'ParsedExpense(amount: $amount, '
      'desc: $description, payer: $payerUserId, '
      'participants: $participantUserIds)';
}

/// Parses a voice transcript into structured expense fields.
///
/// Examples handled:
///   "thirty euros for pizza"             → amount: 30, desc: pizza
///   "I paid 45.50 for groceries"         → amount: 45.50, payer: currentUser
///   "John paid 120 euros for the hotel"  → amount: 120, payer: john
///   "fifteen dollars split with Anna"    → amount: 15, participants: [anna]
///   "between me and Sarah, €60 dinner"   → amount: 60, participants: [me, sarah]
class ExpenseNlpParser {
  ExpenseNlpParser._();

  // ─────────────────────────────────────────
  // Patterns
  // ─────────────────────────────────────────

  // Numeric amount with optional currency symbol
  static final _numericAmountPattern = RegExp(
    r'(?:€|\$|£|eur(?:os?)?|usd|gbp|chf)?\s*'
    r'(\d{1,6}(?:[.,]\d{1,2})?)'
    r'\s*(?:€|\$|£|euros?|dollars?|pounds?|chf|bucks?)?',
    caseSensitive: false,
  );

  // "I paid" / "I spent"
  static final _selfPayerPattern = RegExp(
    r'\b(i\s+(?:paid|spent|covered)|my\s+treat)\b',
    caseSensitive: false,
  );

  // "Name paid" — matches first word before "paid"
  static final _namedPayerPattern = RegExp(
    r'\b([A-Z][a-z]{1,20})\s+(?:paid|spent|covered)\b',
    caseSensitive: false,
  );

  // "paid by Name"
  static final _paidByPattern = RegExp(
    r'\bpaid\s+by\s+([A-Z][a-z]{1,20})\b',
    caseSensitive: false,
  );

  // "split with", "between", "for" + names
  static final _splitWithPattern = RegExp(
    r'\b(?:split\s+with|between|for)\s+((?:[A-Z][a-z]{1,20}(?:\s+and\s+|\s*,\s*)?)+)',
    caseSensitive: false,
  );

  // Words to drop when building description
  static final _noiseWords = {
    'i', 'paid', 'spent', 'covered', 'for', 'the', 'a', 'an',
    'and', 'with', 'split', 'between', 'by', 'euros', 'euro',
    'dollars', 'dollar', 'pounds', 'pound', 'bucks', 'chf',
    'me', 'my', 'treat',
  };

  // Word-to-number for common English number words
  static const _wordNumbers = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
    'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
    'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13,
    'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
    'eighteen': 18, 'nineteen': 19, 'twenty': 20, 'thirty': 30,
    'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70,
    'eighty': 80, 'ninety': 90, 'hundred': 100,
  };

  // ─────────────────────────────────────────
  // Main entry point
  // ─────────────────────────────────────────

  static ParsedExpense parse({
    required String transcript,
    required List<GroupMember> members,
    String? currentUserId,
  }) {
    final text = transcript.trim();
    if (text.isEmpty) return const ParsedExpense();

    double? amount       = _extractAmount(text);
    String? payerUserId  = _extractPayer(text, members, currentUserId);
    List<String> splits  = _extractParticipants(text, members, currentUserId);
    String? description  = _extractDescription(text, amount);

    return ParsedExpense(
      amount:             amount,
      description:        description,
      payerUserId:        payerUserId,
      participantUserIds: splits,
    );
  }

  // ─────────────────────────────────────────
  // Amount extraction
  // ─────────────────────────────────────────

  static double? _extractAmount(String text) {
    // Try word-based number first (e.g. "thirty euros")
    final wordAmount = _extractWordNumber(text);
    if (wordAmount != null) return wordAmount;

    // Try numeric pattern
    final match = _numericAmountPattern.firstMatch(text);
    if (match != null) {
      final raw = match.group(1)!.replaceAll(',', '.');
      return double.tryParse(raw);
    }
    return null;
  }

  static double? _extractWordNumber(String text) {
    final words  = text.toLowerCase().split(RegExp(r'\s+'));
    double total = 0;
    bool   found = false;

    for (int i = 0; i < words.length; i++) {
      final word = words[i].replaceAll(RegExp(r'[^a-z]'), '');
      final val  = _wordNumbers[word];
      if (val != null) {
        found = true;
        if (word == 'hundred') {
          // "two hundred" → 200
          total = total == 0 ? 100 : total * 100;
        } else {
          total += val;
        }
      } else if (found) {
        // Stop at first non-number word after finding numbers
        break;
      }
    }

    return found && total > 0 ? total : null;
  }

  // ─────────────────────────────────────────
  // Payer extraction
  // ─────────────────────────────────────────

  static String? _extractPayer(
    String text,
    List<GroupMember> members,
    String? currentUserId,
  ) {
    // "I paid" → current user
    if (_selfPayerPattern.hasMatch(text)) return currentUserId;

    // "paid by Name" → find member
    final paidByMatch = _paidByPattern.firstMatch(text);
    if (paidByMatch != null) {
      final name = paidByMatch.group(1)!;
      return _findMemberByName(name, members)?.user.id;
    }

    // "Name paid" → find member
    final namedMatch = _namedPayerPattern.firstMatch(text);
    if (namedMatch != null) {
      final name = namedMatch.group(1)!;
      return _findMemberByName(name, members)?.user.id;
    }

    return null;
  }

  // ─────────────────────────────────────────
  // Participant extraction
  // ─────────────────────────────────────────

  static List<String> _extractParticipants(
    String text,
    List<GroupMember> members,
    String? currentUserId,
  ) {
    final match = _splitWithPattern.firstMatch(text);
    if (match == null) return [];

    final namesText = match.group(1)!;
    final names = namesText
        .split(RegExp(r'\s+and\s+|\s*,\s*'))
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    final ids = <String>[];
    for (final name in names) {
      if (name.toLowerCase() == 'me' && currentUserId != null) {
        ids.add(currentUserId);
      } else {
        final member = _findMemberByName(name, members);
        if (member != null) ids.add(member.user.id);
      }
    }
    return ids;
  }

  // ─────────────────────────────────────────
  // Description extraction
  // ─────────────────────────────────────────

  static String? _extractDescription(String text, double? amount) {
    // Remove amount tokens
    String cleaned = text;
    if (amount != null) {
      cleaned = cleaned.replaceAll(_numericAmountPattern, ' ');
      cleaned = _removeWordNumbers(cleaned, amount);
    }

    // Remove payer patterns
    cleaned = cleaned
        .replaceAll(_selfPayerPattern, ' ')
        .replaceAll(_namedPayerPattern, ' ')
        .replaceAll(_paidByPattern, ' ')
        .replaceAll(_splitWithPattern, ' ');

    // Remove noise words and clean up
    final words = cleaned
        .split(RegExp(r'\s+'))
        .map((w) => w.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''))
        .where((w) => w.length > 1 && !_noiseWords.contains(w))
        .toList();

    if (words.isEmpty) return null;

    // Capitalize first word
    final desc = words.join(' ');
    return desc[0].toUpperCase() + desc.substring(1);
  }

  static String _removeWordNumbers(String text, double amount) {
    // Remove matched word-number sequences
    for (final word in _wordNumbers.keys) {
      text = text.replaceAll(RegExp(r'\b' + word + r'\b', caseSensitive: false), '');
    }
    return text;
  }

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────

  static GroupMember? _findMemberByName(
    String name,
    List<GroupMember> members,
  ) {
    final lower = name.toLowerCase();
    for (final m in members) {
      final displayName  = (m.user.displayName ?? '').toLowerCase();
      final emailPrefix  = m.user.email.split('@').first.toLowerCase();

      if (displayName == lower ||
          displayName.startsWith(lower) ||
          emailPrefix == lower ||
          emailPrefix.startsWith(lower)) {
        return m;
      }
    }
    return null;
  }
}
