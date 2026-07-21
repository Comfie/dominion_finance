import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/obligation.dart';
import '../repositories/obligations_repository.dart';
import '../repositories/repository_providers.dart';

class ObligationsState {
  final List<Obligation> obligations;
  final bool isLoading;
  final String? error;

  ObligationsState({
    this.obligations = const [],
    this.isLoading = false,
    this.error,
  });

  List<Obligation> get activeObligations => obligations.where((o) => o.isActive).toList();
  List<Obligation> get uncompromisedObligations => obligations.where((o) => o.isUncompromised && o.isActive).toList();
  List<Obligation> get variableObligations => obligations.where((o) => !o.isUncompromised && o.isActive).toList();
  List<Obligation> get debtObligations => obligations.where((o) => o.totalBalance != null && o.totalBalance! > 0 && o.isActive).toList();

  double get totalMonthlyAmount => activeObligations.fold(0, (sum, o) => sum + o.amount);
  double get totalUncompromised => uncompromisedObligations.fold(0, (sum, o) => sum + o.amount);
  double get totalVariable => variableObligations.fold(0, (sum, o) => sum + o.amount);
  double get totalDebt => debtObligations.fold(0, (sum, o) => sum + (o.totalBalance ?? 0));

  int get paidCount => obligations.where((o) => o.isPaidThisMonth && o.isActive).length;
  int get unpaidCount => obligations.where((o) => !o.isPaidThisMonth && o.isActive).length;

  ObligationsState copyWith({
    List<Obligation>? obligations,
    bool? isLoading,
    String? error,
  }) {
    return ObligationsState(
      obligations: obligations ?? this.obligations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ObligationsNotifier extends Notifier<ObligationsState> {
  late final ObligationsRepository _repository;

  @override
  ObligationsState build() {
    _repository = ref.read(obligationsRepositoryProvider);
    return ObligationsState();
  }

  Future<void> loadObligations({bool? isActive}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final obligations = await _repository.getObligations(isActive: isActive);
      state = state.copyWith(obligations: obligations, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load obligations');
    }
  }

  Future<bool> createObligation(Map<String, dynamic> data) async {
    try {
      await _repository.createObligation(data);
      await loadObligations();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateObligation(String id, Map<String, dynamic> data) async {
    try {
      await _repository.updateObligation(id, data);
      await loadObligations();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteObligation(String id) async {
    try {
      await _repository.deleteObligation(id);
      await loadObligations();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> recordPayment(String obligationId, double amount, {String? notes}) async {
    try {
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await _repository.createPayment({
        'obligationId': obligationId,
        'amount': amount,
        'month': month,
        if (notes != null) 'notes': notes,
      });
      await loadObligations();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final obligationsProvider = NotifierProvider<ObligationsNotifier, ObligationsState>(
  ObligationsNotifier.new,
);
