import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 상태 아이콘을 [size] 정사각형 가운데에 그린다(상태칩·Safety Status 위젯·지갑 상세 알약 공용).
/// `triangleWarning`은 원화가 상자를 꽉 채워 같은 크기의 다른 아이콘보다 크고 굵어 보여서 16 상자에 13.5, 24 상자에 20
/// (그 밖의 크기는 24와 같은 비율)으로 줄인다. [color]가 null이면 원래 색 그대로(예: cloud-disconnected).
Widget safetyStateIcon(String path, double size, Color? color) {
  final inner = path == CommonStateIconPath.triangleWarning ? (size == 16 ? 13.5 : size * 20 / 24) : size;
  return SizedBox.square(
    dimension: size,
    child: Center(
      child: SvgPicture.asset(
        path,
        width: inner,
        height: inner,
        colorFilter: color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
      ),
    ),
  );
}
