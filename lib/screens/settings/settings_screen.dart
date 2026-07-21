import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage_mode.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final settingsState = ref.watch(settingsProvider);
    final settings = settingsState.settings;
    final storageMode = ref.watch(storageModeProvider);
    final isLocalMode = storageMode == StorageMode.local;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: 'Data storage',
            children: isLocalMode
                ? [
                    const _SettingsTile(
                      icon: Icons.smartphone_rounded,
                      title: 'Local',
                      subtitle: 'Data is stored only on this device',
                    ),
                    _SettingsTile(
                      icon: Icons.cloud_sync_rounded,
                      title: 'Switch to cloud sync (sign in)',
                      subtitle: 'Sign in to sync your data across devices',
                      onTap: () async {
                        await ref
                            .read(storageModeProvider.notifier)
                            .setMode(StorageMode.cloud);
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    ),
                  ]
                : [
                    _SettingsTile(
                      icon: Icons.cloud_rounded,
                      title: 'Cloud',
                      subtitle: authState.user?.email ?? 'Data syncs to your account',
                    ),
                  ],
          ),
          const SizedBox(height: 24),
          if (!isLocalMode) ...[
            _SettingsSection(
              title: 'Account',
              children: [
                _SettingsTile(
                  icon: Icons.person_outlined,
                  title: authState.user?.name ?? 'User',
                  subtitle: authState.user?.email ?? '',
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          _SettingsSection(
            title: 'Finances',
            children: [
              _SettingsTile(
                icon: Icons.attach_money_rounded,
                title: 'Monthly Income',
                subtitle: '${settings?.currencySymbol ?? 'R'} ${settings?.monthlyIncome.toStringAsFixed(2) ?? '0.00'}',
                onTap: () {
                  // TODO: Open income edit dialog
                },
              ),
              _SettingsTile(
                icon: Icons.calendar_today_rounded,
                title: 'Payday',
                subtitle: 'Day ${settings?.payday ?? 25} of each month',
                onTap: () {
                  // TODO: Open payday edit dialog
                },
              ),
              _SettingsTile(
                icon: Icons.money_rounded,
                title: 'Currency',
                subtitle: settings?.currency ?? 'ZAR',
                onTap: () {
                  // TODO: Open currency picker
                },
              ),
              _SettingsTile(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Monthly Budget',
                subtitle: settings?.monthlyBudget != null
                    ? '${settings?.currencySymbol ?? 'R'} ${settings?.monthlyBudget?.toStringAsFixed(2)}'
                    : 'Not set',
                onTap: () {
                  // TODO: Open budget edit dialog
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Notifications',
            children: [
              _SettingsToggle(
                icon: Icons.warning_rounded,
                title: 'Budget Alerts',
                subtitle: 'Get notified when approaching budget limit',
                value: settings?.notifyBudgetAlerts ?? true,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).updateSettings({
                    'notifyBudgetAlerts': value,
                  });
                },
              ),
              _SettingsToggle(
                icon: Icons.event_rounded,
                title: 'Upcoming Bills',
                subtitle: 'Reminders for upcoming payments',
                value: settings?.notifyUpcomingBills ?? true,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).updateSettings({
                    'notifyUpcomingBills': value,
                  });
                },
              ),
              _SettingsToggle(
                icon: Icons.celebration_rounded,
                title: 'Payday',
                subtitle: 'Get notified on payday',
                value: settings?.notifyPayday ?? true,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).updateSettings({
                    'notifyPayday': value,
                  });
                },
              ),
            ],
          ),
          if (!isLocalMode) ...[
            const SizedBox(height: 24),
            _SettingsSection(
              title: 'Account',
              children: [
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  subtitle: 'Sign out of your account',
                  iconColor: AppTheme.error,
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.error,
                            ),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppTheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted)
          : null,
      onTap: onTap,
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppTheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primary,
    );
  }
}
