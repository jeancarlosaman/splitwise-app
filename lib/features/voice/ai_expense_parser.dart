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

    final systemPrompt = '''
You extract structured expense data from voice transcripts for a bill-splitting app.

The speaker's name is "$speakerName". When they say "I", "me", or "my", they refer to themselves.

The group members are: ${memberNames.map((n) => '"$n"').join(', ')}.

When the user mentions a person, match their words (case-insensitive, partial OK) to one of the group member names above. Use the EXACT member name as it appears in that list. If no match is found, omit that person.

If the user says "split between X and Y" without mentioning themselves, include only X and Y. If they say "split with X and Y" they usually mean themselves + X + Y. If they don't specify who to split with, leave splitWithNames empty (the app defaults to all group members).

Default split mode is "equal". Only use "exact"/"shares"/"percentage" if the user clearly specifies non-equal splits.

Default currency is $defaultCurrency unless the user mentions another.

Always call the record_expense tool. Set isEmpty=true only if the transcript contains no useful expense info at all.
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

      if (response.statusCode != 200) {
        debugPrint('[AiExpenseParser] HTTP ${response.statusCode}: ${response.body}');
        return AiParsedExpense.empty('AI request failed (${response.statusCode})');
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
