import 'dart:io' show InternetAddress;

/// DNS lookup with a short timeout.
Future<bool> platformReachabilityCheck() async {
  try {
    final result = await InternetAddress.lookup('one.one.one.one')
        .timeout(const Duration(seconds: 3));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}
