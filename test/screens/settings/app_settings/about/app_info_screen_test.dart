import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/settings/app_settings/about/app_info_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');

  for (final (locale, termsUrl, privacyUrl) in [
    (AppLocale.ko, 'https://www.coconut.onl/tos', 'https://www.coconut.onl/privacy'),
    (AppLocale.en, 'https://www.coconut.onl/tos', 'https://www.coconut.onl/privacy'),
    (AppLocale.ja, 'https://www.coconut.onl/tos', 'https://www.coconut.onl/privacy'),
    (AppLocale.es, 'https://www.coconut.onl/tos', 'https://www.coconut.onl/privacy'),
    (AppLocale.de, 'https://www.coconut.onl/tos', 'https://www.coconut.onl/privacy'),
    (AppLocale.th, 'https://www.coconut.onl/en/tos', 'https://www.coconut.onl/en/privacy'),
  ]) {
    testWidgets('${locale.languageCode}: terms and privacy buttons open the locale-specific URLs externally', (
      tester,
    ) async {
      LocaleSettings.setLocaleSync(locale);
      addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
      PackageInfo.setMockInitialValues(
        appName: 'Coconut Wallet',
        packageName: 'onl.coconut.wallet',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      final launches = <Map<dynamic, dynamic>>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'canLaunch':
            return true;
          case 'launch':
            launches.add(call.arguments as Map<dynamic, dynamic>);
            return true;
          default:
            throw StateError('Unexpected URL launcher method: ${call.method}');
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        Provider<AnalyticsService>.value(
          value: AnalyticsService(null, true),
          child: MaterialApp(theme: buildCoconutThemeData(), home: const AppInfoScreen()),
        ),
      );
      await tester.pumpAndSettle();

      for (final title in [t.app_info_screen.terms_of_service, t.app_info_screen.privacy_policy]) {
        final button = find.byWidgetPredicate((widget) => widget is SingleButton && widget.title == title);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      expect(launches.map((call) => call['url']), [termsUrl, privacyUrl]);
      for (final call in launches) {
        expect(call['useSafariVC'], isFalse);
        expect(call['useWebView'], isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
