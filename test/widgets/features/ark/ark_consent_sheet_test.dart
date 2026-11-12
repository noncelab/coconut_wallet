import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/ark/ark_fee_guide.dart';
import 'package:coconut_wallet/widgets/features/ark/ark_consent_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<ArkConsent?> pumpSheet(WidgetTester tester, {Future<ArkFeeGuide?>? feeGuide}) async {
    ArkConsent? agreed;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: ArkConsentSheet(
            scrollController: ScrollController(),
            feeGuide: feeGuide ?? Future.value(null),
            onAgree: (consent) => agreed = consent,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return agreed;
  }

  testWidgets('자동 갱신을 끄면 위험 문구를 보여 주고 끈 채로 동의한다', (tester) async {
    ArkConsent? agreed;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: ArkConsentSheet(
            scrollController: ScrollController(),
            feeGuide: Future.value(null),
            onAgree: (consent) => agreed = consent,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ark-consent-auto-refresh-warning')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ark-consent-auto-refresh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ark-consent-auto-refresh-warning')), findsOneWidget);

    await tester.tap(find.text(t.ark.consent.agree));
    expect(agreed?.autoRefresh, isFalse);
  });

  testWidgets('서버에 닿지 못하면 수수료를 불러오지 못했다고 알린다', (tester) async {
    await pumpSheet(tester);
    expect(find.text(t.ark.consent.fee_unavailable), findsOneWidget);
  });
}
