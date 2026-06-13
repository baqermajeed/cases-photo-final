import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/theme/app_theme.dart';
import '../models/patient.dart';
import '../repositories/local/patient_local_repository.dart';
import '../services/sync_service.dart';
import 'patient_detail_screen.dart';

class PhaseCompletedPatientsScreen extends StatefulWidget {
  final int phase; // 1..4
  const PhaseCompletedPatientsScreen({super.key, required this.phase});

  @override
  State<PhaseCompletedPatientsScreen> createState() => _PhaseCompletedPatientsScreenState();
}

class _PhaseCompletedPatientsScreenState extends State<PhaseCompletedPatientsScreen> {
  final _localRepository = PatientLocalRepository.instance;
  final _syncService = SyncService.instance;

  String get _title {
    switch (widget.phase) {
      case 1:
        return 'المرحلة: قبل العملية (مكتملين)';
      case 2:
        return 'المرحلة: أثناء العملية (مكتملين)';
      case 3:
        return 'المرحلة: المعالجة (مكتملين)';
      case 4:
      default:
        return 'المرحلة: بعد العملية (مكتملين)';
    }
  }

  Future<void> _handleRefresh() async {
    final synced = await _syncService.syncNow();
    if (!synced && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد اتصال بالإنترنت'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  List<int> _phaseSteps(int phase) {
    switch (phase) {
      case 1:
        return [1, 2, 3, 4, 5, 6, 7, 8];
      case 2:
        return [9, 10, 11, 12, 13, 14];
      case 3:
        return [24];
      case 4:
      default:
        return [15, 16, 17, 18, 19, 20, 21, 22, 23, 25];
    }
  }

  bool _isPhaseCompleted(Patient patient) {
    final required = _phaseSteps(widget.phase);
    final stepMap = {for (final step in patient.steps) step.stepNumber: step};
    for (final stepNumber in required) {
      final step = stepMap[stepNumber];
      if (step == null || !step.isDone) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ValueListenableBuilder<Box<Patient>>(
          valueListenable: _localRepository.listenable,
          builder: (context, box, _) {
            final patients =
                _localRepository.getPatients(where: _isPhaseCompleted);
            if (patients.isEmpty) {
              return const Center(child: Text('لا يوجد مرضى مكتملين لهذه المرحلة'));
            }
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final patient = patients[index];
                  return _Row(
                    patient: patient,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientDetailScreen(patientId: patient.id),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;
  const _Row({required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String? avatarUrl;
    try {
      final step1 = patient.steps.firstWhere((s) => s.stepNumber == 1);
      if (step1.images.isNotEmpty) avatarUrl = step1.images.first.url;
    } catch (_) {}
    final dateFormat = intl.DateFormat('dd/MM/yyyy', 'ar');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.primaryBlue.withOpacity(0.06),
                ),
                child: avatarUrl == null
                    ? const Icon(Icons.person, color: AppTheme.primaryBlue)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: avatarUrl,
                          width: 56,
                          height: 72,
                          fit: BoxFit.cover,
                          memCacheHeight: 144,
                          memCacheWidth: 112,
                          maxHeightDiskCache: 180,
                          maxWidthDiskCache: 140,
                          placeholder: (context, url) => Container(
                            color: AppTheme.primaryBlue.withOpacity(0.06),
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.person,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(dateFormat.format(patient.registrationDate),
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}


