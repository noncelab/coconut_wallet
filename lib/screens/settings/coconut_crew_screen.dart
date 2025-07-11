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
  final ScrollController _scrollController = ScrollController();
  List<BetaTester> _testers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {}

  Future<void> _loadData() async {
    final String detailsContent = await rootBundle.loadString('assets/files/beta_testers.json');
    final List<dynamic> jsonList = jsonDecode(detailsContent);
    _testers = jsonList.map((json) => BetaTester.fromJson(json)).toList();
    _testers.sort((a, b) {
      // ㄱㄴㄷ,ABC,123,특수문자 순으로 정렬
      int rank(String s) {
        final first = s.isNotEmpty ? s.codeUnitAt(0) : 0;
        if (first >= 0xAC00 && first <= 0xD7AF) return 0; // 한글
        if ((first >= 0x41 && first <= 0x5A) || (first >= 0x61 && first <= 0x7A)) {
          return 1; // 영어
        }
        if (first >= 0x30 && first <= 0x39) return 2; // 숫자
        return 3; // 특수문자
      }

      final rankA = rank(a.nickname);
      final rankB = rank(b.nickname);

      if (rankA != rankB) return rankA.compareTo(rankB);
      return a.nickname.compareTo(b.nickname);
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(context: context, title: t.app_info_screen.coconut_crew),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.builder(
          controller: _scrollController,
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

            return Padding(
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
                              style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                            ),
                            CoconutLayout.spacing_100h,
                            Text(
                              message,
                              overflow: TextOverflow.ellipsis,
                              style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                              maxLines: 2,
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        ),
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
