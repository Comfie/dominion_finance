// lib/screens/settings/family_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/person.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/persons_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/cards/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/scooped_header.dart';

/// Family/Person management screen for managing family members and their budgets.
class FamilyManagementScreen extends ConsumerStatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  ConsumerState<FamilyManagementScreen> createState() =>
      _FamilyManagementScreenState();
}

class _FamilyManagementScreenState
    extends ConsumerState<FamilyManagementScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(personsProvider.notifier).loadPersons();
      ref.read(expensesProvider.notifier).loadExpenses();
    });
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(personsProvider.notifier).loadPersons(),
      ref.read(expensesProvider.notifier).loadExpenses(),
    ]);
  }

  void _showAddPersonModal() {
    showDialog(
      context: context,
      builder: (context) => const _AddPersonDialog(),
    );
  }

  void _showEditPersonModal(Person person) {
    showDialog(
      context: context,
      builder: (context) => _AddPersonDialog(person: person),
    );
  }

  Future<bool> _confirmDeletePerson(BuildContext context, String name) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Family Member'),
        content: Text(
          'Are you sure you want to delete $name? This will not delete their associated expenses or obligations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deletePerson(String id, String name) async {
    final success = await ref.read(personsProvider.notifier).deletePerson(id);
    if (mounted) {
      final colorScheme = Theme.of(context).colorScheme;
      final appColors = Theme.of(context).extension<AppColors>()!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Family member deleted'
                : 'Failed to delete family member',
          ),
          backgroundColor: success ? appColors.success : colorScheme.error,
        ),
      );
    }
  }

  double _calculatePersonSpending(String personId, List<dynamic> expenses) {
    return expenses
        .where((e) => e.personId == personId)
        .fold<double>(0, (sum, e) => sum + e.amount);
  }

  @override
  Widget build(BuildContext context) {
    final personsState = ref.watch(personsProvider);
    final expensesState = ref.watch(expensesProvider);
    final settingsState = ref.watch(settingsProvider);
    final currencySymbol = settingsState.settings?.currencySymbol ?? 'R';
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    // The teal hero draws behind the (transparent) status bar, so this
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
      body: personsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlayStyle,
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: ScoopedHeader(
                        background: colorScheme.primary,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  color: colorScheme.onPrimary,
                                  onPressed: () => context.pop(),
                                ),
                                Text(
                                  'Family',
                                  style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage family members and track their spending',
                              style: TextStyle(
                                color: colorScheme.onPrimary.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Icon(
                                  Icons.people_rounded,
                                  color: colorScheme.onPrimary.withValues(
                                    alpha: 0.7,
                                  ),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${personsState.persons.length}',
                                  style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    personsState.persons.length == 1
                                        ? 'family member'
                                        : 'family members',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (personsState.persons.isEmpty)
                            AppEmptyState(
                              icon: Icons.people_rounded,
                              title: 'No family members yet',
                              message: 'Tap + to add family members',
                            )
                          else
                            ...personsState.persons.map((person) {
                              final spending = _calculatePersonSpending(
                                person.id,
                                expensesState.expenses,
                              );
                              final budgetPercentage =
                                  person.budgetLimit != null &&
                                      person.budgetLimit! > 0
                                  ? (spending / person.budgetLimit!) * 100
                                  : 0.0;

                              return _PersonCard(
                                person: person,
                                spending: spending,
                                budgetPercentage: budgetPercentage,
                                currencySymbol: currencySymbol,
                                onTap: () => _showEditPersonModal(person),
                                onDelete: () =>
                                    _deletePerson(person.id, person.name),
                                confirmDelete: (ctx) =>
                                    _confirmDeletePerson(ctx, person.name),
                              );
                            }),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPersonModal,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final Person person;
  final double spending;
  final double budgetPercentage;
  final String currencySymbol;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Future<bool> Function(BuildContext) confirmDelete;

  const _PersonCard({
    required this.person,
    required this.spending,
    required this.budgetPercentage,
    required this.currencySymbol,
    required this.onTap,
    required this.onDelete,
    required this.confirmDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasBudget = person.budgetLimit != null && person.budgetLimit! > 0;
    final isOverBudget = hasBudget && spending > person.budgetLimit!;

    return Dismissible(
      key: Key(person.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        child: Icon(Icons.delete_rounded, color: colorScheme.onError),
      ),
      confirmDismiss: (direction) => confirmDelete(context),
      onDismissed: (direction) => onDelete(),
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    person.name[0].toUpperCase(),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasBudget
                            ? 'Budget: $currencySymbol ${person.budgetLimit!.toStringAsFixed(2)}'
                            : 'No budget set',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currencySymbol ${spending.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isOverBudget
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                    ),
                    if (hasBudget)
                      Text(
                        '${budgetPercentage.toStringAsFixed(0)}% used',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isOverBudget ? colorScheme.error : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (hasBudget) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: budgetPercentage > 100 ? 1.0 : budgetPercentage / 100,
                  minHeight: 8,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverBudget ? colorScheme.error : colorScheme.primary,
                  ),
                ),
              ),
            ],
            if (isOverBudget) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      size: 16,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Over budget by $currencySymbol ${(spending - person.budgetLimit!).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddPersonDialog extends ConsumerStatefulWidget {
  final Person? person;

  const _AddPersonDialog({this.person});

  @override
  ConsumerState<_AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends ConsumerState<_AddPersonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.person != null) {
      _nameController.text = widget.person!.name;
      if (widget.person!.budgetLimit != null) {
        _budgetController.text = widget.person!.budgetLimit.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _savePerson() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _nameController.text,
      if (_budgetController.text.isNotEmpty)
        'budgetLimit': double.parse(_budgetController.text),
    };

    final person = widget.person;
    final success = person == null
        ? await ref.read(personsProvider.notifier).createPerson(data)
        : await ref
              .read(personsProvider.notifier)
              .updatePerson(person.id, data);

    if (mounted) {
      final colorScheme = Theme.of(context).colorScheme;
      final appColors = Theme.of(context).extension<AppColors>()!;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? person == null
                      ? 'Family member added'
                      : 'Family member updated'
                : 'Failed to save family member',
          ),
          backgroundColor: success ? appColors.success : colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.person == null ? 'Add Family Member' : 'Edit Family Member',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _budgetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Budget Limit (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
                helperText: 'Set a monthly budget limit for this person',
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final budget = double.tryParse(value);
                  if (budget == null || budget <= 0) {
                    return 'Please enter a valid budget amount';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _savePerson,
          child: Text(widget.person == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
