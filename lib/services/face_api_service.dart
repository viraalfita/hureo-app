import 'package:dio/dio.dart';

import 'api_service.dart';

/// Pemanggil API enroll & verify wajah menggunakan Dio.
class FaceApiService {
  FaceApiService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiService.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {'Content-Type': 'application/json'},
            ),
          );

  final Dio _dio;

  Future<Response<dynamic>> enrollFace({
    required String userId,
    required List<List<double>> embeddings,
  }) async {
    await ApiService.loadSession();
    return _dio.post(
      '/face/enroll',
      data: {'userId': userId, 'embeddings': embeddings},
      options: Options(
        headers: {'Authorization': 'Bearer ${ApiService.token}'},
      ),
    );
  }

  /// Kirim 1 embedding + lokasi GPS untuk verifikasi absensi.
  Future<Response<dynamic>> verifyFace({
    required String userId,
    required List<double> embedding,
    required double latitude,
    required double longitude,
  }) async {
    await ApiService.loadSession();
    return _dio.post(
      '/face/verify',
      data: {
        'userId': userId,
        'embedding': embedding,
        'location': {
          'lat': latitude,
          'lng': longitude,
        },
      },
      options: Options(
        headers: {'Authorization': 'Bearer ${ApiService.token}'},
      ),
    );
  }
}
