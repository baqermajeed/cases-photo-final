import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../models/patient.dart';
import '../repositories/remote/patient_remote_repository.dart';
import '../widgets/statistics_paginated_list.dart';
import 'patient_detail_screen.dart';

class AllPatientsScreen extends StatefulWidget {
  const AllPatientsScreen({super.key});

  @override
  State<AllPatientsScreen> createState() => _AllPatientsScreenState();
}

class _AllPatientsScreenState extends State<AllPatientsScreen> {
  final _remoteRepository = PatientRemoteRepository();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('جميع المرضى'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: StatisticsPaginatedPatientList(
          onFetchPage: ({required page, required limit}) =>
              _remoteRepository.getStatisticsAllPatients(page: page, limit: limit),
          emptyMessage: 'لا يوجد مرضى بعد',
          itemBuilder: (context, patient) => _PatientRow(
            patient: patient,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientDetailScreen(patientId: patient.id),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;
  const _PatientRow({required this.patient, required this.onTap});

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
