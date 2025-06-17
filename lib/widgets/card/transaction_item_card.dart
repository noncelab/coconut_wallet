import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class TransactionItemCard extends StatelessWidget {
  final TransactionRecord tx;
  final Unit currentUnit;
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

  Widget _buildStatus() {
    switch (status) {
      case TransactionStatus.received:
        return _buildIconStatus('assets/svg/tx-received.svg', t.status_received);
      case TransactionStatus.receiving:
        return _buildIconStatus('assets/svg/tx-receiving.svg', t.status_receiving);
      case TransactionStatus.sent:
        return _buildIconStatus('assets/svg/tx-sent.svg', t.status_sent);
      case TransactionStatus.sending:
        return _buildIconStatus('assets/svg/tx-sending.svg', t.status_sending);
      case TransactionStatus.self:
        return _buildIconStatus('assets/svg/tx-self.svg', t.status_sent);
      case TransactionStatus.selfsending:
        return _buildIconStatus('assets/svg/tx-self-sending.svg', t.status_sending);
      default:
        return const SizedBox.shrink(); // fallback
    }
  }

  Widget _buildIconStatus(String assetPath, String statusString) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          assetPath,
          width: 24,
          height: 24,
        ),
        CoconutLayout.spacing_200w,
        Text(
          statusString,
          style: CoconutTypography.body2_14.setColor(CoconutColors.white),
        )
      ],
    );
  }

  Widget _buildAmount() {
    final String amountString = currentUnit == Unit.btc
        ? satoshiToBitcoinString(tx.amount)
        : addCommasToIntegerPart(tx.amount.toDouble());
    final bool isReceived =
        status == TransactionStatus.received || status == TransactionStatus.receiving;
    final String prefix = isReceived ? '+' : '';

    return Text('$prefix$amountString',
        style: CoconutTypography.body1_16_Number.setColor(CoconutColors.white));
  }

  Widget _buildTimestamp(List<String> transactionTimeStamp) {
    final textStyle = CoconutTypography.body3_12_Number.setColor(CoconutColors.gray400);
    return Row(
      children: [
        Text(
          transactionTimeStamp[0],
          style: textStyle,
        ),
        CoconutLayout.spacing_200w,
        Text(
          '|',
          style: textStyle,
        ),
        CoconutLayout.spacing_200w,
        Text(
          transactionTimeStamp[1],
          style: textStyle,
        ),
      ],
    );
  }

  Widget _buildMemo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SvgPicture.asset('assets/svg/pen.svg',
            colorFilter: const ColorFilter.mode(CoconutColors.gray350, BlendMode.srcIn),
            width: Sizes.size12),
        CoconutLayout.spacing_100w,
        Padding(
          padding: const EdgeInsets.only(bottom: Sizes.size2),
          child: Text(
            TextUtils.ellipsisIfLonger(
              tx.memo!,
              maxLength: 13,
            ),
            style: CoconutTypography.body3_12.setColor(CoconutColors.white),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String>? transactionTimeStamp =
        DateTimeUtil.formatTimestamp(tx.getDateTimeToDisplay()!.toLocal());
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
              _buildTimestamp(transactionTimeStamp),
              CoconutLayout.spacing_200h,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [_buildStatus(), _buildAmount()],
              ),
              if (tx.memo != null) _buildMemo(),
            ],
          ),
        ));
  }
}
