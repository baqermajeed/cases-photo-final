import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/pending_upload.dart';

class PendingUploadRepository {
  PendingUploadRepository._();

  static final PendingUploadRepository instance = PendingUploadRepository._();
  static const String uploadsBoxName = 'pending_uploads_box';

  Box<PendingUpload>? _uploadsBox;

  bool get isInitialized => _uploadsBox != null;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(PendingUploadAdapter());
    }
    _uploadsBox = await _openUploadsBox();
  }

  Future<Box<PendingUpload>> _openUploadsBox() async {
    if (Hive.isBoxOpen(uploadsBoxName)) {
      return Hive.box<PendingUpload>(uploadsBoxName);
    }
    return Hive.openBox<PendingUpload>(uploadsBoxName);
  }

  ValueListenable<Box<PendingUpload>> get listenable {
    final box = _uploadsBox;
    if (box == null) {
      throw StateError('PendingUploadRepository not initialized');
    }
    return box.listenable();
  }

  List<PendingUpload> getAll() {
    final box = _uploadsBox;
    if (box == null) return [];
    final items = box.values.toList();
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  int get count => _uploadsBox?.length ?? 0;

  Future<void> add(PendingUpload upload) async {
    final box = _uploadsBox;
    if (box == null) return;
    await box.put(upload.id, upload);
  }

  Future<void> put(PendingUpload upload) async {
    final box = _uploadsBox;
    if (box == null) return;
    await box.put(upload.id, upload);
  }

  PendingUpload? getById(String id) {
    final box = _uploadsBox;
    if (box == null) return null;
    return box.get(id);
  }

  Future<void> delete(String id) async {
    final box = _uploadsBox;
    if (box == null) return;
    await box.delete(id);
  }
}
