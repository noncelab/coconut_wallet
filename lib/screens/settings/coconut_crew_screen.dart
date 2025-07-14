import 'dart:convert';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CoconutCrewScreen extends StatefulWidget {
  const CoconutCrewScreen({super.key});

  @override
  State<CoconutCrewScreen> createState() => _CoconutCrewScreenState();
}

class _CoconutCrewScreenState extends State<CoconutCrewScreen> {
  // final ScrollController _scrollController = ScrollController();
  List<BetaTester> _testers = [];
  final List<ScrollbarItemData> _scrollbarList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    // _scrollController.addListener(_scrollListener);
  }

  // void _scrollListener() {}

  Future<void> _loadData() async {
    final String detailsContent = await rootBundle.loadString('assets/files/coconut_crew.json');
    final List<dynamic> jsonList = jsonDecode(detailsContent);
    _testers = jsonList.map((json) => BetaTester.fromJson(json)).toList();
    _testers.sort((a, b) {
      // ㄱㄴㄷ,ABC,123,특수문자 순으로 정렬
      int rank(String s) {
        final first = s.isNotEmpty ? s.codeUnitAt(0) : 0;
        if (first >= 0xAC00 && first <= 0xD7AF) {
          // 한글
          final initialCode = ((first - 0xAC00) / 588).floor();
          const initials = [
            'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', // 개행 방지
            'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', // 개행 방지
            'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ' // 개행 방지
          ];
          final initialChar = initials[initialCode];
          final normalizedInitial = switch (initialChar) {
            'ㄲ' => 'ㄱ',
            'ㄸ' => 'ㄷ',
            'ㅃ' => 'ㅂ',
            'ㅆ' => 'ㅅ',
            'ㅉ' => 'ㅈ',
            _ => initialChar,
          };
          // 첫 글자의 자음을 추출해서 _scrollbarList에 추가, 쌍자음은 자음으로 변환
          if (_scrollbarList.where((w) => w.str == normalizedInitial).isEmpty) {
            _scrollbarList.add(ScrollbarItemData(str: normalizedInitial, offsetY: 0));
          }
          return 0;
        }
        if ((first >= 0x41 && first <= 0x5A) || (first >= 0x61 && first <= 0x7A)) {
          // 영어
          final upperChar = s[0].toUpperCase();
          if (_scrollbarList.where((w) => w.str == upperChar).isEmpty) {
            _scrollbarList.add(ScrollbarItemData(str: upperChar, offsetY: 0));
          }
          return 1;
        }
        if (first >= 0x30 && first <= 0x39) {
          // 숫자
          if (_scrollbarList.where((w) => w.str == '1').isEmpty) {
            _scrollbarList.add(ScrollbarItemData(str: '1', offsetY: 0));
          }
          return 2;
        }

        // 특수문자
        if (_scrollbarList.where((w) => w.str == '#').isEmpty) {
          _scrollbarList.add(ScrollbarItemData(str: '#', offsetY: 0));
        }
        return 3;
      }

      final rankA = rank(a.nickname);
      final rankB = rank(b.nickname);

      if (rankA != rankB) return rankA.compareTo(rankB);
      return a.nickname.compareTo(b.nickname);
    });

    setState(() {});

    // WidgetsBinding.instance.endOfFrame.then((_) async {
    //   await Future.delayed(const Duration(milliseconds: 1000));
    //   for (final item in _scrollbarList) {
    //     final index = _testers.indexWhere((tester) {
    //       final firstChar = tester.nickname.characters.first;
    //       if (item.str == '#') {
    //         return !RegExp(r'[ㄱ-ㅎ가-힣A-Za-z0-9]').hasMatch(firstChar);
    //       }
    //       if (RegExp(r'[ㄱ-ㅎ가-힣]').hasMatch(firstChar)) {
    //         const initials = [
    //           'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', // 개행 방지
    //           'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', // 개행 방지
    //           'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ' // 개행 방지
    //         ];
    //         final initialCode = ((firstChar.codeUnitAt(0) - 0xAC00) / 588).floor();
    //         final initialChar = initials[initialCode];
    //         final normalized = switch (initialChar) {
    //           'ㄲ' => 'ㄱ',
    //           'ㄸ' => 'ㄷ',
    //           'ㅃ' => 'ㅂ',
    //           'ㅆ' => 'ㅅ',
    //           'ㅉ' => 'ㅈ',
    //           _ => initialChar,
    //         };
    //         return item.str == normalized;
    //       }
    //       return item.str == firstChar.toUpperCase();
    //     });

    //     if (index != -1) {
    //       final key = GlobalObjectKey(index);
    //       final context = key.currentContext;
    //       if (context != null) {
    //         final box = context.findRenderObject() as RenderBox;
    //         final offset = box.localToGlobal(Offset.zero);
    //         item.offsetY = offset.dy;
    //         debugPrint('_scrollbarList offset Y : ${item.str} -> ${item.offsetY}');
    //       } else {
    //         debugPrint('_scrollbarList context null : ${item.str}');
    //       }
    //     }
    //   }
    // });

    // debugPrint('_scrollbarList ::: ${_scrollbarList.map((item) => item.str).toList()}');
    // const List<String> customOrder = [
    //   'ㄱ', 'ㄴ', 'ㄷ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅅ', 'ㅇ', 'ㅈ', 'ㅊ',
    //   'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ', // 한글 자음
    //   'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
    //   'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    //   'U', 'V', 'W', 'X', 'Y', 'Z', // 영어 대문자
    //   '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', // 숫자
    //   '#' // 특수문자
    // ];

    // _scrollbarList.sort((a, b) {
    //   int indexA = customOrder.indexOf(a.str);
    //   int indexB = customOrder.indexOf(b.str);
    //   return indexA.compareTo(indexB);
    // });

    // debugPrint('_scrollbarList sorted::: ${_scrollbarList.map((item) => item.str).toList()}');
    // debugPrint('_scrollbarList sorted::: ${_scrollbarList.map((item) => item.offsetY).toList()}');

    // setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(context: context, title: t.app_info_screen.coconut_crew),
      body: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              // controller: _scrollController,
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: _testers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    padding: const EdgeInsets.only(top: 24, bottom: 42),
                    child: Center(
                      child: Text(
                        t.app_info_screen.coconut_crew_thanks_msg,
                        style: CoconutTypography.body2_14,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                String nickname = _testers[index - 1].nickname;
                String profileImageSrc = _testers[index - 1].profileImage; // TODO: 실제 CDN 링크로 파일 구성
                String message = _testers[index - 1].message;
                String? sns = _testers[index - 1].sns;
                String? link = _testers[index - 1].link;

                return KeyedSubtree(
                  key: GlobalObjectKey(index - 1),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ShrinkAnimationButton(
                      defaultColor: CoconutColors.gray800,
                      pressedColor: CoconutColors.gray750,
                      borderRadius: 12,
                      onPressed: () {
                        if (link != null) {
                          launchURL(link);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.only(
                          top: 20,
                          bottom: 20,
                          left: 20,
                          right: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: CoconutColors.borderGray,
                              backgroundImage: NetworkImage(
                                profileImageSrc,
                              ),
                            ),
                            CoconutLayout.spacing_400w,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nickname,
                                    style: CoconutTypography.body1_16_Bold,
                                  ),
                                  Text(
                                    sns ?? ' ',
                                    style:
                                        CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                                  ),
                                  CoconutLayout.spacing_100h,
                                  Text(
                                    message,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                                    maxLines: 2,
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Positioned(
          //   right: 16,
          //   top: 0,
          //   bottom: 0,
          //   child: Align(
          //     alignment: Alignment.center,
          //     child: Container(
          //       width: 30,
          //       padding: const EdgeInsets.symmetric(vertical: 8),
          //       decoration: BoxDecoration(
          //         color: CoconutColors.white.withOpacity(0.3),
          //         borderRadius: const BorderRadius.all(
          //           Radius.circular(12),
          //         ),
          //       ),
          //       child: ConstrainedBox(
          //         constraints: BoxConstraints(
          //           maxHeight: MediaQuery.sizeOf(context).height - 32,
          //         ),
          //         child: Column(
          //           mainAxisSize: MainAxisSize.min,
          //           mainAxisAlignment: MainAxisAlignment.center,
          //           children: _scrollbarList
          //               .take(((MediaQuery.sizeOf(context).height - 32) ~/ 24))
          //               .map((item) {
          //             return Padding(
          //               padding: const EdgeInsets.symmetric(vertical: 4),
          //               child: Text(
          //                 item.str,
          //                 style: CoconutTypography.body3_12.setColor(CoconutColors.black),
          //               ),
          //             );
          //           }).toList(),
          //         ),
          //       ),
          //     ),
          //   ),
          // )
        ],
      ),
    );
  }
}

class BetaTester {
  final String nickname;
  final String message;
  final String profileImage;
  final String? sns;
  final String? link;

  BetaTester({
    required this.nickname,
    required this.message,
    required this.profileImage,
    this.sns,
    this.link,
  });

  factory BetaTester.fromJson(Map<String, dynamic> json) {
    return BetaTester(
      nickname: json['nickname'],
      message: json['message'],
      profileImage: json['profile_image'],
      sns: json['sns'],
      link: json['link'],
    );
  }
}

class ScrollbarItemData {
  final String str;
  double offsetY;

  ScrollbarItemData({required this.str, required this.offsetY});
}
