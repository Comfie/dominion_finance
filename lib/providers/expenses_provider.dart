import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../repositories/expenses_repository.dart';
import '../repositories/repository_providers.dart';

class ExpensesState {
  final List<Expense> expenses;
  final bool isLoading;
  final String? error;
  final String currentMonth;

  ExpensesState({
    this.expenses = const [],
    this.isLoading = false,
    this.error,
    String? currentMonth,
  }) : currentMonth = currentMonth ?? _getCurrentMonth();

  static String _getCurrentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  double get totalExpenses => expenses.fold(0, (sum, e) => sum + e.amount);

  ExpensesState copyWith({
    List<Expense>? expenses,
    bool? isLoading,
    String? error,
    String? currentMonth,
  }) {
    return ExpensesState(
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentMonth: currentMonth ?? this.currentMonth,
    );
  }
}

class ExpensesNotifier extends Notifier<ExpensesState> {
  late final ExpensesRepository _repository;

  @override
  ExpensesState build() {
    _repository = ref.read(expensesRepositoryProvider);
    return ExpensesState();
  }

  Future<void> loadExpenses({String? month}) async {
    final targetMonth = month ?? state.currentMonth;
    state = state.copyWith(isLoading: true, error: null, currentMonth: targetMonth);
    try {
      final expenses = await _repository.getExpenses(month: targetMonth);
      state = state.copyWith(expenses: expenses, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load expenses');
    }
  }

  Future<bool> createExpense(Map<String, dynamic> data) async {
    try {
      await _repository.createExpense(data);
      await loadExpenses();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateExpense(String id, Map<String, dynamic> data) async {
    try {
      await _repository.updateExpense(id, data);
      await loadExpenses();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    try {
      await _repository.deleteExpense(id);
      await loadExpenses();
      return true;
    } catch (e) {
      return false;
    }
  }

  void setMonth(String month) {
    loadExpenses(month: month);
  }
}

final expensesProvider = NotifierProvider<ExpensesNotifier, ExpensesState>(
  ExpensesNotifier.new,
);
