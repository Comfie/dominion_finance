import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/obligation.dart';
import '../../providers/obligations_provider.dart';
import '../../providers/persons_provider.dart';

class AddObligationModal extends ConsumerStatefulWidget {
  final Obligation? obligation;

  const AddObligationModal({super.key, this.obligation});

  @override
  ConsumerState<AddObligationModal> createState() => _AddObligationModalState();
}

class _AddObligationModalState extends ConsumerState<AddObligationModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _providerController = TextEditingController();
  final _amountController = TextEditingController();
  final _balanceController = TextEditingController();
  final _interestController = TextEditingController();
  final _notesController = TextEditingController();
  Category _selectedCategory = Category.OTHER;
  int _debitOrderDate = 1;
  bool _isUncompromised = true;
  String? _selectedPersonId;
  bool _isLoading = false;
  bool _hasDebt = false;

  bool get isEditing => widget.obligation != null;

  @override
  void initState() {
    super.initState();
    if (widget.obligation != null) {
      _nameController.text = widget.obligation!.name;
      _providerController.text = widget.obligation!.provider;
      _amountController.text = widget.obligation!.amount.toStringAsFixed(2);
      _notesController.text = widget.obligation!.notes ?? '';
      _selectedCategory = widget.obligation!.category;
      _debitOrderDate = widget.obligation!.debitOrderDate;
      _isUncompromised = widget.obligation!.isUncompromised;
      _selectedPersonId = widget.obligation!.personId;
      if (widget.obligation!.totalBalance != null) {
        _hasDebt = true;
        _balanceController.text = widget.obligation!.totalBalance!.toStringAsFixed(2);
        if (widget.obligation!.interestRate != null) {
          _interestController.text = widget.obligation!.interestRate!.toStringAsFixed(2);
        }
      }
    }
    Future.microtask(() {
      ref.read(personsProvider.notifier).loadPersons();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _providerController.dispose();
    _amountController.dispose();
    _balanceController.dispose();
    _interestController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'name': _nameController.text.trim(),
      'provider': _providerController.text.trim(),
      'amount': double.parse(_amountController.text),
      'category': _selectedCategory.name,
      'debitOrderDate': _debitOrderDate,
      'isUncompromised': _isUncompromised,
      if (_hasDebt && _balanceController.text.isNotEmpty)
        'totalBalance': double.parse(_balanceController.text),
      if (_hasDebt && _interestController.text.isNotEmpty)
        'interestRate': double.parse(_interestController.text),
      if (_selectedPersonId != null) 'personId': _selectedPersonId,
      if (_notesController.text.isNotEmpty) 'notes': _notesController.text.trim(),
    };

    bool success;
    if (isEditing) {
      success = await ref.read(obligationsProvider.notifier).updateObligation(widget.obligation!.id, data);
    } else {
      success = await ref.read(obligationsProvider.notifier).createObligation(data);
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${isEditing ? 'update' : 'create'} bill'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final personsState = ref.watch(personsProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Bill' : 'Add Bill',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Bill Name',
                  prefixIcon: Icon(Icons.receipt_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _providerController,
                decoration: const InputDecoration(
                  labelText: 'Provider',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a provider';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Monthly Amount',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Category>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                dropdownColor: AppTheme.surfaceLight,
                items: Category.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _debitOrderDate,
                decoration: const InputDecoration(
                  labelText: 'Debit Order Day',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                dropdownColor: AppTheme.surfaceLight,
                items: List.generate(31, (index) {
                  return DropdownMenuItem(
                    value: index + 1,
                    child: Text('Day ${index + 1}'),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _debitOrderDate = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Essential Bill'),
                subtitle: const Text('Non-negotiable monthly payment'),
                value: _isUncompromised,
                onChanged: (value) {
                  setState(() => _isUncompromised = value);
                },
                activeColor: AppTheme.primary,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Debt/Loan'),
                subtitle: const Text('Track total balance owed'),
                value: _hasDebt,
                onChanged: (value) {
                  setState(() => _hasDebt = value);
                },
                activeColor: AppTheme.primary,
              ),
              if (_hasDebt) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _balanceController,
                  decoration: const InputDecoration(
                    labelText: 'Total Balance Owed',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _interestController,
                  decoration: const InputDecoration(
                    labelText: 'Interest Rate % (optional)',
                    prefixIcon: Icon(Icons.percent_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              if (personsState.persons.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  value: _selectedPersonId,
                  decoration: const InputDecoration(
                    labelText: 'Person (optional)',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  dropdownColor: AppTheme.surfaceLight,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None'),
                    ),
                    ...personsState.persons.map((person) {
                      return DropdownMenuItem(
                        value: person.id,
                        child: Text(person.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedPersonId = value);
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'Update' : 'Add Bill'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
