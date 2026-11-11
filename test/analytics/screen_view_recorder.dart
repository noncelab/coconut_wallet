import 'dart:convert';

import 'package:coconut_wallet/analytics/analytics_screen_observer.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/widgets.dart';

/// 화면 기록(screen_view)을 앱과 같은 규칙으로 모은다.
/// 라우트 화면은 앱 관찰자와 같은 [analyticsRouteScreenName]으로 이름을 정하고, 스스로 기록하는 화면(SelfLoggedScreenView)은
/// 이 서비스를 Provider로 받아 이름과 파라미터를 남긴다. 기록마다 `SCREEN_VIEW <이름> <파라미터 JSON>` 한 줄을 출력한다.
class ScreenViewRecorder extends AnalyticsService {
  ScreenViewRecorder({this.rootName}) : super(null, false);

  /// 루트 화면('/')의 이름. 앱은 루트를 진입 단계에 따라 splash·pin-check·wallet-home 등으로 남긴다
  /// (app.dart의 `_extractAnalyticsScreenName`). null이면 다른 라우트처럼 `/`로 남긴다
  final String? rootName;

  /// (화면 이름, 파라미터) 기록 순서대로
  final views = <(String, Map<String, Object>)>[];

  late final observer = AnalyticsScreenObserver(
    logScreenView: (name) => logScreenView(screenName: name),
    nameExtractor:
        (settings) =>
            rootName != null && settings.name == Navigator.defaultRouteName
                ? rootName
                : analyticsRouteScreenName(settings),
  );

  List<String> get names => [for (final (name, _) in views) name];

  @override
  Future<void> logScreenView({required String screenName, Map<String, Object>? parameters}) {
    final normalized = AnalyticsService.normalizeParameters(parameters);
    views.add((screenName, normalized));
    debugPrint('SCREEN_VIEW $screenName ${jsonEncode(normalized)}');
    return super.logScreenView(screenName: screenName, parameters: parameters);
  }
}
