class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  /// Public revolut.me handle (e.g. "aliceman"). Used to build deep-link
  /// payment URLs when this user is the payee on a settlement.
  final String? revolutTag;

  /// Bizum phone (E.164, e.g. "+34600000000"). Shown as copy-able text on
  /// settlements because Bizum has no public deep-link.
  final String? bizumPhone;

  /// 'free' (default) or 'pro'. Use [isPro] which also respects [proUntil].
  final String subscriptionTier;

  /// When the pro grant lapses. Null while free, or set in the future while pro.
  final DateTime? proUntil;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.createdAt,
    this.revolutTag,
    this.bizumPhone,
    this.subscriptionTier = 'free',
    this.proUntil,
  });

  /// True while the user has an active Pro subscription (tier=pro AND
  /// expiry is in the future or unset).
  bool get isPro =>
      subscriptionTier == 'pro' &&
      (proUntil == null || proUntil!.isAfter(DateTime.now()));

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: (json['display_name'] as String?) ??
            (json['email'] as String).split('@').first,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(
            json['created_at'] as String? ?? DateTime.now().toIso8601String()),
        revolutTag: (json['revolut_tag'] as String?)?.trim().isEmpty == true
            ? null
            : json['revolut_tag'] as String?,
        bizumPhone: (json['bizum_phone'] as String?)?.trim().isEmpty == true
            ? null
            : json['bizum_phone'] as String?,
        subscriptionTier:
            (json['subscription_tier'] as String?) ?? 'free',
        proUntil: json['pro_until'] != null
            ? DateTime.parse(json['pro_until'] as String)
            : null,
      );

  bool get hasAnyPaymentMethod => revolutTag != null || bizumPhone != null;

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return displayName.substring(0, displayName.length.clamp(0, 2)).toUpperCase();
  }

  AppUser copyWith({
    String? displayName,
    String? avatarUrl,
    String? revolutTag,
    String? bizumPhone,
  }) =>
      AppUser(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt,
        revolutTag: revolutTag ?? this.revolutTag,
        bizumPhone: bizumPhone ?? this.bizumPhone,
      );
}
