import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/constants/app_language.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/settings/tools/glossary_screen.dart';
import 'package:coconut_wallet/utils/locale_sort_util.dart';
import 'package:coconut_wallet/utils/locale_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  _Preferences(this.language);

  @override
  final String language;
}

bool _isThaiLeadingVowel(int rune) => rune >= 0x0E40 && rune <= 0x0E44;

/// [language] 용어집을 열고 화면에 나온 묶음을 순서대로 돌려준다(머리글 → 그 아래 용어들).
Future<Map<String, List<String>>> _openGlossary(WidgetTester tester, AppLanguage language) async {
  LocaleSettings.setLocaleSync(resolveAppLocale(language.code));
  addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
  // 목록 전체가 한 번에 그려지도록 긴 화면에서 연다
  tester.view
    ..physicalSize = const Size(390, 6000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<PreferenceProvider>.value(
      value: _Preferences(language.code),
      child: MaterialApp(theme: buildCoconutThemeData(), home: const GlossaryScreen()),
    ),
  );
  await tester.pumpAndSettle();

  // 목록에는 머리글(16px)과 그 아래 용어 칩(14px)이 차례로 온다
  final groups = <String, List<String>>{};
  String? header;
  for (final text in tester.widgetList<Text>(find.descendant(of: find.byType(ListView), matching: find.byType(Text)))) {
    if (text.style?.fontSize == 16) {
      header = text.data!;
      groups[header] = [];
    } else {
      groups[header]!.add(text.data!);
    }
  }
  return groups;
}

List<String> _terms(AppLanguage language) =>
    (json.decode(File('assets/files/glossary_details_${language.code}.json').readAsStringSync())
            as Map<String, dynamic>)
        .keys
        .toList();

void main() {
  testWidgets('태국어 용어집: 영문 용어 다음에 태국어 용어가 첫 자음으로 묶여 자음 순서로 나온다', (tester) async {
    final groups = await _openGlossary(tester, AppLanguage.th);
    final terms = _terms(AppLanguage.th);

    expect(groups.values.expand((group) => group).toList()..sort(), [...terms]..sort());

    // 머리글은 라틴 대문자, 그다음 태국 자음이다. 자음 앞에 쓰는 모음(เ แ โ ใ ไ)은 머리글이 되지 않는다
    final headers = groups.keys.toList();
    final latin = headers.where((header) => RegExp(r'^[A-Z]$').hasMatch(header)).toList();
    final thai = headers.where((header) => header.runes.single >= 0x0E01 && header.runes.single <= 0x0E2E).toList();
    expect(headers, [...latin, ...thai]);
    expect(latin, [...latin]..sort());
    expect(thai, isNotEmpty);
    expect(thai, [...thai]..sort());

    // 용어는 첫 자음의 묶음에 들어간다. 앞 모음으로 시작하면 그다음 글자가 그 자음이다
    for (final MapEntry(key: header, value: group) in groups.entries) {
      for (final term in group) {
        final first = term.runes.first;
        final consonant = _isThaiLeadingVowel(first) ? term.runes.elementAt(1) : first;
        expect(header, String.fromCharCode(consonant).toUpperCase(), reason: term);
      }
      expect(group, [...group]..sort((a, b) => compareByLocaleDictionaryOrder(a, b, AppLocale.th)), reason: header);
    }
    // 앞 모음으로 시작하는 용어가 실제로 있어야 위 규칙을 확인한 것이다
    expect(terms.where((term) => _isThaiLeadingVowel(term.runes.first)), isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('영어 용어집은 지금처럼 첫 글자 알파벳으로 묶는다', (tester) async {
    final groups = await _openGlossary(tester, AppLanguage.en);

    expect(groups.values.expand((group) => group).toList()..sort(), [..._terms(AppLanguage.en)]..sort());
    expect(groups.keys.toList(), [...groups.keys]..sort());
    for (final MapEntry(key: header, value: group) in groups.entries) {
      for (final term in group) {
        expect(header, term[0].toUpperCase(), reason: term);
      }
    }
    expect(groups['B'], ['BIP', 'BSMS']);
    expect(tester.takeException(), isNull);
  });
}
