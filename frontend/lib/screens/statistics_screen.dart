import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/theme/app_theme.dart';
import '../models/patient.dart';
import '../repositories/local/patient_local_repository.dart';
import '../services/sync_service.dart';
import 'completed_patients_screen.dart';
import 'all_patients_screen.dart';
import 'incomplete_patients_screen.dart';
import 'phase_completed_patients_screen.dart';
import 'zero_step_patients_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _localRepository = PatientLocalRepository.instance;
  final _syncService = SyncService.instance;

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

  bool _isPhaseCompleted(Patient patient, int phase) {
    final required = _phaseSteps(phase);
    final stepMap = {for (final step in patient.steps) step.stepNumber: step};
    for (final step in required) {
      final current = stepMap[step];
      if (current == null || !current.isDone) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'الإحصائيات',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ValueListenableBuilder<Box<Patient>>(
          valueListenable: _localRepository.listenable,
          builder: (context, box, _) {
            final patients = _localRepository.getPatients();
            final totalPatients = patients.length;
            int completedPatients = 0;
            int zeroStepPatients = 0;
            final phaseCounts = {1: 0, 2: 0, 3: 0, 4: 0};

            for (final patient in patients) {
              final allDone = patient.steps.isNotEmpty &&
                  patient.steps.every((s) => s.isDone);
              if (allDone) {
                completedPatients++;
              }
              if (patient.completedStepsCount == 0) {
                zeroStepPatients++;
              }
              for (var phase = 1; phase <= 4; phase++) {
                if (_isPhaseCompleted(patient, phase)) {
                  phaseCounts[phase] = phaseCounts[phase]! + 1;
                }
              }
            }

            final incompletePatients = totalPatients - completedPatients;
            final completionRate = totalPatients > 0
                ? ((completedPatients / totalPatients) * 100).toStringAsFixed(1)
                : '0.0';

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF5BA8D0),
                              Color(0xFF4A90B8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.analytics_outlined,
                              color: Colors.white,
                              size: 50,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'نسبة الإنجاز الكلية',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$completionRate%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'تفاصيل الإحصائيات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // إجمالي المرضى
                      _buildStatCard(
                        icon: Icons.people_outline_rounded,
                        title: 'إجمالي المرضى',
                        value: totalPatients.toString(),
                        color: const Color(0xFF5BA8D0),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5BA8D0), Color(0xFF4A90B8)],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AllPatientsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // المرضى المكتملين
                      _buildStatCard(
                        icon: Icons.check_circle_outline_rounded,
                        title: 'المرضى المكتملين',
                        value: completedPatients.toString(),
                        color: AppTheme.successGreen,
                        gradient: const LinearGradient(
                          colors: [AppTheme.successGreen, Color(0xFF10B981)],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CompletedPatientsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // المرضى غير المكتملين
                      _buildStatCard(
                        icon: Icons.hourglass_empty_rounded,
                        title: 'المرضى غير المكتملين',
                        value: incompletePatients.toString(),
                        color: const Color(0xFFFFA726),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFA726), Color(0xFFFF9800)],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const IncompletePatientsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // لم يكملوا أي خطوة
                      _buildStatCard(
                        icon: Icons.remove_done_rounded,
                        title: 'لم يكملوا أي خطوة',
                        value: zeroStepPatients.toString(),
                        color: Colors.redAccent,
                        gradient: const LinearGradient(
                          colors: [Colors.redAccent, Color(0xFFE53935)],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ZeroStepPatientsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'مكتملو المراحل',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // شبكة بطاقات المراحل (ارتفاع ثابت لتجنّب Overflow)
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 96, // ارتفاع ثابت لكل بطاقة
                        ),
                        children: [
                          _phaseCard(
                            icon: Icons.filter_1_rounded,
                            title: 'قبل العملية',
                            value: phaseCounts[1]!.toString(),
                            color: const Color(0xFF3B82F6),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PhaseCompletedPatientsScreen(phase: 1),
                                ),
                              );
                            },
                          ),
                          _phaseCard(
                            icon: Icons.filter_2_rounded,
                            title: 'أثناء العملية',
                            value: phaseCounts[2]!.toString(),
                            color: const Color(0xFFF59E0B),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PhaseCompletedPatientsScreen(phase: 2),
                                ),
                              );
                            },
                          ),
                          _phaseCard(
                            icon: Icons.filter_3_rounded,
                            title: 'المعالجة',
                            value: phaseCounts[3]!.toString(),
                            color: const Color(0xFF8B5CF6),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PhaseCompletedPatientsScreen(phase: 3),
                                ),
                              );
                            },
                          ),
                          _phaseCard(
                            icon: Icons.filter_4_rounded,
                            title: 'بعد العملية',
                            value: phaseCounts[4]!.toString(),
                            color: const Color(0xFF10B981),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PhaseCompletedPatientsScreen(phase: 4),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
          },
        ),
      ),
    );
  }

  Widget _phaseCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Gradient gradient,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // أيقونة بتدرج
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          // النص
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // شيفرون
          Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.grey.shade400,
            size: 20,
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: card,
    );
  }
}
