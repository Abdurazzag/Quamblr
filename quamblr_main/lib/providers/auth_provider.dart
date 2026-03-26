import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/secure_storage_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../services/user_service.dart';
import '../services/dashboard_service.dart';
import '../services/personal_service.dart';

class AuthState {
  final bool isLoading;
  final String? error;

  const AuthState({this.isLoading = false, this.error});

  AuthState copyWith({bool? isLoading, String? error}) {
    return AuthState(isLoading: isLoading ?? this.isLoading, error: error);
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SecureStorageService storage;
  final AuthService authService;

  AuthNotifier(this.storage, this.authService) : super(const AuthState());

  Future<bool> isLoggedIn() async {
    final token = await storage.getAccessToken();
    return token != null;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await authService.login(
        username: username,
        password: password,
      );
      await storage.saveTokens(
        accessToken: response['accessToken'],
        refreshToken: response['refreshToken'],
      );
      final user = response['user'] as Map<String, dynamic>?;
      if (user != null && user['userId'] != null) {
        await storage.saveUserId(user['userId'] as int);
      }
      state = state.copyWith(isLoading: false, error: null);
      return response;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final message = responseData is Map && responseData['error'] != null
          ? responseData['error'].toString()
          : 'Login failed';
      state = state.copyWith(isLoading: false, error: message);
      rethrow;
    }
  }

  Future<void> register(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await authService.register(
        username: username,
        password: password,
      );
      await storage.saveTokens(
        accessToken: response['accessToken'],
        refreshToken: response['refreshToken'],
      );
      final user = response['user'] as Map<String, dynamic>?;
      if (user != null && user['userId'] != null) {
        await storage.saveUserId(user['userId'] as int);
      }
      state = state.copyWith(isLoading: false, error: null);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final message = responseData is Map && responseData['error'] != null
          ? responseData['error'].toString()
          : 'Registration failed';
      state = state.copyWith(isLoading: false, error: message);
      rethrow;
    }
  }

  Future<void> logout() async {
    final refreshToken = await storage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await authService.logout(refreshToken);
      } catch (_) {}
    }
    await storage.clearTokens();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final secureStorageProvider = Provider((_) => SecureStorageService());

final apiClientProvider = Provider((ref) {
  return ApiClient(ref.read(secureStorageProvider));
});

final authServiceProvider = Provider((ref) {
  return AuthService(ref.read(apiClientProvider));
});

final groupServiceProvider = Provider((ref) {
  return GroupService(ref.read(apiClientProvider));
});

final userServiceProvider = Provider((ref) {
  return UserService(ref.read(apiClientProvider));
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(secureStorageProvider),
    ref.read(authServiceProvider),
  );
});

final dashboardServiceProvider = Provider((ref) {
  return DashboardService(ref.read(apiClientProvider));
});

final personalServiceProvider = Provider((ref) {
  return PersonalService(ref.read(apiClientProvider));
});
