import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coconut_wallet/styles.dart';

class Bip39ListScreen extends StatefulWidget {
  const Bip39ListScreen({super.key});

  @override
  State<Bip39ListScreen> createState() => _Bip39ListScreenState();
}

class _Bip39ListScreenState extends State<Bip39ListScreen> {
  final String _titleText = t.mnemonic_wordlist;
  final String _hintText = t.text_field.search_mnemonic_word;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems =
        List.generate(wordList.length, (index) => {'index': index + 1, 'item': wordList[index]});

    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    if (_searchController.text.isNotEmpty) {
      setState(() {
        _queryWord();
      });
    } else {
      setState(() {
        _filteredItems = List.generate(
            wordList.length, (index) => {'index': index + 1, 'item': wordList[index]});
      });
    }
  }

  void _queryWord() {
    String query = _searchController.text.toLowerCase();

    final isBinary = RegExp(r'^[01]+$').hasMatch(query);
    final isNumeric = RegExp(r'^\d+$').hasMatch(query);
    final isAlphabetic = RegExp(r'^[a-zA-Z]+$').hasMatch(query);

    List<Map<String, dynamic>> numericResults = [];
    List<Map<String, dynamic>> binaryResults = [];
    List<Map<String, dynamic>> alphabeticResults = [];

    for (int i = 0; i < wordList.length; i++) {
      final item = wordList[i];
      final indexNum = i + 1;

      if (isNumeric && query.length <= 4 && indexNum.toString().contains(query)) {
        numericResults.add({'index': indexNum, 'item': item, 'type': 'numeric'});
      }

      if (isBinary) {
        final binaryStr = (indexNum - 1).toRadixString(2).padLeft(11, '0');
        if (binaryStr.contains(query)) {
          binaryResults.add({'index': indexNum, 'item': item, 'type': 'binary'});
        }
      }

      if (isAlphabetic && item.toLowerCase().contains(query)) {
        alphabeticResults.add({'index': indexNum, 'item': item, 'type': 'alphabetic'});
      }
    }

    if (isAlphabetic) {
      alphabeticResults.sort((a, b) {
        final itemA = (a['item'] as String).toLowerCase();
        final itemB = (b['item'] as String).toLowerCase();

        final startsWithA = itemA.startsWith(query);
        final startsWithB = itemB.startsWith(query);

        if (startsWithA && !startsWithB) return -1;
        if (!startsWithA && startsWithB) return 1;
        return itemA.compareTo(itemB);
      });
      _filteredItems = alphabeticResults;
    } else {
      numericResults.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
      binaryResults.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
      _filteredItems = [...numericResults, ...binaryResults];
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: CoconutColors.black,
        appBar: CoconutAppBar.build(
          title: _titleText,
          context: context,
          isBottom: true,
        ),
        body: Column(
          children: [
            Container(
              color: CoconutColors.black,
              child: Container(
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: MyColors.borderLightgrey,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: TextField(
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      ],
                      controller: _searchController,
                      maxLines: 1,
                      maxLength: 11,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: _hintText,
                        hintStyle: Styles.body2.merge(
                          const TextStyle(
                            color: MyColors.transparentWhite_50,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: MyColors.transparentWhite_50,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 16.0),
                      ),
                      style: const TextStyle(
                        decorationThickness: 0,
                        color: CoconutColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width,
              child: _resultWidget(),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _filteredItems.length,
                itemBuilder: (ctx, index) {
                  return _buildListItem(context, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultWidget() {
    return _searchController.text.isEmpty
        ? Container()
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.bip39_list_screen.result(text: _searchController.text),
                    style: Styles.body1.merge(
                      const TextStyle(
                        color: CoconutColors.white,
                      ),
                    ),
                  ),
                ),
              ),
              _filteredItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Center(
                        child: Text(
                          t.bip39_list_screen.no_result,
                          style: Styles.body1Bold.merge(
                            const TextStyle(color: MyColors.transparentWhite_70),
                          ),
                        ),
                      ),
                    )
                  : Container(),
            ],
          );
  }

  Widget _buildListItem(BuildContext context, int index) {
    final item = _filteredItems[index]['item'] as String;
    final indexNum = _filteredItems[index]['index'] as int;
    final type = _filteredItems[index]['type'] as String?;
    final query = _searchController.text;

    // 인덱스와 바이너리 문자열 준비
    final indexStr = '${indexNum}. ';
    final binaryStr = 'Binary: ${(indexNum - 1).toRadixString(2).padLeft(11, '0')}';
    
    List<TextSpan> highlightOccurrences(
      String source,
      String query, {
      String? type,
      bool isIndex = false,
      }) {
      if (query.isEmpty) {
        return [TextSpan(text: source)];
      }

      // 소스와 쿼리를 둘 다 소문자로 비교
      final lowerSource = source.toLowerCase();
      final lowerQuery = query.toLowerCase();

      final matches = RegExp(RegExp.escape(lowerQuery))
      .allMatches(lowerSource);

      if (matches.isEmpty) {
        return [TextSpan(text: source)];
      }

      Color highlightColor;
      switch (type) {
        case 'numeric':
          highlightColor = CoconutColors.cyanBlue;
          break;
        case 'binary':
          highlightColor = CoconutColors.cyanBlue;
          break;
        default:
          highlightColor = CoconutColors.cyanBlue;
      }

      List<TextSpan> spans = [];
      int lastMatchEnd = 0;
      for (final match in matches) {
        if (match.start != lastMatchEnd) {
          spans.add(TextSpan(text: source.substring(lastMatchEnd, match.start)));
        }
        spans.add(
          TextSpan(
          text: source.substring(match.start, match.end),
            style: TextStyle(fontWeight: FontWeight.bold, color: highlightColor),
          ),
        );
        lastMatchEnd = match.end;
      }
      if (lastMatchEnd != source.length) {
        spans.add(TextSpan(text: source.substring(lastMatchEnd)));
      }
      return spans;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        RichText(
                          text: TextSpan(
                            children: highlightOccurrences(
                              indexStr,
                              query,
                              type: 'numeric',
                            ),
                          style: Styles.body1.merge(TextStyle(
                            color: MyColors.transparentWhite_70,
                            fontFamily: CustomFonts.number.getFontFamily,
                          )),
                        ),
                      ),
                        RichText(
                          text: TextSpan(
                            children:
                                highlightOccurrences(item, _searchController.text, type: type,),
                            style: Styles.h3.merge(const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: RichText(
                  text: TextSpan(
                    children: highlightOccurrences(binaryStr, query, type: 'binary'),
                    style: Styles.subLabel.merge(
                      const TextStyle(color: MyColors.transparentWhite_50),
                    ),
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
        if (index != wordList.length - 1) const Divider(color: MyColors.borderLightgrey),
      ],
    );
  }
}
