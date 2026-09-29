import 'dart:async';

import 'connection_status.dart';
import 'connectivity_source.dart';

/// Watches connectivity and exposes it as a plain [Stream] + getter, so it
/// works with Provider, BLoC, Riverpod, GetX, or no state management at all.
class ConnectivityMonitor {
  ConnectivityMonitor({
    ConnectivitySource? source,
    ReachabilityChecker? reachabilityChecker,
    this.offlineDebounce = const Duration(seconds: 1),
    this.offlineRecheckInterval = const Duration(seconds: 5),
  })  : _source = source ?? ConnectivityPlusSource(),
        _checker = reachabilityChecker ?? defaultReachabilityChecker;

  /// Shared instance for apps that don't need custom configuration.
  static final ConnectivityMonitor instance = ConnectivityMonitor();

  /// How long a loss must persist before we report offline. Filters out
  /// brief flaps such as Wi-Fi <-> mobile handovers.
  final Duration offlineDebounce;

  /// While offline, how often to re-verify reachability (covers the case
  /// where an interface stays up and the internet silently returns).
  final Duration offlineRecheckInterval;

  final ConnectivitySource _source;
  final ReachabilityChecker _checker;
  final _controller = StreamController<ConnectionStatus>.broadcast();

  ConnectionStatus _status = ConnectionStatus.online;
  StreamSubscription<bool>? _subscription;
  Timer? _offlineTimer;
  Timer? _recheckTimer;
  int _generation = 0;
  bool _started = false;
  bool _disposed = false;

  /// Latest known status. Optimistically `online` until proven otherwise.
  ConnectionStatus get status => _status;
  bool get isOnline => _status == ConnectionStatus.online;

  /// Emits only when the status actually changes.
  Stream<ConnectionStatus> get onStatusChanged => _controller.stream;

  /// Begins monitoring. Safe to call more than once.
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _subscription = _source.onInterfaceChanged.listen(_evaluate);
    await _evaluate(await _source.hasNetworkInterface());
  }

  /// Forces an immediate re-check (e.g. from a "Retry" button).
  Future<void> refresh() async =>
      _evaluate(await _source.hasNetworkInterface(), immediate: true);

  Future<void> _evaluate(bool hasInterface, {bool immediate = false}) async {
    if (_disposed) return;
    final gen = ++_generation;
    final reachable = hasInterface && await _checker();
    if (_disposed || gen != _generation) return; // a newer check superseded us

    if (reachable) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      _set(ConnectionStatus.online);
    } else if (_status == ConnectionStatus.online) {
      _offlineTimer?.cancel();
      if (immediate || offlineDebounce == Duration.zero) {
        _set(ConnectionStatus.offline);
      } else {
        _offlineTimer = Timer(offlineDebounce, () {
          _offlineTimer = null;
          _set(ConnectionStatus.offline);
        });
      }
    }
  }

  void _set(ConnectionStatus next) {
    if (_disposed || next == _status) return;
    _status = next;
    _controller.add(next);
    _recheckTimer?.cancel();
    _recheckTimer = null;
    if (next == ConnectionStatus.offline) {
      _recheckTimer = Timer.periodic(offlineRecheckInterval, (_) async {
        try {
          _evaluate(await _source.hasNetworkInterface());
        } catch (_) {/* keep polling */}
      });
    }
  }

  /// Stops monitoring and closes the stream. Don't dispose [instance]
  /// unless the whole app is shutting down.
  Future<void> dispose() async {
    _disposed = true;
    _offlineTimer?.cancel();
    _recheckTimer?.cancel();
    await _subscription?.cancel();
    await _controller.close();
  }
}
