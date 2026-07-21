import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try to refresh token
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry the request
            final token = await _storage.read(key: AppConstants.tokenKey);
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          }
        }

        // Retry logic for network errors
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.connectionError) {
          final retryCount = error.requestOptions.extra['retryCount'] as int? ?? 0;

          // Retry up to 2 times
          if (retryCount < 2) {
            error.requestOptions.extra['retryCount'] = retryCount + 1;

            // Wait before retrying (exponential backoff)
            await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));

            try {
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (e) {
              // If retry fails, continue with error
            }
          }
        }

        return handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _storage.write(key: AppConstants.tokenKey, value: data['token']);
        await _storage.write(key: AppConstants.refreshTokenKey, value: data['refreshToken']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> setTokens(String token, String refreshToken) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userKey);
  }

  Future<bool> hasToken() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    return token != null;
  }

  // Auth endpoints
  Future<Response> register(String name, String email, String password) {
    return _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  Future<Response> login(String email, String password) {
    return _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
  }

  // Expenses
  Future<Response> getExpenses({String? month, String? category, String? personId}) {
    return _dio.get('/expenses', queryParameters: {
      if (month != null) 'month': month,
      if (category != null) 'category': category,
      if (personId != null) 'personId': personId,
    });
  }

  Future<Response> createExpense(Map<String, dynamic> data) {
    return _dio.post('/expenses', data: data);
  }

  Future<Response> updateExpense(String id, Map<String, dynamic> data) {
    return _dio.put('/expenses/$id', data: data);
  }

  Future<Response> deleteExpense(String id) {
    return _dio.delete('/expenses/$id');
  }

  // Incomes
  Future<Response> getIncomes({String? month, String? source}) {
    return _dio.get('/incomes', queryParameters: {
      if (month != null) 'month': month,
      if (source != null) 'source': source,
    });
  }

  Future<Response> createIncome(Map<String, dynamic> data) {
    return _dio.post('/incomes', data: data);
  }

  Future<Response> updateIncome(String id, Map<String, dynamic> data) {
    return _dio.put('/incomes/$id', data: data);
  }

  Future<Response> deleteIncome(String id) {
    return _dio.delete('/incomes/$id');
  }

  // Obligations
  Future<Response> getObligations({String? category, bool? isActive}) {
    return _dio.get('/obligations', queryParameters: {
      if (category != null) 'category': category,
      if (isActive != null) 'isActive': isActive,
    });
  }

  Future<Response> createObligation(Map<String, dynamic> data) {
    return _dio.post('/obligations', data: data);
  }

  Future<Response> updateObligation(String id, Map<String, dynamic> data) {
    return _dio.put('/obligations/$id', data: data);
  }

  Future<Response> deleteObligation(String id) {
    return _dio.delete('/obligations/$id');
  }

  // Payments
  Future<Response> getPayments({String? month}) {
    return _dio.get('/payments', queryParameters: {
      if (month != null) 'month': month,
    });
  }

  Future<Response> createPayment(Map<String, dynamic> data) {
    return _dio.post('/payments', data: data);
  }

  // Goals
  Future<Response> getGoals({bool? completed}) {
    return _dio.get('/goals', queryParameters: {
      if (completed != null) 'completed': completed,
    });
  }

  Future<Response> createGoal(Map<String, dynamic> data) {
    return _dio.post('/goals', data: data);
  }

  Future<Response> updateGoal(String id, Map<String, dynamic> data) {
    return _dio.put('/goals/$id', data: data);
  }

  Future<Response> addFundsToGoal(String id, double amount) {
    return _dio.post('/goals/$id/add-funds', data: {'amount': amount});
  }

  Future<Response> deleteGoal(String id) {
    return _dio.delete('/goals/$id');
  }

  // Settings
  Future<Response> getSettings() {
    return _dio.get('/settings');
  }

  Future<Response> updateSettings(Map<String, dynamic> data) {
    return _dio.put('/settings', data: data);
  }

  // Persons
  Future<Response> getPersons() {
    return _dio.get('/persons');
  }

  Future<Response> createPerson(Map<String, dynamic> data) {
    return _dio.post('/persons', data: data);
  }

  Future<Response> updatePerson(String id, Map<String, dynamic> data) {
    return _dio.put('/persons/$id', data: data);
  }

  Future<Response> deletePerson(String id) {
    return _dio.delete('/persons/$id');
  }

  // AI
  Future<Response> scanReceipt(String imageBase64, String mimeType) {
    return _dio.post('/ai/scan-receipt', data: {
      'imageBase64': imageBase64,
      'mimeType': mimeType,
    });
  }

  Future<Response> getInsights({String? month}) {
    return _dio.get('/ai/insights', queryParameters: {
      if (month != null) 'month': month,
    });
  }

  // Analytics
  Future<Response> getSpendingAnalytics({int? months, String? targetMonth}) {
    return _dio.get('/analytics/spending', queryParameters: {
      if (months != null) 'months': months,
      if (targetMonth != null) 'targetMonth': targetMonth,
    });
  }
}
