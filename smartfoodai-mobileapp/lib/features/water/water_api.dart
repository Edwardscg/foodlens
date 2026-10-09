import 'package:dio/dio.dart';

import '../../core/api_config.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';

class WaterSummary {
  final int consumed;
  final int? goal;
  final String date;
  const WaterSummary(this.consumed, this.goal, this.date);
  factory WaterSummary.fromJson(dynamic json) {
    if (json is! Map ||
        json['consumedMl'] is! int ||
        json['consumedMl'] < 0 ||
        json['date'] is! String ||
        (json['goalMl'] != null &&
            (json['goalMl'] is! int || json['goalMl'] <= 0))) {
      throw const FormatException('Invalid water summary');
    }
    return WaterSummary(
      json['consumedMl'] as int,
      json['goalMl'] as int?,
      json['date'] as String,
    );
  }
}

class WaterApi {
  final AuthController auth;
  final _dio = Dio(
    BaseOptions(
      baseUrl: '${ApiConfig.origin}/api/water',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  WaterApi(this.auth);
  Future<WaterSummary?> _call(
    String method,
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) => auth.withAccessToken((token) async {
    try {
      final result = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return method == 'PUT' ? null : WaterSummary.fromJson(result.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      throw ApiFailure(
        status != null &&
                status < 500 &&
                body is Map &&
                body['message'] is String
            ? body['message'] as String
            : 'No pudimos confirmar la operación. Revisa tu conexión y reintenta.',
        status: status,
      );
    } on FormatException {
      throw const ApiFailure('No pudimos leer la confirmación del servidor.');
    } on TypeError {
      throw const ApiFailure('La respuesta del servidor no es válida.');
    }
  }, retryUnauthorized: method == 'GET');
  Future<WaterSummary?> get(String zone) =>
      _call('GET', '', query: {'timeZone': zone});
  Future<WaterSummary?> add(int amount, String key, String zone) => _call(
    'POST',
    '',
    data: {'amount': amount, 'requestId': key, 'timeZone': zone},
  );
  Future<WaterSummary?> goal(int amount) =>
      _call('PUT', '/goal', data: {'goalMl': amount});
  void dispose() => _dio.close(force: true);
}
