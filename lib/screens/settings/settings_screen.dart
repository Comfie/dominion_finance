import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage_mode.dart';
import '../../core/theme.dart';
import '../../data/local/backup_io.dart';
import '../../models/settings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/goals_provider.dart';
import '../../providers/incomes_provider.dart';
import '../../providers/obligations_provider.dart';
import '../../providers/persons_provider.dart';
import '../../providers/settings_provider.dart';
import '../../repositories/repository_providers.dart';
import '../../widgets/scooped_header.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _backupIo = const BackupIo();

  @override
  void initState() {
    super.initState();
    // Mirrors the pattern used by other screens (expenses, goals, family
    // management): each screen ensures its own data is loaded on entry
    // rather than relying solely on the dashboard's initial load.
    Future.microtask(() {
      ref.read(settingsProvider.notifier).loadSettings();
    });
  }

  Future<void> _editMonthlyIncome(Settings? settings) async {
    await showDialog(
      context: context,
      builder: (context) => _EditFieldDialog(
        title: 'Monthly Income',
        label: 'Monthly Income',
        icon: Icons.attach_money_rounded,
        initialValue: settings?.monthlyIncome.toString() ?? '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) {
          if (value == null || value.trim().isEmpty)
            return 'Please enter an amount';
          final parsed = double.tryParse(value.trim());
          if (parsed == null || parsed < 0)
            return 'Please enter a valid amount';
          return null;
        },
        buildData: (value) => {'monthlyIncome': double.parse(value)},
      ),
    );
  }

  Future<void> _editPayday(Settings? settings) async {
    await showDialog(
      context: context,
      builder: (context) => _EditFieldDialog(
        title: 'Payday',
        label: 'Day of month (1-31)',
        icon: Icons.calendar_today_rounded,
        initialValue: settings?.payday.toString() ?? '',
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.trim().isEmpty)
            return 'Please enter a day';
          final parsed = int.tryParse(value.trim());
          if (parsed == null || parsed < 1 || parsed > 31) {
            return 'Enter a day between 1 and 31';
          }
          return null;
        },
        buildData: (value) => {'payday': int.parse(value)},
      ),
    );
  }

  Future<void> _editMonthlyBudget(Settings? settings) async {
    await showDialog(
      context: context,
      builder: (context) => _EditFieldDialog(
        title: 'Monthly Budget',
        label: 'Monthly Budget (optional)',
        icon: Icons.account_balance_wallet_rounded,
        initialValue: settings?.monthlyBudget?.toString() ?? '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        showClear: true,
        validator: (value) {
          if (value == null || value.trim().isEmpty) return null;
          final parsed = double.tryParse(value.trim());
          if (parsed == null || parsed < 0)
            return 'Please enter a valid amount';
          return null;
        },
        buildData: (value) => {
          'monthlyBudget': value.trim().isEmpty
              ? null
              : double.parse(value.trim()),
        },
      ),
    );
  }

  Future<void> _editCurrency(Settings? settings) async {
    await showDialog(
      context: context,
      builder: (context) =>
          _EditCurrencyDialog(currentCurrency: settings?.currency ?? 'ZAR'),
    );
  }

  Future<void> _exportData() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await ref.read(backupServiceProvider).exportJson();
      await _backupIo.shareBackup(json);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Failed to export data'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _importData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text(
          'This merges the backup into your current data. Entries with matching ids are overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await _backupIo.pickBackupJson();
      if (json == null) return;

      final result = await ref.read(backupServiceProvider).importJson(json);

      // Refresh in-memory state so the UI reflects the restored data,
      // mirroring how each screen loads its own data on entry.
      await Future.wait([
        ref.read(settingsProvider.notifier).loadSettings(),
        ref.read(expensesProvider.notifier).loadExpenses(),
        ref.read(incomesProvider.notifier).loadIncomes(),
        ref.read(obligationsProvider.notifier).loadObligations(),
        ref.read(goalsProvider.notifier).loadGoals(),
        ref.read(personsProvider.notifier).loadPersons(),
      ]);

      if (!mounted) return;
      final summary = result.imported.entries
          .where((entry) => entry.value > 0)
          .map((entry) => '${entry.value} ${entry.key}')
          .join(', ');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            summary.isEmpty ? 'Backup imported' : 'Imported $summary',
          ),
          backgroundColor: Theme.of(context).extension<AppColors>()!.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final settingsState = ref.watch(settingsProvider);
    final settings = settingsState.settings;
    final storageMode = ref.watch(storageModeProvider);
    final isLocalMode = storageMode == StorageMode.local;

    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    // The emerald hero draws behind the (transparent) status bar, so this
    // screen needs dark status icons regardless of theme brightness; the
    // other tabs' AppBars re-assert the theme's overlay style when shown.
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: appColors.surfaceElevated,
      systemNavigationBarIconBrightness:
          Theme.of(context).brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    );

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScoopedHeader(
                background: colorScheme.primary,
                child: Text(
                  'Settings',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
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
                              subtitle:
                                  'Sign in to sync your data across devices',
                              onTap: () async {
                                await ref
                                    .read(storageModeProvider.notifier)
                                    .setMode(StorageMode.cloud);
                                if (context.mounted) {
                                  context.go('/login');
                                }
                              },
                            ),
                            _SettingsTile(
                              icon: Icons.upload_file_rounded,
                              title: 'Export data',
                              subtitle: 'Save a backup of your data as JSON',
                              onTap: _exportData,
                            ),
                            _SettingsTile(
                              icon: Icons.download_rounded,
                              title: 'Import data',
                              subtitle: 'Restore from a backup file',
                              onTap: _importData,
                            ),
                          ]
                        : [
                            _SettingsTile(
                              icon: Icons.cloud_rounded,
                              title: 'Cloud',
                              subtitle:
                                  authState.user?.email ??
                                  'Data syncs to your account',
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
                        subtitle:
                            '${settings?.currencySymbol ?? 'R'} ${settings?.monthlyIncome.toStringAsFixed(2) ?? '0.00'}',
                        onTap: () => _editMonthlyIncome(settings),
                      ),
                      _SettingsTile(
                        icon: Icons.calendar_today_rounded,
                        title: 'Payday',
                        subtitle: 'Day ${settings?.payday ?? 25} of each month',
                        onTap: () => _editPayday(settings),
                      ),
                      _SettingsTile(
                        icon: Icons.money_rounded,
                        title: 'Currency',
                        subtitle: settings?.currency ?? 'ZAR',
                        onTap: () => _editCurrency(settings),
                      ),
                      _SettingsTile(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Monthly Budget',
                        subtitle: settings?.monthlyBudget != null
                            ? '${settings?.currencySymbol ?? 'R'} ${settings?.monthlyBudget?.toStringAsFixed(2)}'
                            : 'Not set',
                        onTap: () => _editMonthlyBudget(settings),
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
                          iconColor: colorScheme.error,
                          onTap: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Sign Out'),
                                content: const Text(
                                  'Are you sure you want to sign out?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.error,
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
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(children: children),
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
    final color = iconColor ?? Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: onTap != null
          ? Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).textTheme.bodySmall?.color,
            )
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
    final colorScheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: colorScheme.primary, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      value: value,
      onChanged: onChanged,
      activeThumbColor: colorScheme.primary,
    );
  }
}

/// Generic single-field edit dialog used for the simple text/number
/// settings fields (monthly income, payday, monthly budget). Saves by
/// calling [SettingsNotifier.updateSettings] and closes with a snackbar
/// reporting success/failure, mirroring `_AddPersonDialog` in
/// family_management_screen.dart.
class _EditFieldDialog extends ConsumerStatefulWidget {
  final String title;
  final String label;
  final IconData icon;
  final String initialValue;
  final TextInputType keyboardType;
  final String? Function(String?) validator;
  final Map<String, dynamic> Function(String value) buildData;
  final bool showClear;

  const _EditFieldDialog({
    required this.title,
    required this.label,
    required this.icon,
    required this.initialValue,
    required this.keyboardType,
    required this.validator,
    required this.buildData,
    this.showClear = false,
  });

  @override
  ConsumerState<_EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends ConsumerState<_EditFieldDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save({String? overrideValue}) async {
    if (overrideValue == null && !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = widget.buildData(overrideValue ?? _controller.text.trim());
    final success = await ref
        .read(settingsProvider.notifier)
        .updateSettings(data);
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${widget.title} updated'
              : 'Failed to update ${widget.title.toLowerCase()}',
        ),
        backgroundColor: success ? appColors.success : colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          keyboardType: widget.keyboardType,
          autofocus: true,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(widget.icon),
          ),
          validator: widget.validator,
        ),
      ),
      actions: [
        if (widget.showClear)
          TextButton(
            onPressed: _saving ? null : () => _save(overrideValue: ''),
            child: const Text('Clear'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : () => _save(),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Currency picker dialog. Supported currencies mirror
/// `Settings.currencySymbol` in lib/models/settings.dart.
class _EditCurrencyDialog extends ConsumerWidget {
  static const _currencies = ['ZAR', 'USD', 'EUR', 'GBP'];

  final String currentCurrency;

  const _EditCurrencyDialog({required this.currentCurrency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Currency'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: _currencies
            .map(
              (code) => ListTile(
                title: Text(code),
                trailing: code == currentCurrency
                    ? Icon(Icons.check_rounded, color: colorScheme.primary)
                    : null,
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final appColors = Theme.of(context).extension<AppColors>()!;
                  final success = await ref
                      .read(settingsProvider.notifier)
                      .updateSettings({'currency': code});
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Currency updated'
                            : 'Failed to update currency',
                      ),
                      backgroundColor: success
                          ? appColors.success
                          : colorScheme.error,
                    ),
                  );
                },
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
