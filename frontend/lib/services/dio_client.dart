import 'package:dio/dio.dart';
import 'dart:io';

class DioClient {
  static final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  )..interceptors.add(InterceptorsWrapper(
      onError: (e, handler) async {
        // Retry Logic
        if (_shouldRetry(e)) {
          try {
            return handler.resolve(await _retry(e.requestOptions));
          } catch (_) {
            return handler.next(e);
          }
        }
        return handler.next(e);
      },
    ));

  static bool _shouldRetry(DioException e) {
    final method = e.requestOptions.method.toUpperCase();
    final retryableFromExtra = e.requestOptions.extra['retryable'] == true;
    final isIdempotentMethod =
        method == 'GET' || method == 'HEAD' || method == 'OPTIONS';
    if (!isIdempotentMethod && !retryableFromExtra) {
      return false;
    }

    return e.type == DioExceptionType.connectionError ||
        e.error is SocketException ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.unknown;
  }

  static Future<Response> _retry(RequestOptions requestOptions) async {
    await Future.delayed(const Duration(seconds: 2));
    return dio.fetch(requestOptions);
  }
}
