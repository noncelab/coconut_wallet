import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<BlockExplorerProvider> providerWith(Map<String, Object> values, NetworkType network) async {
    SharedPreferences.setMockInitialValues(values);
    // ignore: deprecated_member_use_from_same_package
    SharedPrefsRepository().setSharedPreferencesForTest(await SharedPreferences.getInstance());
    NetworkType.setNetworkType(network);
    final provider = BlockExplorerProvider();
    addTearDown(provider.dispose);
    return provider;
  }

  tearDown(() => NetworkType.setNetworkType(NetworkType.regtest));

  group('메인넷 기본 탐색기(mempool.space)는 앱 언어 경로를 붙인다. 영어는 경로가 없다', () {
    for (final (language, url) in [
      ('th', 'https://mempool.space/th'),
      ('ko', 'https://mempool.space/ko'),
      ('ja', 'https://mempool.space/ja'),
      ('es', 'https://mempool.space/es'),
      ('de', 'https://mempool.space/de'),
      ('en', 'https://mempool.space'),
    ]) {
      test('$language → $url', () async {
        final provider = await providerWith({SharedPrefKeys.kLanguage: language}, NetworkType.mainnet);

        expect(provider.blockExplorerUrl, url);
        expect(provider.explorerUrlFor(BlockExplorerPathType.tx, 'abc'), '$url/tx/abc');
      });
    }
  });

  test('테스트넷과 레그테스트 탐색기 주소에는 언어 경로를 붙이지 않는다', () async {
    for (final (network, url) in [
      (NetworkType.testnet, 'https://mempool.space/testnet'),
      (NetworkType.regtest, 'https://regtest-mempool.coconut.onl'),
    ]) {
      final provider = await providerWith({SharedPrefKeys.kLanguage: 'th'}, network);

      expect(provider.blockExplorerUrl, url, reason: '$network');
    }
  });

  test('직접 넣은 탐색기 주소는 앱 언어와 관계없이 그대로 쓴다', () async {
    final provider = await providerWith({
      SharedPrefKeys.kLanguage: 'th',
      SharedPrefKeys.kUseDefaultExplorer: false,
      SharedPrefKeys.kCustomExplorerUrl: 'https://explorer.example.com',
    }, NetworkType.mainnet);

    expect(provider.blockExplorerUrl, 'https://explorer.example.com');
    expect(provider.explorerUrlFor(BlockExplorerPathType.address, 'bc1q'), 'https://explorer.example.com/address/bc1q');
  });
}
