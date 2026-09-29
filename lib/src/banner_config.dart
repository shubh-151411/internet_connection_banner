import 'package:flutter/material.dart';

/// Which edge of the screen the banner attaches to.
enum BannerPosition { top, bottom }

/// Visual and timing options for [ConnectivityBanner].
@immutable
class ConnectivityBannerConfig {
  const ConnectivityBannerConfig({
    this.offlineText = 'No internet connection',
    this.restoredText = 'Back online',
    this.offlineColor = const Color(0xFF424242),
    this.restoredColor = const Color(0xFF2E7D32),
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.none,
    ),
    this.height = 30,
    this.restoredDuration = const Duration(seconds: 2),
    this.animationDuration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.respectSafeArea = true,
    this.showReconnectingIndicator = true,
    this.indicatorColor = Colors.white54,
    this.showIcon = true,
    this.offlineIcon,
    this.restoredIcon,
    this.offlineDecoration,
    this.restoredDecoration,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.margin = EdgeInsets.zero,
    this.position = BannerPosition.top,
    this.interactive = false,
  });

  final String offlineText;
  final String restoredText;

  /// Background colors, ignored when the matching decoration is set.
  final Color offlineColor;
  final Color restoredColor;
  final TextStyle textStyle;

  /// Height of the banner content (safe area inset is added on top).
  final double height;

  /// How long the "back online" message stays before sliding away.
  final Duration restoredDuration;

  final Duration animationDuration;

  /// Curve of the default slide/fade transition.
  final Curve curve;

  /// Keep the banner clear of the status bar / notch (or the home indicator
  /// when [position] is [BannerPosition.bottom]).
  final bool respectSafeArea;

  /// Show a thin indeterminate progress line while offline.
  final bool showReconnectingIndicator;
  final Color indicatorColor;

  final bool showIcon;

  /// Replaces the default pulsing wifi-off icon, e.g. a Lottie animation.
  final Widget? offlineIcon;

  /// Replaces the default bouncing check icon.
  final Widget? restoredIcon;

  /// Full background styling (gradient, border radius, shadow...).
  /// Use [BoxDecoration] for both so the change animates smoothly.
  final Decoration? offlineDecoration;
  final Decoration? restoredDecoration;

  /// Space between the banner edge and its content.
  final EdgeInsets padding;

  /// Space around the banner. With a zero margin the background extends
  /// behind the status bar; with a non-zero margin the banner floats below
  /// it as a card.
  final EdgeInsets margin;

  final BannerPosition position;

  /// Let the banner receive taps (needed for e.g. a "Retry" button in a
  /// custom banner). When false, taps pass through to the app underneath.
  final bool interactive;

  ConnectivityBannerConfig copyWith({
    String? offlineText,
    String? restoredText,
    Color? offlineColor,
    Color? restoredColor,
    TextStyle? textStyle,
    double? height,
    Duration? restoredDuration,
    Duration? animationDuration,
    Curve? curve,
    bool? respectSafeArea,
    bool? showReconnectingIndicator,
    Color? indicatorColor,
    bool? showIcon,
    Widget? offlineIcon,
    Widget? restoredIcon,
    Decoration? offlineDecoration,
    Decoration? restoredDecoration,
    EdgeInsets? padding,
    EdgeInsets? margin,
    BannerPosition? position,
    bool? interactive,
  }) {
    return ConnectivityBannerConfig(
      offlineText: offlineText ?? this.offlineText,
      restoredText: restoredText ?? this.restoredText,
      offlineColor: offlineColor ?? this.offlineColor,
      restoredColor: restoredColor ?? this.restoredColor,
      textStyle: textStyle ?? this.textStyle,
      height: height ?? this.height,
      restoredDuration: restoredDuration ?? this.restoredDuration,
      animationDuration: animationDuration ?? this.animationDuration,
      curve: curve ?? this.curve,
      respectSafeArea: respectSafeArea ?? this.respectSafeArea,
      showReconnectingIndicator:
          showReconnectingIndicator ?? this.showReconnectingIndicator,
      indicatorColor: indicatorColor ?? this.indicatorColor,
      showIcon: showIcon ?? this.showIcon,
      offlineIcon: offlineIcon ?? this.offlineIcon,
      restoredIcon: restoredIcon ?? this.restoredIcon,
      offlineDecoration: offlineDecoration ?? this.offlineDecoration,
      restoredDecoration: restoredDecoration ?? this.restoredDecoration,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      position: position ?? this.position,
      interactive: interactive ?? this.interactive,
    );
  }
}
