import 'package:coconut_design_system/coconut_design_system.dart' show CoconutCircularIndicator;
import 'package:flutter/widgets.dart';

/// Lottie 원본의 빈 캔버스를 줄여 실제 그림 크기를 유지하는 연결 진행 표시.
class WalletConnectLoadingIndicator extends StatelessWidget {
  /// Lottie 렌더링 크기. 레이아웃 영역은 절반으로 줄여 원본의 빈 여백을 잘라낸다.
  final double size;

  const WalletConnectLoadingIndicator({super.key, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size / 3.5,
      child: ClipRect(
        child: OverflowBox(
          minWidth: size,
          maxWidth: size,
          minHeight: size,
          maxHeight: size,
          child: CoconutCircularIndicator(size: size),
        ),
      ),
    );
  }
}
