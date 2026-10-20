import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutUnderlinedButton;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

/// Security Guide 상단 4단계 진행 바. 경로 전환이 끝난 뒤 직전 단계 값에서 새 값으로 채운다
class SafetyGuideProgressBar extends StatefulWidget {
  const SafetyGuideProgressBar({super.key, required this.value});

  final double value;

  @override
  State<SafetyGuideProgressBar> createState() => _SafetyGuideProgressBarState();
}

class _SafetyGuideProgressBarState extends State<SafetyGuideProgressBar> with SingleTickerProviderStateMixin {
  // 단계마다 새 경로라서 직전 단계 값을 여기 둔다. 새로 시작·이어 하기처럼 값이 줄면 0부터 채운다
  static double _lastShown = 0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  double _from = 0;
  late double _to = widget.value;
  bool _started = false;
  VoidCallback? _cancelWait;

  double get _value => _from + (_to - _from) * _curve.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _from = _lastShown <= _to ? _lastShown : 0;
    _lastShown = _to;
    if (safetyReduceMotion(context)) {
      _controller.value = 1;
    } else {
      _cancelWait = whenRouteSettled(context, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didUpdateWidget(covariant SafetyGuideProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == _to) return;
    _from = _value;
    _to = _lastShown = widget.value;
    if (safetyReduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _cancelWait?.call();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    // 0.04 → 1, 0.25 → 2, 0.5 → 3, 0.75 이상 → 4
    final step = ((_to * 4).floor() + 1).clamp(1, 4);
    return Semantics(
      container: true,
      label: t.safety_guide.progress_label,
      value: t.safety_guide.progress_a11y(total: 4, step: step),
      child: SizedBox(
        width: double.infinity,
        height: 4,
        child: ColoredBox(
          color: colors.pageIndicatorInactive,
          child: AnimatedBuilder(
            animation: _controller,
            builder:
                (context, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _value.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.pageIndicatorActive,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

/// 단계 화면 틀(핫월렛 백업 가이드 구성): 진행 바 · 아이콘 원 · 제목 · 설명 · 내용 + 하단 고정 버튼.
/// [onButton]이 없으면 하단 버튼을 그리지 않는다(선택 행이 버튼인 단계). [footer]는 버튼 위 자리를 "나중에 하기" 대신 쓴다
class SafetyGuidePage extends StatefulWidget {
  const SafetyGuidePage({
    super.key,
    required this.progress,
    this.iconPath,
    this.icon,
    this.hero,
    required this.title,
    this.description,
    this.children = const [],
    required this.buttonText,
    this.onButton,
    this.buttonEnabled = true,
    this.laterText,
    this.onLater,
    this.footer,
  });

  final double progress;
  final String? iconPath;

  /// 아이콘 원 안에 [iconPath] 대신 넣을 위젯
  final Widget? icon;

  /// 제 모양을 가진 머리 그림(예: PremiumHero). 있으면 회색 72 원 대신 그대로 그린다
  final Widget? hero;
  final String title;
  final String? description;
  final List<Widget> children;
  final String buttonText;
  final VoidCallback? onButton;
  final bool buttonEnabled;
  final String? laterText;
  final VoidCallback? onLater;
  final Widget? footer;

  @override
  State<SafetyGuidePage> createState() => _SafetyGuidePageState();
}

class _SafetyGuidePageState extends State<SafetyGuidePage> {
  static const _entryCount = 4; // 아이콘 원 · 제목 · 설명 · 내용

  int _visible = 0;
  bool _started = false;
  VoidCallback? _cancelWait;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (safetyReduceMotion(context)) {
      _visible = _entryCount;
    } else {
      _cancelWait = whenRouteSettled(context, () {
        if (mounted) setState(_reveal);
      });
    }
  }

  /// 경로 전환이 끝나면 80ms 간격으로 하나씩
  void _reveal() {
    _visible = 1;
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _visible++);
      if (_visible >= _entryCount) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelWait?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final hasButton = widget.onButton != null;
    final hasSubWidget = widget.footer != null || (widget.laterText != null && widget.onLater != null);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, backgroundColor: colors.background),
      body: SafeArea(
        top: false,
        // 버튼 묶음 높이를 재서 아래 여백·페이드를 그만큼 키운다(X1)
        child: SafetyFooterScope(
          builder:
              (context) => Stack(
                children: [
                  Column(
                    children: [
                      SafetyGuideProgressBar(value: widget.progress),
                      Expanded(
                        child: SingleChildScrollView(
                          // 아래 버튼 묶음과 그 위 페이드를 비켜 간다(R4, 버튼 글이 커지는 만큼 같이)
                          padding: EdgeInsets.fromLTRB(
                            20,
                            40,
                            20,
                            hasButton ? safetyFooterClearance(context, hasSubWidget: hasSubWidget) : 40,
                          ),
                          child: Column(
                            children: [
                              if (widget.hero != null) ...[
                                // 제 모양을 가진 머리 그림(예: PremiumHero)은 회색 원 없이 그대로
                                _SequentialEntry(visible: _visible > 0, child: widget.hero!),
                                CoconutLayout.spacing_400h,
                              ] else if (widget.iconPath != null || widget.icon != null) ...[
                                _SequentialEntry(
                                  visible: _visible > 0,
                                  child: SafetyIconCircle(
                                    size: 72,
                                    background: colors.iconBackgroundSubtle,
                                    icon:
                                        widget.icon ??
                                        SvgPicture.asset(
                                          widget.iconPath!,
                                          width: 32,
                                          height: 32,
                                          colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                                        ),
                                  ),
                                ),
                                CoconutLayout.spacing_400h,
                              ],
                              _SequentialEntry(
                                visible: _visible > 1,
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    safetyKoText(widget.title),
                                    textAlign: TextAlign.center,
                                    style: CoconutTypography.heading3_21_Bold.setColor(colors.primaryText),
                                  ),
                                ),
                              ),
                              if (widget.description != null) ...[
                                CoconutLayout.spacing_300h,
                                _SequentialEntry(
                                  visible: _visible > 2,
                                  child: Text(
                                    safetyKoText(widget.description!),
                                    textAlign: TextAlign.center,
                                    style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                                  ),
                                ),
                              ],
                              if (widget.children.isNotEmpty) ...[
                                CoconutLayout.spacing_600h,
                                _SequentialEntry(
                                  visible: _visible > 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: widget.children,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasButton && _visible > 0) _bottomButton(context),
                ],
              ),
        ),
      ),
    );
  }

  Widget _bottomButton(BuildContext context) {
    final colors = context.coconutColors;
    final subWidget =
        widget.footer ??
        (widget.laterText != null && widget.onLater != null
            ? CoconutUnderlinedButton(
              key: const Key('safety-guide-later'),
              text: widget.laterText!,
              onTap: widget.onLater!,
              defaultColor: colors.secondaryTextStrong,
            )
            : null);
    final button = FixedBottomButton(
      buttonKey: const Key('safety-guide-button'),
      surroundingsKey: const Key('safety-guide-fade'),
      onButtonClicked: widget.onButton!,
      text: widget.buttonText,
      isActive: widget.buttonEnabled,
      surroundingsColor: colors.background,
      // 보조 줄이 있으면 페이드의 불투명한 절반이 그 줄 위에서 시작한다(X1)
      surroundingsPadding: subWidget == null ? null : safetySubLineFadePadding(context),
      subWidget: subWidget,
    );
    if (safetyReduceMotion(context)) return button;
    return button.slideUpAnimation(
      duration: const Duration(milliseconds: 350),
      delay: const Duration(milliseconds: 200),
      offset: const Offset(0, 8),
      curve: Curves.easeOutCubic,
    );
  }
}

/// 핫월렛 백업 가이드와 같은 차례 등장(위로 0.12 + 페이드)
class _SequentialEntry extends StatelessWidget {
  const _SequentialEntry({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.12),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
    );
  }
}

/// ✓ / 회전 / ○ 진행 목록(비트코인 옮기기, Premium 분석 중). [activeIndex]가 길이와 같으면 모두 끝남
class SafetyStepList extends StatelessWidget {
  const SafetyStepList({super.key, required this.steps, required this.activeIndex, this.failed = false});

  final List<String> steps;
  final int activeIndex;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[if (i > 0) CoconutLayout.spacing_600h, _row(context, i)],
      ],
    );
  }

  Widget _row(BuildContext context, int index) {
    final colors = context.coconutColors;
    final reduceMotion = safetyReduceMotion(context);
    final isDone = index < activeIndex;
    final isActive = index == activeIndex;
    final Widget indicator;
    final String? status;
    if (isDone) {
      final check = SafetyIconCircle(
        size: 28,
        background: colors.success,
        icon: SvgPicture.asset(
          CommonActionIconPath.check,
          width: 14,
          height: 14,
          colorFilter: ColorFilter.mode(colors.background, BlendMode.srcIn),
        ),
      );
      indicator = KeyedSubtree(key: const ValueKey('done'), child: reduceMotion ? check : check.scaleInAnimation());
      status = t.done;
    } else if (isActive && failed) {
      indicator = SafetyIconCircle(
        key: const ValueKey('failed'),
        size: 28,
        background: colors.dangerSurface,
        icon: SvgPicture.asset(
          CommonStateIconPath.triangleWarning,
          width: 14,
          height: 14,
          colorFilter: ColorFilter.mode(colors.danger, BlendMode.srcIn),
        ),
      );
      status = t.safety_guide.move.step_failed_a11y;
    } else if (isActive) {
      indicator = SizedBox(
        key: const ValueKey('active'),
        width: 28,
        height: 28,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            // 동작 줄이기면 돌지 않는 표시(진행 중 의미는 아래 Semantics가 말한다)
            child: CircularProgressIndicator(
              value: reduceMotion ? 0.25 : null,
              strokeWidth: 2.5,
              color: colors.success,
            ),
          ),
        ),
      );
      status = t.safety_guide.move.step_in_progress_a11y;
    } else {
      indicator = SvgPicture.asset(
        CommonFormIconPath.circle,
        key: const ValueKey('pending'),
        width: 28,
        height: 28,
        colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn), // 코코넛에서도 보이는 대기 원(D26)
      );
      status = t.safety_guide.move.step_pending_a11y;
    }
    return Semantics(
      container: true,
      label: steps[index],
      value: status,
      child: ExcludeSemantics(
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
              child: indicator,
            ),
            CoconutLayout.spacing_400w,
            Expanded(
              child: Text(
                safetyKoText(steps[index]),
                style: CoconutTypography.body1_16_Bold.setColor(
                  isDone || isActive ? colors.primaryText : colors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 성공·결과 화면(니모닉 백업 완료 화면 틀 + 테마 체크 Lottie). 가이드 단계면 [progress]로 위에 진행 바
class SafetyResultPage extends StatefulWidget {
  const SafetyResultPage({
    super.key,
    required this.title,
    required this.description,
    this.children = const [],
    required this.buttonText,
    required this.onButton,
    this.subWidget,
    this.progress,
    this.icon,
    this.badge,
  });

  final String title;
  final String description;
  final List<Widget> children;
  final String buttonText;
  final VoidCallback onButton;
  final Widget? subWidget;
  final double? progress;

  /// 체크 대신 보여 줄 64 아이콘(결제 대기 등). 있으면 체크 애니메이션과 진동을 하지 않는다
  final Widget? icon;

  /// 아이콘과 제목 사이 표시(예: Premium 구매 완료의 PremiumChip). 없으면 자리도 없다
  final Widget? badge;

  @override
  State<SafetyResultPage> createState() => _SafetyResultPageState();
}

class _SafetyResultPageState extends State<SafetyResultPage> with SingleTickerProviderStateMixin {
  // icon이 있으면 체크를 그리지 않아도 dispose에서 처음 만들어지지 않게 미리 만든다
  late final AnimationController _check;
  VoidCallback? _cancelSettle;
  bool _settled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _check = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (safetyReduceMotion(context)) _check.value = 1;
    // 화면이 다 밀려 들어온 뒤에 체크를 그리고 진동한다(전환 중에 끝나 버리지 않게, POLISH D13)
    _cancelSettle ??= whenRouteSettled(context, () {
      if (!mounted) return;
      _settled = true;
      if (widget.icon == null) vibrateLight();
      _startCheck();
    });
  }

  void _startCheck() {
    if (_settled && _loaded && mounted && !safetyReduceMotion(context)) _check.forward();
  }

  @override
  void dispose() {
    _cancelSettle?.call();
    _check.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: CoconutAppBar.build(context: context, isLeadingVisible: false, backgroundColor: colors.background),
        body: SafeArea(
          top: false,
          child: SafetyFooterScope(
            builder:
                (context) => Stack(
                  children: [
                    Column(
                      children: [
                        if (widget.progress != null) SafetyGuideProgressBar(value: widget.progress!),
                        Expanded(
                          child: LayoutBuilder(
                            builder:
                                (context, constraints) => SingleChildScrollView(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                    // 내용이 짧으면 가운데에서 28 위, 길면 버튼 묶음과 그 위 페이드를 비켜 스크롤(R4, 버튼 글이 커지는 만큼 같이)
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        20,
                                        widget.subWidget == null ? 104 : 128,
                                        20,
                                        safetyFooterClearance(context, hasSubWidget: widget.subWidget != null),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            widget.icon ?? _checkMark(context),
                                            CoconutLayout.spacing_600h,
                                            if (widget.badge != null) ...[widget.badge!, CoconutLayout.spacing_300h],
                                            Semantics(
                                              header: true,
                                              child: Text(
                                                safetyKoText(widget.title),
                                                textAlign: TextAlign.center,
                                                style: CoconutTypography.heading3_21_Bold.setColor(colors.primaryText),
                                              ),
                                            ),
                                            CoconutLayout.spacing_400h,
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              child: Text(
                                                safetyKoText(widget.description),
                                                textAlign: TextAlign.center,
                                                style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                                              ),
                                            ),
                                            if (widget.children.isNotEmpty) ...[
                                              CoconutLayout.spacing_600h,
                                              ...widget.children,
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                    FixedBottomButton(
                      buttonKey: const Key('safety-result-button'),
                      surroundingsKey: const Key('safety-result-fade'),
                      onButtonClicked: widget.onButton,
                      text: widget.buttonText,
                      surroundingsColor: colors.background,
                      surroundingsPadding: widget.subWidget == null ? null : safetySubLineFadePadding(context),
                      subWidget: widget.subWidget,
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  /// 패스프레이즈 확인 화면과 같은 테마 체크. 불러오기 전·실패 시 같은 색의 정지 원
  Widget _checkMark(BuildContext context) {
    final colors = context.coconutColors;
    final fallback = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: colors.checkIconBackground, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        CommonActionIconPath.check,
        width: 32,
        height: 32,
        colorFilter: ColorFilter.mode(colors.checkIconForeground, BlendMode.srcIn),
      ),
    );
    return ExcludeSemantics(
      child: Lottie.asset(
        StateLottiePath.checkComplete,
        width: 64,
        height: 64,
        fit: BoxFit.contain,
        controller: _check,
        repeat: false,
        onLoaded: (_) {
          _loaded = true;
          _startCheck();
        },
        delegates: LottieDelegates(
          values: [
            ValueDelegate.color(const ['Shape Layer 1', 'Group 1', 'Fill'], value: colors.checkIconBackground),
            ValueDelegate.strokeColor(const ['Path 1', 'Stroke'], value: colors.checkIconForeground),
          ],
        ),
        frameBuilder: (_, child, composition) => composition == null ? fallback : child,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
