import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/user.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class AuthState {
  final User? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final ApiClient _apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  AuthState build() {
    _apiClient = ref.read(apiClientProvider);
    Future.microtask(_checkAuth);
    return AuthState();
  }

  Future<void> _checkAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final hasToken = await _apiClient.hasToken();
      if (hasToken) {
        final userJson = await _storage.read(key: AppConstants.userKey);
        if (userJson != null) {
          final user = User.fromJson(jsonDecode(userJson));
          state = state.copyWith(
            user: user,
            isAuthenticated: true,
            isLoading: false,
          );
          return;
        }
      }
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.register(name, email, password);
      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);
        await _apiClient.setTokens(authResponse.token, authResponse.refreshToken);
        await _storage.write(
          key: AppConstants.userKey,
          value: jsonEncode(authResponse.user.toJson()),
        );
        state = state.copyWith(
          user: authResponse.user,
          isAuthenticated: true,
          isLoading: false,
        );
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: response.data['error'] ?? 'Registration failed',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.login(email, password);
      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);
        await _apiClient.setTokens(authResponse.token, authResponse.refreshToken);
        await _storage.write(
          key: AppConstants.userKey,
          value: jsonEncode(authResponse.user.toJson()),
        );
        state = state.copyWith(
          user: authResponse.user,
          isAuthenticated: true,
          isLoading: false,
        );
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Invalid email or password',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed. Please try again.',
      );
      return false;
    }
  }

  /// Demo login - creates a fake user without API
  /// Use this for testing when API is not available
  Future<void> loginAsDemo() async {
    state = state.copyWith(isLoading: true, error: null);
    
    // Simulate a short delay for UX
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Create a demo user
    final demoUser = User(
      id: 'demo-user-001',
      name: 'Demo User',
      email: 'demo@dominion.app',
      image: null,
    );
    
    // Store demo user data
    await _storage.write(
      key: AppConstants.userKey,
      value: jsonEncode(demoUser.toJson()),
    );
    
    // Set a fake token so hasToken() returns true
    await _apiClient.setTokens('demo-token', 'demo-refresh-token');
    
    state = state.copyWith(
      user: demoUser,
      isAuthenticated: true,
      isLoading: false,
    );
  }

  Future<void> logout() async {
    await _apiClient.clearTokens();
    state = AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
