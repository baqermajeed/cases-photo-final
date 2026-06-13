import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../core/utils/dialogs.dart';
import 'patients_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _authService.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      setState(() => _isLoading = true);
      try {
        await SyncService.instance.initialLoad(force: true);
        await SyncService.instance.syncNow();
      } catch (_) {}
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PatientsListScreen()),
      );
    } else {
      final msg = (result['message'] as String?) ?? 'فشل تسجيل الدخول';
      if (msg.contains('الإنترنت')) {
        await Dialogs.showNoInternetDialog(context);
      } else if (msg.contains('كلمة المرور') || msg.contains('اسم المستخدم')) {
        await Dialogs.showWarningDialog(context, 'اسم المستخدم أو كلمة المرور غير صحيحة');
      } else {
        final retry = await Dialogs.showErrorRetryDialog(context, msg);
        if (retry) {
          await _login();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundWhite,
              AppTheme.lightBlue.withOpacity(0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Image.asset(
                          'assets/images/new-farah.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Title
                    Text(
                      'Farah photographers',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'نظام إدارة حالات المرضى',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textGray,
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Username field
                    TextFormField(
                      controller: _usernameController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم',
                        hintText: 'أدخل اسم المستخدم',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال اسم المستخدم';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        hintText: 'أدخل كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال كلمة المرور';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),
                    
                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          elevation: 4,
                          shadowColor: AppTheme.primaryBlue.withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('تسجيل الدخول'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Footer text
                    Text(
                      'Farah photographers',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
