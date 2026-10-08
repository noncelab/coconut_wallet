import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';

({Color up, Color down}) homePriceColors(BuildContext context) {
  final colors = context.coconutColors;
  return (up: colors.priceUp, down: colors.priceDown);
}

/// 변화율에 맞는 색. 변화가 없거나 값이 없으면 [neutral]
Color homePriceColorOf(BuildContext context, double? rate, {required Color neutral}) {
  if (rate == null || rate == 0) return neutral;
  final price = homePriceColors(context);
  return rate > 0 ? price.up : price.down;
}

/// 누를 수 있는 홈 위젯. 누르는 동안 살짝 줄어든다.
class HomeWidgetPressable extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const HomeWidgetPressable({super.key, required this.onTap, required this.child});

  @override
  State<HomeWidgetPressable> createState() => _HomeWidgetPressableState();
}

class _HomeWidgetPressableState extends State<HomeWidgetPressable> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

/// 모든 위젯의 첫 줄 높이. 제목·보조 텍스트를 이 줄의 세로 가운데에 두어, 위젯을 나란히 놓아도 첫 줄이 맞는다.
const kHomeWidgetHeaderHeight = 20.0;

class HomeWidgetHeader extends StatelessWidget {
  final String iconPath;
  final Key? iconKey;
  final String title;
  final TextStyle style;

  const HomeWidgetHeader({super.key, required this.iconPath, this.iconKey, required this.title, required this.style});

  @override
  Widget build(BuildContext context) {
    final color = context.coconutColors.primaryText;
    return SizedBox(
      height: kHomeWidgetHeaderHeight,
      child: Row(
        children: [
          SvgPicture.asset(
            iconPath,
            key: iconKey,
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(color: color, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

/// 데이터를 기다리는 동안 보여 주는 위젯 자리
class HomeWidgetSkeleton extends StatelessWidget {
  final bool wide;

  const HomeWidgetSkeleton({super.key, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(color: colors.surfaceSkeletonBase, borderRadius: BorderRadius.circular(4)),
      ),
    );
    return HomeWidgetCard(
      child: Shimmer.fromColors(
        baseColor: colors.surfaceSkeletonBase,
        highlightColor: colors.surfaceSkeletonHighlight,
        child: Column(
          key: const Key('home-widget-skeleton'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(wide ? 0.4 : 0.7, 16),
            const SizedBox(height: 8),
            bar(wide ? 0.25 : 0.45, 10),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: colors.surfaceSkeletonBase, borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            bar(wide ? 0.3 : 0.55, 10),
          ],
        ),
      ),
    );
  }
}

/// 이 아래 카드의 바탕색을 바꾼다. 카드가 회색 띠 위에 놓일 때 흰 카드로 뒤집는 데 쓴다.
class HomeCardSurface extends InheritedWidget {
  final Color color;

  const HomeCardSurface({super.key, required this.color, required super.child});

  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeCardSurface>()?.color ?? context.coconutColors.homeSurface;

  @override
  bool updateShouldNotify(HomeCardSurface oldWidget) => oldWidget.color != color;
}

class HomeWidgetCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsets padding;

  const HomeWidgetCard({super.key, required this.child, this.onPressed, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final surface = HomeCardSurface.of(context);
    final content = SizedBox.expand(child: Padding(padding: padding, child: child));
    if (onPressed == null) {
      return DecoratedBox(
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20)),
        child: content,
      );
    }
    return ShrinkAnimationButton(
      defaultColor: surface,
      pressedOverlayColor: colors.homeSurfacePressOverlay,
      pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
      borderRadius: 20,
      onPressed: onPressed!,
      child: content,
    );
  }
}

/// [Text]가 그릴 때와 같은 조건(주변 기본 스타일, 글자 배율, 언어)으로 잰 한 줄 폭
double measureHomeText(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

String formatHomeFiat(int? amount, FiatCode fiat, {bool withSymbol = true}) {
  if (amount == null) return '-';
  final text = amount.toThousandsSeparatedString();
  return withSymbol ? '${fiat.symbol} $text' : text;
}

String formatHomeRate(double rate) => '${(rate.abs() * 100).toStringAsFixed(2)}%';

String formatHomeRelativeTime(DateTime time, DateTime now) {
  final difference = now.difference(time);
  if (difference.inMinutes < 1) return t.relative_time.just_now;
  if (difference.inHours < 1) return t.relative_time.minutes_ago(n: difference.inMinutes);
  if (difference.inDays < 1) return t.relative_time.hours_ago(n: difference.inHours);
  return t.relative_time.days_ago(n: difference.inDays);
}

String formatHomeShortDate(DateTime day) => '${day.month}/${day.day}';

String formatHomeMonth(DateTime day) => t.home_widgets.months_short[day.month - 1];

String homePeriodLabel(HomeWidgetPeriod period) => switch (period) {
  HomeWidgetPeriod.week => t.home_edit.periods.week,
  HomeWidgetPeriod.month => t.home_edit.periods.month,
  HomeWidgetPeriod.threeMonths => t.home_edit.periods.three_months,
  HomeWidgetPeriod.year => t.home_edit.periods.year,
  HomeWidgetPeriod.all => t.home_edit.periods.all,
};

String formatHomeDateTime(DateTime time, DateTime now) {
  final hhmm = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  final isToday = time.year == now.year && time.month == now.month && time.day == now.day;
  return isToday ? '${t.home_widgets.today} $hhmm' : '${formatHomeShortDate(time)} $hhmm';
}

int fiatAmountOf(int sats, int price) => FiatUtil.calculateFiatAmount(sats, price);

class HomeAmount {
  final String number;
  final String unit;
  final bool unitFirst;

  const HomeAmount(this.number, this.unit, {this.unitFirst = false});
}

/// 숫자는 크고 굵게, 단위는 작고 보통 굵기로
class HomeAmountText extends StatelessWidget {
  final HomeAmount amount;
  final TextStyle numberStyle;
  final TextStyle unitStyle;

  const HomeAmountText({super.key, required this.amount, required this.numberStyle, required this.unitStyle});

  @override
  Widget build(BuildContext context) {
    final color = context.coconutColors.primaryText;
    final number = TextSpan(
      text: amount.number,
      style: numberStyle.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]),
    );
    final unit = TextSpan(text: amount.unit, style: unitStyle.copyWith(color: color));
    final gap = TextSpan(text: ' ', style: unitStyle);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: amount.unit.isEmpty ? [number] : (amount.unitFirst ? [unit, gap, number] : [number, gap, unit]),
        ),
        maxLines: 1,
      ),
    );
  }
}

String formatHomeRateCompact(double rate) {
  final fixed = (rate.abs() * 100).toStringAsFixed(2);
  final trimmed = fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
  return '$trimmed%';
}

/// 추이 위젯의 변화율: 상승·하락 색 ↑ / ↓ + 회색 비율. 변화가 없거나 값이 없으면 회색 –
class HomeTrendChange extends StatelessWidget {
  final double? rate;

  /// 정하면 이 폭의 칸 안에 오른쪽 정렬한다. 칸 폭이 고정이라 값이 바뀌어도 옆 요소가 움직이지 않는다.
  final double? width;

  const HomeTrendChange({super.key, required this.rate, this.width});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final rate = this.rate;
    final color = homePriceColorOf(context, rate, neutral: colors.tertiaryText);
    final arrowStyle = CoconutTypography.body3_12_Number.copyWith(color: color);
    final rateStyle = CoconutTypography.caption_10_Number.copyWith(
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final hasChange = rate != null && rate != 0;
    final arrow = hasChange ? Text(rate > 0 ? '↑' : '↓', style: arrowStyle) : null;
    final percent = Text(hasChange ? formatHomeRateCompact(rate) : '–', maxLines: 1, style: rateStyle);
    final group = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (arrow != null) ...[arrow, const SizedBox(width: 2)],
        percent,
      ],
    );
    if (width == null) return group;
    return SizedBox(
      width: width,
      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomRight, child: group),
    );
  }
}

class HomeSparkline extends StatelessWidget {
  final List<num> values;
  final Color? color;
  final double strokeWidth;

  /// 손가락으로 짚은 점. 세로 안내선과 점을 그린다.
  final int? selectedIndex;

  const HomeSparkline({super.key, required this.values, this.color, this.strokeWidth = 2, this.selectedIndex});

  /// [index]번째 값이 [size] 안에서 그려지는 위치
  static Offset pointOf(List<num> values, int index, Size size, {double strokeWidth = 2}) {
    final doubles = [for (final value in values) value.toDouble()];
    final minValue = doubles.reduce(math.min);
    final range = doubles.reduce(math.max) - minValue;
    final x = values.length < 2 ? size.width / 2 : size.width * index / (values.length - 1);
    final ratio = range == 0 ? 0.5 : (doubles[index] - minValue) / range;
    return Offset(x, strokeWidth + (size.height - strokeWidth * 2) * (1 - ratio));
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(
        [for (final value in values) value.toDouble()],
        color ?? context.coconutColors.homeChartLine,
        strokeWidth,
        selectedIndex: selectedIndex,
        guideColor: context.coconutColors.tertiaryText,
      ),
      size: Size.infinite,
    );
  }
}

/// 점들을 단조 3차 보간(Fritsch-Carlson)으로 잇는다. 곡선이 실제 값보다 위아래로 튀지 않는다.
Path smoothPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  if (points.length == 1) return path;
  final n = points.length;
  final slopes = [
    for (var i = 0; i < n - 1; i++) (points[i + 1].dy - points[i].dy) / math.max(points[i + 1].dx - points[i].dx, 1e-9),
  ];
  final tangents = List<double>.filled(n, 0);
  tangents[0] = slopes.first;
  tangents[n - 1] = slopes.last;
  for (var i = 1; i < n - 1; i++) {
    tangents[i] = slopes[i - 1] * slopes[i] <= 0 ? 0 : (slopes[i - 1] + slopes[i]) / 2;
  }
  for (var i = 0; i < n - 1; i++) {
    if (slopes[i] == 0) {
      tangents[i] = 0;
      tangents[i + 1] = 0;
      continue;
    }
    final a = tangents[i] / slopes[i];
    final b = tangents[i + 1] / slopes[i];
    final h = a * a + b * b;
    if (h > 9) {
      final tau = 3 / math.sqrt(h);
      tangents[i] = tau * a * slopes[i];
      tangents[i + 1] = tau * b * slopes[i];
    }
  }
  for (var i = 0; i < n - 1; i++) {
    final from = points[i];
    final to = points[i + 1];
    final third = (to.dx - from.dx) / 3;
    path.cubicTo(
      from.dx + third,
      from.dy + tangents[i] * third,
      to.dx - third,
      to.dy - tangents[i + 1] * third,
      to.dx,
      to.dy,
    );
  }
  return path;
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double strokeWidth;

  final int? selectedIndex;
  final Color? guideColor;

  _SparklinePainter(this.values, this.color, this.strokeWidth, {this.selectedIndex, this.guideColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = maxValue - minValue;
    final inset = strokeWidth;
    Offset point(int i) {
      final x = size.width * i / (values.length - 1);
      final ratio = range == 0 ? 0.5 : (values[i] - minValue) / range;
      return Offset(x, inset + (size.height - inset * 2) * (1 - ratio));
    }

    final points = [for (var i = 0; i < values.length; i++) point(i)];
    final path = smoothPath(points);
    canvas.drawPath(
      path.shift(Offset(0, strokeWidth * 2)),
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 1.5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < values.length) {
      final at = points[selected];
      canvas.drawLine(
        Offset(at.dx, 0),
        Offset(at.dx, size.height),
        Paint()
          ..color = (guideColor ?? color).withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(at, strokeWidth * 2.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.selectedIndex != selectedIndex ||
      !_sameValues(oldDelegate.values, values);

  static bool _sameValues(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
