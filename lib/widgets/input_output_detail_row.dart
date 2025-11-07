import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class InputOutputDetailRow extends StatelessWidget {
  final String address;
  final int balance;
  final double balanceMaxWidth;
  final InputOutputRowType rowType;
  final bool? isCurrentAddress;
  final TransactionStatus? transactionStatus;
  final RowProperty rowProperty;
  final BitcoinUnit currentUnit;

  InputOutputDetailRow({
    super.key,
    required this.address,
    required this.balance,
    required this.balanceMaxWidth,
    required this.rowType,
    required this.currentUnit,
    this.isCurrentAddress,
    this.transactionStatus,
  }) : rowProperty = getRowProperty(rowType, transactionStatus, isCurrentAddress ?? false);

  String get balanceText => currentUnit.displayBitcoinAmount(balance.abs(), forceEightDecimals: true);

  @override
  Widget build(BuildContext context) {
    bool shouldTrimText = (balanceMaxWidth != 0.0 ? balanceMaxWidth : 100.0) > MediaQuery.of(context).size.width * 0.3;
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                shouldTrimText ? TextUtils.truncate(address, 14, 8, 6) : TextUtils.truncate(address, 19, 11, 8),
                style: CoconutTypography.body2_14_Number.copyWith(
                  color: rowProperty.leftItemColor,
                  fontSize: 14,
                  height: 16 / 14,
                ),
                textScaler: const TextScaler.linear(1.0),
                maxLines: 1,
              ),
            ),
          ),
        ),
        CoconutLayout.spacing_300w,
        if (rowType == InputOutputRowType.output || rowType == InputOutputRowType.fee)
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: balanceMaxWidth + 26,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SvgPicture.asset(
                        rowProperty.svgPath,
                        width: 16,
                        height: 12,
                        colorFilter: ColorFilter.mode(rowProperty.svgColor, BlendMode.srcIn),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: balanceMaxWidth,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              textAlign: TextAlign.end,
                              balanceText,
                              style: CoconutTypography.body2_14_Number.copyWith(
                                color: rowProperty.rightItemColor,
                                height: 16 / 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (rowType == InputOutputRowType.input)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: balanceMaxWidth,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          balanceText,
                          style: CoconutTypography.body2_14_Number.copyWith(
                            color: rowProperty.rightItemColor,
                            height: 16 / 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                SvgPicture.asset(
                  rowProperty.svgPath,
                  width: 16,
                  height: 12,
                  colorFilter: ColorFilter.mode(rowProperty.svgColor, BlendMode.srcIn),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static RowProperty getRowProperty(
    InputOutputRowType rowType,
    TransactionStatus? transactionStatus,
    bool isCurrentAddress,
  ) {
    Color leftItemColor = CoconutColors.gray500;
    Color rightItemColor = CoconutColors.gray500;
    Color svgColor = CoconutColors.gray500;

    String svgPath = 'assets/svg/circle-arrow-right.svg';

    if (rowType == InputOutputRowType.fee) {
      // UTXO 화면인 경우
      svgPath = 'assets/svg/circle-pick.svg';
      if (transactionStatus == null) {
        return RowProperty(
          leftItemColor: leftItemColor,
          rightItemColor: rightItemColor,
          svgColor: svgColor,
          svgPath: svgPath,
        );
      }

      if (transactionStatus == TransactionStatus.sending || transactionStatus == TransactionStatus.sent) {
        leftItemColor = rightItemColor = svgColor = CoconutColors.primary;
      } else if (transactionStatus == TransactionStatus.self || transactionStatus == TransactionStatus.selfsending) {
        leftItemColor = CoconutColors.white;
        rightItemColor = svgColor = CoconutColors.primary;
      }

      return RowProperty(
        leftItemColor: leftItemColor,
        rightItemColor: rightItemColor,
        svgColor: svgColor,
        svgPath: svgPath,
      );
    }

    if (transactionStatus != null) {
      /// transactionStatus가 null이 아니면 거래 자세히 보기 화면
      switch (transactionStatus) {
        case TransactionStatus.received:
        case TransactionStatus.receiving:
          if (rowType == InputOutputRowType.input) {
            if (!isCurrentAddress) {
              leftItemColor = rightItemColor = svgColor = CoconutColors.gray500;
            }
          } else {
            if (isCurrentAddress) {
              leftItemColor = rightItemColor = svgColor = CoconutColors.cyan;
            } else {
              leftItemColor = rightItemColor = svgColor = CoconutColors.gray500;
            }
          }
          break;
        case TransactionStatus.sending:
        case TransactionStatus.sent:
          if (rowType == InputOutputRowType.input) {
            leftItemColor = rightItemColor = svgColor = CoconutColors.white;
          } else if (rowType == InputOutputRowType.output) {
            if (isCurrentAddress) {
              leftItemColor = rightItemColor = svgColor = CoconutColors.white;
            } else {
              leftItemColor = rightItemColor = svgColor = CoconutColors.primary;
            }
          } else if (rowType == InputOutputRowType.fee) {
            leftItemColor = rightItemColor = svgColor = CoconutColors.primary;
          }
          break;
        case TransactionStatus.self:
        case TransactionStatus.selfsending:
          if (rowType == InputOutputRowType.input) {
            if (isCurrentAddress) {
              leftItemColor = rightItemColor = svgColor = CoconutColors.white;
            }
          } else if (rowType == InputOutputRowType.fee) {
            leftItemColor = CoconutColors.white;
          } else {
            if (isCurrentAddress) {
              leftItemColor = CoconutColors.white;
              rightItemColor = svgColor = CoconutColors.cyan;
            }
          }
          break;
      }
    } else {
      /// transactionStatus가 null이면 UTXO 상세 화면
      if (rowType == InputOutputRowType.output && isCurrentAddress) {
        leftItemColor = rightItemColor = svgColor = CoconutColors.white;
      }
    }
    return RowProperty(
      leftItemColor: leftItemColor,
      rightItemColor: rightItemColor,
      svgColor: svgColor,
      svgPath: svgPath,
    );
  }
}

class RowProperty {
  final Color leftItemColor;
  final Color rightItemColor;
  final Color svgColor;
  final String svgPath;

  const RowProperty({
    required this.leftItemColor,
    required this.rightItemColor,
    required this.svgColor,
    required this.svgPath,
  });
}

enum InputOutputRowType { input, output, fee }
