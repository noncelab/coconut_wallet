import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/cupertino.dart';

class WalletDetailStickyHeader extends StatelessWidget {
  final Key widgetKey;
  final double height;
  final bool isVisible;
  final Unit currentUnit;
  final int? balance;
  final Function() onTapReceive;
  final Function() onTapSend;

  const WalletDetailStickyHeader({
    required this.widgetKey,
    required this.height,
    required this.isVisible,
    required this.currentUnit,
    required this.balance,
    required this.onTapReceive,
    required this.onTapSend,
  }) : super(key: widgetKey);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: height,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            children: [
              Container(
                color: MyColors.black,
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16,
                  top: 20.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: balance != null
                              ? (currentUnit == Unit.btc
                                  ? satoshiToBitcoinString(balance!)
                                  : addCommasToIntegerPart(balance!.toDouble()))
                              : '-',
                          style: Styles.h2Number,
                          children: [
                            TextSpan(
                              text: balance != null
                                  ? currentUnit == Unit.btc
                                      ? ' ${t.btc}'
                                      : ' ${t.sats}'
                                  : '',
                              style: Styles.label.merge(
                                TextStyle(
                                  fontFamily: CustomFonts.number.getFontFamily,
                                  color: MyColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    CupertinoButton(
                      onPressed: onTapReceive,
                      borderRadius: BorderRadius.circular(8.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      minSize: 0,
                      color: MyColors.white,
                      child: SizedBox(
                        width: 35,
                        child: Center(
                          child: Text(
                            t.receive,
                            style: Styles.caption.merge(
                              const TextStyle(
                                  color: MyColors.black,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    CupertinoButton(
                      onPressed: onTapSend,
                      borderRadius: BorderRadius.circular(8.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      minSize: 0,
                      color: MyColors.primary,
                      child: SizedBox(
                        width: 35,
                        child: Center(
                          child: Text(
                            '보내기',
                            style: Styles.caption.merge(
                              const TextStyle(
                                  color: MyColors.black,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                children: [
                  Column(
                    children: [
                      Container(
                        width: MediaQuery.sizeOf(context).width,
                        padding: const EdgeInsets.only(
                            top: 10, left: 16, right: 16, bottom: 9),
                        decoration: const BoxDecoration(
                          color: MyColors.black,
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(255, 255, 255, 0.2),
                              offset: Offset(0, 3),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 16,
                        child: Container(),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MyColors.black,
                            border: Border.all(
                                color: MyColors.transparentWhite_50,
                                width: 0.5),
                            borderRadius: BorderRadius.circular(
                              16,
                            ),
                          ),
                          child: Text(
                            t.tx_list,
                            // selectedListType == WalletDetailTabType.transaction
                            // ? '거래 내역'
                            // : 'UTXO 목록', // TODO: 선택된 리스트 대입
                            style: Styles.caption2.merge(
                              const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: MyColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
