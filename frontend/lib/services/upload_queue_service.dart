import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';

import '../models/patient.dart';
import '../models/pending_upload.dart';
import '../repositories/local/patient_local_repository.dart';
import '../repositories/local/pending_upload_repository.dart';
import '../repositories/remote/patient_remote_repository.dart';
import 'image_compress_service.dart';
import 'network_checker.dart';

class UploadQueueService {
  UploadQueueService._();

  static final UploadQueueService instance = UploadQueueService._();

  final PendingUploadRepository _pendingRepository =
      PendingUploadRepository.instance;
  final PatientRemoteRepository _remoteRepository = PatientRemoteRepository();
  final PatientLocalRepository _localRepository = PatientLocalRepository.instance;

  bool _initialized = false;
  bool _isProcessing = false;
  Timer? _pollTimer;

  Future<void> initialize() async {
    if (_initialized) return;
    await _pendingRepository.init();
    await _recoverInterruptedUploads();
    await wakePendingNow();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => unawaited(runNow()));
    _initialized = true;
    unawaited(runNow());
  }

  Future<int> enqueuePickedImages({
    required String patientId,
    required String patientName,
    required int stepNumber,
    required String stepTitle,
    required List<XFile> images,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    int enqueued = 0;
    for (final image in images) {
      try {
        final compressedFile =
            await ImageCompressService.instance.compressAndPersist(image);
        final now = DateTime.now().toUtc();
        final upload = PendingUpload(
          id: _buildId(),
          patientId: patientId,
          patientName: patientName,
          stepNumber: stepNumber,
          stepTitle: stepTitle,
          localFilePath: compressedFile.path,
          localFileName: compressedFile.uri.pathSegments.isNotEmpty
              ? compressedFile.uri.pathSegments.last
              : compressedFile.path,
          status: PendingUploadStatus.pending,
          retryCount: 0,
          progress: 0,
          lastError: null,
          nextAttemptAt: now,
          createdAt: now,
          updatedAt: now,
        );
        await _pendingRepository.add(upload);
        enqueued += 1;
      } catch (_) {
        // Keep queue robust even when one image fails to compress.
      }
    }

    if (enqueued > 0) {
      unawaited(runNow());
    }
    return enqueued;
  }

  Future<void> runNow() async {
    if (_isProcessing) return;
    if (!await NetworkChecker.hasInternet()) return;

    _isProcessing = true;
    try {
      while (true) {
        if (!await NetworkChecker.hasInternet()) {
          break;
        }

        final next = _nextReadyUpload();
        if (next == null) {
          break;
        }

        await _processUpload(next);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> retryAllNow() async {
    await wakePendingNow(clearErrors: true, resetRetryCount: true);
    await runNow();
  }

  Future<void> retryNow(String uploadId) async {
    final upload = _pendingRepository.getById(uploadId);
    if (upload == null) return;
    final now = DateTime.now().toUtc();
    await _pendingRepository.put(
      upload.copyWith(
        status: PendingUploadStatus.pending,
        progress: 0,
        retryCount: 0,
        clearLastError: true,
        nextAttemptAt: now,
        updatedAt: now,
      ),
    );
    await runNow();
  }

  Future<void> wakePendingNow({
    bool clearErrors = false,
    bool resetRetryCount = false,
  }) async {
    final now = DateTime.now().toUtc();
    final items = _pendingRepository.getAll();
    for (final upload in items) {
      if (upload.status == PendingUploadStatus.uploading ||
          upload.status == PendingUploadStatus.pending) {
        await _pendingRepository.put(
          upload.copyWith(
            status: PendingUploadStatus.pending,
            progress: 0,
            retryCount: resetRetryCount ? 0 : upload.retryCount,
            clearLastError: clearErrors,
            nextAttemptAt: now,
            updatedAt: now,
          ),
        );
      }
    }
  }

  PendingUpload? _nextReadyUpload() {
    final now = DateTime.now().toUtc();
    final items = _pendingRepository.getAll();
    for (final upload in items) {
      if (!upload.nextAttemptAt.isAfter(now)) {
        return upload;
      }
    }
    return null;
  }

  Future<void> _recoverInterruptedUploads() async {
    final now = DateTime.now().toUtc();
    final items = _pendingRepository.getAll();
    for (final upload in items) {
      if (upload.status == PendingUploadStatus.uploading) {
        await _pendingRepository.put(
          upload.copyWith(
            status: PendingUploadStatus.pending,
            progress: 0,
            nextAttemptAt: now,
            updatedAt: now,
          ),
        );
      }
    }
  }

  Future<void> _processUpload(PendingUpload upload) async {
    final now = DateTime.now().toUtc();
    var current = upload.copyWith(
      status: PendingUploadStatus.uploading,
      progress: 0,
      clearLastError: true,
      updatedAt: now,
    );
    await _pendingRepository.put(current);

    final file = File(upload.localFilePath);
    if (!await file.exists()) {
      await _pendingRepository.delete(upload.id);
      return;
    }

    double lastPersistedProgress = 0;

    final result = await _remoteRepository.uploadSingleImageFile(
      patientId: upload.patientId,
      stepNumber: upload.stepNumber,
      imageFile: file,
      onSendProgress: (sent, total) async {
        if (total <= 0) return;
        final progress = (sent / total).clamp(0.0, 1.0).toDouble();
        if ((progress - lastPersistedProgress).abs() < 0.03 && progress < 1) {
          return;
        }
        lastPersistedProgress = progress;
        final latest = _pendingRepository.getById(upload.id);
        if (latest == null) return;
        await _pendingRepository.put(
          latest.copyWith(
            status: PendingUploadStatus.uploading,
            progress: progress,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      },
    );

    final latestCurrent = _pendingRepository.getById(upload.id);
    if (latestCurrent != null) {
      current = latestCurrent;
    }

    if (result['success'] == true) {
      final stepData = result['data'];
      if (stepData is Map<String, dynamic>) {
        await _updateStepInLocalCache(upload.patientId, stepData);
      }

      if (await file.exists()) {
        await file.delete();
      }
      await _pendingRepository.delete(upload.id);
      return;
    }

    final nextRetryCount = current.retryCount + 1;
    final delay = _retryDelay(nextRetryCount);
    await _pendingRepository.put(
      current.copyWith(
        status: PendingUploadStatus.pending,
        retryCount: nextRetryCount,
        progress: 0,
        lastError: result['message']?.toString() ?? 'تعذر رفع الصورة',
        nextAttemptAt: DateTime.now().toUtc().add(delay),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Duration _retryDelay(int retryCount) {
    final seconds = 5 * pow(2, min(retryCount, 4)).toInt();
    final cappedSeconds = min(seconds, 60);
    return Duration(seconds: cappedSeconds);
  }

  Future<void> _updateStepInLocalCache(
    String patientId,
    Map<String, dynamic> stepData,
  ) async {
    final patient = _localRepository.getPatient(patientId);
    if (patient == null) return;

    Step updatedStep;
    try {
      updatedStep = Step.fromJson(stepData);
    } catch (_) {
      return;
    }

    final steps = patient.steps
        .map(
          (step) => step.stepNumber == updatedStep.stepNumber ? updatedStep : step,
        )
        .toList();
    final updatedPatient =
        patient.copyWith(steps: steps, updatedAt: DateTime.now().toUtc());
    await _localRepository.upsertPatients([updatedPatient]);
  }

  String _buildId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(1000000);
    return 'pending_${now}_$random';
  }

  Future<void> dispose() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _initialized = false;
  }
}
