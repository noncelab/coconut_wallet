import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Lottie 아이콘과 내용 영역이 있는 요약 카드.
///
/// 좌측 Lottie 아이콘(24x24)과 우측의 [AnimatedSwitcher]로 감싼 [child]를
/// 동일한 스타일의 카드 컨테이너 안에 표시한다.
/// 내부 레이아웃/애니메이션 설정은 고정이며, 상태에 따른 Lottie 제어는
/// [lottieController]와 [onLottieLoaded]를 통해 호출부가 담당한다.
class AnimatedSummaryCard extends StatelessWidget {
  const AnimatedSummaryCard({
    super.key,
    required this.lottieController,
    required this.onLottieLoaded,
    required this.child,
    this.cardKey,
  });

  final AnimationController lottieController;
  final void Function(LottieComposition composition) onLottieLoaded;

  /// [AnimatedSwitcher]의 child로 주입될 위젯. 전환을 트리거하려면
  /// 이 위젯에 [ValueKey]를 설정해야 한다.
  final Widget child;

  /// Container 자체에 부여할 Key (선택).
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Container(
        key: cardKey,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CoconutColors.gray800,
          border: Border.all(color: CoconutColors.gray600, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 0),
              child: Lottie.asset(
                'assets/lottie/three-stars-growing.json',
                controller: lottieController,
                onLoaded: onLottieLoaded,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                repeat: false,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previousChildren, if (currentChild != null) currentChild],
                    );
                  },
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
