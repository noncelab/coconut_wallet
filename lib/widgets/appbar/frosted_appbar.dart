import 'dart:ui';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/label_testnet.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';

@Deprecated('Use CoconutAppBar.buildHomeAppbar instead')
class FrostedAppBar extends StatelessWidget {
  final Function onTapSeeMore;
  final Function onTapAddScanner;
  final PreferredSizeWidget? bottomWidget;
  const FrostedAppBar({
    super.key,
    required this.onTapSeeMore,
    required this.onTapAddScanner,
    this.bottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 84 + (bottomWidget?.preferredSize.height ?? 0),
      backgroundColor: Colors.transparent,
      bottom: bottomWidget != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(30),
              child: bottomWidget!,
            )
          : null,
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
                          color: CoconutColors.white, width: 24)),
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
                          const TestnetLabelWidget(),
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
                        colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                      ),
                      onPressed: () {
                        CustomDialogs.showCustomAlertDialog(
                          context,
                          title: '도움이 필요하신가요?',
                          message: '튜토리얼 사이트로\n안내해 드릴게요',
                          onConfirm: () async {
                            launchURL(
                              'https://noncelab.gitbook.io/coconut.onl',
                              defaultMode: false,
                            );
                            Navigator.of(context).pop();
                          },
                          onCancel: () {
                            Navigator.of(context).pop();
                          },
                          confirmButtonText: '튜토리얼 보기',
                          confirmButtonColor: MyColors.cyanblue,
                          cancelButtonText: '닫기',
                        );
                      },
                      color: CoconutColors.white,
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
                      color: CoconutColors.white,
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
                      color: CoconutColors.white,
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
