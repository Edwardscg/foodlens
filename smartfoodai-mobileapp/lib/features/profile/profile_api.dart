import 'package:dio/dio.dart';

import '../../core/api_config.dart';
import '../auth/auth_models.dart';
import 'profile_models.dart';

class ProfileApi {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '${ApiConfig.origin}/api/users/me/profile',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ),
  );
  Future<T> _call<T>(
    Future<T> Function() operation, {
    bool saving = false,
  }) async {
    try {
      return await operation();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      final fields = <String, String>{};
      if (data is Map && data['errors'] is Map) {
        (data['errors'] as Map).forEach((key, value) {
          if (key is String && value is String) {
            fields[key.replaceFirst(RegExp(r'^profile\.'), '')] = value;
          }
        });
      }
      final message =
          error.type == DioExceptionType.badResponse &&
              data is Map &&
              data['message'] is String &&
              status != null &&
              status < 500
          ? data['message'] as String
          : saving
          ? 'No pudimos confirmar el guardado. Conservamos tus datos; puedes volver a intentarlo.'
          : 'No pudimos consultar el perfil. Revisa tu conexión e inténtalo nuevamente.';
      throw ApiFailure(message, fields: fields, status: status);
    } on FormatException {
      throw const ApiFailure(
        'La respuesta del perfil no es válida. Inténtalo nuevamente.',
      );
    } on TypeError {
      throw const ApiFailure(
        'La respuesta del perfil no es válida. Inténtalo nuevamente.',
      );
    }
  }

  Options _options(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});
  Future<UserProfile> get(String token) => _call(() async {
    final result = await _dio.get<dynamic>('', options: _options(token));
    return UserProfile.fromJson(Map<String, dynamic>.from(result.data as Map));
  });
  Future<CalorieSuggestion> suggest(String token, ProfileData data) =>
      _call(() async {
        final result = await _dio.post<dynamic>(
          '/calorie-suggestion',
          data: data.toJson(),
          options: _options(token),
        );
        return CalorieSuggestion.fromJson(
          Map<String, dynamic>.from(result.data as Map),
        );
      });
  Future<UserProfile> save(
    String token,
    ProfileData data, {
    required bool suggested,
    int? target,
  }) => _call(() async {
    final result = await _dio.put<dynamic>(
      '',
      options: _options(token),
      data: {
        'profile': data.toJson(),
        'goalSource': suggested ? 'SUGGESTED' : 'MANUAL',
        if (!suggested) 'dailyCalorieGoal': target,
      },
    );
    final profile = UserProfile.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
    if (!profile.completed) {
      throw const FormatException('Profile not completed');
    }
    return profile;
  }, saving: true);
  void dispose() => _dio.close(force: true);
}
