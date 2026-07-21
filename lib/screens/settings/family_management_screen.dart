import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/persons_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/expenses_provider.dart';

/// Family/Person management screen for managing family members and their budgets
/// Follows SKILL.md guidelines for proper state management and widget composition
class FamilyManagementScreen extends ConsumerStatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  ConsumerState<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends ConsumerState<FamilyManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Load persons and expenses on screen init
    Future.microtask(() {
      ref.read(personsProvider.notifier).loadPersons();
      ref.read(expensesProvider.notifier).loadExpenses();
    });
  }

  /// Handle pull-to-refresh
  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(personsProvider.notifier).loadPersons(),
      ref.read(expensesProvider.notifier).loadExpenses(),
    ]);
  }

  /// Show add person modal
  void _showAddPersonModal() {
    showDialog(
      context: context,
      builder: (context) => const _AddPersonDialog(),
    );
  }

  /// Show edit person modal
  void _showEditPersonModal(dynamic person) {
    showDialog(
      context: context,
      builder: (context) => _AddPersonDialog(person: person),
    );
  }

  /// Delete person with confirmation
  Future<void> _deletePerson(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Family Member'),
        content: Text('Are you sure you want to delete $name? This will not delete their associated expenses or obligations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(personsProvider.notifier).deletePerson(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Family member deleted' : 'Failed to delete family member'),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
          ),
        );
      }
    }
  }

  /// Calculate spending for a person
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Management'),
      ),
      body: personsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Summary section
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppTheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Family Members',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage family members and track their spending',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                        const SizedBox(height: 16),
                        _SummaryCard(
                          label: 'Total Members',
                          value: '${personsState.persons.length}',
                          icon: Icons.people_rounded,
                          color: AppTheme.primary,
                        ),
                      ],
                    ),
                  ),
                  // Persons list
                  Expanded(
                    child: personsState.persons.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_rounded,
                                  size: 64,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No family members yet',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap + to add family members',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _onRefresh,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: personsState.persons.length,
                              itemBuilder: (context, index) {
                                final person = personsState.persons[index];
                                final spending = _calculatePersonSpending(
                                  person.id,
                                  expensesState.expenses,
                                );
                                final budgetPercentage = person.budgetLimit != null && person.budgetLimit! > 0
                                    ? (spending / person.budgetLimit!) * 100
                                    : 0.0;

                                return _PersonCard(
                                  person: person,
                                  spending: spending,
                                  budgetPercentage: budgetPercentage,
                                  currencySymbol: currencySymbol,
                                  onTap: () => _showEditPersonModal(person),
                                  onDelete: () => _deletePerson(person.id, person.name),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPersonModal,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }
}

/// Summary card widget
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Individual person card widget
class _PersonCard extends StatelessWidget {
  final dynamic person;
  final double spending;
  final double budgetPercentage;
  final String currencySymbol;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PersonCard({
    required this.person,
    required this.spending,
    required this.budgetPercentage,
    required this.currencySymbol,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasbudget = person.budgetLimit != null && person.budgetLimit > 0;
    final isOverBudget = hasbudget && spending > person.budgetLimit!;

    return Dismissible(
      key: Key(person.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Family Member'),
            content: Text('Are you sure you want to delete ${person.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return confirmed == true;
      },
      onDismissed: (direction) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: isOverBudget
                ? Border.all(color: AppTheme.error, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text(
                      person.name[0].toUpperCase(),
                      style: TextStyle(
                        color: AppTheme.primary,
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
                          hasbudget
                              ? 'Budget: $currencySymbol ${person.budgetLimit.toStringAsFixed(2)}'
                              : 'No budget set',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
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
                              color: isOverBudget ? AppTheme.error : AppTheme.primary,
                            ),
                      ),
                      if (hasbudget)
                        Text(
                          '${budgetPercentage.toStringAsFixed(0)}% used',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isOverBudget ? AppTheme.error : AppTheme.textMuted,
                              ),
                        ),
                    ],
                  ),
                ],
              ),
              if (hasbudget) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: budgetPercentage > 100 ? 1.0 : budgetPercentage / 100,
                    minHeight: 8,
                    backgroundColor: AppTheme.primary.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOverBudget ? AppTheme.error : AppTheme.primary,
                    ),
                  ),
                ),
              ],
              if (isOverBudget) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_rounded, size: 16, color: AppTheme.error),
                      const SizedBox(width: 6),
                      Text(
                        'Over budget by $currencySymbol ${(spending - person.budgetLimit!).toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.error,
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
      ),
    );
  }
}

/// Add/Edit person dialog
class _AddPersonDialog extends ConsumerStatefulWidget {
  final dynamic person;

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
      _nameController.text = widget.person.name;
      if (widget.person.budgetLimit != null) {
        _budgetController.text = widget.person.budgetLimit.toString();
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

    final success = widget.person == null
        ? await ref.read(personsProvider.notifier).createPerson(data)
        : await ref.read(personsProvider.notifier).updatePerson(widget.person.id, data);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? widget.person == null
                  ? 'Family member added'
                  : 'Family member updated'
              : 'Failed to save family member'),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.person == null ? 'Add Family Member' : 'Edit Family Member'),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
