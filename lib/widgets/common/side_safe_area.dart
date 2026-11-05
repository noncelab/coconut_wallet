import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 상태바가 한쪽 세로 열로 가는 기기에서 내용은 열을 피하고 실제 화면 가장자리를 열 밑까지 이어 그린다.
/// 시트의 딤, 사진, 그라데이션과 화면 전환도 같은 배경을 사용하므로 화면별 등록이 필요 없다.
/// 좌우 안전 영역이 없는 기기에는 필터나 추가 페인트 없이 원래 MediaQuery를 그대로 전달한다.
class SideSafeArea extends StatelessWidget {
  final Widget child;

  const SideSafeArea({super.key, required this.child});

  /// 루트에서 적용한 좌우 여백을 구독한다. SideSafeArea 밖에서는 여백이 없다.
  static EdgeInsets insetsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SideInsets>()?.insets ?? EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final left = media.padding.left;
    final right = media.padding.right;
    final hasSideInset = left > 0 || right > 0;
    final contentMedia =
        hasSideInset
            ? media
                .removePadding(removeLeft: true, removeRight: true)
                .copyWith(size: Size(media.size.width - left - right, media.size.height))
            : media;

    // 내용의 위치와 트리는 여백이 생기거나 없어져도 같게 유지해 내비게이션 상태를 보존한다.
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.only(left: left, right: right),
          child: MediaQuery(
            data: contentMedia,
            child: _SideInsets(insets: EdgeInsets.only(left: left, right: right), child: child),
          ),
        ),
        if (left > 0) _EdgeExtension(inset: left, edge: left, isLeft: true, devicePixelRatio: media.devicePixelRatio),
        if (right > 0)
          _EdgeExtension(
            inset: right,
            edge: media.size.width - right,
            isLeft: false,
            devicePixelRatio: media.devicePixelRatio,
          ),
      ],
    );
  }
}

class _SideInsets extends InheritedWidget {
  final EdgeInsets insets;

  const _SideInsets({required this.insets, required super.child});

  @override
  bool updateShouldNotify(_SideInsets oldWidget) => insets != oldWidget.insets;
}

class _EdgeExtension extends StatelessWidget {
  final double inset;
  final double edge;
  final bool isLeft;
  final double devicePixelRatio;

  const _EdgeExtension({required this.inset, required this.edge, required this.isLeft, required this.devicePixelRatio});

  @override
  Widget build(BuildContext context) {
    // 가장자리 안쪽의 1px 띠를 뒤집어 늘린다. 투명한 열이 섞이지 않도록 1px 안에서 샘플링한다.
    final pixel = 1 / devicePixelRatio;
    final scale = -inset / pixel;
    final sourceEdge = edge + (isLeft ? pixel : -pixel);
    final translate = edge - scale * sourceEdge;
    final matrix = Float64List.fromList([scale, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, translate, 0, 0, 1]);

    // 창 전체 크기의 레이어를 클립한다. 필터 행렬과 샘플 위치가 같은 창 좌표계를 사용하도록 한다.
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          clipper: _SideColumnClipper(inset: inset, isLeft: isLeft),
          // 늘리기 전 좌표계에서 블러 반경을 보정한다. 옆의 아이콘을 끌어오지 않고 출력에서는 12pt로 부드러워진다.
          child: BackdropFilter(
            filter: ui.ImageFilter.compose(
              outer: ui.ImageFilter.matrix(matrix, filterQuality: FilterQuality.low),
              inner: ui.ImageFilter.blur(sigmaX: 12 / scale.abs(), tileMode: TileMode.clamp),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _SideColumnClipper extends CustomClipper<Rect> {
  final double inset;
  final bool isLeft;

  const _SideColumnClipper({required this.inset, required this.isLeft});

  @override
  Rect getClip(Size size) => Rect.fromLTWH(isLeft ? 0 : size.width - inset, 0, inset, size.height);

  @override
  bool shouldReclip(_SideColumnClipper oldClipper) => inset != oldClipper.inset || isLeft != oldClipper.isLeft;
}
