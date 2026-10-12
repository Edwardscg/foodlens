import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api_config.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'meal_models.dart';
import 'meal_detail.dart';

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
    List<MealEntry> entries, {
    Uint8List? image,
  }) => auth.withAccessToken((token) async {
    try {
      final meal = {
        'mealType': type.apiValue,
        'consumedAt': consumedAt.toUtc().toIso8601String(),
        'timeZone': zone,
        'items': entries.map((item) => item.toJson()).toList(),
      };
      final response = await _dio.post<dynamic>(
        image == null ? '' : '/photo',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(seconds: 30),
        ),
        data: image == null
            ? meal
            : FormData.fromMap({
                'meal': MultipartFile.fromString(
                  jsonEncode(meal),
                  contentType: DioMediaType('application', 'json'),
                ),
                'image': MultipartFile.fromBytes(image, filename: 'meal-image'),
              }),
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

  Future<Uint8List> photo(int mealId) => auth.withAccessToken((token) async {
    try {
      final response = await _dio.get<List<int>>(
        '/$mealId/photo',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.data == null || response.data!.isEmpty) {
        throw const ApiFailure('No pudimos leer la foto.');
      }
      return Uint8List.fromList(response.data!);
    } on DioException catch (error) {
      throw ApiFailure(
        'No pudimos cargar la foto. Inténtalo nuevamente.',
        status: error.response?.statusCode,
      );
    }
  }, retryUnauthorized: true);

  Future<T> _read<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? query,
  }) => auth.withAccessToken((token) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return parse(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      throw ApiFailure(
        status != null &&
                status < 500 &&
                data is Map &&
                data['message'] is String
            ? data['message'] as String
            : 'No pudimos cargar las comidas. Revisa tu conexión e inténtalo nuevamente.',
        status: status,
      );
    } on FormatException {
      throw const ApiFailure(
        'Los datos recibidos no son válidos. Inténtalo nuevamente.',
      );
    } on TypeError {
      throw const ApiFailure(
        'No pudimos leer los datos de la comida. Inténtalo nuevamente.',
      );
    }
  }, retryUnauthorized: true);

  Future<MealHistoryPage> list(DateTime start, DateTime end, int page) => _read(
    '',
    MealHistoryPage.fromJson,
    query: {
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
      'page': page,
      'size': 20,
    },
  );

  Future<({int count, MealNutrition totals})> summary(
    DateTime start,
    DateTime end,
  ) => _read(
    '/summary',
    (json) {
      final count = json['mealCount'];
      if (count is! int || count < 0) {
        throw const FormatException('Invalid meal count');
      }
      return (count: count, totals: MealNutrition.fromJson(json));
    },
    query: {
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
    },
  );

  Future<MealDetail> get(int id) => _read('/$id', (json) {
    final meal = MealDetail.fromJson(json);
    if (meal.summary.id != id) throw const FormatException('Unexpected meal');
    return meal;
  });

  Future<void> update(
    MealDetail meal,
    MealType type,
    Map<int, double> quantities, {
    List<MealEntry> added = const [],
    DateTime? consumedAt,
    String? timeZone,
  }) => auth.withAccessToken((token) async {
    try {
      await _dio.put<dynamic>(
        '/${meal.summary.id}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {
          if (consumedAt != null)
            'consumedAt': consumedAt.toUtc().toIso8601String(),
          'timeZone': ?timeZone,
          'addedItems': added.map((entry) => entry.toJson()).toList(),
          'version': meal.version,
          'mealType': type.apiValue,
          'items': quantities.entries
              .map((entry) => {'id': entry.key, 'quantity': entry.value})
              .toList(),
        },
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
            : 'No pudimos confirmar los cambios. Vuelve al detalle para comprobar el registro antes de editar nuevamente.',
        status: status,
      );
    }
  });

  Future<bool> delete(int id) => auth.withAccessToken((token) async {
    try {
      final response = await _dio.delete<void>(
        '/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode != 204) {
        throw const ApiFailure(
          'No pudimos confirmar la eliminación. Comprueba el estado de la comida.',
        );
      }
      return true;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404) return false;
      final data = error.response?.data;
      throw ApiFailure(
        status != null &&
                status < 500 &&
                data is Map &&
                data['message'] is String
            ? data['message'] as String
            : 'No pudimos confirmar la eliminación. Comprueba el estado de la comida antes de intentarlo nuevamente.',
        status: status,
      );
    }
  });

  void dispose() => _dio.close(force: true);
}
