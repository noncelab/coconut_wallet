import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

enum WalletDetailTabType { transaction, utxo }

class WalletDetailTab extends StatelessWidget {
  final WalletDetailTabType selectedListType;
  final WalletInitState state;
  final int utxoListLength;
  final bool isUtxoDropdownVisible;
  final bool isPullToRefreshing;
  final String utxoOrderText;
  final Function onTapTransaction;
  final Function onTapUtxo;
  final Function onTapUtxoDropdown;
  const WalletDetailTab({
    super.key,
    required this.selectedListType,
    required this.state,
    required this.utxoListLength,
    required this.isUtxoDropdownVisible,
    required this.isPullToRefreshing,
    this.utxoOrderText = '',
    required this.onTapTransaction,
    required this.onTapUtxo,
    required this.onTapUtxoDropdown,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: 12.0,
        top: 30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // CupertinoButton(
              // pressedOpacity: 0.8,
              // padding: const EdgeInsets.symmetric(horizontal: 8),
              // minSize: 0,
              // onPressed: () {
              //   onTapTransaction();
              // },
              // child:
              Text(t.tx_list, style: Styles.h3
                  // .merge(
                  //   TextStyle(
                  //     color: selectedListType == WalletDetailTabType.transaction
                  //         ? MyColors.white
                  //         : MyColors.transparentWhite_50,
                  //   ),
                  // ),
                  ),
              // ),
              // const SizedBox(
              //   width: 8,
              // ),
              // CupertinoButton(
              //   padding: const EdgeInsets.symmetric(horizontal: 8),
              //   pressedOpacity: 0.8,
              //   // focusColor: MyColors.white,
              //   minSize: 0,
              //   onPressed: () {
              //     onTapUtxo();
              //   },
              //   child: Text.rich(
              //     TextSpan(
              //       text: 'UTXO 목록',
              //       style: Styles.h3.merge(
              //         TextStyle(
              //           color: selectedListType == WalletDetailTabType.utxo
              //               ? MyColors.white
              //               : MyColors.transparentWhite_50,
              //         ),
              //       ),
              //       children: [
              //         if (utxoListLength > 0) ...{
              //           TextSpan(
              //             text: ' ($utxoListLength개)',
              //             style: Styles.caption.merge(
              //               TextStyle(
              //                 color:
              //                     selectedListType == WalletDetailTabType.utxo
              //                         ? MyColors.transparentWhite_70
              //                         : MyColors.transparentWhite_50,
              //                 fontFamily: 'Pretendard',
              //               ),
              //             ),
              //           ),
              //         }
              //       ],
              //     ),
              //   ),
              // ),
              // const Spacer(),
              Visibility(
                visible:
                    !isPullToRefreshing && state == WalletInitState.processing,
                child: Row(
                  children: [
                    const Text(
                      '업데이트 중',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        color: MyColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    LottieBuilder.asset(
                      'assets/files/status_loading.json',
                      width: 20,
                      height: 20,
                    ),
                  ],
                ),
              ),
              Visibility(
                visible: state == WalletInitState.error,
                child: Row(
                  children: [
                    const Text(
                      '업데이트 실패',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        color: MyColors.failedYellow,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SvgPicture.asset('assets/svg/status-failure.svg',
                        width: 18,
                        colorFilter: const ColorFilter.mode(
                            MyColors.failedYellow, BlendMode.srcIn)),
                  ],
                ),
              ),
            ],
          ),
          // if (isUtxoDropdownVisible) ...{
          //   Row(
          //     mainAxisAlignment: MainAxisAlignment.end,
          //     children: [
          //       CupertinoButton(
          //         onPressed: () {
          //           onTapUtxoDropdown();
          //         },
          //         minSize: 0,
          //         padding: const EdgeInsets.only(left: 8, top: 8),
          //         child: Row(
          //           children: [
          //             Text(
          //               utxoOrderText,
          //               style: Styles.caption2.merge(
          //                 const TextStyle(
          //                   color: MyColors.white,
          //                   fontSize: 12,
          //                 ),
          //               ),
          //             ),
          //             const SizedBox(
          //               width: 4,
          //             ),
          //             SvgPicture.asset(
          //               'assets/svg/arrow-down.svg',
          //             ),
          //           ],
          //         ),
          //       ),
          //     ],
          //   ),
          // }
        ],
      ),
    );
  }
}
