## 0.1.0

- Initial release.
- `ConnectivityBanner` overlays a non-blocking banner when the internet drops
  and a short "Back online" confirmation when it returns.
- `ConnectivityMonitor` exposes connectivity as a `Stream` for any state
  management; debounces flaps and verifies real reachability.
- Customization through `ConnectivityBannerConfig` (text, colors, icons,
  decorations, margin, position, timing), a full `bannerBuilder`, and a
  custom `transitionBuilder`.
