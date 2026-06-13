import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/patient.dart';

class PatientLocalRepository {
  PatientLocalRepository._();

  static final PatientLocalRepository instance = PatientLocalRepository._();

  static const String patientsBoxName = 'patients_box';
  static const String metaBoxName = 'meta_box';
  static const String _lastSyncKey = 'lastSync';

  Box<Patient>? _patientsBox;
  Box<dynamic>? _metaBox;

  bool get isInitialized => _patientsBox != null && _metaBox != null;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PatientImageAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(StepAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(PatientAdapter());
    }

    _patientsBox = await _openPatientsBox();
    _metaBox = await _openMetaBox();
  }

  Future<Box<Patient>> _openPatientsBox() async {
    if (Hive.isBoxOpen(patientsBoxName)) {
      return Hive.box<Patient>(patientsBoxName);
    }
    return Hive.openBox<Patient>(patientsBoxName);
  }

  Future<Box<dynamic>> _openMetaBox() async {
    if (Hive.isBoxOpen(metaBoxName)) {
      return Hive.box<dynamic>(metaBoxName);
    }
    return Hive.openBox<dynamic>(metaBoxName);
  }

  bool get isEmpty => _patientsBox?.isEmpty ?? true;

  ValueListenable<Box<Patient>> get listenable {
    final box = _patientsBox;
    if (box == null) {
      throw StateError('PatientLocalRepository not initialized');
    }
    return box.listenable();
  }

  List<Patient> getPatients({
    String? query,
    bool includeDeleted = false,
    bool Function(Patient patient)? where,
  }) {
    final box = _patientsBox;
    if (box == null) return [];

    final q = query?.trim().toLowerCase();
    final patients = box.values.where((patient) {
      if (!includeDeleted && patient.isDeleted) return false;
      if (q != null && q.isNotEmpty) {
        final matchName = patient.name.toLowerCase().contains(q);
        final matchPhone = patient.phone.toLowerCase().contains(q);
        if (!matchName && !matchPhone) return false;
      }
      if (where != null && !where(patient)) return false;
      return true;
    }).toList();

    patients.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return patients;
  }

  Patient? getPatient(String id) {
    final box = _patientsBox;
    if (box == null) return null;
    final patient = box.get(id);
    if (patient == null || patient.isDeleted) return null;
    return patient;
  }

  Future<void> replaceAll(List<Patient> patients) async {
    final box = _patientsBox;
    if (box == null) return;
    await box.clear();
    await box.putAll({
      for (final patient in patients) patient.id: patient,
    });
  }

  Future<void> upsertPatients(List<Patient> patients) async {
    final box = _patientsBox;
    if (box == null) return;

    for (final patient in patients) {
      if (patient.isDeleted) {
        await box.delete(patient.id);
      } else {
        await box.put(patient.id, patient);
      }
    }
  }

  Future<void> deletePatient(String id) async {
    final box = _patientsBox;
    if (box == null) return;
    await box.delete(id);
  }

  DateTime? getLastSync() {
    final box = _metaBox;
    if (box == null) return null;
    final value = box.get(_lastSyncKey) as String?;
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    return parsed?.toUtc();
  }

  Future<void> setLastSync(DateTime timestamp) async {
    final box = _metaBox;
    if (box == null) return;
    await box.put(_lastSyncKey, timestamp.toUtc().toIso8601String());
  }
}

