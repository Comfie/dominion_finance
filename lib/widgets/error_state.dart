import 'package:flutter/material.dart';
import 'icon_message_card.dart';

/// Full-state error placeholder: icon + title + message + optional retry,
/// fading in once on first build. Same restrained entrance as
/// [IconMessageCard]'s other consumer, `AppEmptyState` (fade only, 200ms).
///
/// Collapses the old ErrorView/ErrorBanner/NetworkErrorView trio (all
/// unused) into one parametrized widget.
class AppErrorState extends StatefulWidget {
  const AppErrorState({
    super.key,
    this.message,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  State<AppErrorState> createState() => _AppErrorStateState();
}

class _AppErrorStateState extends State<AppErrorState>
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
        iconColor: Theme.of(context).colorScheme.error,
        title: 'Something went wrong',
        message: widget.message ?? 'An unexpected error occurred. Please try again.',
        action: widget.onRetry == null
            ? null
            : ElevatedButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
      ),
    );
  }
}
