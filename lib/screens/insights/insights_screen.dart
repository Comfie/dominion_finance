import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage_mode.dart';
import '../../core/theme.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocalMode = ref.watch(storageModeProvider) == StorageMode.local;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Insights'),
      ),
      body: Center(
        child: isLocalMode
            ? _AccountRequiredNotice(
                onSignIn: () async {
                  await ref
                      .read(storageModeProvider.notifier)
                      .setMode(StorageMode.cloud);
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.insights_rounded,
                    size: 64,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No insights yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add expenses to get AI-powered insights',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
      ),
    );
  }
}

class _AccountRequiredNotice extends StatelessWidget {
  final VoidCallback onSignIn;

  const _AccountRequiredNotice({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'Requires an account',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Spending insights are generated via our servers and never '
            'stored. Sign in to use this feature.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onSignIn,
            child: const Text('Switch to cloud sync (sign in)'),
          ),
        ],
      ),
    );
  }
}
