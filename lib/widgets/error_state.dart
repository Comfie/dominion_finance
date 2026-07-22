import 'package:flutter/material.dart';
import 'icon_message_card.dart';

/// Full-state error placeholder: icon + title + message + optional retry.
///
/// Collapses the old ErrorView/ErrorBanner/NetworkErrorView trio (all
/// unused) into one parametrized widget.
class AppErrorState extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return IconMessageCard(
      icon: icon,
      iconColor: Theme.of(context).colorScheme.error,
      title: 'Something went wrong',
      message: message ?? 'An unexpected error occurred. Please try again.',
      action: onRetry == null
          ? null
          : ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
    );
  }
}
