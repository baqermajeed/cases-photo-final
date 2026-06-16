import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/dialogs.dart';
import '../models/patient.dart';
import '../models/user.dart';
import '../repositories/local/patient_local_repository.dart';
import '../repositories/remote/patient_remote_repository.dart';
import '../services/auth_service.dart';
import '../services/network_checker.dart';
import '../services/sync_service.dart';
import 'add_patient_screen.dart';
import 'patient_detail_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class PatientsListScreen extends StatefulWidget {
  final bool showIncompleteOnly;
  const PatientsListScreen({super.key, this.showIncompleteOnly = false});

  @override
  State<PatientsListScreen> createState() => _PatientsListScreenState();
}

class _PatientsListScreenState extends State<PatientsListScreen> {
  static const int _pageSize = 30;
  final _remoteRepository = PatientRemoteRepository();
  final _authService = AuthService();
  final _localRepository = PatientLocalRepository.instance;
  final _syncService = SyncService.instance;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String? _searchQuery;
  User? _currentUser;
  Timer? _searchDebounce;
  bool _isLoadingMore = false;
  bool _hasMoreRemote = true;
  int _nextPage = 2;
  bool _isSearchingRemote = false;
  bool _isLoadingMoreSearch = false;
  bool _hasMoreSearchResults = false;
  int _nextSearchPage = 2;
  List<Patient>? _remoteSearchResults;

  @override
  void initState() {
    super.initState();
    _initializePagingState();
    _scrollController.addListener(_onScroll);
    _loadCurrentUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncService.syncNow());
    });
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() => _currentUser = user);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initializePagingState() {
    final localCount = _localRepository.getPatients().length;
    final localPages = (localCount / _pageSize).ceil();
    _nextPage = (localPages <= 0) ? 2 : (localPages + 1);
    _hasMoreRemote = true;
  }

  void _onScroll() {
    if (_searchQuery != null) {
      if (_isLoadingMoreSearch || !_hasMoreSearchResults) return;
    } else if (_isLoadingMore || !_hasMoreRemote) {
      return;
    }
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      if (_searchQuery != null) {
        unawaited(_loadMoreSearchResults());
      } else {
        unawaited(_loadMorePatients());
      }
    }
  }

  Future<void> _loadMorePatients() async {
    if (_isLoadingMore || !_hasMoreRemote) return;
    if (_searchQuery != null) return;

    if (mounted) {
      setState(() => _isLoadingMore = true);
    }

    try {
      final result = await _remoteRepository.getPatients(
        page: _nextPage,
        limit: _pageSize,
      );

      if (result['success'] == true) {
        final patients = result['patients'] as List<Patient>;
        if (patients.isNotEmpty) {
          await _localRepository.upsertPatients(patients);
        }

        final pagination = result['pagination'];
        final hasMore =
            (pagination is Map && pagination['has_next'] == true) ||
            patients.length == _pageSize;

        if (mounted) {
          setState(() {
            _hasMoreRemote = hasMore;
            if (hasMore) _nextPage += 1;
          });
        }
      }
    } catch (_) {
      // Keep silent: user already has cached data and can continue browsing.
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج من الحساب؟'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _onSearch(String query) {
    _searchDebounce?.cancel();
    final normalized = query.trim();

    setState(() {
      _searchQuery = normalized.isEmpty ? null : normalized;
      if (_searchQuery == null) {
        _remoteSearchResults = null;
        _isSearchingRemote = false;
        _isLoadingMoreSearch = false;
        _hasMoreSearchResults = false;
        _nextSearchPage = 2;
      }
    });

    if (_searchQuery != null) {
      setState(() {
        _remoteSearchResults = null;
        _isLoadingMoreSearch = false;
        _hasMoreSearchResults = false;
        _nextSearchPage = 2;
      });
      _searchDebounce = Timer(const Duration(milliseconds: 450), () {
        unawaited(_searchFromServer(_searchQuery!, page: 1, reset: true));
      });
    }
  }

  Future<void> _searchFromServer(
    String query, {
    required int page,
    required bool reset,
  }) async {
    if (!mounted) return;
    setState(() {
      _isSearchingRemote = reset;
      _isLoadingMoreSearch = !reset;
    });

    try {
      final result = await _remoteRepository.getPatients(
        query: query,
        page: page,
        limit: _pageSize,
      );

      if (!mounted || _searchQuery != query) return;

      if (result['success'] == true) {
        var patients = (result['patients'] as List<Patient>);

        if (widget.showIncompleteOnly) {
          patients = patients.where((p) => p.progressPercentage < 100).toList();
        }

        final pagination = result['pagination'];
        final hasMore =
            (pagination is Map && pagination['has_next'] == true) ||
            patients.length == _pageSize;

        setState(() {
          if (reset) {
            _remoteSearchResults = patients;
          } else {
            final current = _remoteSearchResults ?? <Patient>[];
            final byId = {for (final patient in current) patient.id: patient};
            for (final patient in patients) {
              byId[patient.id] = patient;
            }
            _remoteSearchResults = byId.values.toList();
          }
          _hasMoreSearchResults = hasMore;
          _nextSearchPage = hasMore ? page + 1 : page;
        });
      } else {
        setState(() => _remoteSearchResults = null);
      }
    } catch (_) {
      if (!mounted || _searchQuery != query) return;
      setState(() => _remoteSearchResults = null);
    } finally {
      if (mounted && _searchQuery == query) {
        setState(() {
          _isSearchingRemote = false;
          _isLoadingMoreSearch = false;
        });
      }
    }
  }

  Future<void> _loadMoreSearchResults() async {
    final query = _searchQuery;
    if (query == null || query.isEmpty) return;
    if (_isLoadingMoreSearch || !_hasMoreSearchResults) return;
    await _searchFromServer(query, page: _nextSearchPage, reset: false);
  }

  Future<void> _handleRefresh() async {
    final synced = await _syncService.syncNow();
    if (!synced && mounted) {
      final hasInternet = await NetworkChecker.hasInternet();
      if (!mounted) return;

      if (!hasInternet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد اتصال بالإنترنت'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _deletePatient(Patient patient) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف مريض'),
          content: Text('هل أنت متأكد من حذف ملف المريض "${patient.name}"؟\n\nسيتم حذف جميع البيانات والصور نهائياً.'),
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
      final result = await _remoteRepository.deletePatient(patient.id);
      if (mounted) {
        if (result['success'] == true) {
          await _localRepository.deletePatient(patient.id);
          unawaited(_syncService.syncNow());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف المريض بنجاح'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else {
          if (result['sessionExpired'] == true) {
            await _authService.logout();
            if (!mounted) return;
            await Dialogs.showWarningDialog(
              context,
              result['message']?.toString() ??
                  'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى',
            );
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'فشل في حذف المريض'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
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
            'المرضى',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_outline_rounded, size: 20),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded, size: 20, color: AppTheme.errorRed),
              ),
              tooltip: 'تسجيل الخروج',
              onPressed: _confirmLogout,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مريض...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
                    suffixIcon: _isSearchingRemote
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: Colors.grey.shade600),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearch('');
                                },
                              )
                            : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            
            // Patients list
            Expanded(
              child: ValueListenableBuilder<Box<Patient>>(
                valueListenable: _localRepository.listenable,
                builder: (context, box, _) {
                  final localPatients = _localRepository.getPatients(
                    query: _searchQuery,
                    where: widget.showIncompleteOnly
                        ? (p) => p.progressPercentage < 100
                        : null,
                  );
                  final patients = (_searchQuery != null &&
                          _remoteSearchResults != null)
                      ? _remoteSearchResults!
                      : localPatients;

                  return ValueListenableBuilder<bool>(
                    valueListenable: _syncService.isSyncing,
                    builder: (context, syncing, __) {
                      if (patients.isEmpty && syncing && _searchQuery == null) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (patients.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search_rounded,
                                size: 80,
                                color: AppTheme.textGray.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery != null
                                    ? 'لا توجد نتائج للبحث'
                                    : widget.showIncompleteOnly
                                        ? 'لا يوجد مرضى قيد الإكمال'
                                        : 'لا يوجد مرضى بعد',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _handleRefresh,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: patients.length +
                              (((_searchQuery == null && _isLoadingMore) ||
                                      (_searchQuery != null && _isLoadingMoreSearch))
                                  ? 1
                                  : 0),
                          itemBuilder: (context, index) {
                            if (index >= patients.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.2),
                                  ),
                                ),
                              );
                            }

                            final patient = patients[index];
                            return _PatientCard(
                              patient: patient,
                              isAdmin: _currentUser?.isAdmin ?? false,
                              onDelete: () => _deletePatient(patient),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PatientDetailScreen(
                                      patientId: patient.id,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final created = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddPatientScreen()),
            );
            if (created == true) {
              await _syncService.syncNow();
            }
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة مريض'),
        ),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final Patient patient;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PatientCard({
    required this.patient,
    required this.isAdmin,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = intl.DateFormat('dd/MM/yyyy', 'ar');
    final progress = patient.progressPercentage;
    final isCompleted = progress >= 100;
    
    // جلب الصورة
    String? avatarUrl;
    try {
      final step1 = patient.steps.firstWhere((s) => s.stepNumber == 1);
      if (step1.images.isNotEmpty) avatarUrl = step1.images.first.url;
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: isCompleted
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  const Color(0xFF10B981).withOpacity(0.05),
                ],
              )
            : null,
        color: isCompleted ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isCompleted 
                ? const Color(0xFF10B981).withOpacity(0.12)
                : AppTheme.primaryBlue.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Row(
              children: [
                // الصورة مع تصميم مميز
                Hero(
                  tag: 'patient_${patient.id}',
                  child: Container(
                    width: 60,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: avatarUrl != null
                            ? [Colors.transparent, Colors.transparent]
                            : [
                                AppTheme.primaryBlue.withOpacity(0.1),
                                AppTheme.primaryBlue.withOpacity(0.05),
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: avatarUrl == null
                        ? const Icon(
                            Icons.person_rounded,
                            color: AppTheme.primaryBlue,
                            size: 32,
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: avatarUrl,
                              width: 60,
                              height: 80,
                              fit: BoxFit.cover,
                              memCacheHeight: 160,
                              memCacheWidth: 120,
                              maxHeightDiskCache: 200,
                              maxWidthDiskCache: 150,
                              placeholder: (context, url) => Container(
                                color: AppTheme.primaryBlue.withOpacity(0.1),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.person_rounded,
                                color: AppTheme.primaryBlue,
                                size: 32,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // المعلومات
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الاسم
                      Text(
                        patient.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // الهاتف
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.phone_rounded,
                              size: 14,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            patient.phone,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // شريط التقدم
                      Row(
                        children: [
                          Expanded(child: _PhasedProgressBar(patient: patient)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.successGreen,
                                  AppTheme.successGreen.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${progress.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // التاريخ وعدد الخطوات
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(patient.registrationDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.check_circle_outline, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                      Text(
                        '${patient.completedStepsCount}/${patient.steps.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // زر الحذف للمدير فقط
                if (isAdmin)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.errorRed,
                      size: 22,
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
      height: 8,
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
                  margin: EdgeInsets.only(right: i < 3 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
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
                            borderRadius: BorderRadius.circular(8),
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
