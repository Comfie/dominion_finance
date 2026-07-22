// lib/screens/insights/insights_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage_mode.dart';
import '../../core/theme.dart';
import '../../providers/insights_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/cards/app_card.dart';
import '../../widgets/charts/monthly_trend_chart.dart';
import '../../widgets/charts/spending_by_category_chart.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_skeleton.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  @override
  void initState() {
    super.initState();
    if (ref.read(storageModeProvider) == StorageMode.cloud) {
      Future.microtask(() {
        ref.read(insightsProvider.notifier).loadAll();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocalMode = ref.watch(storageModeProvider) == StorageMode.local;
    final insightsState = ref.watch(insightsProvider);
    final settingsState = ref.watch(settingsProvider);
    final currencySymbol = settingsState.settings?.currencySymbol ?? 'R';

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: isLocalMode
          ? Center(
              child: _AccountRequiredNotice(
                onSignIn: () async {
                  await ref.read(storageModeProvider.notifier).setMode(StorageMode.cloud);
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
            )
          : _InsightsBody(state: insightsState, currencySymbol: currencySymbol),
    );
  }
}

class _InsightsBody extends ConsumerWidget {
  final InsightsState state;
  final String currencySymbol;

  const _InsightsBody({required this.state, required this.currencySymbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoadingInsights || state.isLoadingAnalytics) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SummaryCardSkeleton(),
          SizedBox(height: 16),
          SummaryCardSkeleton(),
        ],
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppErrorState(
            message: state.error,
            onRetry: () => ref.read(insightsProvider.notifier).loadAll(),
          ),
        ),
      );
    }

    final insights = state.insights;
    final analytics = state.analytics;
    if (insights == null || analytics == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppEmptyState(
            icon: Icons.insights_rounded,
            title: 'No insights yet',
            message: 'Add expenses to get AI-powered insights',
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(insights.summary, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  insights.trend,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
        if (insights.highlights.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Highlights', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...insights.highlights.map(
            (highlight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  children: [
                    Icon(Icons.insights_rounded, color: colorScheme.secondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(highlight, style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (insights.recommendations.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Recommendations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...insights.recommendations.map(
            (recommendation) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Theme.of(context).extension<AppColors>()!.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(recommendation, style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SpendingByCategoryChart(
          categoryTotals: {for (final c in analytics.categoryBreakdown) c.category: c.amount},
          currencySymbol: currencySymbol,
        ),
        const SizedBox(height: 16),
        MonthlyTrendChart(trends: analytics.monthlyTrends, currencySymbol: currencySymbol),
      ],
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
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 64,
              color: Theme.of(context).textTheme.bodySmall?.color,
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
      ),
    );
  }
}
