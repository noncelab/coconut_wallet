import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/onboarding/start_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/app_version_service.dart';
import 'package:coconut_wallet/services/model/response/app_version_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../analytics/screen_view_recorder.dart';
import '../safety/safety_test_harness.dart' show findText;

class _LatestVersion extends Fake implements AppVersion {
  _LatestVersion(this.version);

  final String version;

  @override
  Future<dynamic> getLatestAppVersion() async => AppVersionResponse(latestVersion: version);
}

class _Visibility extends Fake with ChangeNotifier implements VisibilityProvider {
  @override
  bool get hasLaunchedBefore => true;

  @override
  String? get lastRunAppVersion => '1.0.0';

  @override
  int get walletCount => 0;
}

class _Auth extends Fake with ChangeNotifier implements AuthProvider {
  @override
  bool get isAuthEnabled => false;

  @override
  bool get isBiometricsAuthEnabled => false;
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  String get language => 'kr';
}

void main() {
  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'coconut_wallet',
      packageName: 'com.coconut.wallet',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({});
    // ignore: deprecated_member_use_from_same_package
    SharedPrefsRepository().setSharedPreferencesForTest(await SharedPreferences.getInstance());
  });

  // T5-21: 앱을 열 때 뜨는 업데이트 안내가 화면 기록에 남는다. [업데이트]를 누르지 않은 사람까지 본 사람 수를 셀 수 있다
  testWidgets('analytics: the start-screen update dialog is recorded by name', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    // 시작 화면이 루트일 때 앱은 루트를 splash로 남긴다(app.dart). 팝업을 닫은 다음 프레임에도 아직 splash 단계다
    final recorder = ScreenViewRecorder(rootName: AnalyticsScreenNames.splash);
    AppEntryFlow? next;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<VisibilityProvider>.value(value: _Visibility()),
          ChangeNotifierProvider<AuthProvider>.value(value: _Auth()),
          ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences()),
          Provider<AnalyticsService>.value(value: recorder),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          navigatorObservers: [recorder.observer],
          home: StartScreen(onComplete: (flow) => next = flow, appVersionRepository: _LatestVersion('2.0.0')),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(findText(t.alert.update.title), findsOneWidget);

    await tester.tap(findText(t.alert.update.btn_do_later));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(next, AppEntryFlow.main);
    expect(recorder.names, ['splash', 'splash-update-dialog', 'splash']);
    expect(recorder.names[1], AnalyticsScreenNames.splashUpdateDialog);
  });
}
