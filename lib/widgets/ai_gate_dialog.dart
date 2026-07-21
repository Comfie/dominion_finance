import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/storage_mode.dart';
import '../core/theme.dart';

/// Shows a notice explaining that an AI feature (receipt scanning, spending
/// insights) requires an account, since it's processed via the remote API.
/// Offers a way to switch to cloud sync and sign in, or dismiss.
Future<void> showAiGateDialog(
  BuildContext context,
  WidgetRef ref, {
  String message = 'Requires an account — receipt data is processed via '
      'our servers and never stored.',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Account required'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Not now'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await ref.read(storageModeProvider.notifier).setMode(StorageMode.cloud);
            if (context.mounted) {
              context.go('/login');
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          child: const Text('Sign In'),
        ),
      ],
    ),
  );
}
