import 'package:dio/dio.dart';

import '../../core/api_config.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'meal_models.dart';

class MealSaveFailure extends ApiFailure {
  final bool uncertain;
  const MealSaveFailure(super.message, {this.uncertain = false, super.status});
}

class MealsApi {
  final AuthController auth;
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '${ApiConfig.origin}/api/meals',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  MealsApi(this.auth);

  Future<int> create(
    MealType type,
    DateTime consumedAt,
    String zone,
    List<MealEntry> entries,
  ) => auth.withAccessToken((token) async {
    try {
      final response = await _dio.post<dynamic>(
        '',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {
          'mealType': type.apiValue,
          'consumedAt': consumedAt.toUtc().toIso8601String(),
          'timeZone': zone,
          'items': entries.map((item) => item.toJson()).toList(),
        },
      );
      final data = response.data;
      if (data is! Map || data['id'] is! int || (data['id'] as int) <= 0) {
        throw const MealSaveFailure(
          'No pudimos leer la confirmación del guardado.',
          uncertain: true,
        );
      }
      return data['id'] as int;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final uncertain = status == null || status >= 500;
      final data = error.response?.data;
      throw MealSaveFailure(
        uncertain
            ? 'No pudimos confirmar el guardado. La comida podría haberse registrado.'
            : data is Map && data['message'] is String
            ? data['message'] as String
            : 'No pudimos guardar la comida. Revisa los datos.',
        uncertain: uncertain,
        status: status,
      );
    }
  });

  Future<MealHistoryPage> list(DateTime start, DateTime end, int page) =>
      auth.withAccessToken((token) async {
        try {
          final response = await _dio.get<dynamic>(
            '',
            queryParameters: {
              'start': start.toUtc().toIso8601String(),
              'end': end.toUtc().toIso8601String(),
              'page': page,
              'size': 20,
            },
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          return MealHistoryPage.fromJson(
            Map<String, dynamic>.from(response.data as Map),
          );
        } on DioException catch (error) {
          final status = error.response?.statusCode;
          final data = error.response?.data;
          throw ApiFailure(
            status != null &&
                    status < 500 &&
                    data is Map &&
                    data['message'] is String
                ? data['message'] as String
                : 'No pudimos cargar tu historial. Revisa la conexión e inténtalo nuevamente.',
            status: status,
          );
        } on FormatException {
          throw const ApiFailure(
            'El historial recibido no es válido. Inténtalo nuevamente.',
          );
        } on TypeError {
          throw const ApiFailure(
            'No pudimos leer el historial. Inténtalo nuevamente.',
          );
        }
      }, retryUnauthorized: true);

  void dispose() => _dio.close(force: true);
}
