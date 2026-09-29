import 'dart:async';

import 'package:internet_connection_banner/internet_connection_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSource implements ConnectivitySource {
  final _c = StreamController<bool>.broadcast();
  bool up = true;

  void set(bool value) {
    up = value;
    _c.add(value);
  }

  @override
  Future<bool> hasNetworkInterface() async => up;

  @override
  Stream<bool> get onInterfaceChanged => _c.stream;
}

void main() {
  late FakeSource source;
  late ConnectivityMonitor monitor;

  setUp(() {
    source = FakeSource();
    monitor = ConnectivityMonitor(
      source: source,
      reachabilityChecker: () async => source.up,
      offlineDebounce: const Duration(milliseconds: 100),
      offlineRecheckInterval: const Duration(hours: 1),
    );
  });

  tearDown(() => monitor.dispose());

  Widget app({
    ConnectivityBannerConfig config = const ConnectivityBannerConfig(
      restoredDuration: Duration(seconds: 2),
    ),
    ConnectivityBannerBuilder? bannerBuilder,
    Widget home = const Scaffold(body: Center(child: Text('content'))),
  }) =>
      MaterialApp(
        builder: ConnectivityBanner.builder(
          monitor: monitor,
          config: config,
          bannerBuilder: bannerBuilder,
        ),
        home: home,
      );

  Future<void> goOffline(WidgetTester t) async {
    source.set(false);
    await t.pump(); // event delivered + reachability check
    await t.pump(const Duration(milliseconds: 150)); // debounce elapses
    await t.pump(const Duration(milliseconds: 400)); // slide-in
  }

  /// Restores connectivity and lets the banner hide, which also cancels the
  /// monitor's offline re-check timer.
  Future<void> goOnlineAndSettle(WidgetTester t) async {
    source.set(true);
    await t.pump();
    await t.pump(const Duration(seconds: 3));
    await t.pump(const Duration(milliseconds: 500));
  }

  testWidgets('shows nothing while online', (t) async {
    await t.pumpWidget(app());
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('No internet connection'), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('offline -> banner, online -> restored -> disappears',
      (t) async {
    await t.pumpWidget(app());
    await t.pump();

    await goOffline(t);
    expect(find.text('No internet connection'), findsOneWidget);

    source.set(true);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Back online'), findsOneWidget);

    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Back online'), findsNothing);
  });

  testWidgets('custom bannerBuilder receives phase and message', (t) async {
    await t.pumpWidget(app(
      bannerBuilder: (context, d) =>
          Text('${d.isOffline ? 'OFF' : 'ON'}: ${d.message}'),
    ));
    await t.pump();

    await goOffline(t);
    expect(find.text('OFF: No internet connection'), findsOneWidget);

    source.set(true);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('ON: Back online'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('custom icon and text replace defaults', (t) async {
    await t.pumpWidget(app(
      config: const ConnectivityBannerConfig(
        offlineText: 'You are offline',
        offlineIcon: Icon(Icons.cloud_off),
      ),
    ));
    await t.pump();
    await goOffline(t);
    expect(find.text('You are offline'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    await goOnlineAndSettle(t);
  });

  testWidgets('interactive banner can be tapped to retry', (t) async {
    var retries = 0;
    await t.pumpWidget(app(
      config: const ConnectivityBannerConfig(interactive: true),
      bannerBuilder: (context, d) => TextButton(
        onPressed: () {
          retries++;
          d.retry();
        },
        child: const Text('Retry'),
      ),
    ));
    await t.pump();
    await goOffline(t);

    await t.tap(find.text('Retry'));
    await t.pump();
    expect(retries, 1);
    await goOnlineAndSettle(t);
  });

  testWidgets('bottom position attaches banner to the bottom edge',
      (t) async {
    await t.pumpWidget(app(
      config: const ConnectivityBannerConfig(position: BannerPosition.bottom),
    ));
    await t.pump();
    await goOffline(t);

    final screen = t.getSize(find.byType(MaterialApp));
    final text = t.getCenter(find.text('No internet connection'));
    expect(text.dy, greaterThan(screen.height / 2));
    await goOnlineAndSettle(t);
  });

  testWidgets('brief drop shorter than debounce is ignored', (t) async {
    await t.pumpWidget(app());
    await t.pump();

    source.set(false);
    await t.pump(const Duration(milliseconds: 50));
    source.set(true);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('No internet connection'), findsNothing);
    expect(find.text('Back online'), findsNothing);
  });

  testWidgets('banner does not block taps on content', (t) async {
    var taps = 0;
    await t.pumpWidget(MaterialApp(
      builder: ConnectivityBanner.builder(monitor: monitor),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: TextButton(onPressed: () => taps++, child: const Text('tap')),
        ),
      ),
    ));
    await t.pump();
    source.set(false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));

    await t.tap(find.text('tap'));
    expect(taps, 1);
    await goOnlineAndSettle(t);
  });
}
