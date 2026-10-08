import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter/cupertino.dart';

class HomeFiatRow {
  final FiatCode fiat;
  final String amountText;
  final double? rate;

  const HomeFiatRow({required this.fiat, required this.amountText, this.rate});
}

/// 2×2: BTC 잔액 + 추이 + 법정화폐 환산액 + 기간 변화율
class BitcoinBalanceTrendView extends StatelessWidget {
  final HomeAmount balance;
  final String fiatText;
  final double? rate;
  final List<num> values;

  const BitcoinBalanceTrendView({
    super.key,
    required this.balance,
    required this.fiatText,
    required this.rate,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return HomeWidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeAmountText(
            amount: balance,
            numberStyle: CoconutTypography.heading4_18_NumberBold,
            unitStyle: CoconutTypography.body3_12_Number,
          ),
          Expanded(
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: HomeSparkline(values: values)),
          ),
          _TrendFooter(valueText: fiatText, rate: rate, valueColor: context.coconutColors.homeChartLine),
        ],
      ),
    );
  }
}

/// 2×2: 법정화폐 평가액 + 추이 + BTC 시세 + 24시간 변화율
/// 2×2: 비트코인 시세 추이. 잔액을 보여 주지 않아 가짜 잔액과 상관없다.
class FiatPriceTrendView extends StatelessWidget {
  final HomeAmount price;

  /// 아래 줄 왼쪽의 통화 쌍(예: BTC · KRW)
  final String pairLabel;

  /// 기간 동안의 시세 등락률
  final double? rate;
  final List<num> values;

  const FiatPriceTrendView({
    super.key,
    required this.price,
    required this.pairLabel,
    required this.rate,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return HomeWidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeAmountText(
            amount: price,
            numberStyle: CoconutTypography.heading4_18_NumberBold,
            unitStyle: CoconutTypography.body3_12_Number,
          ),
          Expanded(
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: HomeSparkline(values: values)),
          ),
          _TrendFooter(valueText: pairLabel, rate: rate, valueColor: context.coconutColors.tertiaryText),
        ],
      ),
    );
  }
}

class _TrendFooter extends StatelessWidget {
  static const changeWidth = 48.0;

  /// 줄 높이를 고정하고 아래 끝에 맞춰, 값의 길이가 바뀌어 글자가 줄어들어도 위치가 움직이지 않게 한다.
  static const height = 17.0;

  final String valueText;
  final double? rate;

  /// 정하지 않으면 변화율에 따른 상승/하락 색
  final Color? valueColor;

  const _TrendFooter({required this.valueText, required this.rate, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('home-trend-footer'),
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Text(
                valueText,
                maxLines: 1,
                style: CoconutTypography.body3_12_NumberBold.copyWith(
                  color: valueColor ?? homePriceColorOf(context, rate, neutral: context.coconutColors.primaryText),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          HomeTrendChange(rate: rate, width: changeWidth),
        ],
      ),
    );
  }
}

/// 2×2: 통화별 BTC 시세
class FiatValuesView extends StatelessWidget {
  final List<HomeFiatRow> rows;

  const FiatValuesView({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return HomeWidgetCard(
      child: _FiatRows(
        rows: rows,
        amountStyle: CoconutTypography.body2_14_NumberBold,
        dividerKeyPrefix: 'fiat-values-divider',
      ),
    );
  }
}

/// 2×2: BTC 잔액 + 통화별 환산액
class BitcoinBalanceByFiatView extends StatelessWidget {
  final HomeAmount balance;
  final List<HomeFiatRow> rows;

  const BitcoinBalanceByFiatView({super.key, required this.balance, required this.rows});

  @override
  Widget build(BuildContext context) {
    return HomeWidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeAmountText(
            amount: balance,
            numberStyle: CoconutTypography.heading4_18_NumberBold,
            unitStyle: CoconutTypography.body3_12_Number,
          ),
          const SizedBox(height: 8),
          Expanded(child: _FiatRows(rows: rows, amountStyle: CoconutTypography.body3_12_NumberBold)),
        ],
      ),
    );
  }
}

/// 통화별 줄. 금액이 칸보다 길면 가장 긴 금액에 맞춘 같은 크기로 모든 줄의 금액을 줄인다.
class _FiatRows extends StatelessWidget {
  static const arrowGap = 3.0;
  static const amountGap = 8.0;
  static final codeStyle = CoconutTypography.body3_12_Bold;

  final List<HomeFiatRow> rows;
  final TextStyle amountStyle;
  final String? dividerKeyPrefix;

  const _FiatRows({required this.rows, required this.amountStyle, this.dividerKeyPrefix});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final arrowSize = codeStyle.fontSize ?? 14;
    final numberStyle = amountStyle.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final codeWidth = rows.fold<double>(0, (max, row) {
          final width = measureHomeText(context, row.fiat.code, codeStyle);
          return width > max ? width : max;
        });
        final available = constraints.maxWidth - arrowSize - arrowGap - codeWidth - amountGap;
        var scale = 1.0;
        for (final row in rows) {
          final width = measureHomeText(context, row.amountText, numberStyle);
          if (width > available && available > 0) scale = scale < available / width ? scale : available / width;
        }
        final scaledStyle = numberStyle.copyWith(fontSize: (numberStyle.fontSize ?? 14) * scale);
        Widget rowOf(HomeFiatRow row) => Row(
          children: [
            SizedBox(width: arrowSize, child: Center(child: _RateArrow(rate: row.rate, size: arrowSize))),
            const SizedBox(width: arrowGap),
            SizedBox(
              width: codeWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(row.fiat.code, maxLines: 1, style: codeStyle.copyWith(color: colors.primaryText)),
              ),
            ),
            const SizedBox(width: amountGap),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  row.amountText,
                  maxLines: 1,
                  style: scaledStyle.copyWith(color: homePriceColorOf(context, row.rate, neutral: colors.primaryText)),
                ),
              ),
            ),
          ],
        );
        if (dividerKeyPrefix == null) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final row in rows) rowOf(row)],
          );
        }
        return Column(
          children: [
            for (final (index, row) in rows.indexed) ...[
              if (index > 0)
                Expanded(
                  child: Center(
                    child: Container(key: ValueKey('$dividerKeyPrefix-$index'), height: 1, color: colors.divider),
                  ),
                ),
              rowOf(row),
            ],
          ],
        );
      },
    );
  }
}

/// 통화 줄의 등락 표시. 글자 대신 도형 아이콘이라 글꼴과 상관없이 줄 가운데에 놓인다.
class _RateArrow extends StatelessWidget {
  final double? rate;
  final double size;

  const _RateArrow({required this.rate, required this.size});

  @override
  Widget build(BuildContext context) {
    final rate = this.rate;
    if (rate == null || rate == 0) {
      return Text(
        '–',
        key: const Key('fiat-rate-neutral'),
        style: CoconutTypography.body3_12.copyWith(color: context.coconutColors.tertiaryText, height: 1),
      );
    }
    return Icon(
      rate > 0 ? CupertinoIcons.arrowtriangle_up_fill : CupertinoIcons.arrowtriangle_down_fill,
      key: Key(rate > 0 ? 'fiat-rate-up' : 'fiat-rate-down'),
      size: size,
      color: homePriceColorOf(context, rate, neutral: context.coconutColors.tertiaryText),
    );
  }
}

/// 4×2: BTC 잔액 + 법정화폐 + 기간 변화율·변화량 + 일별 추이
class BalanceChangeOverTimeView extends StatelessWidget {
  final HomeAmount balance;
  final String fiatText;
  final double? rate;
  final String deltaText;
  final int deltaSign;
  final List<num> values;
  final List<String> dayLabels;

  const BalanceChangeOverTimeView({
    super.key,
    required this.balance,
    required this.fiatText,
    required this.rate,
    required this.deltaText,
    required this.deltaSign,
    required this.values,
    required this.dayLabels,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final deltaColor = homePriceColorOf(context, deltaSign.toDouble(), neutral: colors.primaryText);
    return HomeWidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeAmountText(
                      amount: balance,
                      numberStyle: CoconutTypography.heading4_18_NumberBold,
                      unitStyle: CoconutTypography.body3_12_Number,
                    ),
                    Text(
                      fiatText,
                      key: const Key('balance-change-fiat'),
                      style: CoconutTypography.caption_10_Number.copyWith(color: colors.secondaryText),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  HomeTrendChange(key: const Key('balance-change-rate'), rate: rate),
                  const SizedBox(height: 2),
                  Text(
                    deltaText,
                    key: const Key('balance-change-delta'),
                    style: CoconutTypography.body3_12_Number.copyWith(color: deltaColor),
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: HomeSparkline(values: values)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in dayLabels)
                Text(label, style: CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText)),
            ],
          ),
        ],
      ),
    );
  }
}
