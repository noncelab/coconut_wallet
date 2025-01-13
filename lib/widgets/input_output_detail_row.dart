import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_detail_screen.dart';
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
    Color leftItemColor = MyColors.white;
    Color rightItemColor = MyColors.white;
    String assetAddress = 'assets/svg/circle-arrow-right.svg';
    Color assetColor = MyColors.white;

    if (transactionStatus != null) {
      /// transactionStatus가 null이 아니면 거래 자세히 보기 화면
      if (transactionStatus == TransactionStatus.received ||
          transactionStatus == TransactionStatus.receiving) {
        /// transaction 받기 결과
        if (rowType == InputOutputRowType.input) {
          /// 인풋
          if (isCurrentAddress) {
            /// 현재 주소인 경우
            leftItemColor = rightItemColor = assetColor = MyColors.white;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          } else {
            /// 현재 주소가 아닌 경우
            leftItemColor =
                rightItemColor = assetColor = MyColors.transparentWhite_40;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          }
        } else if (rowType == InputOutputRowType.output) {
          /// 아웃풋
          if (isCurrentAddress) {
            /// 현재 주소인 경우
            leftItemColor = MyColors.white;
            rightItemColor = MyColors.secondary;
            assetColor = rightItemColor;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          } else {
            /// 현재 주소가 아닌 경우
            leftItemColor =
                rightItemColor = assetColor = MyColors.transparentWhite_40;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          }
        } else {
          /// 수수료
          leftItemColor = rightItemColor = assetColor = MyColors.white;
          assetAddress = 'assets/svg/circle-pick.svg';
        }
      } else if (transactionStatus == TransactionStatus.sending ||
          transactionStatus == TransactionStatus.sent) {
        /// transaction 보내기 결과
        if (rowType == InputOutputRowType.input) {
          /// 안풋
          leftItemColor = MyColors.white;
          rightItemColor = assetColor = MyColors.primary;
          assetAddress = 'assets/svg/circle-arrow-right.svg';
        } else if (rowType == InputOutputRowType.output) {
          /// 아웃풋
          if (isCurrentAddress) {
            /// 현재 주소인 경우
            leftItemColor = MyColors.white;
            rightItemColor = assetColor = MyColors.white;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          } else {
            /// 현재 주소가 아닌 경우
            leftItemColor =
                rightItemColor = assetColor = MyColors.transparentWhite_40;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          }
        } else {
          /// 수수료
          leftItemColor = rightItemColor = assetColor = MyColors.white;
          assetAddress = 'assets/svg/circle-pick.svg';
        }
      } else if (transactionStatus == TransactionStatus.self ||
          transactionStatus == TransactionStatus.selfsending) {
        if (rowType == InputOutputRowType.input) {
          if (isCurrentAddress) {
            leftItemColor = MyColors.white;
            rightItemColor = assetColor = MyColors.primary;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          } else {
            leftItemColor = MyColors.transparentWhite_40;
            rightItemColor = assetColor = MyColors.transparentWhite_40;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          }
        } else if (rowType == InputOutputRowType.output) {
          if (isCurrentAddress) {
            leftItemColor = MyColors.white;
            rightItemColor = assetColor = MyColors.secondary;
          } else {
            leftItemColor = MyColors.transparentWhite_40;
            rightItemColor = assetColor = MyColors.transparentWhite_40;
          }
          assetAddress = 'assets/svg/circle-arrow-right.svg';
        } else {
          leftItemColor = MyColors.white;
          rightItemColor = assetColor = MyColors.white;
          assetAddress = 'assets/svg/circle-pick.svg';
        }
      }
    } else {
      /// transactionStatus가 null이면 UTXO 상세 화면
      if (rowType == InputOutputRowType.input) {
        /// 인풋
        leftItemColor =
            rightItemColor = assetColor = MyColors.transparentWhite_40;
        assetAddress = 'assets/svg/circle-arrow-right.svg';
      } else if (rowType == InputOutputRowType.output) {
        /// 아웃풋
        if (isCurrentAddress) {
          /// 현재 주소인 경우
          leftItemColor = rightItemColor = assetColor = MyColors.white;
        } else {
          /// 현재 주소가 아닌 경우
          leftItemColor =
              rightItemColor = assetColor = MyColors.transparentWhite_40;
          assetAddress = 'assets/svg/circle-arrow-right.svg';
        }
      } else {
        /// 수수료
        leftItemColor =
            rightItemColor = assetColor = MyColors.transparentWhite_40;
        assetAddress = 'assets/svg/circle-pick.svg';
      }
    }

    return Row(
      children: [
        Text(
          TextUtils.truncateNameMax19(address),
          style: Styles.body2Number.merge(
            TextStyle(
              color: leftItemColor,
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
                  assetAddress,
                  width: 16,
                  height: 12,
                  colorFilter: ColorFilter.mode(assetColor, BlendMode.srcIn),
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
                        color: rightItemColor,
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
                        color: rightItemColor,
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
                  assetAddress,
                  width: 16,
                  height: 12,
                  colorFilter: ColorFilter.mode(assetColor, BlendMode.srcIn),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
