import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../models/patient.dart';
import '../repositories/local/patient_local_repository.dart';
import '../repositories/remote/patient_remote_repository.dart';
import 'patient_detail_screen.dart';

class ZeroStepPatientsScreen extends StatefulWidget {
  const ZeroStepPatientsScreen({super.key});

  @override
  State<ZeroStepPatientsScreen> createState() => _ZeroStepPatientsScreenState();
}

class _ZeroStepPatientsScreenState extends State<ZeroStepPatientsScreen> {
  final _localRepository = PatientLocalRepository.instance;
  final _remoteRepository = PatientRemoteRepository();

  List<Patient> _patients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final result = await _remoteRepository.getZeroStepPatients();
    if (!mounted) return;

    if (result['success'] == true) {
      final patients = result['patients'] as List<Patient>;
      await _localRepository.upsertPatients(patients);
      setState(() {
        _patients = patients;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _error = result['message']?.toString() ?? 'فشل جلب المرضى';
      _isLoading = false;
    });
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPatients,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_patients.isEmpty) {
      return const Center(child: Text('لا يوجد مرضى بدون خطوات مكتملة'));
    }

    return RefreshIndicator(
      onRefresh: _loadPatients,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _patients.length,
        itemBuilder: (context, index) {
          final patient = _patients[index];
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
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لم يكملوا أي خطوة'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _buildBody(),
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
