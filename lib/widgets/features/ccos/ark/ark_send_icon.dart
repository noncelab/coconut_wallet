import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

/// 보내기 확인·결과 위 아이콘. 거래 내역 줄과 같은 단색, 보내기 전·보내는 중에는 아크는 화살표 로티, 라이트닝은 번개 둘레 링
class ArkSendIcon extends StatelessWidget {
  const ArkSendIcon({super.key, required this.lightning, required this.sending});

  final bool lightning;
  final bool sending;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    if (sending && !lightning) {
      return Container(
        key: const Key('ark-send-icon-arrow'),
        width: _size,
        height: _size,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.primaryText.withValues(alpha: 0.1)),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcATop),
          child: Lottie.asset(TransactionLottiePath.arrowUp, fit: BoxFit.contain),
        ),
      );
    }
    final path = switch ((lightning, sending)) {
      (true, true) => FeatureArkIconPath.txLightningSending,
      (true, false) => FeatureArkIconPath.txLightningSent,
      (false, _) => FeatureArkIconPath.txSent,
    };
    final icon = SvgPicture.asset(
      path,
      key: Key('ark-send-icon-$path'),
      width: _size,
      height: _size,
      colorFilter: monochromeIconFilter(colors.primaryText),
    );
    if (!(lightning && sending)) return icon;
    return SizedBox.square(
      key: const Key('ark-send-icon-progress'),
      dimension: _size,
      child: Stack(alignment: Alignment.center, children: [icon, const _ArkSendRing()]),
    );
  }
}

/// 번개 둘레를 2초에 한 바퀴 도는 호
class _ArkSendRing extends StatefulWidget {
  const _ArkSendRing();

  @override
  State<_ArkSendRing> createState() => _ArkSendRingState();
}

class _ArkSendRingState extends State<_ArkSendRing> with SingleTickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return SizedBox.expand(
      child: RotationTransition(
        turns: _turns,
        child: CircularProgressIndicator(
          value: 0.25,
          strokeWidth: 2,
          strokeCap: StrokeCap.round,
          color: colors.primaryText,
          backgroundColor: colors.primaryText.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}
