import 'dart:ui';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';

class FrostedAppBar extends StatelessWidget {
  final Function onTapSeeMore;
  final Function onTapAddScanner;
  const FrostedAppBar({
    super.key,
    required this.onTapSeeMore,
    required this.onTapAddScanner,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 84,
      backgroundColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: SvgPicture.asset('assets/svg/coconut.svg',
                          color: MyColors.white, width: 24)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Wallet',
                            style: TextStyle(
                              fontFamily: CustomFonts.number.getFontFamily,
                              color: Colors.white,
                              fontSize: 22,
                              fontStyle: FontStyle.normal,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          CoconutChip(
                            color: CoconutColors.cyan,
                            isRectangle: true,
                            padding: const EdgeInsets.symmetric(
                                vertical: 2, horizontal: 8),
                            child: Text(
                              t.testnet,
                              style: CoconutTypography.caption_10_Bold.copyWith(
                                color: CoconutColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 32),
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      icon: SvgPicture.asset(
                        'assets/svg/book.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(
                            MyColors.white, BlendMode.srcIn),
                      ),
                      onPressed: () {
                        CustomDialogs.showCustomDialog(context,
                            title: t.alert.tutorial.title,
                            description: t.alert.tutorial.description,
                            rightButtonColor: CoconutColors.cyan,
                            rightButtonText: t.alert.tutorial.btn_view,
                            leftButtonText: '닫기', onTapRight: () {
                          launchURL(
                            'https://noncelab.gitbook.io/coconut.onl',
                            defaultMode: false,
                          );
                          Navigator.of(context).pop();
                        }, onTapLeft: () {
                          Navigator.of(context).pop();
                        });
                      },
                      color: MyColors.white,
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    width: 40,
                    child: IconButton(
                      icon: const Icon(
                        Icons.add_rounded,
                      ),
                      onPressed: () {
                        onTapAddScanner();
                      },
                      color: MyColors.white,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 32),
                    height: 40,
                    width: 40,
                    child: IconButton(
                      icon: const Icon(CupertinoIcons.ellipsis, size: 18),
                      onPressed: () {
                        onTapSeeMore.call();
                      },
                      color: MyColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
