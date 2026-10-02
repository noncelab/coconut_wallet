import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';

/// Records the visible named page/sheet once per frame, including dismissals.
class AnalyticsScreenObserver extends NavigatorObserver {
  AnalyticsScreenObserver({required this.logScreenView, this.nameExtractor = defaultNameExtractor});

  final ValueChanged<String> logScreenView;
  final ScreenNameExtractor nameExtractor;

  Route<dynamic>? _topRoute;
  Route<dynamic>? _lastReportedRoute;
  String? _lastReportedName;
  bool _isScheduled = false;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _topRoute = topRoute;
    refreshScreenName();
  }

  /// The root route also switches splash/PIN/home without changing routes.
  void refreshScreenName() {
    if (_topRoute == null || _isScheduled) return;
    _isScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isScheduled = false;
      final route = _topRoute;
      if (route == null || !route.isCurrent || (route is! PageRoute && route is! PopupRoute)) {
        return;
      }
      final name = nameExtractor(route.settings);
      if (name == null || name.isEmpty) {
        // Unnamed pages may log their own internal screens (for example CCOS).
        if (route is PageRoute) {
          _lastReportedRoute = null;
          _lastReportedName = null;
        }
        return;
      }
      if (route == _lastReportedRoute && name == _lastReportedName) {
        return;
      }
      _lastReportedRoute = route;
      _lastReportedName = name;
      logScreenView(name);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
