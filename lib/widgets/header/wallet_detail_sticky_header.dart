import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/selector/wallet_detail_tab.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';

class WalletDetailStickyHeader extends StatelessWidget {
  final WalletListItemBase wallet;
  final Key widgetKey;
  final Key dropdownKey;
  final double height;
  final bool isVisible;
  final Unit currentUnit;
  final SelectedListType selectedListType;
  final String selectedFilter;
  final Function(int?, String, String) onTapReceive;
  final Function(int?) onTapSend;
  final Function onTapDropdown;
  const WalletDetailStickyHeader({
    required this.wallet,
    required this.widgetKey,
    required this.dropdownKey,
    required this.height,
    required this.isVisible,
    required this.currentUnit,
    required this.selectedListType,
    required this.selectedFilter,
    required this.onTapReceive,
    required this.onTapSend,
    required this.onTapDropdown,
  }) : super(key: widgetKey);

  @override
  Widget build(BuildContext context) {
    Address receiveAddress = wallet.walletBase.getReceiveAddress();
    final walletAddress = receiveAddress.address;
    final derivationPath = receiveAddress.derivationPath;
    final utxoListIsNotEmpty =
        wallet.walletFeature.walletStatus?.utxoList.isNotEmpty == true;
    final balance = wallet.balance;
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
                                  ? satoshiToBitcoinString(balance)
                                  : addCommasToIntegerPart(balance.toDouble()))
                              : '잔액 조회 불가',
                          style: Styles.h2Number,
                          children: [
                            TextSpan(
                              text: balance != null
                                  ? currentUnit == Unit.btc
                                      ? ' BTC'
                                      : ' sats'
                                  : '잔액 조회 불가',
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
                      onPressed: () {
                        onTapReceive(balance, walletAddress, derivationPath);
                      },
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
                            '받기',
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
                      onPressed: () {
                        if (balance == null) {
                          CustomToast.showToast(
                              context: context, text: "잔액이 없습니다.");
                          return;
                        }
                        onTapSend(balance);
                      },
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
                        child: Visibility(
                          visible: selectedListType == SelectedListType.utxo &&
                              utxoListIsNotEmpty,
                          maintainAnimation: true,
                          maintainState: true,
                          maintainSize: true,
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.only(
                                  top: 10,
                                ),
                                minSize: 0,
                                onPressed: () {
                                  onTapDropdown();
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      key: dropdownKey,
                                      selectedFilter,
                                      style: Styles.caption2.merge(
                                        const TextStyle(
                                          color: MyColors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 5,
                                    ),
                                    SvgPicture.asset(
                                        'assets/svg/arrow-down.svg'),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                            selectedListType == SelectedListType.transaction
                                ? '거래 내역'
                                : 'UTXO 목록', // TODO: 선택된 리스트 대입
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
