import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsScreen extends StatefulWidget {
  static double gutter = 16;

  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  List<String> termList = [];
  Map<String, dynamic> termDetails = {};
  Map<String, List<String>> groupedTermList = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    String detailsContent =
        await rootBundle.loadString('assets/files/terms_details.json');
    setState(() {
      termDetails = json.decode(detailsContent);
      termList = termDetails.keys.toList();
      termList.sort();
      groupedTermList = groupByInitials(termList);
    });
  }

  String getInitial(String input) {
    const int kSBase = 0xAC00;
    const int kLBase = 0x1100;
    const int kLEnd = 0x1112;

    List<String> initials = [
      'ㄱ',
      'ㄲ',
      'ㄴ',
      'ㄷ',
      'ㄸ',
      'ㄹ',
      'ㅁ',
      'ㅂ',
      'ㅃ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅉ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ'
    ];

    // 첫 글자 추출
    String firstChar = input[0];
    int codeUnit = firstChar.codeUnitAt(0);

    // 한글인지 확인
    if (codeUnit >= kSBase &&
        codeUnit <= kSBase + (initials.length * 21 * 28) - 1) {
      // 초성 인덱스 계산
      int initialIndex = (codeUnit - kSBase) ~/ (21 * 28);
      return initials[initialIndex];
    } else if (codeUnit >= kLBase && codeUnit <= kLEnd) {
      // 자모음인 경우 바로 반환
      return firstChar;
    } else {
      // 한글이 아닌 경우
      return firstChar;
    }
  }

  Map<String, List<String>> groupByInitials(List<String> terms) {
    Map<String, List<String>> groupedTerms = {};

    for (String term in terms) {
      String initial = getInitial(term);

      if (!groupedTerms.containsKey(initial)) {
        groupedTerms[initial] = [];
      }
      groupedTerms[initial]!.add(term);
    }

    return groupedTerms;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: MyColors.black,
        appBar: CustomAppBar.build(
            title: '용어집',
            context: context,
            onBackPressed: null,
            hasRightIcon: false,
            isBottom: true,
            showTestnetLabel: false),
        body: Padding(
            padding: EdgeInsets.only(
                left: TermsScreen.gutter, right: TermsScreen.gutter, top: 20),
            child: Column(children: [
              Row(
                children: [
                  AskCard(
                    imagePath: 'assets/images/pow_logo.png',
                    title: '포우에 물어보기',
                    backgroundColor: const Color.fromRGBO(255, 238, 233, 1),
                    gutter: TermsScreen.gutter,
                    url: 'https://powbitcoiner.com/',
                    externalBrowser: true,
                  ),
                  SizedBox(width: TermsScreen.gutter / 2),
                  AskCard(
                      imagePath: 'assets/images/telegram_logo.png',
                      title: '텔레그램에 물어보기',
                      backgroundColor: const Color.fromRGBO(233, 242, 255, 1),
                      gutter: TermsScreen.gutter,
                      url: 'https://t.me/+s4D6-03LjaY5ZmU1'),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                  child: ListView(
                      children: groupedTermList.keys.map((initial) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(initial, style: Styles.body1Bold),
                    Wrap(
                      children: groupedTermList[initial]!.map((term) {
                        return Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: GestureDetector(
                              onTap: () => _showBottomSheet(term),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(32),
                                      color: MyColors.borderLightgrey),
                                  child: Text(term,
                                      style: Styles.body2.merge(const TextStyle(
                                          color:
                                              MyColors.transparentWhite_70))))),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20)
                  ],
                );
              }).toList()))
            ])));
  }

  void _showBottomSheet(String term) {
    showModalBottomSheet(
      useSafeArea: true,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: MyColors.grey,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      context: context,
      builder: (context) {
        var details = termDetails[term];
        return details != null
            ? SingleChildScrollView(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 36, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          term,
                          style: Styles.h3,
                        ),
                        Text(
                          '${details['en']}',
                          style: Styles.label,
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 32),
                      color: MyColors.black,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${details['content']}',
                            style: Styles.label
                                .merge(const TextStyle(color: MyColors.white)),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            '같은 용어',
                            style: Styles.body2Bold,
                          ),
                          const SizedBox(height: 8),
                          if (details['synonym'] != null) ...[
                            Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: details['synonym']
                                    .map<Widget>(
                                        (text) => Keyword(keyword: text))
                                    .toList()),
                            const SizedBox(height: 32),
                            const Text(
                              '관련 용어',
                              style: Styles.body2Bold,
                            ),
                            const SizedBox(height: 8),
                            if (details['related'] != null) ...[
                              Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  children: details['related']
                                      .map<Widget>(
                                          (text) => Keyword(keyword: text))
                                      .toList())
                            ],
                            const SizedBox(height: 40),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ))
            : Center(child: Text('No details available for $term'));
      },
    );
  }
}

class AskCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final Color backgroundColor;
  final double gutter;
  final String url;
  final bool externalBrowser;

  const AskCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.backgroundColor,
    required this.gutter,
    required this.url,
    this.externalBrowser = false,
  });

  Future<void> _launchURL() async {
    final Uri url = Uri.parse(this.url);
    if (!await launchUrl(url,
        mode: externalBrowser
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: _launchURL,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          width:
              (MediaQuery.of(context).size.width - gutter * 2 - gutter / 2) / 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: backgroundColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color.fromRGBO(255, 255, 255, 0.5),
                ),
                child: Image.asset(
                  imagePath,
                  width: 28,
                  height: 28,
                ),
              ),
              Text(title,
                  style: Styles.body2.merge(const TextStyle(
                      color: MyColors.darkgrey, fontWeight: FontWeight.bold))),
            ],
          ),
        ));
  }
}

class Keyword extends StatelessWidget {
  final String keyword;

  const Keyword({
    super.key,
    required this.keyword,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: MyColors.lightblue),
        child: Text(
          keyword,
          style: Styles.caption.merge(TextStyle(
              fontFamily: CustomFonts.text.getFontFamily,
              color: MyColors.darkgrey,
              letterSpacing: 0.1)),
        ));
  }
}
