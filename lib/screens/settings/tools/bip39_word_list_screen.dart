import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutAppBar, CoconutTextField, CoconutTextFieldStyle;
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 하이라이트 처리 함수
List<TextSpan> highlightOccurrences(
  BuildContext context,
  String source,
  String query, {
  bool isIndex = false,
  Color? highlightColor,
}) {
  final colors = context.coconutColors;
  final normalStyle =
      isIndex ? CoconutTypography.body1_16_Number.setColor(colors.mutedText) : TextStyle(color: colors.primaryText);
  final resolvedHighlightColor = highlightColor ?? colors.success;

  if (query.isEmpty) {
    return [TextSpan(text: source, style: normalStyle)];
  }

  final matches = query.allMatches(source);
  if (matches.isEmpty) {
    return [TextSpan(text: source, style: normalStyle)];
  }

  final spans = <TextSpan>[];
  int lastMatchEnd = 0;

  for (final match in matches) {
    if (match.start > lastMatchEnd) {
      spans.add(TextSpan(text: source.substring(lastMatchEnd, match.start), style: normalStyle));
    }

    spans.add(
      TextSpan(
        text: source.substring(match.start, match.end),
        style: normalStyle.copyWith(fontWeight: FontWeight.bold, color: resolvedHighlightColor),
      ),
    );

    lastMatchEnd = match.end;
  }

  if (lastMatchEnd < source.length) {
    spans.add(TextSpan(text: source.substring(lastMatchEnd), style: normalStyle));
  }

  return spans;
}

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
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _filteredItems = [];
  bool _isTop = true;
  bool _isFabShown = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = _generateFullList();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// 전체 워드리스트 생성
  List<Map<String, dynamic>> _generateFullList() =>
      List.generate(wordList.length, (index) => {'index': index + 1, 'item': wordList[index], 'type': null});

  /// 스크롤 리스너
  void _scrollListener() {
    final scrollPosition = _scrollController.position;

    if (_isTop && scrollPosition.pixels > 0) {
      _isTop = false;
      setState(() {});
    } else if (!_isTop && scrollPosition.pixels <= 0) {
      _isTop = true;
      setState(() {});
    }

    if (!_isFabShown && scrollPosition.pixels > 450) {
      setState(() => _isFabShown = true);
    } else if (_isTop) {
      setState(() => _isFabShown = false);
    }
  }

  /// 검색창 변경 시 실행
  void _filterItems() {
    final text = _searchController.text;
    setState(() {
      _filteredItems = text.isNotEmpty ? _queryWord(text) : _generateFullList();
    });
  }

  /// 검색 로직 (원본 유지)
  List<Map<String, dynamic>> _queryWord(String input) {
    final query = input.toLowerCase();
    final isBinary = RegExp(r'^[01]+$').hasMatch(query);
    final isNumeric = RegExp(r'^\d+$').hasMatch(query);
    final isAlphabetic = RegExp(r'^[a-zA-Z]+$').hasMatch(query);

    final numericResults = <Map<String, dynamic>>[];
    final binaryResults = <Map<String, dynamic>>[];
    final alphabeticResults = <Map<String, dynamic>>[];

    for (var i = 0; i < wordList.length; i++) {
      final indexNum = i + 1;
      final item = wordList[i];
      final binaryStr = (indexNum - 1).toRadixString(2).padLeft(11, '0');

      // 숫자 검색 → index 동일 시 매칭
      if (isNumeric && query.length <= 4 && i.toString() == query) {
        numericResults.add({'index': indexNum, 'item': item, 'type': 'numeric'});
      }

      // 이진 검색
      if (isBinary && binaryStr.contains(query)) {
        binaryResults.add({'index': indexNum, 'item': item, 'type': 'binary'});
      }

      // 알파벳 검색
      if (isAlphabetic && item.toLowerCase().contains(query)) {
        alphabeticResults.add({'index': indexNum, 'item': item, 'type': 'alphabetic'});
      }
    }

    // 알파벳 검색 → startsWith 우선 정렬
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
      return alphabeticResults;
    } else {
      return [
        ...numericResults..sort((a, b) => a['index'].compareTo(b['index'])),
        ...binaryResults..sort((a, b) => a['index'].compareTo(b['index'])),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: CoconutAppBar.build(title: _titleText, context: context, isBottom: true),
        body: Column(
          children: [
            _searchBar(context),
            SizedBox(width: MediaQuery.of(context).size.width, child: _resultWidget()),
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

  Widget _searchBar(BuildContext context) {
    final colors = context.coconutColors;

    return Container(
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: Sizes.size16, vertical: Sizes.size8),
      child: CoconutTextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (_) {},
        textInputType: TextInputType.text,
        textInputFormatter: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))],
        maxLines: 1,
        maxLength: 11,
        isLengthVisible: false,
        size: CoconutTextFieldSize.search,
        prefix: IgnorePointer(
          ignoring: true,
          child: IconButton(
            onPressed: null,
            icon: Icon(Icons.search_rounded, color: colors.iconSecondary),
            iconSize: Sizes.size22,
          ),
        ),
        clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
        onClear: () {
          _searchFocusNode.requestFocus();
          _searchController.clear();
        },
        placeholderText: _hintText,
        activeColor: colors.primaryText,
        cursorColor: colors.primaryText,
        placeholderColor: colors.inputPlaceholder,
        borderColor: colors.inputBorder,
        backgroundColor: colors.inputSurface,
      ),
    );
  }

  Widget _resultWidget() {
    final colors = context.coconutColors;

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
                  style: CoconutTypography.body1_16.setColor(colors.primaryText),
                ),
              ),
            ),
            _filteredItems.isEmpty
                ? Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Center(
                    child: Text(
                      t.bip39_list_screen.no_result,
                      style: CoconutTypography.body2_14_Bold.setColor(colors.secondaryText),
                    ),
                  ),
                )
                : Container(),
          ],
        );
  }

  Widget _buildListItem(BuildContext context, int index) {
    final colors = context.coconutColors;
    final data = _filteredItems[index];
    final item = data['item'] as String;
    final indexNum = data['index'] as int;
    final type = data['type'] as String?;
    final query = _searchController.text.toLowerCase();
    final binaryStr = (indexNum - 1).toRadixString(2).padLeft(11, '0');

    return Column(
      children: [
        ListTile(
          title: RichText(
            text: TextSpan(
              children: highlightOccurrences(context, item, query),
              style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText),
            ),
          ),
          trailing: RichText(
            text: TextSpan(
              style: CoconutTypography.body1_16_Number.setColor(colors.tertiaryText),
              children: [
                const TextSpan(text: 'Binary: '),
                ...highlightOccurrences(
                  context,
                  binaryStr,
                  type == 'numeric' ? binaryStr : (type == 'binary' ? query : ''),
                  isIndex: true,
                ),
              ],
            ),
          ),
        ),
        if (index != _filteredItems.length - 1) Divider(color: colors.divider),
      ],
    );
  }
}
