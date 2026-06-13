import 'dart:io';

class NetworkChecker {
  static Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
