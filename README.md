# internet_connection_banner

A tiny Flutter package that shows a non-blocking banner at the top of your app
when the internet drops, and a short "Back online" confirmation when it returns
(the pattern used by PhonePe, Paytm, LinkedIn).

- Floats over your UI in a `Stack`, ignores touches, never shifts layout
- Fully customizable: config options, your own banner widget, your own animation
- Slide + fade animations, pulsing offline icon, animated check on restore
- Debounces flaps (Wi-Fi <-> mobile handover) and verifies real reachability
  (interface up but no internet, e.g. captive Wi-Fi)
- Works with any state management: it is just a widget + a `Stream`

## Install

```sh
flutter pub add internet_connection_banner
```

## Use

```dart
MaterialApp(
  builder: ConnectivityBanner.builder(),
  home: const HomePage(),
);
```

## Customize

There are three levels, from simple settings to a completely custom UI.
The package always handles detection, timing, positioning and not blocking
taps.

### 1. Config

```dart
builder: ConnectivityBanner.builder(
  config: ConnectivityBannerConfig(
    offlineText: 'You are offline',
    restoredText: 'Connected',
    offlineColor: Colors.black87,
    restoredColor: Colors.green,
    restoredDuration: const Duration(seconds: 3),
    offlineIcon: Lottie.asset('assets/no_wifi.json', width: 20), // any widget
    position: BannerPosition.bottom,
    // Floating pill: a margin makes the banner a card below the status bar.
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    offlineDecoration: BoxDecoration(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(24),
    ),
  ),
),
```

Other options: `textStyle`, `height`, `padding`, `showIcon`, `restoredIcon`,
`restoredDecoration`, `showReconnectingIndicator`, `indicatorColor`,
`animationDuration`, `curve`, `respectSafeArea`, `interactive`. Use
`copyWith` to tweak a shared config.

### 2. Your own banner

```dart
builder: ConnectivityBanner.builder(
  config: const ConnectivityBannerConfig(interactive: true), // allow taps
  bannerBuilder: (context, d) => Container(
    color: d.isOffline ? Colors.red : Colors.teal,
    padding: d.safeArea + const EdgeInsets.all(12),
    child: Row(children: [
      Expanded(child: Text(d.message)),
      if (d.isOffline) TextButton(onPressed: d.retry, child: const Text('Retry')),
    ]),
  ),
),
```

`BannerDetails` gives you `phase` / `isOffline`, `message`, `safeArea`
(status bar or home indicator inset), `config` and `retry`.

### 3. Your own animation

```dart
transitionBuilder: (context, animation, child) => ScaleTransition(
  scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
  child: FadeTransition(opacity: animation, child: child),
),
```

`animation` runs 0 to 1 when showing and 1 to 0 when hiding.

Android needs `ACCESS_NETWORK_STATE` (added by `connectivity_plus`).
Disable the default DNS reachability check by passing
`ConnectivityMonitor(reachabilityChecker: () async => true)`.

## Reacting to connectivity in your own code

Share one monitor with the banner and the rest of the app:

```dart
final monitor = ConnectivityMonitor.instance..start();

// plain Dart
monitor.onStatusChanged.listen((s) => print(s));
if (monitor.isOnline) { /* ... */ }
```

**Provider**
```dart
StreamProvider<ConnectionStatus>(
  create: (_) => ConnectivityMonitor.instance.onStatusChanged,
  initialData: ConnectionStatus.online,
  child: ...,
)
```

**Riverpod**
```dart
final connectionProvider = StreamProvider<ConnectionStatus>(
    (ref) => ConnectivityMonitor.instance.onStatusChanged);
```

**BLoC / Cubit**
```dart
class ConnectionCubit extends Cubit<ConnectionStatus> {
  ConnectionCubit(this._m) : super(_m.status) {
    _sub = _m.onStatusChanged.listen(emit);
  }
  final ConnectivityMonitor _m;
  late final StreamSubscription _sub;
  @override
  Future<void> close() { _sub.cancel(); return super.close(); }
}
```

Pass the same monitor to the banner:
`ConnectivityBanner.builder(monitor: ConnectivityMonitor.instance)`.

## Custom backend / testing

Implement `ConnectivitySource` (two members) to swap `connectivity_plus` or
fake connectivity in tests, see `test/internet_connection_banner_test.dart`.
