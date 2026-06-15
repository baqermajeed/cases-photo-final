import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../repositories/remote/patient_remote_repository.dart';
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
  final _remoteRepository = PatientRemoteRepository();
  Map<String, dynamic>? _stats;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    if (mounted) {
      setState(() => _isLoadingStats = true);
    }

    final result = await _remoteRepository.getStatistics();
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _stats = Map<String, dynamic>.from(result['data'] as Map);
        _isLoadingStats = false;
      });
      return;
    }

    setState(() => _isLoadingStats = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'فشل جلب الإحصائيات'),
        backgroundColor: AppTheme.errorRed,
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await _loadStatistics();
  }

  int _phaseCount(int phase) {
    final phaseCompleted = _stats?['phase_completed'];
    if (phaseCompleted is! Map) return 0;
    final value = phaseCompleted[phase] ?? phaseCompleted['$phase'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
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
        body: Builder(
          builder: (context) {
            if (_isLoadingStats && _stats == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final totalPatients = (_stats?['total_patients'] as num?)?.toInt() ?? 0;
            final completedPatients =
                (_stats?['completed_patients'] as num?)?.toInt() ?? 0;
            final incompletePatients =
                (_stats?['incomplete_patients'] as num?)?.toInt() ?? 0;
            final zeroStepPatients =
                (_stats?['zero_step_patients'] as num?)?.toInt() ?? 0;
            final completionRate = ((_stats?['completion_rate'] as num?) ?? 0)
                .toStringAsFixed(1);

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
                            value: _phaseCount(1).toString(),
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
                            value: _phaseCount(2).toString(),
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
                            value: _phaseCount(3).toString(),
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
                            value: _phaseCount(4).toString(),
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
