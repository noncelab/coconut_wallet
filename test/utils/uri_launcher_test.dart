import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BlockExplorerProvider blockExplorerProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({SharedPrefKeys.kLanguage: 'en'});
    final prefs = await SharedPreferences.getInstance();
    SharedPrefsRepository().setSharedPreferencesForTest(prefs);
    NetworkType.setNetworkType(NetworkType.mainnet);
    blockExplorerProvider = BlockExplorerProvider();
  });

  group('fallbackSanitizedAnalyticsValue - 기본 explorer(mempool.space)', () {
    test('address 경로가 포함된 URL이면 sanitized된 analytics 값을 반환한다', () {
      final uri = Uri.parse('https://mempool.space/en/address/bc1qxxxxsensitiveaddress');

      final result = fallbackSanitizedAnalyticsValue(blockExplorerProvider, uri);

      expect(result, 'https://mempool.space/en/address');
      expect(result, isNot(contains('bc1qxxxxsensitiveaddress')));
    });

    test('tx 경로가 포함된 URL이면 sanitized된 analytics 값을 반환한다', () {
      final uri = Uri.parse('https://mempool.space/en/tx/deadbeefsensitivehash');

      final result = fallbackSanitizedAnalyticsValue(blockExplorerProvider, uri);

      expect(result, 'https://mempool.space/en/tx');
    });

    test('block 경로가 포함된 URL이면 sanitized된 analytics 값을 반환한다', () {
      final uri = Uri.parse('https://mempool.space/en/block/840000');

      final result = fallbackSanitizedAnalyticsValue(blockExplorerProvider, uri);

      expect(result, 'https://mempool.space/en/block');
    });

    test('explorer host와 다른 URL이면 null을 반환한다', () {
      final uri = Uri.parse('https://example.com/address/bc1qxxxx');

      final result = fallbackSanitizedAnalyticsValue(blockExplorerProvider, uri);

      expect(result, isNull);
    });

    test('explorer host는 같지만 tx/block/address 경로가 아니면 null을 반환한다', () {
      final uri = Uri.parse('https://mempool.space/en/docs/api');

      final result = fallbackSanitizedAnalyticsValue(blockExplorerProvider, uri);

      expect(result, isNull);
    });
  });

  group('fallbackSanitizedAnalyticsValue - custom explorer', () {
    setUp(() async {
      await blockExplorerProvider.setUseDefaultExplorer(false);
      await blockExplorerProvider.setCustomExplorerUrl('https://my-custom-explorer.com');
    });

    test('custom explorer host와 일치하면 CUSTOM_EXPLORER 접두사가 붙은 sanitized 값을 반환한다', () {
      final uri = Uri.parse('https://my-custom-explorer.com/address/bc1qxxxxsensitiveaddress');

      final result = fallbackSanitizedAnalyticsValue(blockExplorerProvider, uri);

      expect(result, 'CUSTOM_EXPLORER/ADDRESS');
    });

    test('기본 explorer host의 URL은 더 이상 매칭되지 않는다', () {
      final uri = Uri.parse('https://mempool.space/en/address/bc1qxxxx');

      final result = fallbackSanitizedAnalyticsValue(blockExplorerProvider, uri);

      expect(result, isNull);
    });
  });

  group('fallbackSanitizedAnalyticsValue - regtest', () {
    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
    });

    test('regtest explorer host와 일치하면 sanitized 값을 반환한다', () {
      final uri = Uri.parse('https://regtest-mempool.coconut.onl/tx/deadbeef');

      final result = fallbackSanitizedAnalyticsValue(blockExplorerProvider, uri);

      expect(result, 'https://regtest-mempool.coconut.onl/tx');
    });
  });

  group('fallbackSanitizedAnalyticsValue - mailto 등 explorer와 무관한 링크', () {
    test('mailto scheme은 host가 비어 있어 null을 반환한다', () {
      final uri = Uri.parse('mailto:hello@noncelab.com');

      final result = fallbackSanitizedAnalyticsValue(blockExplorerProvider, uri);

      expect(result, isNull);
    });
  });
}
