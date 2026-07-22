// lib/widgets/auth_header.dart
import 'package:flutter/material.dart';
import 'scooped_header.dart';

/// Shared hero for the auth screens (Login/Register): a ScoopedHeader with
/// an icon badge, title, and subtitle. Extracted once because Dart's
/// library-private classes can't be shared between the two separate screen
/// files, and the two screens' heroes are structurally identical.
class AuthHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const AuthHeader({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ScoopedHeader(
      background: colorScheme.primary,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: colorScheme.onPrimary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(color: colorScheme.onPrimary, fontSize: 26, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.8), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
