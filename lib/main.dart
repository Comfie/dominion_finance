import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/storage_mode.dart';
import 'core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the persisted storage mode (cloud vs. local) before the first
  // frame so the router's redirect logic never flashes the login screen
  // for a user who previously chose local-only mode.
  final container = ProviderContainer();
  await container.read(storageModeProvider.notifier).load();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DominionApp(),
    ),
  );
}

class DominionApp extends ConsumerWidget {
  const DominionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Dominion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Pinned dark until enough screens have migrated off the deprecated
      // AppTheme.* consts for light mode to be presentable everywhere (see
      // docs/superpowers/specs/2026-07-21-modern-ui-redesign-phase1-design.md).
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
