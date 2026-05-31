import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Predefined expense categories with emoji + accent color, used by the
/// category picker and the personal-group "Categories" tab.
///
/// Stored in `expenses.category` as the lowercase `code`. The DB column is
/// free-text so we can add new categories without a migration — anything
/// not in this enum is bucketed as [other] in the breakdown view.
enum ExpenseCategory {
  food('food', 'Food & Drink', '🍔', AppTheme.amber),
  groceries('groceries', 'Groceries', '🛒', AppTheme.mint),
  transport('transport', 'Transport', '🚗', AppTheme.blue),
  shopping('shopping', 'Shopping', '🛍️', AppTheme.pink),
  entertainment('entertainment', 'Entertainment', '🎬', AppTheme.violet),
  bills('bills', 'Bills', '🧾', AppTheme.orange),
  health('health', 'Health', '💊', AppTheme.negative),
  travel('travel', 'Travel', '✈️', AppTheme.mintBright),
  other('other', 'Other', '💸', AppTheme.textSecondary);

  final String code;
  final String label;
  final String emoji;
  final Color color;
  const ExpenseCategory(this.code, this.label, this.emoji, this.color);

  /// Look up a category by its persisted code (case-insensitive). Returns
  /// [other] when the value is null or unknown.
  static ExpenseCategory fromCode(String? code) {
    if (code == null || code.isEmpty) return other;
    for (final c in values) {
      if (c.code == code.toLowerCase()) return c;
    }
    return other;
  }
}
