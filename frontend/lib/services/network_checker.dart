import 'dart:io';

import '../core/constants/api_constants.dart';

class NetworkChecker {
  static Future<bool> hasInternet() async {
    // First boot can produce transient false negatives, so retry briefly.
    for (var attempt = 0; attempt < 2; attempt++) {
      if (await _checkHost(ApiConstants.baseUrl)) return true;
      if (await _checkHost('one.one.one.one')) return true;
      if (await _checkHost('google.com')) return true;

      if (attempt == 0) {
        await Future.delayed(const Duration(milliseconds: 700));
      }
    }
    return false;
  }

  static Future<bool> _checkHost(String hostOrUrl) async {
    try {
      final host = _extractHost(hostOrUrl);
      if (host.isEmpty) return false;

      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String _extractHost(String hostOrUrl) {
    final uri = Uri.tryParse(hostOrUrl);
    if (uri != null && uri.hasAuthority && uri.host.isNotEmpty) {
      return uri.host;
    }
    return hostOrUrl;
  }
}
