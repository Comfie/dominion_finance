import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/goal.dart';
import '../repositories/goals_repository.dart';
import '../repositories/repository_providers.dart';

class GoalsState {
  final List<SavingsGoal> goals;
  final bool isLoading;
  final String? error;

  GoalsState({
    this.goals = const [],
    this.isLoading = false,
    this.error,
  });

  List<SavingsGoal> get activeGoals => goals.where((g) => !g.isCompleted).toList();
  List<SavingsGoal> get completedGoals => goals.where((g) => g.isCompleted).toList();

  double get totalSaved => goals.fold(0, (sum, g) => sum + g.currentAmount);
  double get totalTarget => goals.fold(0, (sum, g) => sum + g.targetAmount);

  GoalsState copyWith({
    List<SavingsGoal>? goals,
    bool? isLoading,
    String? error,
  }) {
    return GoalsState(
      goals: goals ?? this.goals,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class GoalsNotifier extends Notifier<GoalsState> {
  late final GoalsRepository _repository;

  @override
  GoalsState build() {
    _repository = ref.read(goalsRepositoryProvider);
    return GoalsState();
  }

  Future<void> loadGoals({bool? completed}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final goals = await _repository.getGoals(completed: completed);
      state = state.copyWith(goals: goals, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load goals');
    }
  }

  Future<bool> createGoal(Map<String, dynamic> data) async {
    try {
      await _repository.createGoal(data);
      await loadGoals();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateGoal(String id, Map<String, dynamic> data) async {
    try {
      await _repository.updateGoal(id, data);
      await loadGoals();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addFunds(String id, double amount) async {
    try {
      await _repository.addFundsToGoal(id, amount);
      await loadGoals();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteGoal(String id) async {
    try {
      await _repository.deleteGoal(id);
      await loadGoals();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final goalsProvider = NotifierProvider<GoalsNotifier, GoalsState>(
  GoalsNotifier.new,
);
