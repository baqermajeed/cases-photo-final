import 'package:hive_flutter/hive_flutter.dart';

enum PendingUploadStatus {
  pending,
  uploading,
}

class PendingUpload {
  final String id;
  final String patientId;
  final String patientName;
  final int stepNumber;
  final String stepTitle;
  final String localFilePath;
  final String localFileName;
  final PendingUploadStatus status;
  final int retryCount;
  final double progress;
  final String? lastError;
  final DateTime nextAttemptAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PendingUpload({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.stepNumber,
    required this.stepTitle,
    required this.localFilePath,
    required this.localFileName,
    required this.status,
    required this.retryCount,
    required this.progress,
    required this.nextAttemptAt,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });

  PendingUpload copyWith({
    String? id,
    String? patientId,
    String? patientName,
    int? stepNumber,
    String? stepTitle,
    String? localFilePath,
    String? localFileName,
    PendingUploadStatus? status,
    int? retryCount,
    double? progress,
    String? lastError,
    bool clearLastError = false,
    DateTime? nextAttemptAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PendingUpload(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      stepNumber: stepNumber ?? this.stepNumber,
      stepTitle: stepTitle ?? this.stepTitle,
      localFilePath: localFilePath ?? this.localFilePath,
      localFileName: localFileName ?? this.localFileName,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      progress: progress ?? this.progress,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PendingUploadAdapter extends TypeAdapter<PendingUpload> {
  @override
  final int typeId = 4;

  @override
  PendingUpload read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingUpload(
      id: fields[0] as String,
      patientId: fields[1] as String,
      patientName: fields[2] as String,
      stepNumber: fields[3] as int,
      stepTitle: fields[4] as String,
      localFilePath: fields[5] as String,
      localFileName: fields[6] as String,
      status: PendingUploadStatus.values[fields[7] as int],
      retryCount: fields[8] as int,
      progress: fields[9] as double,
      lastError: fields[10] as String?,
      nextAttemptAt: fields[11] as DateTime,
      createdAt: fields[12] as DateTime,
      updatedAt: fields[13] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PendingUpload obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientId)
      ..writeByte(2)
      ..write(obj.patientName)
      ..writeByte(3)
      ..write(obj.stepNumber)
      ..writeByte(4)
      ..write(obj.stepTitle)
      ..writeByte(5)
      ..write(obj.localFilePath)
      ..writeByte(6)
      ..write(obj.localFileName)
      ..writeByte(7)
      ..write(obj.status.index)
      ..writeByte(8)
      ..write(obj.retryCount)
      ..writeByte(9)
      ..write(obj.progress)
      ..writeByte(10)
      ..write(obj.lastError)
      ..writeByte(11)
      ..write(obj.nextAttemptAt)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt);
  }
}
