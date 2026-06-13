import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import 'login_screen.dart';
import 'statistics_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
} 

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد تسجيل الخروج'),
          content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
              ),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      await _authService.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الحساب'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _user == null
                ? const Center(child: Text('فشل في تحميل البيانات'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Profile avatar
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.lightBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 50,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Name
                        Text(
                          _user!.fullName,
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '@${_user!.username}',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textGray,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // إحصائيات متاحة للجميع (المصورين والمديرين)
                        ..._buildAdminSection(),

                        const SizedBox(height: 24),

                        // Info cards
                        _InfoCard(
                          icon: Icons.badge_outlined,
                          title: 'الاسم الكامل',
                          value: _user!.fullName,
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'الصلاحية',
                          value: _user!.isAdmin ? 'مدير' : 'مصور',
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          icon: Icons.person_outline_rounded,
                          title: 'اسم المستخدم',
                          value: _user!.username,
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          icon: Icons.calendar_today_outlined,
                          title: 'تاريخ الإنشاء',
                          value: intl.DateFormat('dd/MM/yyyy', 'ar')
                              .format(_user!.createdAt),
                        ),
                        const SizedBox(height: 40),

                        // Logout button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorRed,
                            ),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('تسجيل الخروج'),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  List<Widget> _buildAdminSection() {
    return [
      // عنوان القسم
      const Text(
        'لوحة التحكم',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.textDark,
        ),
      ),
      const SizedBox(height: 16),
      // زر الإحصائيات
      _AdminButton(
        icon: Icons.analytics_outlined,
        title: 'الإحصائيات',
        subtitle: 'عرض إحصائيات المرضى',
        color: AppTheme.primaryBlue,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StatisticsScreen()),
          );
        },
      ),
      // تمت إزالة زر المرضى المكتملين حسب المتطلبات
    ];
  }
}

class _AdminButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                color: color,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryBlue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
