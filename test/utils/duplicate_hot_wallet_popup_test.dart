import 'package:coconut_design_system/coconut_design_system.dart' show CoconutCheckbox;
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/wallet_sync_result_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 문구는 `t`(테스트 기본 로케일)에서 읽고, languageCode는 줄바꿈 처리 분기만 고른다(en = 단어 결합 없음).
Widget _host(void Function(BuildContext) onOpen) => MaterialApp(
  theme: buildCoconutThemeData(variant: CoconutThemeVariant.values.first),
  home: Builder(
    builder: (context) => Scaffold(body: TextButton(onPressed: () => onOpen(context), child: const Text('open'))),
  ),
);

void main() {
  testWidgets('both add paths share the duplicate popup: ticking removal reveals the mnemonic warning', (tester) async {
    ({bool removeHotWallet})? choice;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.values.first),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    choice = await showDuplicateHotWalletPopup(
                      context,
                      existingWalletName: 'Daily',
                      languageCode: 'en',
                    );
                    closed = true;
                  },
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final warning = t.wallet_home_screen.hot_wallet_restore.remove_hot_wallet_warning;
    expect(find.textContaining(warning), findsNothing);

    await tester.tap(find.byType(CoconutCheckbox));
    await tester.pumpAndSettle();
    expect(find.textContaining(warning), findsOneWidget);

    await tester.tap(find.text(t.wallet_home_screen.add_wallet_action));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(choice?.removeHotWallet, isTrue);
  });

  testWidgets('adding without ticking keeps the hot wallet', (tester) async {
    ({bool removeHotWallet})? choice;
    await tester.pumpWidget(
      _host((context) async {
        choice = await showDuplicateHotWalletPopup(context, existingWalletName: 'Daily', languageCode: 'en');
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.wallet_home_screen.add_wallet_action));
    await tester.pumpAndSettle();
    expect(choice?.removeHotWallet, isFalse);
  });

  // 체크하면 경고 전체가 스크롤 없이 보여야 한다(못 보고 지우면 안 됨). 실제 글꼴·로케일이어야 재현된다:
  // 상한이 없으면 de·es 320×568·2배에서 버튼이 밀려나고(Codex M37 v2 B1), ja·de·es 360×640·3배에서 경고 칸이 0이 된다.
  group('large text with real fonts', () {
    setUpAll(() async {
      for (final family in ['Pretendard', 'SpaceGrotesk']) {
        await (FontLoader(family)
              ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
              ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf')))
            .load();
      }
    });

    Future<({Finder warning, Rect popup, ({bool removeHotWallet})? Function() choice})> openAndTick(
      WidgetTester tester,
      AppLocale locale,
      Size screen,
      double scale,
    ) async {
      final previousLocale = LocaleSettings.currentLocale;
      LocaleSettings.setLocaleSync(locale);
      addTearDown(() => LocaleSettings.setLocaleSync(previousLocale));
      tester.view
        ..physicalSize = screen
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      ({bool removeHotWallet})? choice;
      await tester.pumpWidget(
        _host((context) async {
          choice = await showDuplicateHotWalletPopup(
            context,
            existingWalletName: 'Daily',
            languageCode: locale.languageCode,
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CoconutCheckbox));
      await tester.pumpAndSettle();
      // 한국어 팝업은 단어 안 줄바꿈을 막는 결합 문자를 넣어 그린다
      final warningText = t.wallet_home_screen.hot_wallet_restore.remove_hot_wallet_warning;
      return (
        warning: find.textContaining(
          locale == AppLocale.ko ? TextUtils.preventLineBreakInsideWords(warningText) : warningText,
        ),
        popup: tester.getRect(find.descendant(of: find.byType(Dialog), matching: find.byType(ClipRRect)).first),
        choice: () => choice,
      );
    }

    for (final locale in [AppLocale.ko, AppLocale.en, AppLocale.ja, AppLocale.es, AppLocale.de]) {
      for (final (screen, scale) in [
        (const Size(320, 568), 2.0),
        (const Size(360, 640), 3.0),
        (const Size(390, 844), 3.0),
      ]) {
        testWidgets('${locale.languageCode} ${screen.width.toInt()}x${screen.height.toInt()} @${scale}x: '
            'the whole warning shows without scrolling and the add button works', (tester) async {
          final opened = await openAndTick(tester, locale, screen, scale);
          final viewport = tester.getRect(
            find.ancestor(of: opened.warning, matching: find.byType(SingleChildScrollView)).first,
          );
          final warning = tester.getRect(opened.warning);
          expect(warning.top, greaterThanOrEqualTo(viewport.top));
          expect(warning.bottom, lessThanOrEqualTo(viewport.bottom));
          expect(viewport.bottom, lessThanOrEqualTo(opened.popup.bottom));

          await tester.tap(find.text(t.wallet_home_screen.add_wallet_action));
          await tester.pumpAndSettle();
          expect(opened.choice()?.removeHotWallet, isTrue);
        });
      }
    }

    // 아주 작은 화면에서는 경고만 스크롤된다. 끝까지 읽을 수 있고 버튼은 팝업 안에 남는다
    testWidgets('de 320x480 @2x: the warning scrolls to its end inside the popup', (tester) async {
      final opened = await openAndTick(tester, AppLocale.de, const Size(320, 480), 2);
      await tester.drag(
        find.ancestor(of: opened.warning, matching: find.byType(SingleChildScrollView)).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(opened.warning).bottom, lessThanOrEqualTo(opened.popup.bottom));
      await tester.tap(find.text(t.wallet_home_screen.add_wallet_action));
      await tester.pumpAndSettle();
      expect(opened.choice()?.removeHotWallet, isTrue);
    });
  });
}
