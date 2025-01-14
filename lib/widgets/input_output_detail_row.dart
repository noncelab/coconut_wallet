import 'package:coconut_wallet/enums/input_output_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class InputOutputDetailRow extends StatelessWidget {
  final String address;
  final int balance;
  final double balanceMaxWidth;
  final InputOutputRowType rowType;
  final bool isCurrentAddress;
  final TransactionStatus? transactionStatus;

  const InputOutputDetailRow({
    super.key,
    required this.address,
    required this.balance,
    required this.balanceMaxWidth,
    required this.rowType,
    this.isCurrentAddress = false,
    this.transactionStatus,
  });

  @override
  Widget build(BuildContext context) {
    InputOutputRowFeature rowFeature = getRowFeature();
    return Row(
      children: [
        Text(
          TextUtils.truncateNameMax19(address),
          style: Styles.body2Number.merge(
            TextStyle(
              color: rowFeature.leftItemColor,
              fontSize: 14,
              height: 16 / 14,
            ),
          ),
          maxLines: 1,
        ),
        if (rowType == InputOutputRowType.output ||
            rowType == InputOutputRowType.fee)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SvgPicture.asset(
                  rowFeature.assetAddress,
                  width: 16,
                  height: 12,
                  colorFilter:
                      ColorFilter.mode(rowFeature.assetColor, BlendMode.srcIn),
                ),
                const SizedBox(
                  width: 10,
                ),
                SizedBox(
                  width: balanceMaxWidth,
                  child: Text(
                    textAlign: TextAlign.end,
                    satoshiToBitcoinString(balance).normalizeTo11Characters(),
                    style: Styles.body2Number.merge(
                      TextStyle(
                        color: rowFeature.rightItemColor,
                        fontSize: 14,
                        height: 16 / 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (rowType == InputOutputRowType.input)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: balanceMaxWidth,
                  child: Text(
                    satoshiToBitcoinString(balance).normalizeTo11Characters(),
                    style: Styles.body2Number.merge(
                      TextStyle(
                        color: rowFeature.rightItemColor,
                        fontSize: 14,
                        height: 16 / 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                SvgPicture.asset(
                  rowFeature.assetAddress,
                  width: 16,
                  height: 12,
                  colorFilter:
                      ColorFilter.mode(rowFeature.assetColor, BlendMode.srcIn),
                ),
              ],
            ),
          ),
      ],
    );
  }

  InputOutputRowFeature getRowFeature() {
    Color leftItemColor = MyColors.white;
    Color rightItemColor = MyColors.white;
    Color assetColor = MyColors.white;

    String assetAddress = 'assets/svg/circle-arrow-right.svg';

    if (rowType == InputOutputRowType.fee) {
      assetAddress = 'assets/svg/circle-pick.svg';
      if (transactionStatus == null) {
        // UTXO 화면인 경우 색상 변경
        leftItemColor =
            rightItemColor = assetColor = MyColors.transparentWhite_40;
      }

      /// 수수료인 경우 바로 리턴
      return InputOutputRowFeature(
          leftItemColor: leftItemColor,
          rightItemColor: rightItemColor,
          assetColor: assetColor,
          assetAddress: assetAddress,
          pickAddress: 'assets/svg/circle-pick.svg');
    }

    if (transactionStatus != null) {
      /// transactionStatus가 null이 아니면 거래 자세히 보기 화면
      switch (transactionStatus!) {
        case TransactionStatus.received:
        case TransactionStatus.receiving:
          if (rowType == InputOutputRowType.input) {
            /// 인풋
            if (!isCurrentAddress) {
              /// 현재 주소가 아닌 경우
              leftItemColor =
                  rightItemColor = assetColor = MyColors.transparentWhite_40;
            }
          } else {
            /// 아웃풋
            if (isCurrentAddress) {
              /// 현재 주소인 경우
              rightItemColor = assetColor = MyColors.secondary;
            } else {
              /// 현재 주소가 아닌 경우
              leftItemColor =
                  rightItemColor = assetColor = MyColors.transparentWhite_40;
            }
          }
          break;
        case TransactionStatus.sending:
        case TransactionStatus.sent:
          if (rowType == InputOutputRowType.input) {
            /// 안풋
            rightItemColor = assetColor = MyColors.primary;
          } else if (rowType == InputOutputRowType.output &&
              !isCurrentAddress) {
            /// 아웃풋, 현재 주소가 아닌 경우
            leftItemColor =
                rightItemColor = assetColor = MyColors.transparentWhite_40;
          }
          break;
        case TransactionStatus.self:
        case TransactionStatus.selfsending:
          if (rowType == InputOutputRowType.input) {
            if (isCurrentAddress) {
              rightItemColor = assetColor = MyColors.primary;
            } else {
              leftItemColor =
                  rightItemColor = assetColor = MyColors.transparentWhite_40;
            }
          } else {
            if (isCurrentAddress) {
              rightItemColor = assetColor = MyColors.secondary;
            } else {
              leftItemColor =
                  rightItemColor = assetColor = MyColors.transparentWhite_40;
            }
          }
          break;
      }
    } else {
      /// transactionStatus가 null이면 UTXO 상세 화면
      if (rowType == InputOutputRowType.input ||
          (rowType == InputOutputRowType.output && !isCurrentAddress)) {
        leftItemColor =
            rightItemColor = assetColor = MyColors.transparentWhite_40;
      }
    }
    return InputOutputRowFeature(
        leftItemColor: leftItemColor,
        rightItemColor: rightItemColor,
        assetColor: assetColor,
        assetAddress: assetAddress,
        pickAddress: 'assets/svg/circle-pick.svg');
  }
}

class InputOutputRowFeature {
  final Color leftItemColor;
  final Color rightItemColor;
  final Color assetColor;
  final String assetAddress;
  final String pickAddress;

  const InputOutputRowFeature({
    required this.leftItemColor,
    required this.rightItemColor,
    required this.assetColor,
    required this.assetAddress,
    required this.pickAddress,
  });
}
