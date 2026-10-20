import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/safety/safety_assist.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_verification_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// POLISH R21: 직접 비교는 검증과 아이콘·색을 같이 쓰지 않는다(REQ §19.11)
void main() {
  final at = DateTime(2026, 10, 19, 9);
  final date = DateTimeUtil.formatTimestamp(at)[0];

  Future<void> expectLine(
    WidgetTester tester,
    SafetyVerification? verification, {
    required String icon,
    required Color Function(BuildContext context) iconColor,
    required Color Function(BuildContext context) textColor,
    required String text,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(body: SafetyVerificationLine(verification: verification)),
      ),
    );
    final context = tester.element(find.byType(SafetyVerificationLine));
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final label = tester.widget<Text>(find.byType(Text));
    expect((svg.bytesLoader as SvgAssetLoader).assetName, icon);
    expect(svg.colorFilter, ColorFilter.mode(iconColor(context), BlendMode.srcIn));
    expect(label.style!.color, textColor(context));
    expect(label.data!.replaceAll('⁠', ''), text); // R1 이음 문자 빼고
  }

  testWidgets('주소 QR 일치: shieldCheck success + verified_on', (tester) async {
    await expectLine(
      tester,
      (at: at, by: SafetyVerifiedBy.qr),
      icon: CommonStateIconPath.shieldCheck,
      iconColor: (c) => c.coconutColors.success,
      textColor: (c) => c.coconutColors.success,
      text: t.premium.destination.verified_on(date: date),
    );
  });

  testWidgets('BSMS 구성 일치: shieldCheck success + bsms_matched_on', (tester) async {
    await expectLine(
      tester,
      (at: at, by: SafetyVerifiedBy.bsms),
      icon: CommonStateIconPath.shieldCheck,
      iconColor: (c) => c.coconutColors.success,
      textColor: (c) => c.coconutColors.success,
      text: t.premium.destination.bsms_matched_on(date: date),
    );
  });

  testWidgets('직접 비교: 검증과 다른 회색 circleCheck + confirmed_on(초록 shieldCheck 아님)', (tester) async {
    await expectLine(
      tester,
      (at: at, by: SafetyVerifiedBy.user),
      icon: CommonFormIconPath.circleCheck,
      iconColor: (c) => c.coconutColors.iconSecondary,
      textColor: (c) => c.coconutColors.secondaryText,
      text: t.premium.destination.confirmed_on(date: date),
    );
  });

  testWidgets('없음: circleInfo iconSecondary + not_verified', (tester) async {
    await expectLine(
      tester,
      null,
      icon: CommonStateIconPath.circleInfo,
      iconColor: (c) => c.coconutColors.iconSecondary,
      textColor: (c) => c.coconutColors.secondaryText,
      text: t.premium.destination.not_verified,
    );
  });
}
