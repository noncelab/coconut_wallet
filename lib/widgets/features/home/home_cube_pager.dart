import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class HomeCubePager extends StatefulWidget {
  static const double maxAngle = math.pi / 4;

  final Widget home;
  final Widget Function(VoidCallback showHome) allFeaturesBuilder;

  /// 홈 화면 편집 중에는 가로로 넘겨도 All Features로 가지 않는다
  final bool swipeEnabled;

  /// 보이는 면이 바뀔 때. 0은 홈, 1은 All Features
  final ValueChanged<int>? onPageChanged;

  const HomeCubePager({
    super.key,
    required this.home,
    required this.allFeaturesBuilder,
    this.swipeEnabled = true,
    this.onPageChanged,
  });

  @override
  State<HomeCubePager> createState() => HomeCubePagerState();
}

class HomeCubePagerState extends State<HomeCubePager> {
  final PageController _controller = PageController();
  int _page = 0;

  void _showHome() {
    _controller.animateToPage(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  void showAllFeatures() {
    if (!_controller.hasClients) return;
    _controller.animateToPage(1, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  /// 홈을 살짝 밀었다가 되돌리기를 두 번 해서 옆에 All Features가 있다는 걸 보여 준다. 두 번째는 조금 작게
  Future<void> peek() async {
    for (final ratio in const [0.16, 0.08]) {
      if (!mounted || !_controller.hasClients || _page != 0 || !_controller.position.haveDimensions) return;
      final distance = _controller.position.viewportDimension * ratio;
      await _controller.animateTo(distance, duration: const Duration(milliseconds: 360), curve: Curves.easeOutCubic);
      if (!mounted || !_controller.hasClients) return;
      await _controller.animateTo(0, duration: const Duration(milliseconds: 420), curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _face(int index, Widget child) {
    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        final page = _controller.hasClients && _controller.position.haveDimensions ? _controller.page ?? 0 : 0.0;
        final offset = (index - page).clamp(-1.0, 1.0);
        return Transform(
          alignment: offset > 0 ? Alignment.centerLeft : Alignment.centerRight,
          transform:
              Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(-offset * HomeCubePager.maxAngle),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showHome();
      },
      child: PageView(
        key: const Key('home-cube-pager'),
        controller: _controller,
        physics: widget.swipeEnabled ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
        onPageChanged: (page) {
          setState(() => _page = page);
          widget.onPageChanged?.call(page);
        },
        children: [
          _face(0, KeyedSubtree(key: const Key('home-cube-home'), child: widget.home)),
          _face(1, KeyedSubtree(key: const Key('home-cube-all-features'), child: widget.allFeaturesBuilder(_showHome))),
        ],
      ),
    );
  }
}
