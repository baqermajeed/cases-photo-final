import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/patients_list_screen.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // Initialize intl for Arabic date formatting
  await initializeDateFormatting('ar');
  await SyncService.instance.initialize();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, 
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const FarahDentApp());
}

class GlowOnlyScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: AppTheme.primaryBlue.withOpacity(0.25),
      child: child,
    );
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // إلغاء الـ bounce/strech والاكتفاء بالـ clamping + glow
    return const ClampingScrollPhysics();
  }
}

class FarahDentApp extends StatelessWidget {
  const FarahDentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farah photographers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // منع تغيير قياسات النصوص تبعاً لإعدادات الجهاز
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          // تثبيت عامل التكبير للنصوص على 1.0
          data: mq.copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
      scrollBehavior: GlowOnlyScrollBehavior(),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    bool isLoggedIn = false;
    try {
      isLoggedIn = await _authService
          .isLoggedIn()
          .timeout(const Duration(seconds: 4), onTimeout: () => false);
    } catch (_) {
      isLoggedIn = false;
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isLoggedIn
            ? const PatientsListScreen()
            : const LoginScreen(),
      ),
    );
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                child: const Icon(
                  Icons.local_hospital_rounded,
                  size: 60,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Farah photographers',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
