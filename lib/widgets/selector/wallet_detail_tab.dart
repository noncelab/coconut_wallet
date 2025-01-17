import 'package:coconut_wallet/styles.dart';
import 'package:flutter/cupertino.dart';

enum WalletDetailTabType { transaction, utxo }

class WalletDetailTab extends StatefulWidget {
  final WalletDetailTabType selectedListType;
  final int utxoListLength;
  final Function onTapTransaction;
  final Function onTapUtxo;
  const WalletDetailTab({
    super.key,
    required this.selectedListType,
    required this.utxoListLength,
    required this.onTapTransaction,
    required this.onTapUtxo,
  });

  @override
  State<WalletDetailTab> createState() => _WalletDetailTabState();
}

class _WalletDetailTabState extends State<WalletDetailTab> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CupertinoButton(
          pressedOpacity: 0.8,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minSize: 0,
          onPressed: () {
            widget.onTapTransaction();
          },
          child: Text(
            '거래 내역',
            style: Styles.h3.merge(
              TextStyle(
                color:
                    widget.selectedListType == WalletDetailTabType.transaction
                        ? MyColors.white
                        : MyColors.transparentWhite_50,
              ),
            ),
          ),
        ),
        const SizedBox(
          width: 8,
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          pressedOpacity: 0.8,
          // focusColor: MyColors.white,
          minSize: 0,
          onPressed: () {
            widget.onTapUtxo();
          },
          child: Text.rich(
            TextSpan(
              text: 'UTXO 목록',
              style: Styles.h3.merge(
                TextStyle(
                  color: widget.selectedListType == WalletDetailTabType.utxo
                      ? MyColors.white
                      : MyColors.transparentWhite_50,
                ),
              ),
              children: [
                if (widget.utxoListLength > 0) ...{
                  TextSpan(
                    text: ' (${widget.utxoListLength}개)',
                    style: Styles.caption.merge(
                      TextStyle(
                        color:
                            widget.selectedListType == WalletDetailTabType.utxo
                                ? MyColors.transparentWhite_70
                                : MyColors.transparentWhite_50,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                }
              ],
            ),
          ),
        ),
      ],
    );
  }
}
