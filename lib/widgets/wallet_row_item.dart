import 'dart:ui';

import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';

class WalletRowItem extends StatefulWidget {
  final int id;
  final int? balance;
  final String name;
  final int iconIndex;
  final int colorIndex;
  final bool isLastItem;
  final bool isBalanceHidden;

  const WalletRowItem({
    super.key,
    required this.id,
    required this.balance,
    required this.name,
    required this.iconIndex,
    required this.colorIndex,
    required this.isLastItem,
    this.isBalanceHidden = false,
  });

  @override
  State<WalletRowItem> createState() => _WalletRowItemState();
}

class _WalletRowItemState extends State<WalletRowItem> {
  // TODO : 추후 로직 변경될 수 있음
  bool _isMultiSig = false;

  @override
  void initState() {
    super.initState();

    // TODO : 월렛 속성 업데이트
    if (widget.name == '다중지갑') {
      _isMultiSig = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: gradient 적용
    final row = ShrinkAnimationButton(
        onPressed: () {
          if (_isMultiSig) {
            Navigator.pushNamed(context, '/wallet-multisig',
                arguments: {'id': widget.id});
          } else {
            Navigator.pushNamed(context, '/wallet-detail',
                arguments: {'id': widget.id});
          }
        },
        borderGradientColors: _isMultiSig
            ? [
                CustomColorHelper.getColorByIndex(0),
                MyColors.white,
                CustomColorHelper.getColorByIndex(4),
              ]
            : null,
        child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BackgroundColorPalette[widget.colorIndex],
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: SvgPicture.asset(
                      CustomIcons.getPathByIndex(widget.iconIndex),
                      colorFilter: ColorFilter.mode(
                          ColorPalette[widget.colorIndex], BlendMode.srcIn),
                      width: 20.0)),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12.0,
                          fontWeight: FontWeight.w400,
                          color: MyColors.transparentWhite_70,
                          letterSpacing: 0.2),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Padding(
                        padding: const EdgeInsets.only(top: 0),
                        child: ImageFiltered(
                          imageFilter: widget.isBalanceHidden
                              ? ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0)
                              : ImageFilter.blur(sigmaX: 0),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  widget.balance != null
                                      ? satoshiToBitcoinString(widget.balance!)
                                      : '',
                                  style: Styles.h3Number,
                                ),
                                const Text(" BTC", style: Styles.unitSmall),
                              ]),
                        )),
                  ],
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              SvgPicture.asset('assets/svg/arrow-right.svg',
                  width: 24,
                  colorFilter:
                      const ColorFilter.mode(MyColors.white, BlendMode.srcIn))
            ])));

    if (widget.isLastItem) {
      return row;
    }

    return Column(
      children: [
        row,
        const SizedBox(
          height: 10,
        )
      ],
    );
  }
}
