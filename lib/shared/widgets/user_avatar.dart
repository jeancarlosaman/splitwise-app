import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../features/auth/models/app_user.dart';

class UserAvatar extends StatelessWidget {
  final AppUser user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 24});

  /// Deterministic colour from user ID so the same person always gets the same colour.
  Color _colorFor(String id) {
    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.teal, Colors.red, Colors.indigo, Colors.pink,
    ];
    final hash = id.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (user.avatarUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(user.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: _colorFor(user.id),
      child: Text(
        user.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
