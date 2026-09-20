import 'package:dio/dio.dart';

import '../../core/api_config.dart';
import 'auth_models.dart';

class AuthApi {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '${ApiConfig.origin}/api/auth',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ),
  );

  Future<T> _call<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (error.type != DioExceptionType.badResponse) {
        throw const ApiFailure(
          'No pudimos conectar. Revisa tu conexión e inténtalo nuevamente.',
        );
      }
      final data = error.response?.data;
      final fields = <String, String>{};
      if (data is Map && data['errors'] is Map) {
        (data['errors'] as Map).forEach((key, value) {
          if (key is String && value is String) fields[key] = value;
        });
      }
      final safeMessage =
      data is Map &&
          data['message'] is String &&
          status != null &&
          status < 500
          ? data['message'] as String
          : 'No se pudo completar la operación. Inténtalo más tarde.';
      throw ApiFailure(safeMessage, fields: fields, status: status);
    } on FormatException {
      throw const ApiFailure(
        'La respuesta recibida no es válida. Inténtalo nuevamente.',
      );
    } on TypeError {
      throw const ApiFailure(
        'La respuesta recibida no es válida. Inténtalo nuevamente.',
      );
    }
  }

  Future<AuthSession> signIn(
      String email,
      String password, {
        required bool register,
      }) => _call(() async {
    final response = await _dio.post<dynamic>(
      register ? '/register' : '/login',
      data: {'email': email.trim(), 'password': password},
    );
    return AuthSession.fromApi(Map<String, dynamic>.from(response.data as Map));
  });
  Future<AuthSession> refresh(String token) => _call(() async {
    final response = await _dio.post<dynamic>(
      '/refresh',
      data: {'refreshToken': token},
    );
    return AuthSession.fromApi(Map<String, dynamic>.from(response.data as Map));
  });
  Future<AuthUser> me(String token) => _call(() async {
    final response = await _dio.get<dynamic>(
      '/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return AuthUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  });
  Future<void> logout(String token) => _call(() async {
    await _dio.post<dynamic>('/logout', data: {'refreshToken': token});
  });
  void dispose() => _dio.close(force: true);
}
