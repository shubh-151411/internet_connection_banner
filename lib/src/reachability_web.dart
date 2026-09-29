/// Raw lookups are unavailable in browsers; trust the interface state.
Future<bool> platformReachabilityCheck() async => true;
