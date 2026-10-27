import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/constants/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every app language has a glossary with the same number of complete entries', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final counts = <String, int>{};
    for (final language in AppLanguage.values) {
      final path = 'assets/files/glossary_details_${language.code}.json';
      expect(pubspec, contains(path), reason: path);
      final terms = json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
      for (final entry in terms.entries) {
        final details = entry.value as Map<String, dynamic>;
        expect(
          details.keys.toSet(),
          containsAll(['en', 'content', 'synonym', 'related']),
          reason: '$path ${entry.key}',
        );
        expect((details['content'] as String).trim(), isNotEmpty, reason: '$path ${entry.key}');
      }
      counts[language.code] = terms.length;
    }
    expect(counts.values.toSet(), hasLength(1), reason: '$counts');
  });
}
