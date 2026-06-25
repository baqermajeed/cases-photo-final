import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/api_constants.dart';
import '../../models/patient.dart';
import '../../services/auth_service.dart';
import '../../services/dio_client.dart';
import '../../services/network_checker.dart';

class PatientRemoteRepository {
  final AuthService authService = AuthService();
  static const String _sessionExpiredMessage =
      'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';

  Map<String, dynamic> _sessionExpiredResult() {
    return {
      'success': false,
      'sessionExpired': true,
      'message': _sessionExpiredMessage,
    };
  }

  Future<Map<String, dynamic>> _handleDioError(DioException e) async {
    if (e.response?.statusCode == 401) {
      await authService.logout();
      return _sessionExpiredResult();
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.unknown) {
      return {'success': false, 'message': 'تعذر الاتصال بالخادم'};
    }
    final serverMessage = (e.response?.data is Map<String, dynamic>)
        ? (e.response?.data['detail']?.toString())
        : null;
    return {'success': false, 'message': serverMessage ?? 'حدث خطأ غير متوقع'};
  }

  Future<Map<String, dynamic>> getPatients({
    String? query,
    int page = 1,
    int limit = 1000,
  }) async {
    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      String url =
          '${ApiConstants.baseUrl}${ApiConstants.patients}?page=$page&limit=$limit';

      if (query != null && query.isNotEmpty) {
        url += '&q=${Uri.encodeQueryComponent(query)}';
      }

      final response = await DioClient.dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data;
      final patients = (data['data'] as List)
          .map((e) => Patient.fromJson(e))
          .toList();

      return {
        'success': true,
        'patients': patients,
        'pagination': data['pagination'],
      };
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (_) {
      return {'success': false, 'message': 'تعذر الاتصال بالخادم'};
    }
  }

  Future<Map<String, dynamic>> getAllPatients({String? query}) async {
    final List<Patient> all = [];
    int page = 1;
    int size = 100;

    while (true) {
      final result =
          await getPatients(query: query, page: page, limit: size);

      if (result['success'] != true) {
        return result;
      }

      final batch = result['patients'] as List<Patient>;
      all.addAll(batch);

      final pagination = result['pagination'];
      bool hasMore = false;

      if (pagination is Map && pagination['has_next'] == true) {
        hasMore = true;
      } else if (batch.length == size) {
        hasMore = true;
      }

      if (!hasMore) break;
      page++;
    }

    return {'success': true, 'patients': all};
  }

  Future<List<Patient>> fetchAllForOffline() async {
    final result = await getAllPatients();
    if (result['success'] == true) {
      return (result['patients'] as List<Patient>);
    }
    throw Exception(result['message'] ?? 'تعذر تحميل البيانات');
  }

  Future<Map<String, dynamic>> fetchPatientsPage({
    int page = 1,
    int limit = 30,
    String? query,
  }) async {
    final result = await getPatients(
      query: query,
      page: page,
      limit: limit,
    );

    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'تعذر تحميل البيانات');
    }

    final patients = result['patients'] as List<Patient>;
    final pagination = result['pagination'];
    final hasMore = (pagination is Map && pagination['has_next'] == true) ||
        patients.length == limit;

    return {
      'patients': patients,
      'hasMore': hasMore,
      'page': page,
    };
  }

  Future<List<Patient>> fetchUpdates(DateTime since) async {
    try {
      final token = await authService.getToken();
      if (token == null) {
        throw Exception('غير مسجل الدخول');
      }

      final response = await DioClient.dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.patients}/updates',
        queryParameters: {
          'since': since.toUtc().toIso8601String(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data['data'] as List;
      return data.map((e) => Patient.fromJson(e)).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await authService.logout();
        throw Exception(_sessionExpiredMessage);
      }
      throw Exception('فشل مزامنة التحديثات');
    } catch (_) {
      throw Exception('فشل مزامنة التحديثات');
    }
  }

  Future<Map<String, dynamic>> getPatient(String id) async {
    try {
      final token = await authService.getToken();
      if (token == null) return {'success': false};

      final response = await DioClient.dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.patientById(id)}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {
        'success': true,
        'patient': Patient.fromJson(response.data['data']),
      };
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (_) {
      return {'success': false, 'message': 'تعذر الاتصال بالخادم'};
    }
  }

  Future<Map<String, dynamic>> createPatient({
    required String name,
    required String phone,
    required String address,
  }) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      final response = await DioClient.dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.patients}',
        data: {
          'name': name,
          'phone': phone,
          'address': address,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return {
        'success': true,
        'patient': Patient.fromJson(response.data['data']),
      };
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (_) {
      return {'success': false, 'message': 'فشل الاتصال بالخادم'};
    }
  }

  Future<Map<String, dynamic>> updatePatient({
    required String id,
    required String name,
    required String phone,
    required String address,
    String? note,
  }) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();

      final response = await DioClient.dio.patch(
        '${ApiConstants.baseUrl}${ApiConstants.patientById(id)}',
        data: {
          'name': name,
          'phone': phone,
          'address': address,
          if (note != null) 'note': note,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {
        'success': true,
        'patient': Patient.fromJson(response.data['data']),
      };
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (_) {
      return {'success': false, 'message': 'فشل تحديث بيانات المريض'};
    }
  }

  Future<Map<String, dynamic>> uploadImages({
    required String patientId,
    required int stepNumber,
    required List<XFile> images,
  }) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();
      if (token == null) {
        return _sessionExpiredResult();
      }
      final url =
          '${ApiConstants.baseUrl}${ApiConstants.uploadImages(patientId, stepNumber)}';

      final formData = FormData();

      for (var img in images) {
        formData.files.add(
          MapEntry(
            'files',
            await MultipartFile.fromFile(img.path),
          ),
        );
      }

      final response = await DioClient.dio.post(
        url,
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 90),
          extra: {'retryable': false},
        ),
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'تم رفع الصور بنجاح',
        'data': response.data['data'],
      };
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (_) {
      return {'success': false, 'message': 'فشل رفع الصور، حاول مرة أخرى'};
    }
  }

  Future<Map<String, dynamic>> uploadSingleImageFile({
    required String patientId,
    required int stepNumber,
    required File imageFile,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();
      final url =
          '${ApiConstants.baseUrl}${ApiConstants.uploadImages(patientId, stepNumber)}';

      final formData = FormData();
      formData.files.add(
        MapEntry(
          'files',
          await MultipartFile.fromFile(imageFile.path),
        ),
      );

      final response = await DioClient.dio.post(
        url,
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(seconds: 180),
          receiveTimeout: const Duration(seconds: 180),
          extra: {'retryable': false},
        ),
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'تم رفع الصورة بنجاح',
        'data': response.data['data'],
      };
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (_) {
      return {'success': false, 'message': 'فشل رفع الصورة، حاول مرة أخرى'};
    }
  }

  Future<Map<String, dynamic>> markStepDone({
    required String patientId,
    required int stepNumber,
    required bool isDone,
  }) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();

      await DioClient.dio.patch(
        '${ApiConstants.baseUrl}${ApiConstants.markStepDone(
              patientId,
              stepNumber,
            )}',
        data: {'is_done': isDone},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {'success': true};
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (_) {
      return {'success': false, 'message': 'فشل تحديث الخطوة'};
    }
  }

  Future<Map<String, dynamic>> deletePatient(String id) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      await DioClient.dio.delete(
        '${ApiConstants.baseUrl}${ApiConstants.patientById(id)}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {'success': true};
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (_) {
      return {'success': false, 'message': 'فشل حذف المريض'};
    }
  }

  Future<Map<String, dynamic>> getCompletedPatients({
    int page = 1,
    int limit = 30,
  }) async {
    return _fetchFilteredPatients(
      '${ApiConstants.baseUrl}${ApiConstants.patients}/filter/completed',
      'فشل جلب المرضى المكتملين',
      page: page,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> getIncompletePatients({
    int page = 1,
    int limit = 30,
  }) async {
    return _fetchFilteredPatients(
      '${ApiConstants.baseUrl}${ApiConstants.patients}/filter/incomplete',
      'فشل جلب المرضى غير المكتملين',
      page: page,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> getStatisticsAllPatients({
    int page = 1,
    int limit = 30,
  }) async {
    return getPatients(page: page, limit: limit);
  }

  Future<Map<String, dynamic>> _fetchFilteredPatients(
    String url,
    String failureMessage, {
    int page = 1,
    int limit = 30,
  }) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      final separator = url.contains('?') ? '&' : '?';
      final paginatedUrl = '$url${separator}page=$page&limit=$limit';

      final response = await DioClient.dio.get(
        paginatedUrl,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final patients = (response.data['data'] as List)
          .map((e) => Patient.fromJson(e))
          .toList();

      return {
        'success': true,
        'patients': patients,
        'pagination': response.data['pagination'],
      };
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (_) {
      return {'success': false, 'message': failureMessage};
    }
  }

  Future<Map<String, dynamic>> deleteImage({
    required String patientId,
    required int stepNumber,
    required String imageId,
  }) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();

      await DioClient.dio.delete(
        '${ApiConstants.baseUrl}${ApiConstants.deleteImage(
              patientId,
              stepNumber,
              imageId,
            )}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {'success': true, 'message': 'تم حذف الصورة'};
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (_) {
      return {'success': false, 'message': 'فشل حذف الصورة'};
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final token = await authService.getToken();

      final response = await DioClient.dio.get(
        '${ApiConstants.baseUrl}/patients/stats/dashboard',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {
        'success': true,
        'data': response.data['data'],
      };
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (_) {
      return {'success': false, 'message': 'فشل جلب الإحصائيات'};
    }
  }

  Future<Map<String, dynamic>> getCompletedByPhase(
    int phase, {
    int page = 1,
    int limit = 30,
  }) async {
    return _fetchFilteredPatients(
      '${ApiConstants.baseUrl}/patients/filter/completed/phase/$phase',
      'فشل جلب المرضى للمراحل',
      page: page,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> getZeroStepPatients({
    int page = 1,
    int limit = 30,
  }) async {
    return _fetchFilteredPatients(
      '${ApiConstants.baseUrl}/patients/filter/zero-step',
      'فشل جلب المرضى (لا خطوات مكتملة)',
      page: page,
      limit: limit,
    );
  }
}

