import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPrefsRepository prefs;
  late HomeConfigurationRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    repository = HomeConfigurationRepository(prefs);
  });

  test('nothing saved → null', () {
    expect(repository.load(), isNull);
  });

  test('saved configuration loads back equal', () async {
    final config = HomeConfiguration(
      items: [const HomeItem(id: 'a', definitionId: 'w', kind: HomeItemKind.widget, order: 0, span: HomeSpan.wide)],
    );
    await repository.save(config);

    expect(repository.load(), config);
  });

  test('broken JSON → null instead of throwing', () async {
    await prefs.setString(HomeConfigurationRepository.key, '{not json');

    expect(repository.load(), isNull);
  });

  test('a newer version than this app understands → null', () async {
    await prefs.setString(
      HomeConfigurationRepository.key,
      '{"version": ${HomeConfiguration.currentVersion + 1}, "items": []}',
    );

    expect(repository.load(), isNull);
  });
}
