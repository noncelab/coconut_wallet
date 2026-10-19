import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/system_chrome_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _themes = [
  (variant: CoconutThemeVariant.dark, background: Brightness.dark, icons: Brightness.light),
  (variant: CoconutThemeVariant.light, background: Brightness.light, icons: Brightness.dark),
  (variant: CoconutThemeVariant.coconutTheme, background: Brightness.light, icons: Brightness.dark),
];

void main() {
  tearDown(() => buildCoconutThemeData());

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final theme in _themes) {
      testWidgets('${platform.name} app bars keep readable status icons in ${theme.variant.name}', (tester) async {
        for (final withNext in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCoconutThemeData(variant: theme.variant).copyWith(platform: platform),
              home: Builder(
                builder:
                    (context) => Scaffold(
                      appBar:
                          withNext
                              ? CoconutAppBar.buildWithNext(context: context, title: 'Next', onNextPressed: () {})
                              : CoconutAppBar.build(context: context, title: 'Wallet'),
                    ),
              ),
            ),
          );

          final style = tester.widget<AppBar>(find.byType(AppBar)).systemOverlayStyle!;
          expect(style.statusBarBrightness, theme.background);
          expect(style.statusBarIconBrightness, theme.icons);
          expect(style.statusBarColor, isNull);
          expect(style.systemNavigationBarColor, isNull);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('theme changes update iOS status brightness and preserve Android bar colors', (tester) async {
    final overlays = <Map<dynamic, dynamic>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
        overlays.add(call.arguments as Map<dynamic, dynamic>);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    for (final theme in [..._themes, _themes.first]) {
      updateSystemBarColor(theme.variant);
      await tester.pump();

      final style = overlays.last;
      final color = resolveCoconutThemeExtension(variant: theme.variant).colors.background.toARGB32();
      expect(style['statusBarBrightness'], theme.background.toString());
      expect(style['statusBarIconBrightness'], theme.icons.toString());
      expect(style['statusBarColor'], color);
      expect(style['systemNavigationBarColor'], color);
      expect(style['systemNavigationBarDividerColor'], color);
      expect(style['systemNavigationBarIconBrightness'], theme.icons.toString());
    }
  });
}
