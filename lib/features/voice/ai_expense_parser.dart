import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants.dart';

/// Structured expense extracted from a voice transcript by Claude.
class AiParsedExpense {
  final double? amount;
  final String? description;

  /// 'me' if the speaker paid, otherwise the spoken name of the payer.
  /// The caller resolves this to a user ID against the group members list.
  final String? payerName;

  /// Names of people the expense should be split with (may include the payer).
  /// Empty means "split equally among everyone in the group".
  final List<String> splitWithNames;

  /// One of: equal | exact | shares | percentage.
  /// For now the app only honors 'equal' — others are stored for future use.
  final String splitMode;

  /// Optional per-person share amounts for non-equal splits, keyed by name.
  /// For 'exact': monetary amounts. For 'shares': share counts. For 'percentage': 0-100.
  final Map<String, double> shares;

  /// 3-letter ISO currency code if the user mentioned one ("dollars", "euros"),
  /// otherwise null (UI falls back to defaultCurrency).
  final String? currency;

  /// True if Claude couldn't extract anything useful — UI should tell the user.
  final bool isEmpty;

  /// Human-readable note from Claude when something was ambiguous
  /// (e.g. "I split between Alice and Bob — assumed equal").
  final String? note;

  const AiParsedExpense({
    this.amount,
    this.description,
    this.payerName,
    this.splitWithNames = const [],
    this.splitMode = 'equal',
    this.shares = const {},
    this.currency,
    this.isEmpty = false,
    this.note,
  });

  factory AiParsedExpense.empty(String? note) =>
      AiParsedExpense(isEmpty: true, note: note);
}

/// Calls the Claude Messages API with tool use to extract structured expense
/// data from a free-form voice transcript.
///
/// Why tool use: it forces Claude to emit a JSON object matching our schema
/// instead of free-form prose we'd have to parse ourselves. The "tool" here
/// doesn't actually do anything — we just use it as a typed output channel.
class AiExpenseParser {
  static const _model = 'claude-haiku-4-5';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  /// Parses [transcript] in the context of [memberNames] (the people in the
  /// group, so Claude can match "Alice" / "my brother" to actual members).
  /// [speakerName] is the current user's display name so "I paid" resolves.
  static Future<AiParsedExpense> parse({
    required String transcript,
    required List<String> memberNames,
    required String speakerName,
    String defaultCurrency = 'EUR',
  }) async {
    if (transcript.trim().isEmpty) {
      return AiParsedExpense.empty('Empty transcript');
    }

    if (AppConstants.claudeApiKey == 'PASTE_CLAUDE_KEY_HERE' ||
        AppConstants.claudeApiKey.isEmpty) {
      return AiParsedExpense.empty(
          'Claude API key not configured — see lib/core/constants.dart');
    }

    final membersBlock = memberNames.isEmpty
        ? 'There are no other group members yet — only the speaker.'
        : 'The group members are: ${memberNames.map((n) => '"$n"').join(', ')}.';

    final systemPrompt = '''
You extract structured expense data from voice transcripts for a bill-splitting app. The transcript was produced by speech-to-text, so it may have typos, missing punctuation, or homophones (e.g. "for" vs "four"). Be tolerant.

The speaker's name is "$speakerName". When they say "I", "me", "my", "yo", "jo", they refer to themselves — set payerName="me" in that case.

$membersBlock

EXTRACTION RULES:
- amount: any number in the transcript is almost always the amount. Words like "thirty five", "treinta y cinco", "trenta-cinc" count. Strip currency symbols. If multiple numbers, pick the largest one that sounds like a total.
- description: a 1-3 word label for what was bought (dinner, groceries, taxi, sopar, comida). Infer it loosely from context. Never null unless transcript is purely numbers.
- payerName: "me" if the speaker paid (default when unstated, since most expenses are entered by the person who paid). Otherwise the EXACT member name from the list above (case-sensitive match the list).
- splitWithNames: the people the expense is split between. If the speaker says "split with X and Y", that usually means me+X+Y. If "between X and Y", that means just X+Y. If unstated, leave EMPTY — the app will default to all group members. Only include names that match a group member (case-insensitive partial match against the list, but output the exact list name).
- splitMode: almost always "equal". Use other modes only with explicit cues ("I owe 30", "Alice pays 60%").
- currency: $defaultCurrency unless explicitly stated otherwise.

BE LENIENT. If the transcript has ANY hint of an amount, description, or person, extract it. Set isEmpty=true ONLY if the transcript is purely conversational with zero expense info (e.g. "hello", "testing"). Setting isEmpty=true wastes the user's input — when in doubt, fill what you can and leave other fields null.

Always call the record_expense tool.
''';

    final tool = {
      'name': 'record_expense',
      'description':
          'Records the structured expense extracted from the user\'s spoken instruction.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'amount': {
            'type': 'number',
            'description': 'Total expense amount as a positive number, or null if not stated.',
          },
          'description': {
            'type': 'string',
            'description': 'Short label for the expense (e.g. "Dinner", "Groceries"). Null if not mentioned.',
          },
          'payerName': {
            'type': 'string',
            'description':
                'Exact group member name who paid, or "me" if the speaker paid. Null if unstated.',
          },
          'splitWithNames': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'Exact group member names the expense is split between. Empty list = split with everyone in the group.',
          },
          'splitMode': {
            'type': 'string',
            'enum': ['equal', 'exact', 'shares', 'percentage'],
            'description': 'How to divide the amount. Default "equal".',
          },
          'shares': {
            'type': 'object',
            'description':
                'For non-equal splits: map of member name -> amount/share/percent. Empty for equal split.',
            'additionalProperties': {'type': 'number'},
          },
          'currency': {
            'type': 'string',
            'description': '3-letter ISO code if the user mentioned a currency, else null.',
          },
          'isEmpty': {
            'type': 'boolean',
            'description': 'True if no useful expense info could be extracted.',
          },
          'note': {
            'type': 'string',
            'description':
                'Optional short note for the user about assumptions made or ambiguities, or null.',
          },
        },
        'required': ['isEmpty'],
      },
    };

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 512,
      'system': systemPrompt,
      'tools': [tool],
      'tool_choice': {'type': 'tool', 'name': 'record_expense'},
      'messages': [
        {
          'role': 'user',
          'content': 'Transcript: "$transcript"',
        }
      ],
    });

    try {
      debugPrint('[AiExpenseParser] sending transcript: "$transcript"');
      debugPrint(
          '[AiExpenseParser] members: ${memberNames.isEmpty ? "<none>" : memberNames.join(", ")}');
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': AppConstants.claudeApiKey,
              'anthropic-version': '2023-06-01',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      debugPrint(
          '[AiExpenseParser] HTTP ${response.statusCode}: ${response.body.length > 600 ? "${response.body.substring(0, 600)}..." : response.body}');

      if (response.statusCode == 401) {
        return AiParsedExpense.empty(
            'AI auth failed — check the Claude API key in constants.dart');
      }
      if (response.statusCode != 200) {
        // Try to surface Claude's actual error message instead of just the code.
        String detail = '';
        try {
          final err = jsonDecode(response.body) as Map<String, dynamic>;
          final inner = err['error'];
          if (inner is Map) detail = ': ${inner['message']}';
        } catch (_) {}
        return AiParsedExpense.empty(
            'AI request failed (${response.statusCode})$detail');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content = json['content'] as List<dynamic>?;
      if (content == null || content.isEmpty) {
        return AiParsedExpense.empty('AI returned no content');
      }

      // Find the tool_use block — that's where our structured data lives.
      final toolUse = content.firstWhere(
        (b) => b is Map && b['type'] == 'tool_use',
        orElse: () => null,
      );
      if (toolUse == null) {
        return AiParsedExpense.empty('AI did not produce structured output');
      }

      final input = (toolUse as Map)['input'] as Map<String, dynamic>;
      return _fromToolInput(input);
    } catch (e) {
      debugPrint('[AiExpenseParser] exception: $e');
      return AiParsedExpense.empty('AI request error: $e');
    }
  }

  static AiParsedExpense _fromToolInput(Map<String, dynamic> input) {
    final isEmpty = input['isEmpty'] == true;
    if (isEmpty) {
      return AiParsedExpense.empty(input['note'] as String?);
    }

    final rawAmount = input['amount'];
    final amount = rawAmount is num ? rawAmount.toDouble() : null;

    final rawShares = input['shares'];
    final shares = <String, double>{};
    if (rawShares is Map) {
      rawShares.forEach((k, v) {
        if (v is num) shares[k.toString()] = v.toDouble();
      });
    }

    final rawSplitWith = input['splitWithNames'];
    final splitWith = <String>[];
    if (rawSplitWith is List) {
      for (final n in rawSplitWith) {
        if (n is String && n.trim().isNotEmpty) splitWith.add(n.trim());
      }
    }

    return AiParsedExpense(
      amount: amount,
      description: input['description'] as String?,
      payerName: input['payerName'] as String?,
      splitWithNames: splitWith,
      splitMode: (input['splitMode'] as String?) ?? 'equal',
      shares: shares,
      currency: input['currency'] as String?,
      note: input['note'] as String?,
    );
  }
}
