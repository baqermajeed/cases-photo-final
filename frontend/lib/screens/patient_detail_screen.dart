import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Step;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:intl/intl.dart' as intl;
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/dialogs.dart';
import '../models/patient.dart';
import '../repositories/local/patient_local_repository.dart';
import '../repositories/remote/patient_remote_repository.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'login_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  
  const PatientDetailScreen({super.key, required this.patientId});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final _remoteRepository = PatientRemoteRepository();
  final _authService = AuthService();
  final _imagePicker = ImagePicker();
  final _scrollController = ScrollController();
  final _localRepository = PatientLocalRepository.instance;
  final _syncService = SyncService.instance;
  Patient? _patient;
  bool _isLoading = true;
  int _selectedPhase = 1; // 1=قبل, 2=أثناء, 3=بعد, 4=المعالجة
  bool _isAdmin = false;
  late final ValueListenable<Box<Patient>> _patientsListenable;
  bool _isFetchingMissingPatient = false;

  Future<void> _persistLocalPatient(Patient updated) async {
    setState(() {
      _patient = updated;
    });
    await _localRepository.upsertPatients([updated]);
  }

  Future<void> _updateStepLocal(Step updatedStep) async {
    final current = _patient;
    if (current == null) return;
    final steps = current.steps
        .map((s) => s.stepNumber == updatedStep.stepNumber ? updatedStep : s)
        .toList();
    final updatedPatient =
        current.copyWith(steps: steps, updatedAt: DateTime.now().toUtc());
    await _persistLocalPatient(updatedPatient);
  }

  @override
  void initState() {
    super.initState();
    _patientsListenable = _localRepository.listenable;
    _patientsListenable.addListener(_onPatientsChanged);
    _onPatientsChanged();
    unawaited(_ensurePatientDataLoaded());
    _loadUserRole();
  }

  Future<void> _ensurePatientDataLoaded() async {
    if (_isFetchingMissingPatient) return;
    if (_patient != null) {
      // Refresh silently in background to ensure opened profile is up to date.
      final refreshed = await _remoteRepository.getPatient(widget.patientId);
      if (refreshed['success'] == true) {
        await _localRepository.upsertPatients([refreshed['patient'] as Patient]);
      }
      return;
    }

    _isFetchingMissingPatient = true;
    final result = await _remoteRepository.getPatient(widget.patientId);
    _isFetchingMissingPatient = false;
    if (!mounted) return;

    if (result['success'] == true) {
      await _localRepository.upsertPatients([result['patient'] as Patient]);
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _onPatientsChanged() {
    final patient = _localRepository.getPatient(widget.patientId);
    if (!mounted) return;
    setState(() {
      _patient = patient;
      _isLoading = patient == null;
    });
  }

  @override
  void dispose() {
    _patientsListenable.removeListener(_onPatientsChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openNoteDialog() async {
    if (_patient == null) return;
    final controller = TextEditingController(text: _patient!.note ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة/تعديل ملاحظة'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: TextField(
            controller: controller,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'اكتب ملاحظتك هنا',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final result = await _remoteRepository.updatePatient(
        id: _patient!.id,
        name: _patient!.name,
        phone: _patient!.phone,
        address: _patient!.address,
        note: controller.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (result['success'] == true) {
        final updated = result['patient'] as Patient;
        await _persistLocalPatient(updated);
        unawaited(_syncService.syncNow());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الملاحظة')),
        );
      } else {
        if (await _handleSessionExpired(result)) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'فشل حفظ الملاحظة')),
        );
      }
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final user = await _authService.getCurrentUser();
      if (mounted) {
        setState(() {
          _isAdmin = user?.isAdmin ?? false;
        });
      }
    } catch (_) {}
  }

  Future<bool> _handleSessionExpired(Map<String, dynamic> result) async {
    if (result['sessionExpired'] != true) return false;
    await Dialogs.showWarningDialog(
      context,
      result['message']?.toString() ??
          'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى',
    );
    if (!mounted) return true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    return true;
  }

  Future<void> _pickImages(int stepNumber) async {
    // اختر المصدر أولاً
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('التقاط صورة بالكاميرا'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('اختيار صور من المعرض'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    List<XFile> images = [];
    if (source == ImageSource.gallery) {
      images = await _imagePicker.pickMultiImage(imageQuality: 85);
    } else {
      final captured = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (captured != null) images = [captured];
    }
    if (images.isEmpty) return;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _remoteRepository.uploadImages(
      patientId: widget.patientId,
      stepNumber: stepNumber,
      images: images,
    );

    if (!mounted) return;
    Navigator.pop(context);
    if (result['success'] == true) {
      final data = result['data'];
      if (data != null) {
        final updatedStep = Step.fromJson(Map<String, dynamic>.from(data));
        await _updateStepLocal(updatedStep);
      }
      unawaited(_syncService.syncNow());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم رفع ${images.length} صورة'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } else {
      if (await _handleSessionExpired(result)) return;
      final msg = result['message']?.toString() ?? 'فشل الرفع';
      if (msg.contains('الإنترنت')) {
        await Dialogs.showNoInternetDialog(context);
      } else {
        final retry = await Dialogs.showErrorRetryDialog(context, msg);
        if (retry) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
          final again = await _remoteRepository.uploadImages(
            patientId: widget.patientId,
            stepNumber: stepNumber,
            images: images,
          );
          if (!mounted) return;
          Navigator.pop(context);
          if (again['success'] == true) {
            final againData = again['data'];
            if (againData != null) {
              final updatedStep =
                  Step.fromJson(Map<String, dynamic>.from(againData));
              await _updateStepLocal(updatedStep);
            }
            unawaited(_syncService.syncNow());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم رفع الصور بنجاح'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _toggleStepDone(Step step) async {
    final result = await _remoteRepository.markStepDone(
      patientId: widget.patientId,
      stepNumber: step.stepNumber,
      isDone: !step.isDone,
    );

    if (result['success'] == true) {
      final updatedStep = step.copyWith(isDone: !step.isDone);
      await _updateStepLocal(updatedStep);
      unawaited(_syncService.syncNow());
    } else {
      if (await _handleSessionExpired(result)) return;
      final msg = result['message']?.toString() ?? 'فشل تحديث الخطوة';
      if (msg.contains('الإنترنت')) {
        await Dialogs.showNoInternetDialog(context);
      } else {
        final retry = await Dialogs.showErrorRetryDialog(context, msg);
        if (retry) {
          await _toggleStepDone(step);
        }
      }
    }
  }

  Future<void> _deleteImage(int stepNumber, String imageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الصورة'),
          content: const Text('هل أنت متأكد من حذف هذه الصورة؟'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final result = await _remoteRepository.deleteImage(
        patientId: widget.patientId,
        stepNumber: stepNumber,
        imageId: imageId,
      );

      if (result['success'] == true) {
        final data = result['data'];
        if (data != null) {
          Step? updatedStep;
          try {
            final existing =
                _patient?.steps.firstWhere((s) => s.stepNumber == stepNumber);
            final imagesList = (data['images'] as List)
                .map((e) =>
                    PatientImage.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
            if (existing != null) {
              updatedStep = existing.copyWith(images: imagesList);
            } else {
              updatedStep = Step.fromJson(Map<String, dynamic>.from(data));
            }
          } catch (_) {}
          if (updatedStep != null) {
            await _updateStepLocal(updatedStep);
          }
        }
        unawaited(_syncService.syncNow());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الصورة'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } else {
        if (await _handleSessionExpired(result)) return;
        final msg = result['message']?.toString() ?? 'فشل حذف الصورة';
        if (msg.contains('الإنترنت')) {
          await Dialogs.showNoInternetDialog(context);
        } else {
          final retry = await Dialogs.showErrorRetryDialog(context, msg);
          if (retry) {
            await _deleteImage(stepNumber, imageId);
          }
        }
      }
    }
  }

  Future<void> _downloadImage(String url) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري تحميل الصورة...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      print('Downloading from URL: $url'); // debug

      // تحميل الصورة
      final tempDir = await getTemporaryDirectory();
      final fileName = 'farahdent_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${tempDir.path}/$fileName';
      
      // تحميل الملف مع التعامل مع URLs العربية
      await Dio().download(
        Uri.parse(url).toString(), // للتأكد من encoding صحيح
        filePath,
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          followRedirects: true,
          validateStatus: (status) => status! < 500, // قبول 4xx لرؤية الخطأ
        ),
      );

      // حفظ الصورة في المعرض (بدون album)
      await Gal.putImage(filePath);

      // حذف الملف المؤقت
      try {
        await File(filePath).delete();
      } catch (_) {
        // تجاهل أخطاء الحذف
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الصورة في المعرض ✅'),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error downloading image: $e'); // لوج للتشخيص
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ الصورة: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _viewImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PhotoView(imageProvider: CachedNetworkImageProvider(url)),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white, size: 32),
                onPressed: () {
                  Navigator.pop(context);
                  _downloadImage(url);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: WillPopScope(
        onWillPop: () async {
          Navigator.pop(context);
          return false;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFE8F4F8),
          appBar: AppBar(
            backgroundColor: const Color(0xFFE8F4F8),
            elevation: 0,
            title: Text(
              'ملف المريض',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
            actions: [
              if (!_isLoading && _patient != null)
                IconButton(
                  tooltip: 'تعديل بيانات المريض',
                  onPressed: _openEditPatientDialog,
                  icon: const Icon(Icons.edit_rounded),
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _patient == null
                  ? const Center(child: Text('فشل في تحميل البيانات'))
                  : SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildPatientCard(),
                          const SizedBox(height: 16),
                          _buildActionButtons(),
                          const SizedBox(height: 24),
                          _buildPhasesAndSteps(),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildPatientCard() {
    final p = _patient!;
    String? avatarUrl;
    try {
      final step1 = p.steps.firstWhere((s) => s.stepNumber == 1);
      if (step1.images.isNotEmpty) avatarUrl = step1.images.first.url;
    } catch (_) {}
    final progress = p.progressPercentage;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // المعلومات على اليسار
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('الاسم', p.name, const Color(0xFF5BA8D0)),
                    const SizedBox(height: 14),
                    _buildInfoRow('رقم الهاتف', p.phone, Colors.grey.shade700),
                    const SizedBox(height: 14),
                    _buildInfoRow('المدينة', p.address, Colors.grey.shade700),
                    const SizedBox(height: 14),
                    _buildInfoRow('تاريخ التسجيل', intl.DateFormat('dd/MM/yyyy', 'ar').format(p.registrationDate), Colors.grey.shade700),
                    const SizedBox(height: 10),
                    if (p.note == null || p.note!.trim().isEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _openNoteDialog,
                          icon: const Icon(Icons.note_add_outlined, size: 18),
                          label: const Text('إضافة ملاحظة'),
                        ),
                      )
                    else ...[
                      GestureDetector(
                        onTap: _openNoteDialog,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.sticky_note_2_outlined,
                                  size: 18, color: AppTheme.primaryBlue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p.note!.trim(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(Icons.edit_outlined,
                                  size: 16, color: Colors.grey.shade600),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // الصورة على اليمين
              Container(
                width: 130,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: avatarUrl == null ? Colors.grey.shade200 : null,
                ),
                child: avatarUrl == null
                    ? Icon(Icons.person, size: 60, color: Colors.grey.shade400)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: avatarUrl,
                          width: 130,
                          height: 160,
                          fit: BoxFit.cover,
                          memCacheHeight: 320,  // ضعف الحجم للشاشات عالية الدقة
                          memCacheWidth: 260,
                          maxHeightDiskCache: 400,
                          maxWidthDiskCache: 320,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // شريط التقدم العام
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التقدم العام',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PhasedProgressBar(patient: p),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${progress.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5BA8D0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color labelColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label : ',
          style: TextStyle(
            fontSize: 15,
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildButton(
            'قبل العملية',
            _selectedPhase == 1 ? const Color(0xFF5BA8D0) : Colors.white,
            _selectedPhase == 1 ? Colors.white : Colors.grey.shade800,
            () => setState(() => _selectedPhase = 1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildButton(
            'أثناء العملية',
            _selectedPhase == 2 ? const Color(0xFF5BA8D0) : Colors.white,
            _selectedPhase == 2 ? Colors.white : Colors.grey.shade800,
            () => setState(() => _selectedPhase = 2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildButton(
            'المعالجة',
            _selectedPhase == 3 ? const Color(0xFF5BA8D0) : Colors.white,
            _selectedPhase == 3 ? Colors.white : Colors.grey.shade800,
            () => setState(() => _selectedPhase = 3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildButton(
            'بعد العملية',
            _selectedPhase == 4 ? const Color(0xFF5BA8D0) : Colors.white,
            _selectedPhase == 4 ? Colors.white : Colors.grey.shade800,
            () => setState(() => _selectedPhase = 4),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String text, Color bgColor, Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildPhasesAndSteps() {
    // تحديد الخطوات حسب المرحلة المختارة
    List<int> stepNumbers;
    if (_selectedPhase == 1) {
      stepNumbers = [1, 2, 3, 4, 5, 6, 7, 8];
    } else if (_selectedPhase == 2) {
      stepNumbers = [9, 10, 11, 12, 13, 14];
    } else if (_selectedPhase == 3) {
      // المعالجة
      stepNumbers = [24];
    } else {
      // بعد العملية
      stepNumbers = [15, 16, 17, 18, 19, 20, 21, 22, 23, 25];
    }

    final steps = _patient!.steps.where((s) => stepNumbers.contains(s.stepNumber)).toList();

    return Column(
      children: steps.asMap().entries.map((e) => _buildStepCard(e.value, e.key + 1)).toList(),
    );
  }

  Widget _buildStepCard(Step step, int displayNumber) {
    final isDone = step.isDone;
    final hasImages = step.images.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: () => _toggleStepDone(step),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFF5BA8D0) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone ? const Color(0xFF5BA8D0) : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // عنوان الخطوة
              Expanded(
                child: Text(
                  '$displayNumber. ${step.title}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDone ? Colors.grey.shade500 : Colors.grey.shade800,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              // عداد الصور + زر إضافة
              if (hasImages)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5BA8D0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image_outlined, size: 14, color: Color(0xFF5BA8D0)),
                      const SizedBox(width: 4),
                      Text(
                        step.images.length.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5BA8D0),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              // زر الإضافة
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF5BA8D0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => _pickImages(step.stepNumber),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18, color: Color(0xFF5BA8D0)),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          // تاريخ آخر رفع + المرفوع بواسطة
          if (hasImages)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Builder(builder: (context) {
                      // إيجاد آخر صورة مرفوعة
                      final sorted = [...step.images]..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
                      final latest = sorted.first;
                      final formatted = intl.DateFormat('dd/MM/yyyy HH:mm', 'ar').format(latest.uploadedAt);
                      final uploader = latest.uploadedByUsername;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'آخر رفع: $formatted',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                          if (uploader != null && uploader.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'تم رفع الصورة من قبل المستخدم ($uploader)',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          // شريط الصور
          if (hasImages)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: step.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final img = step.images[i];
                    return GestureDetector(
                      onTap: () => _viewImage(img.url),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: img.url,
                              width: 90,
                              height: 70,
                              fit: BoxFit.cover,
                              memCacheHeight: 140,  // ضعف الحجم للشاشات عالية الدقة
                              memCacheWidth: 180,
                              maxHeightDiskCache: 200,
                              maxWidthDiskCache: 250,
                              fadeInDuration: const Duration(milliseconds: 200),
                              placeholder: (_, __) => Container(
                                width: 90,
                                height: 70,
                                color: Colors.grey.shade100,
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 90,
                                height: 70,
                                color: Colors.grey.shade100,
                                child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: _isAdmin
                                ? GestureDetector(
                                    onTap: () => _deleteImage(step.stepNumber, img.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openEditPatientDialog() async {
    if (_patient == null) return;
    final nameController = TextEditingController(text: _patient!.name);
    final phoneController = TextEditingController(text: _patient!.phone);
    final addressController = TextEditingController(text: _patient!.address);
    final noteController = TextEditingController(text: _patient!.note ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل بيانات المريض'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'رقم الهاتف مطلوب' : null,
                  ),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
                  ),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final result = await _remoteRepository.updatePatient(
        id: _patient!.id,
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        note: noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (result['success'] == true) {
        final updated = result['patient'] as Patient;
        await _persistLocalPatient(updated);
        unawaited(_syncService.syncNow());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث بيانات المريض'), backgroundColor: Color(0xFF10B981)),
        );
      } else {
        if (await _handleSessionExpired(result)) return;
        final msg = result['message']?.toString() ?? 'فشل في تحديث البيانات';
        if (msg.contains('الإنترنت')) {
          await Dialogs.showNoInternetDialog(context);
        } else {
          final retry = await Dialogs.showErrorRetryDialog(context, msg);
          if (retry) {
            await _openEditPatientDialog();
          }
        }
      }
    }
  }
}

class _PhasedProgressBar extends StatelessWidget {
  final Patient patient;
  const _PhasedProgressBar({required this.patient});

  double _phaseProgress(int phase) {
    List<int> steps;
    if (phase == 1) {
      steps = [1, 2, 3, 4, 5, 6, 7, 8];
    } else if (phase == 2) {
      steps = [9, 10, 11, 12, 13, 14];
    } else if (phase == 3) {
      // المعالجة
      steps = [24];
    } else {
      // بعد العملية
      steps = [15, 16, 17, 18, 19, 20, 21, 22, 23, 25];
    }
    final phaseSteps = patient.steps.where((s) => steps.contains(s.stepNumber)).toList();
    if (phaseSteps.isEmpty) return 0.0;
    final done = phaseSteps.where((s) => s.isDone).length;
    return done / phaseSteps.length;
  }

  Color _phaseColor(int phase) {
    switch (phase) {
      case 1:
        return const Color(0xFF3B82F6); // أزرق
      case 2:
        return const Color(0xFFF59E0B); // برتقالي
      case 3:
        return const Color(0xFF10B981); // أخضر
      case 4:
      default:
        return const Color(0xFF8B5CF6); // بنفسجي
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: Row(
        children: List.generate(4, (i) {
          final phase = i + 1;
          final progress = _phaseProgress(phase);
          final color = _phaseColor(phase);
          return Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final clamped = progress.clamp(0.0, 1.0);
                final filledWidth = constraints.maxWidth * clamped;
                return Container(
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: filledWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
