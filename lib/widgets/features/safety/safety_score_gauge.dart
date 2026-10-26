import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart'
    show CoconutLayout, CoconutTypography, TextColorExtension;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 점수 라벨. 0–49는 "조치 필요"("Critical"은 사건 전용)
String walletHealthLabelText(WalletHealthLabel label) => switch (label) {
  WalletHealthLabel.excellent => t.wallet_health.score_label.excellent,
  WalletHealthLabel.good => t.wallet_health.score_label.good,
  WalletHealthLabel.needsAttention => t.wallet_health.score_label.needs_attention,
  WalletHealthLabel.actionNeeded => t.wallet_health.score_label.action_needed,
};

/// 라벨 글자색
Color walletHealthLabelColor(BuildContext context, WalletHealthLabel label) {
  final colors = context.walletHealthColors;
  return switch (label) {
    WalletHealthLabel.excellent => colors.excellent,
    WalletHealthLabel.good => colors.good,
    WalletHealthLabel.needsAttention => colors.warning,
    WalletHealthLabel.actionNeeded => colors.critical,
  };
}

/// 위급 머리 문구(모르는 출금 1건·여러 건 / 서버 인증서 변경 / 보기 전용·다중 서명 불일치)
String safetyCriticalTitle(WalletHealthReport report) {
  final incident = t.wallet_health.incident;
  final incidents = report.criticalIncidents.length;
  if (incidents > 1) return incident.outgoing_multiple_title(n: incidents);
  if (incidents == 1) return incident.outgoing_title;
  final check = report.reviewItems.where((r) => r.severity == SafetySeverity.critical).firstOrNull;
  return switch (check?.id) {
    SafetyCheckId.serverCert => incident.server_identity_title,
    SafetyCheckId.watchOnlyVerify => incident.watch_only_mismatch_title,
    SafetyCheckId.multisigConfig => incident.multisig_mismatch_title,
    _ => incident.outgoing_title,
  };
}

/// 270° Wallet Health 게이지(아래가 열림). 화면에 들어오면 0에서 점수까지 차오르고, 값이 바뀌면 지금 값에서 이어서 움직인다.
class HealthGauge extends StatefulWidget {
  const HealthGauge({
    super.key,
    required this.report,
    this.size = 208,
    this.animateEntry = true,
    this.isChecking = false,
  });

  /// 4×2 홈 위젯용. 라벨 없이 숫자만, 채움 애니메이션 없이 최종 값만
  const HealthGauge.compact({super.key, required this.report, this.size = 72})
    : animateEntry = false,
      isChecking = false;

  /// null = 첫 평가 전(트랙만)
  final WalletHealthReport? report;
  final double size;
  final bool animateEntry;
  final bool isChecking;

  bool get _compact => size < 100;

  /// 원호 양 끝(둥근 끝의 가운데) 사이 거리. 아래 버튼 폭을 이것에 맞춘다
  static double arcEndSpan([double size = 208]) {
    final stroke = (size / 7).roundToDouble();
    return (size - stroke) * math.sqrt1_2;
  }

  @override
  State<HealthGauge> createState() => _HealthGaugeState();
}

class _HealthGaugeState extends State<HealthGauge> with TickerProviderStateMixin {
  static const _fillDuration = Duration(milliseconds: 1600);
  static const _startDelay = Duration(milliseconds: 250);
  static const _fade = Duration(milliseconds: 220);

  late final _fill = AnimationController(vsync: this, duration: _fillDuration);
  late final _fillCurve = CurvedAnimation(parent: _fill, curve: Curves.easeOutCubic);
  late final _number = AnimationController(vsync: this, duration: _fade);
  late final _checking = AnimationController(vsync: this, duration: _fade, value: widget.isChecking ? 1 : 0);
  late final _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  double _from = 0;
  late double _to = _progressOf(widget.report);
  bool _still = false;
  bool _entered = false;
  bool _pendingFill = false;
  VoidCallback? _cancelSettle;
  Timer? _start;

  double get _value => _from + (_to - _from) * _fillCurve.value;

  /// 숫자 점수를 보여 주는 상태(S1·S2)
  static bool _scored(WalletHealthReport? report) =>
      report?.status == WalletHealthStatus.scored && report?.score != null && report?.label != null;

  static double _progressOf(WalletHealthReport? report) => _scored(report) ? report!.score!.clamp(0, 100) / 100 : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = !widget.animateEntry || safetyReduceMotion(context);
    if (_still) {
      _start?.cancel();
      _cancelSettle?.call();
      _entered = true;
      _fill.value = 1;
      _number.value = 1;
      _sweep.stop();
      _checking.value = widget.isChecking ? 1 : 0;
      return;
    }
    if (widget.isChecking && !_sweep.isAnimating) _sweep.repeat();
    if (_entered || _cancelSettle != null) return;
    // 화면 전환이 끝난 뒤 잠깐 쉬었다가 차오른다(hodl 인사이트 _OpenProgress와 같은 규칙).
    // 새 경로의 첫 프레임은 Hero 측정용 offstage라 전환이 끝난 것처럼 보여서 프레임 뒤에 판단하는 공용 함수를 쓴다
    _cancelSettle = whenRouteSettled(context, _scheduleStart);
  }

  void _scheduleStart() {
    _start = Timer(_startDelay, () {
      if (!mounted) return;
      _entered = true;
      _number.forward();
      _fill.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(covariant HealthGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isChecking != oldWidget.isChecking) _setChecking(widget.isChecking);
    final target = _progressOf(widget.report);
    if (target == _to) return;
    _from = _value;
    _to = target;
    if (_still) {
      _fill.value = 1;
      return;
    }
    if (!_entered) return; // 진입 애니메이션이 새 값까지 채운다
    _fill.value = 0;
    // 검사 중이면 스윕이 사라진 뒤 이전 값에서 새 값으로
    if (widget.isChecking || _checking.value > 0) {
      _pendingFill = true;
      return;
    }
    _fill.forward();
  }

  void _setChecking(bool checking) {
    if (_still) {
      _checking.value = checking ? 1 : 0;
      return;
    }
    if (checking) {
      _sweep.repeat();
      _checking.forward();
      return;
    }
    _checking.reverse().whenCompleteOrCancel(() {
      if (!mounted || widget.isChecking) return;
      _sweep.stop();
      if (!_pendingFill) return;
      _pendingFill = false;
      _fill.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _cancelSettle?.call();
    _fillCurve.dispose();
    _fill.dispose();
    _number.dispose();
    _checking.dispose();
    _sweep.dispose();
    super.dispose();
  }

  String _caption(WalletHealthReport? report) => switch (report?.status) {
    WalletHealthStatus.noWallet => t.wallet_health.hero.no_wallet_title,
    WalletHealthStatus.notEnoughData => t.wallet_health.hero.not_enough_data_title,
    _ => '',
  };

  String _semanticsLabel(WalletHealthReport? report) {
    final h = t.wallet_health.hero;
    if (report != null && report.isCritical) {
      return t.wallet_health.incident.alert_a11y(title: safetyCriticalTitle(report));
    }
    if (widget.isChecking) return t.wallet_health.summary.checking;
    if (_scored(report)) return h.score_a11y(score: report!.score!, label: walletHealthLabelText(report.label!));
    final caption = _caption(report);
    return caption.isEmpty ? h.no_score : '${h.no_score}, $caption';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final report = widget.report;
    final critical = report?.isCritical ?? false;
    final size = widget.size;
    final stroke = (size / 7).roundToDouble(); // 208 → 30, 72 → 10
    final radius = (size - stroke) / 2;
    final inner = 2 * radius - stroke - (widget._compact ? 8 : 16);
    return Semantics(
      label: _semanticsLabel(report),
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          // 원호 맨 아래까지만
          height: size / 2 + radius * math.sqrt1_2 + stroke / 2,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_fill, _checking, _sweep]),
                  builder:
                      (context, _) => CustomPaint(
                        painter: _GaugePainter(
                          stroke: stroke,
                          track: context.walletHealthColors.gaugeTrack,
                          fill: context.walletHealthColors.gaugeColors,
                          stops: context.walletHealthColors.gaugeStops,
                          critical: critical ? colors.danger.withValues(alpha: 0.28) : null,
                          progress: _value,
                          fillOpacity: 1 - 0.65 * _checking.value,
                          sweep: _still || !_sweep.isAnimating ? null : Curves.easeInOutCubic.transform(_sweep.value),
                          sweepOpacity: _checking.value,
                        ),
                      ),
                ),
              ),
              // 지갑 없음·데이터 부족도 점수 화면과 같은 자리: 대시는 점수 자리, 안내는 라벨 자리
              if (!widget._compact &&
                  !critical &&
                  (_scored(report) || widget.isChecking || _caption(report).isNotEmpty))
                ..._scoreAndLabel(context, report, radius - stroke / 2)
              else
                Positioned(
                  left: (size - inner) / 2,
                  top: (size - inner) / 2,
                  width: inner,
                  height: inner,
                  // 글자를 키워도 원호를 넘지 않게 안쪽 지름에 맞춰 줄인다
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(width: inner, child: _center(context, report, critical)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 점수는 원 중심보다 조금 위, 라벨은 아래쪽 열린 곳. 라벨은 그 높이의 원호 안쪽 폭을 넘지 않게 줄인다
  List<Widget> _scoreAndLabel(BuildContext context, WalletHealthReport? report, double innerRadius) {
    final size = widget.size;
    final checking = widget.isChecking;
    final label = report?.label;
    final labelOffset = size * 0.2;
    final labelHalf = MediaQuery.textScalerOf(context).scale(_labelStyle.fontSize!) * _labelStyle.height! / 2;
    final labelTop = math.max(0.0, labelOffset - labelHalf);
    final labelWidth = 2 * math.sqrt(math.max(0.0, innerRadius * innerRadius - labelTop * labelTop)) - 16;
    final caption = checking || label != null ? null : _caption(report);
    final text =
        checking
            ? t.wallet_health.summary.checking
            : caption != null
            ? safetyKoText(caption)
            : walletHealthLabelText(label!);
    final style =
        caption != null
            ? CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText)
            : _labelStyle.setColor(
              checking ? context.coconutColors.secondaryText : walletHealthLabelColor(context, label!),
            );
    Widget at(double dy, double maxWidth, Widget child) => Positioned(
      left: 0,
      top: 0,
      width: size,
      height: size,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, dy),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          ),
        ),
      ),
    );
    return [
      at(-size * 0.03, innerRadius * 1.7, _scoreNumber(context, report)),
      at(
        labelOffset,
        labelWidth,
        AnimatedSwitcher(
          duration: _still ? Duration.zero : _fade,
          child: Text(text, key: ValueKey(text), maxLines: 1, style: style),
        ),
      ),
    ];
  }

  static final _labelStyle = CoconutTypography.heading3_21.copyWith(fontSize: 22, height: 1.2);

  Widget _scoreNumber(BuildContext context, WalletHealthReport? report) {
    final colors = context.coconutColors;
    final scored = _scored(report);
    return AnimatedBuilder(
      animation: Listenable.merge([_number, _checking, _fill]),
      builder:
          (context, child) => Opacity(
            opacity: (scored ? Curves.easeOut.transform(_number.value) : 1) * (1 - 0.6 * _checking.value),
            child:
                scored
                    ? Text(
                      '${(_value * 100).round()}',
                      textAlign: TextAlign.center,
                      style: CoconutTypography.heading1_32_NumberBold
                          .copyWith(fontSize: 64, height: 1, fontFeatures: const [FontFeature.tabularFigures()])
                          .setColor(colors.primaryText),
                    )
                    : child,
          ),
      child: Container(
        width: 20,
        height: 4,
        decoration: BoxDecoration(color: colors.primaryText, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  Widget _center(BuildContext context, WalletHealthReport? report, bool critical) {
    final colors = context.coconutColors;
    final compact = widget._compact;
    if (critical) {
      final iconSize = compact ? 24.0 : 40.0;
      return SvgPicture.asset(
        CommonStateIconPath.siren,
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(colors.danger, BlendMode.srcIn),
      );
    }
    final scored = _scored(report);
    final top =
        scored
            ? Text(
              '${report!.score}',
              textAlign: TextAlign.center,
              style: CoconutTypography.heading4_18_NumberBold.setColor(colors.primaryText),
            )
            : Center(
              child: Container(
                width: 20,
                height: 4,
                decoration: BoxDecoration(color: colors.primaryText, borderRadius: BorderRadius.circular(2)),
              ),
            );
    // 검사 중이면 이전 값을 옅게
    final dimmed = AnimatedBuilder(
      animation: Listenable.merge([_number, _checking]),
      builder:
          (context, child) => Opacity(
            opacity: (scored ? Curves.easeOut.transform(_number.value) : 1) * (1 - 0.6 * _checking.value),
            child: child,
          ),
      child: top,
    );
    if (compact) return dimmed;
    final caption = _caption(report);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dimmed,
        if (caption.isNotEmpty) ...[
          CoconutLayout.spacing_200h,
          Text(
            safetyKoText(caption),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: CoconutTypography.body3_12.setColor(colors.secondaryText),
          ),
        ],
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  static const _startAngle = 3 * math.pi / 4;
  static const _span = 3 * math.pi / 2;
  static const _highlight = 48 * math.pi / 180;

  _GaugePainter({
    required this.stroke,
    required this.track,
    required this.fill,
    required this.stops,
    required this.critical,
    required this.progress,
    required this.fillOpacity,
    required this.sweep,
    required this.sweepOpacity,
  });

  final double stroke;
  final Color track;
  final List<Color> fill;
  final List<double> stops;
  final Color? critical;
  final double progress, fillOpacity, sweepOpacity;

  /// 검사 중 하이라이트 위치(0~1). null이면 그리지 않는다
  final double? sweep;

  /// 원호 위치 [t](0~1)의 구간 색
  Color _colorAt(double t) {
    for (var i = 1; i < stops.length; i++) {
      if (t <= stops[i]) {
        final span = stops[i] - stops[i - 1];
        return Color.lerp(fill[i - 1], fill[i], span == 0 ? 0 : (t - stops[i - 1]) / span)!;
      }
    }
    return fill.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.width / 2), radius: radius);
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round;
    if (critical != null) {
      canvas.drawArc(rect, _startAngle, _span, false, paint..color = critical!);
      return;
    }
    canvas.drawArc(rect, _startAngle, _span, false, paint..color = track);

    // 둥근 끝이 반대쪽 색을 집지 않게 cap 각도만큼 넓힌다. 각도는 회전으로 맞춘다(시작각 > 끝각을 피함)
    final cap = stroke / 2 / radius;
    Shader gradient(double from, double sweepAngle, List<Color> colors, [List<double>? stops]) => SweepGradient(
      endAngle: sweepAngle,
      colors: colors,
      stops: stops,
      transform: GradientRotation(from),
    ).createShader(rect);
    Color faded(Color color, double opacity) => color.withValues(alpha: color.a * opacity);

    if (progress > 0) {
      canvas.drawArc(
        rect,
        _startAngle,
        _span * progress,
        false,
        paint
          ..shader = gradient(_startAngle - cap, _span + 2 * cap, [
            for (final color in fill) faded(color, fillOpacity),
          ], stops),
      );
    }

    final s = sweep;
    if (s == null || sweepOpacity <= 0) return;
    // 48° 하이라이트가 시작에서 끝으로 지나간다. 머리 불투명 → 꼬리 투명
    final head = s * (_span + _highlight);
    final tail = head - _highlight;
    final from = math.max(0.0, tail);
    final to = math.min(_span, head);
    if (to <= from) return;
    final color = _colorAt((from + to) / 2 / _span);
    Color at(double angle) => faded(color, sweepOpacity * ((angle - tail) / _highlight).clamp(0.0, 1.0));
    canvas.drawArc(
      rect,
      _startAngle + from,
      to - from,
      false,
      paint..shader = gradient(_startAngle + from - cap, to - from + 2 * cap, [at(from), at(to)]),
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fillOpacity != fillOpacity ||
      oldDelegate.sweep != sweep ||
      oldDelegate.sweepOpacity != sweepOpacity ||
      oldDelegate.critical != critical ||
      oldDelegate.track != track ||
      !listEquals(oldDelegate.fill, fill) ||
      !listEquals(oldDelegate.stops, stops) ||
      oldDelegate.stroke != stroke;
}
