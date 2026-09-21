import 'package:dio/dio.dart';

import '../../core/api_config.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'food_models.dart';

class FoodsApi {
  final AuthController auth;
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '${ApiConfig.origin}/api/foods/custom',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ),
  );
  FoodsApi(this.auth);

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
          if (key is String && value is String) fields[key] = value;
        });
      }
      if (error.type != DioExceptionType.badResponse) {
        throw ApiFailure(
          saving
              ? 'No pudimos confirmar el guardado. Revisa Mis alimentos antes de volver a enviarlo para evitar duplicados.'
              : 'No pudimos cargar tus alimentos. Revisa tu conexión e inténtalo nuevamente.',
        );
      }
      throw ApiFailure(
        data is Map &&
            data['message'] is String &&
            status != null &&
            status < 500
            ? data['message'] as String
            : saving
            ? 'No pudimos confirmar el guardado. Revisa Mis alimentos antes de volver a enviarlo.'
            : 'El servicio no está disponible. Inténtalo más tarde.',
        fields: fields,
        status: status,
      );
    } on FormatException {
      throw ApiFailure(
        saving
            ? 'La respuesta de guardado no es válida. Revisa Mis alimentos antes de reenviar.'
            : 'La respuesta recibida no es válida. Inténtalo nuevamente.',
      );
    } on TypeError {
      throw ApiFailure(
        saving
            ? 'No pudimos leer la confirmación. Revisa Mis alimentos antes de reenviar.'
            : 'La respuesta recibida no es válida. Inténtalo nuevamente.',
      );
    }
  }

  Future<FoodPage> list(int page) => auth.withAccessToken(
        (token) => _call(() async {
      final response = await _dio.get<dynamic>(
        '',
        queryParameters: {'page': page, 'size': 20},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return FoodPage.fromJson(Map<String, dynamic>.from(response.data as Map));
    }),
    retryUnauthorized: true,
  );

  Future<CustomFood> create(Map<String, dynamic> data) => auth.withAccessToken(
        (token) => _call(() async {
      final response = await _dio.post<dynamic>(
        '',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return CustomFood.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }, saving: true),
  );

  void dispose() => _dio.close(force: true);
}
