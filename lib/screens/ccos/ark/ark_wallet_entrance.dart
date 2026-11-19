import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 오픈 스토어와 같은 아크 그림, 선 색은 테마를 따름
const arkIllustrationAsset = 'assets/images/ccos/ark_illustration.svg';
const double arkIllustrationWidth = 220;
const double arkIllustrationAspect = 2172 / 1620;

/// 아크 지갑을 다른 앱처럼 여는 짧은 스플래시. 지갑이 없으면 그림이 시작 화면 그림 자리로 옮겨 감
class ArkWalletEntrance extends StatefulWidget {
  const ArkWalletEntrance({super.key, required this.child});

  final Widget child;

  static Route<void> route(Widget child) => PageRouteBuilder<void>(
    settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletHome),
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => ArkWalletEntrance(child: child),
    transitionsBuilder: (_, animation, _, page) => FadeTransition(opacity: animation, child: page),
  );

  @override
  State<ArkWalletEntrance> createState() => _ArkWalletEntranceState();
}

class _ArkWalletEntranceState extends State<ArkWalletEntrance> with SingleTickerProviderStateMixin {
  static const _hold = Duration(milliseconds: 600);
  static const _out = Duration(milliseconds: 450);

  final GlobalKey _target = GlobalKey();
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _hold + _out)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) setState(() => _done = true);
        })
        ..forward();
  late final Animation<double> _leave = CurvedAnimation(
    parent: _controller,
    curve: Interval(_hold.inMilliseconds / (_hold + _out).inMilliseconds, 1, curve: Curves.easeInOutCubic),
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Rect? _targetRect(BuildContext overlay) {
    final target = _target.currentContext?.findRenderObject() as RenderBox?;
    final origin = overlay.findRenderObject() as RenderBox?;
    if (target == null || origin == null || !target.hasSize) return null;
    return origin.globalToLocal(target.localToGlobal(Offset.zero)) & target.size;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ArkSplashScope(
      target: _target,
      covering: !_done,
      child: Stack(
        children: [
          widget.child,
          if (!_done)
            Positioned.fill(
              key: const Key('ark-splash'),
              child: AbsorbPointer(
                child: LayoutBuilder(
                  builder:
                      (overlay, constraints) => AnimatedBuilder(
                        animation: _leave,
                        builder: (overlay, _) {
                          final size = Size(arkIllustrationWidth, arkIllustrationWidth / arkIllustrationAspect);
                          final start = Rect.fromCenter(
                            center: constraints.biggest.center(Offset.zero),
                            width: size.width,
                            height: size.height,
                          );
                          final target = reduceMotion ? null : _targetRect(overlay);
                          final t = _leave.value;
                          final rect = Rect.lerp(start, target ?? start.inflate(start.width * 0.05), t)!;
                          return Stack(
                            children: [
                              Positioned.fill(child: ColoredBox(color: colors.background.withValues(alpha: 1 - t))),
                              Positioned.fromRect(
                                key: const Key('ark-splash-image'),
                                rect: rect,
                                child: Opacity(
                                  opacity: target == null ? 1 - t : 1,
                                  child: SvgPicture.asset(
                                    arkIllustrationAsset,
                                    fit: BoxFit.contain,
                                    theme: SvgTheme(currentColor: colors.primaryText),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 스플래시가 덮고 있는 동안 시작 화면 그림을 숨기고, 그 자리를 스플래시에 알려 줌
class ArkSplashScope extends InheritedWidget {
  const ArkSplashScope({super.key, required this.target, required this.covering, required super.child});

  final GlobalKey target;
  final bool covering;

  static ArkSplashScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ArkSplashScope>();

  @override
  bool updateShouldNotify(ArkSplashScope oldWidget) => covering != oldWidget.covering || target != oldWidget.target;
}
