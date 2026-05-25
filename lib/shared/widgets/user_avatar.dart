import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../features/auth/models/app_user.dart';

/// Circular avatar for a user. Falls back to initials when no image URL.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 20,
  });

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = _initials(user.displayName ?? user.email);

    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colorScheme.primaryContainer,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: user.avatarUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _InitialsAvatar(
              initials: initials,
              radius: radius,
            ),
          ),
        ),
      );
    }

    return _InitialsAvatar(initials: initials, radius: radius);
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.initials,
    required this.radius,
  });

  final String initials;
  final double radius;

  /// Deterministic color from initials.
  Color _color(BuildContext context) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
    ];
    final idx = initials.codeUnitAt(0) % colors.length;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _color(context).withValues(alpha: 0.18),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
          color: _color(context),
        ),
      ),
    );
  }
}

/// Stack of overlapping avatars (e.g., group member list preview).
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.users,
    this.maxVisible = 4,
    this.radius = 16,
  });

  final List<AppUser> users;
  final int maxVisible;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final visible = users.take(maxVisible).toList();
    final overflow = users.length - maxVisible;

    return SizedBox(
      width: (visible.length + (overflow > 0 ? 1 : 0)) * (radius * 1.4) + radius * 0.6,
      height: radius * 2,
      child: Stack(
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * radius * 1.4,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: UserAvatar(user: visible[i], radius: radius),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * radius * 1.4,
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$overflow',
                    style: TextStyle(
                      fontSize: radius * 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
