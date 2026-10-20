import 'package:coconut_design_system/coconut_design_system.dart'
    show CoconutLayout, CoconutTypography, TextColorExtension;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart' show safetyKoText;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 검증 표시 한 규칙(POLISH H8): 확인됨은 shieldCheck `success`, 미확인은 circleInfo `iconSecondary`(경보 아님)
class SafetyVerificationLine extends StatelessWidget {
  const SafetyVerificationLine({super.key, required this.verifiedAt});

  final DateTime? verifiedAt;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final at = verifiedAt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SvgPicture.asset(
            at != null ? CommonStateIconPath.shieldCheck : CommonStateIconPath.circleInfo,
            width: 14,
            height: 14,
            colorFilter: ColorFilter.mode(at != null ? colors.success : colors.iconSecondary, BlendMode.srcIn),
          ),
        ),
        CoconutLayout.spacing_100w,
        Expanded(
          child: Text(
            at != null
                ? t.premium.destination.verified_on(date: DateTimeUtil.formatTimestamp(at)[0])
                : safetyKoText(t.premium.destination.not_verified),
            style: CoconutTypography.body3_12.setColor(at != null ? colors.success : colors.secondaryText),
          ),
        ),
      ],
    );
  }
}
