import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api_config.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'detected_food.dart';

class PhotoAnalysisApi {
  final AuthController auth;
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '${ApiConfig.origin}/api/meals',
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  PhotoAnalysisApi(this.auth);

  void close() => _dio.close(force: true);

  Future<List<DetectedFood>> analyze(Uint8List bytes, CancelToken cancel) =>
      auth.withAccessToken((token) async {
        try {
          if (cancel.isCancelled) throw cancel.cancelError!;
          final response = await _dio.post<dynamic>(
            '/analyze',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
            data: FormData.fromMap({
              'image': MultipartFile.fromBytes(bytes, filename: 'meal-image'),
            }),
            cancelToken: cancel,
          );
          return DetectedFood.parseResponse(response.data);
        } on DioException catch (error) {
          if (CancelToken.isCancel(error)) rethrow;
          final status = error.response?.statusCode;
          final data = error.response?.data;
          throw ApiFailure(
            status == 503
                ? 'El análisis no está disponible por ahora. Puedes registrar tu comida manualmente.'
                : status != null &&
                      status < 500 &&
                      data is Map &&
                      data['message'] is String
                ? data['message'] as String
                : 'No pudimos analizar la foto. Revisa tu conexión e inténtalo nuevamente.',
            status: status,
          );
        } on FormatException {
          throw const ApiFailure(
            'No pudimos interpretar el análisis. Inténtalo nuevamente.',
          );
        }
      });
}
