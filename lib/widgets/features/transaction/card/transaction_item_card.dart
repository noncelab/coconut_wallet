import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/icon/transaction_status_gradient_mask.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

class TransactionItemCard extends StatelessWidget {
  final TransactionRecord tx;
  final BitcoinUnit currentUnit;
  final int id;
  final Function onPressed;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool compact;
  final Color? backgroundColor;

  late final TransactionStatus? status;

  TransactionItemCard({
    super.key,
    required this.tx,
    required this.currentUnit,
    required this.id,
    required this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: Sizes.size20, vertical: Sizes.size16),
    this.borderRadius = 12,
    this.compact = false,
    this.backgroundColor,
  }) {
    status = TransactionUtil.getStatus(tx);
  }

  Widget _buildStatus(BuildContext context, {bool boundedLabel = false}) {
    final iconPath = TransactionUtil.getStatusIconAsset(status);
    String statusText;
    Color? iconColor;
    switch (status) {
      case TransactionStatus.received:
        statusText = t.status_received;
        iconColor = context.coconutColors.receivingColor;
        break;
      case TransactionStatus.receiving:
        statusText = t.status_receiving;
        iconColor = context.coconutColors.receivingColor;
        break;
      case TransactionStatus.sent:
        statusText = t.status_sent;
        iconColor = context.coconutColors.sendingColor;
        break;
      case TransactionStatus.sending:
        statusText = t.status_sending;
        iconColor = context.coconutColors.sendingColor;
        break;
      case TransactionStatus.self:
        statusText = t.status_sent;
        break;
      case TransactionStatus.selfsending:
        statusText = t.status_sending;
        break;
      default:
        return const SizedBox.shrink(); // fallback
    }
    return _buildIconStatus(context, iconPath, iconColor, statusText, boundedLabel: boundedLabel);
  }

  Widget _buildIconStatus(
    BuildContext context,
    String assetPath,
    Color? iconColor,
    String statusString, {
    bool boundedLabel = false,
  }) {
    final icon =
        iconColor == null
            ? TransactionStatusGradientMask(
              child: SvgPicture.asset(
                assetPath,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
              ),
            )
            : SvgPicture.asset(
              assetPath,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            );

    final label = Text(statusString, style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [icon, CoconutLayout.spacing_200w, if (boundedLabel) Expanded(child: label) else label],
    );
  }

  String? _statusText() {
    switch (status) {
      case TransactionStatus.received:
        return t.status_received;
      case TransactionStatus.receiving:
        return t.status_receiving;
      case TransactionStatus.sent:
      case TransactionStatus.self:
        return t.status_sent;
      case TransactionStatus.sending:
      case TransactionStatus.selfsending:
        return t.status_sending;
      default:
        return null;
    }
  }

  Widget _buildCompact(BuildContext context, List<String> transactionTimeStamp) {
    final colors = context.coconutColors;
    final amountString = currentUnit.displayBitcoinAmount(tx.amount);
    final isReceived = status == TransactionStatus.received || status == TransactionStatus.receiving;
    final amountLabel = '${isReceived ? '+' : ''}$amountString';
    final amountStyle = CoconutTypography.body1_16_Number.setColor(colors.primaryText);
    final timeStyle = CoconutTypography.body3_12
        .setColor(colors.tertiaryText)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final timeLabel = transactionTimeStamp[1];
    return LayoutBuilder(
      builder: (context, constraints) {
        final amountWidth = _singleLineWidth(context, amountLabel, amountStyle);
        final timeWidth =
            [for (var digit = 0; digit <= 9; digit++) _singleLineWidth(context, '$digit$digit:$digit$digit', timeStyle)]
                .reduce(math.max)
                .ceilToDouble() +
            2;
        final time = SizedBox(width: timeWidth, child: Text(timeLabel, style: timeStyle, maxLines: 1, softWrap: false));
        final statusText = _statusText();
        final statusWidth =
            statusText == null ? 0.0 : 24 + 8 + _singleLineWidth(context, statusText, CoconutTypography.body2_14);
        final oneRow = timeWidth + 12 + statusWidth + 12 + amountWidth <= constraints.maxWidth;
        final amount = Text(amountLabel, textAlign: TextAlign.right, style: amountStyle);
        if (oneRow) {
          return Row(
            children: [
              Expanded(child: Row(children: [time, const SizedBox(width: 12), _buildStatus(context)])),
              const SizedBox(width: 12),
              amount,
            ],
          );
        }
        // 좁은 화면에서는 왼쪽 그룹 안에서만 줄을 바꾸고 수량은 오른쪽에 유지한다.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [time, const SizedBox(height: 4), _buildStatus(context, boundedLabel: true)],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: math.max(0, (constraints.maxWidth - 12) * 0.5)),
              child: amount,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAmount(BuildContext context) {
    final String amountString = currentUnit.displayBitcoinAmount(tx.amount);
    final bool isReceived = status == TransactionStatus.received || status == TransactionStatus.receiving;
    final String prefix = isReceived ? '+' : '';

    return Expanded(
      child: FittedBox(
        alignment: Alignment.centerRight,
        fit: BoxFit.scaleDown,
        child: Text(
          '$prefix$amountString',
          style: CoconutTypography.body1_16_Number.setColor(context.coconutColors.primaryText),
        ),
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context, List<String> transactionTimeStamp) {
    final textStyle = CoconutTypography.body3_12_Number.setColor(context.coconutColors.tertiaryText);
    return Row(
      children: [
        Text(transactionTimeStamp[0], style: textStyle),
        CoconutLayout.spacing_200w,
        Text('|', style: textStyle),
        CoconutLayout.spacing_200w,
        Text(transactionTimeStamp[1], style: textStyle),
      ],
    );
  }

  Widget _buildMemo(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SvgPicture.asset(
          CommonActionIconPath.editOutlined,
          colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
          width: Sizes.size12,
        ),
        CoconutLayout.spacing_100w,
        Text(
          TextUtils.ellipsisIfLonger(tx.memo!, maxLength: 20),
          style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String>? transactionTimeStamp = DateTimeUtil.formatTimestamp(tx.getDateTimeToDisplay()!.toLocal());
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      onPressed: () {
        onPressed();
      },
      defaultColor: backgroundColor ?? colors.surface,
      pressedOverlayColor: colors.surfacePressOverlay,
      pressedOverlayOpacity: colors.surfacePressOverlayOpacity,
      borderWidth: 0,
      borderRadius: borderRadius,
      child: Container(
        padding: padding,
        child:
            compact
                ? _buildCompact(context, transactionTimeStamp)
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimestamp(context, transactionTimeStamp),
                    CoconutLayout.spacing_200h,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [_buildStatus(context), CoconutLayout.spacing_200w, _buildAmount(context)],
                    ),
                    if (tx.memo != null && tx.memo!.isNotEmpty) _buildMemo(context),
                  ],
                ),
      ),
    );
  }
}

double _singleLineWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
