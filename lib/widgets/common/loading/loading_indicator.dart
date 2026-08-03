import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 화면 전체를 덮는 오버레이에서 사용되는 원형 로딩 인디케이터.
///
/// 주로 CTA 버튼(지갑 추가, 서명 등) 클릭 후 전체 화면 로딩이 필요한 경우에 사용.
/// [CoconutLoadingOverlay]와 함께 사용되어 화면 전체를 반투명 배경으로 덮고
/// 중앙에 인디케이터를 표시한다.
class OverlayLoadingIndicator extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double size;
  final int duration;
  final bool loop;
  final bool reverse;

  const OverlayLoadingIndicator({
    super.key,
    this.padding = EdgeInsets.zero,
    this.color,
    this.size = 200,
    this.duration = 2,
    this.loop = true,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? context.coconutColors.loadingIndicatorColor;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Padding(
        padding: padding,
        child: CircularProgressIndicator(
          color: resolvedColor,
          backgroundColor: resolvedColor.withValues(alpha: 0.2),
          strokeWidth: 10,
          strokeAlign: 0.8,
        ),
      ),
    );
  }
}

/// 화면 내부 일부 영역에서 데이터 로딩을 기다릴 때 사용하는 인라인 로딩 인디케이터.
///
/// 주로 다음과 같은 경우에 사용:
/// - Pull to refresh
/// - 동기화 중 상태 표시 (UTXO 목록, 지갑 홈 등)
/// - 데이터 초기 로딩 (주소 목록, 트랜잭션 상세, UTXO 상세)
/// - 헤더/버튼 내 작은 로딩 표시
/// - 설정 화면에서 비동기 데이터 대기 (앱 정보, Electrum 서버, 블록 익스플로러)
class ContentLoadingIndicator extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  const ContentLoadingIndicator({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 16.0),
    this.color,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? context.coconutColors.loadingIndicatorColor;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Padding(padding: padding, child: CupertinoActivityIndicator(color: resolvedColor, radius: radius)),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Widget? indicator;
  final Color barrierColor;
  final bool dismissible;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.indicator,
    this.barrierColor = Colors.transparent,
    this.dismissible = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) ...[
          ModalBarrier(dismissible: dismissible, color: barrierColor),
          Center(child: indicator ?? const ContentLoadingIndicator()),
        ],
      ],
    );
  }
}
