import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/repository/realm/converter/transaction.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class TransactionItemCard extends StatelessWidget {
  final TransferDTO tx;
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

  // @override
  // State<TransactionItemCard> createState() => _TransactionItemCardState();

  Widget _getStatusWidget() {
    TextStyle fontStyle = Styles.body2.merge(
      const TextStyle(
        fontWeight: FontWeight.w500,
        height: 21 / 14,
      ),
    );
    switch (status) {
      case TransactionStatus.received:
        return Row(
          children: [
            SvgPicture.asset(
              'assets/svg/tx-received.svg',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              '받기 완료',
              style: fontStyle,
            )
          ],
        );
      case TransactionStatus.receiving:
        return Row(
          children: [
            SvgPicture.asset(
              'assets/svg/tx-receiving.svg',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              '받는 중',
              style: fontStyle,
            )
          ],
        );
      case TransactionStatus.sent:
        return Row(
          children: [
            SvgPicture.asset(
              'assets/svg/tx-sent.svg',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              '보내기 완료',
              style: fontStyle,
            )
          ],
        );
      case TransactionStatus.sending:
        return Row(
          children: [
            SvgPicture.asset(
              'assets/svg/tx-sending.svg',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              '보내는 중',
              style: fontStyle,
            )
          ],
        );
      case TransactionStatus.self:
        return Row(
          children: [
            SvgPicture.asset(
              'assets/svg/tx-self.svg',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              '받기 완료',
              style: fontStyle,
            )
          ],
        );
      case TransactionStatus.selfsending:
        return Row(
          children: [
            SvgPicture.asset(
              'assets/svg/tx-self-sending.svg',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              '보내는 중',
              style: fontStyle,
            )
          ],
        );
      default:
        throw "[_TransactionRowItem] status: $status";
    }
  }

  Widget _getAmountWidget() {
    switch (status) {
      case TransactionStatus.receiving:
      case TransactionStatus.received:
        return Text(
          currentUnit == Unit.btc
              ? '+${satoshiToBitcoinString(tx.amount!)}'
              : '+${addCommasToIntegerPart(tx.amount!.toDouble())}',
          style: Styles.body1Number.merge(
            const TextStyle(
              color: MyColors.white,
              fontWeight: FontWeight.w400,
              height: 24 / 16,
            ),
          ),
        );
      case TransactionStatus.self:
      case TransactionStatus.selfsending:
      case TransactionStatus.sent:
      case TransactionStatus.sending:
        return Text(
          currentUnit == Unit.btc
              ? satoshiToBitcoinString(tx.amount!)
              : addCommasToIntegerPart(tx.amount!.toDouble()),
          style: Styles.body1Number.merge(
            const TextStyle(
              color: MyColors.white,
              fontWeight: FontWeight.w400,
              height: 24 / 16,
            ),
          ),
        );
      default:
        // 기본 값으로 처리될 수 있도록 한 경우
        return const SizedBox(
          child: Text("상태 없음"),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String>? transactionTimeStamp = tx.getDateTimeToDisplay() == null
        ? ['--.--.--', '--:--']
        : DateTimeUtil.formatTimeStamp(tx.getDateTimeToDisplay()!.toLocal());

    return ShrinkAnimationButton(
        defaultColor: MyColors.transparentWhite_06,
        onPressed: () {
          onPressed();
        },
        borderWidth: 0,
        borderRadius: MyBorder.defaultRadiusValue,
        child: Container(
          height: 84,
          padding: Paddings.widgetContainer,
          decoration: BoxDecoration(
              borderRadius: MyBorder.defaultRadius,
              color: MyColors.transparentWhite_06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    transactionTimeStamp[0],
                    style: Styles.caption,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Text(
                    '|',
                    style: Styles.caption.merge(
                      const TextStyle(
                        color: MyColors.transparentWhite_40,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Text(
                    transactionTimeStamp[1],
                    style: Styles.caption,
                  ),
                ],
              ),
              const SizedBox(
                height: 5.0,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [_getStatusWidget(), _getAmountWidget()],
              )
            ],
          ),
        ));
  }
}
