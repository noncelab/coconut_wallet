import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class HomeCubePager extends StatefulWidget {
  static const double maxAngle = math.pi / 4;

  final Widget home;
  final Widget Function(VoidCallback showHome) allFeaturesBuilder;

  const HomeCubePager({super.key, required this.home, required this.allFeaturesBuilder});

  @override
  State<HomeCubePager> createState() => _HomeCubePagerState();
}

class _HomeCubePagerState extends State<HomeCubePager> {
  final PageController _controller = PageController();
  int _page = 0;

  void _showHome() {
    _controller.animateToPage(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
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
        physics: const ClampingScrollPhysics(),
        onPageChanged: (page) => setState(() => _page = page),
        children: [
          _face(0, KeyedSubtree(key: const Key('home-cube-home'), child: widget.home)),
          _face(1, KeyedSubtree(key: const Key('home-cube-all-features'), child: widget.allFeaturesBuilder(_showHome))),
        ],
      ),
    );
  }
}
