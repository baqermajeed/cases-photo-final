import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/patient.dart';
import '../repositories/local/patient_local_repository.dart';
import '../repositories/remote/patient_remote_repository.dart';
import 'network_checker.dart';
import 'upload_queue_service.dart';

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();
  static const int _initialPageSize = 30;

  final PatientLocalRepository _localRepository =
      PatientLocalRepository.instance;
  final PatientRemoteRepository _remoteRepository =
      PatientRemoteRepository();

  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  Timer? _periodicTimer;
  Timer? _connectivityTimer;
  bool _initialized = false;
  bool _wasOnline = true;

  Future<void> initialize() async {
    if (_initialized) return;

    if (!_localRepository.isInitialized) {
      await _localRepository.init();
    }
    await UploadQueueService.instance.initialize();

    _startPeriodicSync();
    _startConnectivityWatcher();
    _initialized = true;

    // Do not block app startup on network calls.
    unawaited(_runInitialSyncInBackground());
  }

  Future<void> _runInitialSyncInBackground() async {
    try {
      await initialLoad();
    } catch (_) {}
    await syncNow();
  }

  Future<void> initialLoad({bool force = false}) async {
    if (!force && !_localRepository.isEmpty) {
      return;
    }

    final firstPage = await _remoteRepository.fetchPatientsPage(
      page: 1,
      limit: _initialPageSize,
    );
    final patients = firstPage['patients'] as List<Patient>;
    await _localRepository.replaceAll(patients);
    await _localRepository.setLastSync(DateTime.now().toUtc());
  }

  Future<bool> syncNow() async {
    if (isSyncing.value) return false;

    isSyncing.value = true;
    try {
      final lastSync = _localRepository.getLastSync();
      if (lastSync == null || _localRepository.isEmpty) {
        await initialLoad(force: true);
        return true;
      }

      try {
        final since = lastSync.subtract(const Duration(seconds: 5));
        final updates = await _remoteRepository.fetchUpdates(since);
        if (updates.isNotEmpty) {
          await _localRepository.upsertPatients(updates);
        }
        await _localRepository.setLastSync(DateTime.now().toUtc());
        return true;
      } catch (e) {
        final message = e.toString();
        if (message.contains('انتهت الجلسة')) {
          // Session is invalid; avoid force full-sync loops with expired token.
          return false;
        }
        // Keep local cache stable; avoid replacing visible data on transient errors.
        return false;
      }
    } catch (_) {
      return false;
    } finally {
      isSyncing.value = false;
    }
  }

  void _startPeriodicSync() {
    _periodicTimer ??= Timer.periodic(const Duration(minutes: 2), (_) async {
      await syncNow();
      await UploadQueueService.instance.runNow();
    });
  }

  void _startConnectivityWatcher() {
    _connectivityTimer ??=
        Timer.periodic(const Duration(seconds: 20), (_) async {
      final online = await NetworkChecker.hasInternet();
      if (online && !_wasOnline) {
        _wasOnline = true;
        await syncNow();
        await UploadQueueService.instance.wakePendingNow();
        await UploadQueueService.instance.runNow();
      } else if (online) {
        await UploadQueueService.instance.wakePendingNow();
        await UploadQueueService.instance.runNow();
      } else if (!online) {
        _wasOnline = false;
      }
    });
  }

  Future<void> dispose() async {
    _periodicTimer?.cancel();
    _connectivityTimer?.cancel();
    isSyncing.dispose();
    _initialized = false;
  }

  List<Patient> getPatients({
    String? query,
    bool Function(Patient patient)? filter,
  }) {
    return _localRepository.getPatients(
      query: query,
      where: filter,
    );
  }

  Patient? getPatient(String id) => _localRepository.getPatient(id);
}

