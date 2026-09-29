import 'package:internet_connection_banner/internet_connection_banner.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

/// Switch between the demo styles to see the customisation options.
enum DemoStyle { standard, floatingPill, custom }

const demoStyle = DemoStyle.standard;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // One line of integration. Toggle airplane mode to try it.
      builder: switch (demoStyle) {
        DemoStyle.standard => ConnectivityBanner.builder(),
        DemoStyle.floatingPill => ConnectivityBanner.builder(
            config: ConnectivityBannerConfig(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              offlineDecoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(24),
              ),
              restoredDecoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(24),
              ),
              height: 40,
              showReconnectingIndicator: false,
            ),
            transitionBuilder: (context, animation, child) => ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: FadeTransition(opacity: animation, child: child),
            ),
          ),
        DemoStyle.custom => ConnectivityBanner.builder(
            config: const ConnectivityBannerConfig(interactive: true),
            bannerBuilder: (context, d) => Container(
              color: d.isOffline ? Colors.red.shade700 : Colors.teal,
              padding: d.safeArea +
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    d.isOffline ? Icons.signal_wifi_off : Icons.wifi,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      d.message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (d.isOffline)
                    TextButton(
                      onPressed: d.retry,
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
      },
      home: const Scaffold(
        body: SafeArea(
          child: Center(child: Text('Toggle airplane mode to see the banner')),
        ),
      ),
    );
  }
}
