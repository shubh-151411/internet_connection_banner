import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'reachability_web.dart' if (dart.library.io) 'reachability_io.dart';

/// Tells the monitor whether the device has *any* network interface up
/// (Wi-Fi, mobile, ethernet...). Implement this to plug in another backend
/// or to fake connectivity in tests.
abstract class ConnectivitySource {
  /// Current state of the network interfaces.
  Future<bool> hasNetworkInterface();

  /// Emits whenever the interface state changes.
  Stream<bool> get onInterfaceChanged;
}

/// Default [ConnectivitySource] backed by `connectivity_plus`.
class ConnectivityPlusSource implements ConnectivitySource {
  ConnectivityPlusSource([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _any(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> hasNetworkInterface() async =>
      _any(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onInterfaceChanged =>
      _connectivity.onConnectivityChanged.map(_any);
}

/// Confirms that the internet is actually reachable (an interface can be up
/// with no real connection, e.g. captive Wi-Fi). Return `true` when online.
typedef ReachabilityChecker = Future<bool> Function();

/// Default reachability check: a DNS lookup with a short timeout.
/// Always returns `true` on web, where raw lookups are unavailable.
Future<bool> defaultReachabilityChecker() => platformReachabilityCheck();
