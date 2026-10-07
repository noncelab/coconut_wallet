import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Named pages that log their own screen_view, like the unnamed CCOS pages
/// (coconut_open_store_first_pow_scene.dart): the observer leaves them out and the page mixes in
/// [SelfLoggedScreenView] to log its name with the visible segment (utxo_organizer_screen.dart,
/// utxo_overview_screen.dart).
const analyticsSelfLoggedRouteNames = {AppRouteNames.utxoOrganizer, AppRouteNames.utxoOverview};

/// The screen name the observer reports for [settings]: its route name, unless the page logs its own.
String? analyticsRouteScreenName(RouteSettings settings) =>
    analyticsSelfLoggedRouteNames.contains(settings.name) ? null : settings.name;

/// screen_view of a page in [analyticsSelfLoggedRouteNames]: [analyticsScreenName] with [analyticsParameters]
/// (the visible segment) when first shown, on top again after a page or sheet above it closes, and on
/// [logScreenViewIfChanged] after a segment change. Once per appearance, like the observer: not again when only an
/// unnamed popup closed above it.
mixin SelfLoggedScreenView<T extends StatefulWidget> on State<T> {
  String get analyticsScreenName;
  Map<String, Object> get analyticsParameters;

  bool _isCurrent = false;

  void logScreenViewIfChanged() {
    final analytics = context.read<AnalyticsService>();
    if (analytics.isLastScreenView(analyticsScreenName, analyticsParameters)) return;
    analytics.logScreenView(screenName: analyticsScreenName, parameters: analyticsParameters);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isCurrent = ModalRoute.isCurrentOf(context) ?? false;
    if (isCurrent && !_isCurrent) logScreenViewIfChanged();
    _isCurrent = isCurrent;
  }
}

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
