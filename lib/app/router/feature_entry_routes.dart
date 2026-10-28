import 'package:flutter/widgets.dart';

/// All Features·바로가기로 연 첫 화면을 기억한다. 이런 화면의 앱 바는 뒤로가기 대신 닫기(X) 버튼을 보여 준다.
class FeatureEntryRoutes extends NavigatorObserver {
  static final instance = FeatureEntryRoutes._();

  FeatureEntryRoutes._();

  final Set<Route<dynamic>> _routes = {};
  bool _armed = false;

  /// [launch]가 처음 여는 페이지를 기능 진입 화면으로 표시한다. 지갑 고르기 같은 팝업은 건너뛴다.
  Future<void> launching(Future<void> Function() launch) async {
    _armed = true;
    try {
      await launch();
    } finally {
      _armed = false;
    }
  }

  bool contains(Route<dynamic>? route) => route != null && _routes.contains(route);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_armed || route is! PageRoute) return;
    _armed = false;
    _routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null && _routes.remove(oldRoute) && newRoute != null) _routes.add(newRoute);
  }
}
