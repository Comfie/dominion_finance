import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/person.dart';
import '../repositories/persons_repository.dart';
import '../repositories/repository_providers.dart';

class PersonsState {
  final List<Person> persons;
  final bool isLoading;
  final String? error;

  PersonsState({
    this.persons = const [],
    this.isLoading = false,
    this.error,
  });

  PersonsState copyWith({
    List<Person>? persons,
    bool? isLoading,
    String? error,
  }) {
    return PersonsState(
      persons: persons ?? this.persons,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PersonsNotifier extends Notifier<PersonsState> {
  late final PersonsRepository _repository;

  @override
  PersonsState build() {
    _repository = ref.read(personsRepositoryProvider);
    return PersonsState();
  }

  Future<void> loadPersons() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final persons = await _repository.getPersons();
      state = state.copyWith(persons: persons, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load persons');
    }
  }

  Future<bool> createPerson(Map<String, dynamic> data) async {
    try {
      await _repository.createPerson(data);
      await loadPersons();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updatePerson(String id, Map<String, dynamic> data) async {
    try {
      await _repository.updatePerson(id, data);
      await loadPersons();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deletePerson(String id) async {
    try {
      await _repository.deletePerson(id);
      await loadPersons();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final personsProvider = NotifierProvider<PersonsNotifier, PersonsState>(
  PersonsNotifier.new,
);
