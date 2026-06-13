import 'package:hive_flutter/hive_flutter.dart';

DateTime _parseDate(String? value) {
  final parsed = value == null ? null : DateTime.tryParse(value);
  return (parsed ?? DateTime.now()).toUtc();
}

class PatientImage {
  final String id;
  final String url;
  final DateTime uploadedAt;
  final String? uploadedByUsername;

  PatientImage({
    required this.id,
    required this.url,
    required this.uploadedAt,
    this.uploadedByUsername,
  });

  factory PatientImage.fromJson(Map<String, dynamic> json) {
    return PatientImage(
      id: json['id'] as String,
      url: json['url'] as String,
      uploadedAt: _parseDate(json['uploaded_at'] as String?),
      uploadedByUsername: json['uploaded_by_username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'uploaded_at': uploadedAt.toIso8601String(),
      'uploaded_by_username': uploadedByUsername,
    };
  }
}

class Step {
  final String id;
  final int stepNumber;
  final String title;
  final String? description;
  final List<PatientImage> images;
  final bool isDone;
  final DateTime updatedAt;
  final bool isDeleted;

  Step({
    required this.id,
    required this.stepNumber,
    required this.title,
    this.description,
    required this.images,
    required this.isDone,
    required this.updatedAt,
    required this.isDeleted,
  });

  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(
      id: json['id'] as String,
      stepNumber: json['step_number'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      images: (json['images'] as List<dynamic>)
          .map((e) => PatientImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      isDone: json['is_done'] as bool,
      updatedAt: _parseDate(json['updated_at'] as String?),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'step_number': stepNumber,
      'title': title,
      'description': description,
      'images': images.map((e) => e.toJson()).toList(),
      'is_done': isDone,
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  Step copyWith({
    String? id,
    int? stepNumber,
    String? title,
    String? description,
    List<PatientImage>? images,
    bool? isDone,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Step(
      id: id ?? this.id,
      stepNumber: stepNumber ?? this.stepNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      isDone: isDone ?? this.isDone,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class Patient {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String? note;
  final DateTime registrationDate;
  final DateTime updatedAt;
  final bool isDeleted;
  final List<Step> steps;

  Patient({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.note,
    required this.registrationDate,
    required this.updatedAt,
    required this.isDeleted,
    required this.steps,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    final registrationRaw = json['registration_date'] as String?;
    final updatedRaw = json['updated_at'] as String?;
    return Patient(
      id: json['_id'] as String? ?? json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String,
      note: json['note'] as String?,
      registrationDate: _parseDate(registrationRaw),
      updatedAt: _parseDate(updatedRaw ?? registrationRaw),
      isDeleted: json['is_deleted'] as bool? ?? false,
      steps: (json['steps'] as List<dynamic>)
          .map((e) => Step.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'note': note,
      'registration_date': registrationDate.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'steps': steps.map((e) => e.toJson()).toList(),
    };
  }

  double get progressPercentage {
    if (steps.isEmpty) return 0.0;
    final completedSteps = steps.where((s) => s.isDone).length;
    return (completedSteps / steps.length) * 100;
  }

  int get completedStepsCount {
    return steps.where((s) => s.isDone).length;
  }

  Patient copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? note,
    DateTime? registrationDate,
    DateTime? updatedAt,
    bool? isDeleted,
    List<Step>? steps,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      note: note ?? this.note,
      registrationDate: registrationDate ?? this.registrationDate,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      steps: steps ?? this.steps,
    );
  }
}

class PatientImageAdapter extends TypeAdapter<PatientImage> {
  @override
  final int typeId = 1;

  @override
  PatientImage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PatientImage(
      id: fields[0] as String,
      url: fields[1] as String,
      uploadedAt: fields[2] as DateTime,
      uploadedByUsername: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PatientImage obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.uploadedAt)
      ..writeByte(3)
      ..write(obj.uploadedByUsername);
  }
}

class StepAdapter extends TypeAdapter<Step> {
  @override
  final int typeId = 2;

  @override
  Step read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Step(
      id: fields[0] as String,
      stepNumber: fields[1] as int,
      title: fields[2] as String,
      description: fields[3] as String?,
      images: (fields[4] as List).cast<PatientImage>(),
      isDone: fields[5] as bool,
      updatedAt: fields[6] as DateTime,
      isDeleted: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Step obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.stepNumber)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.images)
      ..writeByte(5)
      ..write(obj.isDone)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.isDeleted);
  }
}

class PatientAdapter extends TypeAdapter<Patient> {
  @override
  final int typeId = 3;

  @override
  Patient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Patient(
      id: fields[0] as String,
      name: fields[1] as String,
      phone: fields[2] as String,
      address: fields[3] as String,
      note: fields[4] as String?,
      registrationDate: fields[5] as DateTime,
      steps: (fields[6] as List).cast<Step>(),
      updatedAt: fields[7] as DateTime,
      isDeleted: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Patient obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.registrationDate)
      ..writeByte(6)
      ..write(obj.steps)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.isDeleted);
  }
}
