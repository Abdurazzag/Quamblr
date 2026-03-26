import 'package:dio/dio.dart';
import 'secure_storage_service.dart';

class ApiClient {
  // Android emulator: 10.0.2.2 maps to host localhost
  // iOS simulator / physical device: use your machine's local IP or deployed URL
  static const String baseUrl = 'https://quamblr-api.hxsseina.workers.dev';

  late final Dio dio;
  final SecureStorageService _storage;

  ApiClient(this._storage) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(_AuthInterceptor(_storage, dio));
  }
}

class _AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final Dio _dio;

  _AuthInterceptor(this._storage, this._dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for auth endpoints
    if (!options.path.startsWith('/auth/')) {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only attempt refresh for non-auth endpoints returning 401
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.startsWith('/auth/')) {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken != null) {
        try {
          // Use a separate Dio instance to avoid interceptor loop
          final refreshDio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl));
          final response = await refreshDio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );

          final newAccessToken = response.data['accessToken'] as String;
          await _storage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: refreshToken,
          );

          // Retry original request with new token
          err.requestOptions.headers['Authorization'] =
              'Bearer $newAccessToken';
          final retryResponse = await _dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        } catch (_) {
          // Refresh failed — clear tokens so app redirects to login
          await _storage.clearTokens();
        }
      }
    }
    handler.next(err);
  }
}
