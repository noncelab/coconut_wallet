import 'package:coconut_design_system/coconut_design_system.dart'
    show CoconutLayout, CoconutTypography, TextColorExtension;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/safety/safety_assist.dart' show SafetyVerification, SafetyVerifiedBy;
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart' show safetyKoText;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 받는 지갑 검증 표시 한 규칙(POLISH H8, R21). 저장된 확인 방법으로 고른다.
/// - 주소 QR 일치: shieldCheck `success` + verified_on
/// - BSMS 백업과 구성 일치: shieldCheck `success` + bsms_matched_on
/// - 사용자가 직접 비교: Health의 "직접 확인함"과 같은 회색 circleCheck `iconSecondary` + confirmed_on. 검증과 같은 아이콘·색을 쓰지 않는다
/// - 없음: circleInfo `iconSecondary` + not_verified(경보 아님)
class SafetyVerificationLine extends StatelessWidget {
  const SafetyVerificationLine({super.key, required this.verification});

  final SafetyVerification? verification;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final v = verification;
    final strings = t.premium.destination;
    final date = v == null ? '' : DateTimeUtil.formatTimestamp(v.at)[0];
    final (icon, iconColor, textColor, text) = switch (v?.by) {
      null => (CommonStateIconPath.circleInfo, colors.iconSecondary, colors.secondaryText, strings.not_verified),
      SafetyVerifiedBy.qr => (
        CommonStateIconPath.shieldCheck,
        colors.success,
        colors.success,
        strings.verified_on(date: date),
      ),
      SafetyVerifiedBy.bsms => (
        CommonStateIconPath.shieldCheck,
        colors.success,
        colors.success,
        strings.bsms_matched_on(date: date),
      ),
      SafetyVerifiedBy.user => (
        CommonFormIconPath.circleCheck,
        colors.iconSecondary,
        colors.secondaryText,
        strings.confirmed_on(date: date),
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SvgPicture.asset(
            icon,
            width: 14,
            height: 14,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
        ),
        CoconutLayout.spacing_100w,
        Expanded(child: Text(safetyKoText(text), style: CoconutTypography.body3_12.setColor(textColor))),
      ],
    );
  }
}
