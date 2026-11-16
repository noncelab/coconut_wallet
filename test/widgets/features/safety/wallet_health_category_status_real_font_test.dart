import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../screens/safety/wallet_health_fixtures.dart';

int _lines(RenderParagraph paragraph, int start, int end) =>
    paragraph
        .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end))
        .map((box) => box.top.round())
        .toSet()
        .length;

void main() {
  setUpAll(() async {
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf')))
          .load();
    }
  });

  // ja는 저장소 글꼴에 한자 글리프가 없어 실제 글꼴로 잴 수 없으므로 뺀다(wallet_health_about_layout_test와 같음)
  for (final locale in [AppLocale.ko, AppLocale.en, AppLocale.de, AppLocale.es]) {
    testWidgets('${locale.languageCode}: category statuses fit in two lines at 320 dp without splitting words', (
      tester,
    ) async {
      await pumpWalletHealthApp(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: WalletHealthCategoryGrid(report: notEnoughDataReport(), isChecking: false, onTap: (_) {}),
          ),
        ),
        width: 320,
        locale: locale,
        variant: CoconutThemeVariant.dark,
      );
      expect(tester.takeException(), isNull);

      final problems = <String>[];
      for (final category in SafetyCategory.values) {
        final status = find.descendant(
          of: find.byKey(Key('wallet-health-category-${category.name}')),
          matching: find.byWidgetPredicate((widget) => widget is Text && widget.maxLines == 2),
        );
        expect(status, findsOneWidget, reason: category.name);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: status, matching: find.byType(RichText)),
        );
        final text = paragraph.text.toPlainText();
        expect(paragraph.constraints.maxWidth, closeTo(104, 0.01));
        if (paragraph.didExceedMaxLines) problems.add('${category.name}: ellipsized "$text"');
        if (_lines(paragraph, 0, text.length) > 2) problems.add('${category.name}: more than two lines "$text"');

        // 한국어는 글자 사이 줄바꿈이 자연스럽다. 라틴 단어는 온전하게 두되 하이픈에서는 줄바꿈할 수 있다.
        if ([AppLocale.en, AppLocale.de, AppLocale.es].contains(locale)) {
          for (final word in RegExp(r'\p{L}+', unicode: true).allMatches(text)) {
            if (_lines(paragraph, word.start, word.end) > 1) {
              problems.add('${category.name}: split word "${word.group(0)}"');
            }
          }
        }
      }
      expect(problems, isEmpty);
    });
  }
}
