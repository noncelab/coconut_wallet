import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class TransactionItemCard extends StatelessWidget {
  final TransactionRecord tx;
  final BitcoinUnit currentUnit;
  final int id;
  final Function onPressed;

  late final TransactionStatus? status;

  TransactionItemCard({
    super.key,
    required this.tx,
    required this.currentUnit,
    required this.id,
    required this.onPressed,
  }) {
    status = TransactionUtil.getStatus(tx);
  }

  LinearGradient _buildSelfStatusGradient(BuildContext context) {
    return LinearGradient(
      colors: [context.coconutColors.sendingColor, context.coconutColors.receivingColor],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }

  Widget _buildGradientMasked({required BuildContext context, required Widget child}) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => _buildSelfStatusGradient(context).createShader(bounds),
      child: child,
    );
  }

  Widget _buildStatus(BuildContext context) {
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
    return _buildIconStatus(context, iconPath, iconColor, statusText);
  }

  Widget _buildIconStatus(BuildContext context, String assetPath, Color? iconColor, String statusString) {
    final icon =
        iconColor == null
            ? _buildGradientMasked(
              context: context,
              child: SvgPicture.asset(
                assetPath,
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            )
            : SvgPicture.asset(
              assetPath,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        icon,
        CoconutLayout.spacing_200w,
        Text(statusString, style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText)),
      ],
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
          'assets/svg/pen.svg',
          colorFilter: ColorFilter.mode(context.coconutColors.iconSubDefault, BlendMode.srcIn),
          width: Sizes.size12,
        ),
        CoconutLayout.spacing_100w,
        Text(
          TextUtils.ellipsisIfLonger(tx.memo!, maxLength: 13),
          style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String>? transactionTimeStamp = DateTimeUtil.formatTimestamp(tx.getDateTimeToDisplay()!.toLocal());
    return ShrinkAnimationButton(
      onPressed: () {
        onPressed();
      },
      borderWidth: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sizes.size24, vertical: Sizes.size16),
        child: Column(
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
