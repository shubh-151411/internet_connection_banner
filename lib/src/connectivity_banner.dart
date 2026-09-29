import 'dart:async';

import 'package:flutter/material.dart';

import 'banner_config.dart';
import 'connection_status.dart';
import 'connectivity_monitor.dart';

/// What the banner is currently telling the user.
enum BannerPhase { offline, restored }

/// Everything a custom [ConnectivityBannerBuilder] needs to render a banner.
@immutable
class BannerDetails {
  const BannerDetails({
    required this.phase,
    required this.message,
    required this.safeArea,
    required this.config,
    required this.retry,
  });

  final BannerPhase phase;

  /// [ConnectivityBannerConfig.offlineText] or
  /// [ConnectivityBannerConfig.restoredText], depending on [phase].
  final String message;

  /// System inset on the edge the banner is attached to (status bar for
  /// top, home indicator for bottom). Zero when `respectSafeArea` is false.
  final EdgeInsets safeArea;

  final ConnectivityBannerConfig config;

  /// Re-checks connectivity right away. Requires
  /// [ConnectivityBannerConfig.interactive] to be tappable.
  final VoidCallback retry;

  bool get isOffline => phase == BannerPhase.offline;
}

/// Builds the whole banner. The package still handles positioning,
/// show/hide timing and the entrance/exit transition.
typedef ConnectivityBannerBuilder = Widget Function(
    BuildContext context, BannerDetails details);

/// Animates the banner in and out. [animation] runs 0 -> 1 on show and
/// 1 -> 0 on hide.
typedef BannerTransitionBuilder = Widget Function(
    BuildContext context, Animation<double> animation, Widget child);

/// Wraps your app and overlays a slim banner when the connection drops,
/// then a short "back online" confirmation when it returns.
///
/// The banner floats above the content in a [Stack] and, unless
/// [ConnectivityBannerConfig.interactive] is set, ignores pointer events,
/// so it never shifts layout or blocks taps.
///
/// ```dart
/// MaterialApp(
///   builder: ConnectivityBanner.builder(),
///   home: const HomePage(),
/// );
/// ```
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({
    super.key,
    required this.child,
    this.monitor,
    this.config = const ConnectivityBannerConfig(),
    this.bannerBuilder,
    this.transitionBuilder,
  });

  final Widget child;

  /// Provide your own (e.g. shared/DI-managed) monitor. When null, a private
  /// one is created and disposed with this widget.
  final ConnectivityMonitor? monitor;

  final ConnectivityBannerConfig config;

  /// Replaces the default banner UI entirely.
  final ConnectivityBannerBuilder? bannerBuilder;

  /// Replaces the default slide + fade transition.
  final BannerTransitionBuilder? transitionBuilder;

  /// Drop-in for [MaterialApp.builder] / [CupertinoApp.builder].
  static TransitionBuilder builder({
    ConnectivityMonitor? monitor,
    ConnectivityBannerConfig config = const ConnectivityBannerConfig(),
    ConnectivityBannerBuilder? bannerBuilder,
    BannerTransitionBuilder? transitionBuilder,
  }) {
    return (context, child) => ConnectivityBanner(
          monitor: monitor,
          config: config,
          bannerBuilder: bannerBuilder,
          transitionBuilder: transitionBuilder,
          child: child ?? const SizedBox.shrink(),
        );
  }

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late ConnectivityMonitor _monitor;
  late bool _ownsMonitor;
  StreamSubscription<ConnectionStatus>? _sub;
  Timer? _hideTimer;

  bool _visible = false;
  BannerPhase _phase = BannerPhase.offline; // kept while sliding out

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: widget.config.animationDuration,
    )..addStatusListener(_onAnimationStatus);
    _attach();
  }

  void _onAnimationStatus(AnimationStatus status) {
    // Drop the banner from the tree once fully hidden.
    if (status == AnimationStatus.dismissed && mounted) setState(() {});
  }

  void _attach() {
    _ownsMonitor = widget.monitor == null;
    _monitor = widget.monitor ?? ConnectivityMonitor();
    _sub = _monitor.onStatusChanged.listen(_onStatus);
    _monitor.start();
    if (!_monitor.isOnline) _onStatus(ConnectionStatus.offline);
  }

  void _detach() {
    _sub?.cancel();
    _hideTimer?.cancel();
    if (_ownsMonitor) _monitor.dispose();
  }

  @override
  void didUpdateWidget(ConnectivityBanner old) {
    super.didUpdateWidget(old);
    _anim.duration = widget.config.animationDuration;
    if (old.monitor != widget.monitor) {
      _detach();
      _visible = false;
      _anim.value = 0;
      _attach();
    }
  }

  void _onStatus(ConnectionStatus status) {
    if (!mounted) return;
    _hideTimer?.cancel();
    if (status == ConnectionStatus.offline) {
      setState(() {
        _phase = BannerPhase.offline;
        _visible = true;
      });
      _anim.forward();
    } else if (_visible) {
      // Only celebrate if we actually showed the offline banner.
      setState(() => _phase = BannerPhase.restored);
      _hideTimer = Timer(widget.config.restoredDuration, () {
        if (!mounted) return;
        _visible = false;
        _anim.reverse();
      });
    }
  }

  @override
  void dispose() {
    _detach();
    _anim.dispose();
    super.dispose();
  }

  Widget _defaultTransition(
      BuildContext context, Animation<double> animation, Widget child) {
    final c = widget.config;
    final curved = CurvedAnimation(parent: animation, curve: c.curve);
    return SlideTransition(
      position: Tween(
        begin: Offset(0, c.position == BannerPosition.top ? -1 : 1),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final isTop = c.position == BannerPosition.top;
    final padding = MediaQuery.maybeOf(context)?.padding ?? EdgeInsets.zero;
    final safeArea = !c.respectSafeArea
        ? EdgeInsets.zero
        : isTop
            ? EdgeInsets.only(top: padding.top)
            : EdgeInsets.only(bottom: padding.bottom);
    final details = BannerDetails(
      phase: _phase,
      message:
          _phase == BannerPhase.offline ? c.offlineText : c.restoredText,
      safeArea: safeArea,
      config: c,
      retry: _monitor.refresh,
    );

    final content = widget.bannerBuilder?.call(context, details) ??
        _DefaultBanner(details: details);
    final transition = widget.transitionBuilder ?? _defaultTransition;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_anim.isDismissed)
          Positioned(
            top: isTop ? 0 : null,
            bottom: isTop ? null : 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !c.interactive || !_visible,
              child: transition(
                context,
                _anim,
                Semantics(
                  liveRegion: true,
                  label: details.message,
                  // Gives custom banners a Material ancestor (ink, text
                  // style) since MaterialApp.builder sits above Scaffold.
                  child: Material(
                    type: MaterialType.transparency,
                    child: content,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DefaultBanner extends StatelessWidget {
  const _DefaultBanner({required this.details});

  final BannerDetails details;

  @override
  Widget build(BuildContext context) {
    final c = details.config;
    final isOffline = details.isOffline;
    final isTop = c.position == BannerPosition.top;
    final floating = c.margin != EdgeInsets.zero;
    final decoration =
        (isOffline ? c.offlineDecoration : c.restoredDecoration) ??
            BoxDecoration(color: isOffline ? c.offlineColor : c.restoredColor);

    final indicator = c.showReconnectingIndicator
        ? SizedBox(
            height: 2,
            child: isOffline
                ? LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    color: c.indicatorColor,
                  )
                : null,
          )
        : null;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isTop && indicator != null) indicator,
        Container(
          height: c.height,
          padding: c.padding,
          child: AnimatedSwitcher(
            duration: c.animationDuration,
            child: _Content(
              key: ValueKey(details.phase),
              details: details,
            ),
          ),
        ),
        if (isTop && indicator != null) indicator,
      ],
    );

    return Padding(
      padding: floating ? c.margin + details.safeArea : EdgeInsets.zero,
      child: AnimatedContainer(
        duration: c.animationDuration,
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        padding: floating ? EdgeInsets.zero : details.safeArea,
        child: body,
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({super.key, required this.details});

  final BannerDetails details;

  @override
  Widget build(BuildContext context) {
    final c = details.config;
    final iconColor = c.textStyle.color ?? Colors.white;
    Widget? icon;
    if (c.showIcon) {
      icon = details.isOffline
          ? c.offlineIcon ??
              _Pulse(
                child:
                    Icon(Icons.wifi_off_rounded, size: 16, color: iconColor),
              )
          : c.restoredIcon ??
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Icon(Icons.check_circle_rounded,
                    size: 16, color: iconColor),
              );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[icon, const SizedBox(width: 8)],
        Flexible(
          child: Text(
            details.message,
            style: c.textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Gentle looping fade used on the offline icon.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.4, end: 1.0).animate(_c),
        child: widget.child,
      );
}
