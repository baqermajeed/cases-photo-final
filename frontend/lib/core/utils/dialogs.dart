import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class Dialogs {
  static Future<void> showNoInternetDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('لا يوجد اتصال بالإنترنت'),
          content: const Text('يرجى التحقق من اتصالك بالشبكة ثم إعادة المحاولة.'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> showWarningDialog(BuildContext context, String message) {
    return showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تنبيه'),
          content: Text(message),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> showErrorRetryDialog(BuildContext context, String message) async {
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حدث خطأ'),
          content: Text(message),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
    return retry == true;
  }
}


