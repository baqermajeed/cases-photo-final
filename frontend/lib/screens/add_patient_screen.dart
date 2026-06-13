import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_theme.dart';
import '../models/patient.dart';
import '../repositories/local/patient_local_repository.dart';
import '../repositories/remote/patient_remote_repository.dart';
import '../services/sync_service.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _remoteRepository = PatientRemoteRepository();
  final _syncService = SyncService.instance;
  final _localRepository = PatientLocalRepository.instance;
  final _picker = ImagePicker();
  XFile? _avatar;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _addPatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _remoteRepository.createPatient(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
    );

    if (!mounted) return;

    // If created successfully and avatar selected, upload it to step 1
    bool avatarUploaded = false;
    Patient? created = result['patient'] as Patient?;

    if (result['success'] == true && _avatar != null && created != null) {
      try {
        final up = await _remoteRepository.uploadImages(
          patientId: created.id,
          stepNumber: 1,
          images: [_avatar!],
        );
        avatarUploaded = up['success'] == true;
      } catch (_) {}
    }

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final msg = _avatar == null
          ? 'تم إضافة المريض بنجاح'
          : (avatarUploaded ? 'تم إضافة المريض ورفع الصورة' : 'تم إضافة المريض (تعذر رفع الصورة)');
      final color = (avatarUploaded || _avatar == null) ? AppTheme.successGreen : AppTheme.errorRed;

      if (created != null) {
        await _localRepository.upsertPatients([created]);
      }
      unawaited(_syncService.syncNow());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'فشل في إضافة المريض'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() => _avatar = picked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إضافة مريض جديد'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar selector
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppTheme.lightBlue,
                        backgroundImage:
                            _avatar != null ? Image.file(File(_avatar!.path)).image : null,
                        child: _avatar == null
                            ? const Icon(
                                Icons.person_add_rounded,
                                size: 40,
                                color: AppTheme.primaryBlue,
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: AppTheme.primaryBlue,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _pickAvatar,
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.edit, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text('صورة المريض (اختياري)'),
                ),
                const SizedBox(height: 24),

                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    hintText: 'أدخل اسم المريض الكامل',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال الاسم';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Phone field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    hintText: 'أدخل رقم الهاتف',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال رقم الهاتف';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Address field
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'عنوان السكن',
                    hintText: 'أدخل عنوان سكن المريض',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال العنوان';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // Add button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addPatient,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('إضافة المريض'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
