import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/income.dart';
import '../repositories/incomes_repository.dart';
import '../repositories/repository_providers.dart';

class IncomesState {
  final List<Income> incomes;
  final bool isLoading;
  final String? error;
  final String currentMonth;

  IncomesState({
    this.incomes = const [],
    this.isLoading = false,
    this.error,
    String? currentMonth,
  }) : currentMonth = currentMonth ?? _getCurrentMonth();

  static String _getCurrentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  double get totalIncome => incomes.fold(0, (sum, i) => sum + i.amount);
  double get recurringIncome => incomes.where((i) => i.isRecurring).fold(0, (sum, i) => sum + i.amount);
  double get oneTimeIncome => incomes.where((i) => !i.isRecurring).fold(0, (sum, i) => sum + i.amount);

  IncomesState copyWith({
    List<Income>? incomes,
    bool? isLoading,
    String? error,
    String? currentMonth,
  }) {
    return IncomesState(
      incomes: incomes ?? this.incomes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentMonth: currentMonth ?? this.currentMonth,
    );
  }
}

class IncomesNotifier extends Notifier<IncomesState> {
  late final IncomesRepository _repository;

  @override
  IncomesState build() {
    _repository = ref.read(incomesRepositoryProvider);
    return IncomesState();
  }

  Future<void> loadIncomes({String? month}) async {
    final targetMonth = month ?? state.currentMonth;
    state = state.copyWith(isLoading: true, error: null, currentMonth: targetMonth);
    try {
      final incomes = await _repository.getIncomes(month: targetMonth);
      state = state.copyWith(incomes: incomes, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load incomes');
    }
  }

  Future<bool> createIncome(Map<String, dynamic> data) async {
    try {
      await _repository.createIncome(data);
      await loadIncomes();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateIncome(String id, Map<String, dynamic> data) async {
    try {
      await _repository.updateIncome(id, data);
      await loadIncomes();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteIncome(String id) async {
    try {
      await _repository.deleteIncome(id);
      await loadIncomes();
      return true;
    } catch (e) {
      return false;
    }
  }

  void setMonth(String month) {
    loadIncomes(month: month);
  }
}

final incomesProvider = NotifierProvider<IncomesNotifier, IncomesState>(
  IncomesNotifier.new,
);
