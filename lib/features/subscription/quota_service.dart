import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/repositories/supabase_client.dart';

/// Features that count against the freemium monthly quota.
enum QuotaFeature {
  ocrScan('ocr_scan', 5, 'receipt scans'),
  voiceParse('voice_parse', 5, 'voice expense notes');

  final String code;
  final int monthlyLimit;
  final String displayPlural;
  const QuotaFeature(this.code, this.monthlyLimit, this.displayPlural);
}

/// Snapshot of a user's quota state for one feature this calendar month.
class QuotaState {
  final bool isPro;
  final int usedThisMonth;
  final int? remaining; // null = unlimited (pro)
  final bool canUse;

  const QuotaState({
    required this.isPro,
    required this.usedThisMonth,
    required this.remaining,
    required this.canUse,
  });

  factory QuotaState.fromRow(Map<String, dynamic> row) => QuotaState(
        isPro: row['is_pro'] == true,
        usedThisMonth: (row['used_this_month'] as num?)?.toInt() ?? 0,
        remaining: row['remaining'] as int?,
        canUse: row['can_use'] == true,
      );

  /// Bias-safe fallback so the UI never blocks on a transient API failure
  /// (better to let the user through than punish them for a network blip).
  factory QuotaState.allowedFallback() => const QuotaState(
      isPro: false, usedThisMonth: 0, remaining: 99, canUse: true);
}

/// Thin wrapper around the SECURITY DEFINER RPCs. Keeps all the per-feature
/// limit constants in QuotaFeature, so callers just pass an enum.
class QuotaService {
  Future<QuotaState> check(QuotaFeature feature) async {
    try {
      final res = await supabase.rpc('check_feature_quota', params: {
        'p_feature': feature.code,
        'p_monthly_limit': feature.monthlyLimit,
      });
      if (res is List && res.isNotEmpty) {
        return QuotaState.fromRow(res.first as Map<String, dynamic>);
      }
      return QuotaState.allowedFallback();
    } catch (e) {
      debugPrint('[QuotaService] check failed for ${feature.code}: $e');
      return QuotaState.allowedFallback();
    }
  }

  /// Logs a use and returns the updated quota. Call AFTER the feature
  /// successfully ran — failed/cancelled uses shouldn't count against the user.
  Future<QuotaState> record(QuotaFeature feature) async {
    try {
      final res = await supabase.rpc('record_feature_use', params: {
        'p_feature': feature.code,
        'p_monthly_limit': feature.monthlyLimit,
      });
      if (res is List && res.isNotEmpty) {
        return QuotaState.fromRow(res.first as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[QuotaService] record failed for ${feature.code}: $e');
    }
    return QuotaState.allowedFallback();
  }

  Future<void> devUpgrade() async {
    await supabase.rpc('dev_upgrade_to_pro');
  }

  Future<void> devDowngrade() async {
    await supabase.rpc('dev_downgrade_to_free');
  }
}

final quotaServiceProvider = Provider<QuotaService>((_) => QuotaService());

/// Live quota state per feature, so the UI (Profile screen + paywall) can
/// show "you've used 3/5 receipt scans this month" without manual refreshes.
final quotaStateProvider =
    FutureProvider.family<QuotaState, QuotaFeature>((ref, feature) {
  return ref.read(quotaServiceProvider).check(feature);
});
