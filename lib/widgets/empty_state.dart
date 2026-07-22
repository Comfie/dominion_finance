import 'package:flutter/material.dart';
import 'icon_message_card.dart';

/// Empty-list placeholder: icon + title + message, fading in once on first
/// build. Deliberately restrained (fade only, 200ms) — a busy entrance on
/// every empty list would read as trying too hard, not premium.
class AppEmptyState extends StatefulWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  State<AppEmptyState> createState() => _AppEmptyStateState();
}

class _AppEmptyStateState extends State<AppEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: IconMessageCard(
        icon: widget.icon,
        iconColor: Theme.of(context).textTheme.bodySmall?.color ??
            Theme.of(context).colorScheme.onSurface,
        title: widget.title,
        message: widget.message,
        action: widget.action,
      ),
    );
  }
}
