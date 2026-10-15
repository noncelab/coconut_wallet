import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/providers/preferences/electrum_server_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ElectrumServerProvider.migrateLegacyCustomServerStorage (mainnet)', () {
    late ElectrumServerProvider provider;

    setUp(() async {
      NetworkType.setNetworkType(NetworkType.mainnet);
      SharedPreferences.setMockInitialValues({});
      SharedPrefsRepository().setSharedPreferencesForTest(await SharedPreferences.getInstance());
      provider = ElectrumServerProvider();
    });

    test('옛 foundationdevices 주소로 저장되어 있던 값은 새 주소의 기본 서버 참조로 옮긴다', () async {
      await provider.setCustomElectrumServer('mainnet.foundationdevices.com', 50002, true);

      await provider.migrateLegacyCustomServerStorage();

      expect(SharedPrefsRepository().getString(SharedPrefKeys.kElectrumServerName), 'FOUNDATIONDEVICES');
      expect(SharedPrefsRepository().isContainsKey(SharedPrefKeys.kCustomElectrumHost), false);

      final migrated = provider.getElectrumServer();
      expect(migrated.host, 'mainnet-0.foundation.xyz');
      expect(migrated.port, 50002);
      expect(migrated.ssl, true);
    });

    test('옛 bluewallet 주소로 저장되어 있던 값도 새 주소의 기본 서버 참조로 옮긴다', () async {
      await provider.setCustomElectrumServer('electrum1.bluewallet.io', 443, true);

      await provider.migrateLegacyCustomServerStorage();

      expect(provider.getElectrumServer().host, 'electrum2.bluewallet.io');
    });

    test('self-signed 기본 서버(emzy)를 지문 없이 CUSTOM으로 저장해 두었던 경우, 기본 서버 참조로 옮기면서 지문도 라이브로 따라온다', () async {
      // 지문 고정(pinning) 도입 전에 저장된 값을 흉내: emzy를 host/port/ssl만 저장, 지문은 없음.
      await provider.setCustomElectrumServer('electrum.emzy.de', 50002, true);

      await provider.migrateLegacyCustomServerStorage();

      final migrated = provider.getElectrumServer();
      expect(migrated.host, 'electrum.emzy.de');
      expect(migrated.pinnedCertFingerprint, isNotNull);
    });

    test('현재 기본 서버(coconut)와 host/port/ssl이 같으면 참조로 옮긴다(변화 없이도 안전)', () async {
      await provider.setCustomElectrumServer('electrum.coconut.onl', 443, true);

      await provider.migrateLegacyCustomServerStorage();

      expect(SharedPrefsRepository().getString(SharedPrefKeys.kElectrumServerName), 'COCONUT');
    });

    test('기본 서버 목록에 없는 진짜 커스텀 서버는 그대로 둔다', () async {
      await provider.setCustomElectrumServer('my-own-node.example.com', 50002, true);

      await provider.migrateLegacyCustomServerStorage();

      expect(SharedPrefsRepository().getString(SharedPrefKeys.kElectrumServerName), 'CUSTOM');
      expect(provider.getElectrumServer().host, 'my-own-node.example.com');
    });

    test('삭제된 기본 서버(jochenhoenicke)로 저장되어 있던 값은 커스텀 서버로 취급해 그대로 둔다', () async {
      await provider.setCustomElectrumServer('electrum.jochen-hoenicke.de', 50006, true);

      await provider.migrateLegacyCustomServerStorage();

      expect(SharedPrefsRepository().getString(SharedPrefKeys.kElectrumServerName), 'CUSTOM');
      expect(provider.getElectrumServer().host, 'electrum.jochen-hoenicke.de');
    });

    test('서버를 저장한 적이 없으면(=최초 실행) 아무것도 하지 않는다', () async {
      await provider.migrateLegacyCustomServerStorage();

      expect(SharedPrefsRepository().isContainsKey(SharedPrefKeys.kCustomElectrumHost), false);
    });

    test('사용자가 직접 등록한 서버 목록(kUserServers)은 건드리지 않는다', () async {
      await provider.addUserServer('mainnet.foundationdevices.com', 50002, true);
      await provider.setCustomElectrumServer('some-other-host.example.com', 50002, true);

      await provider.migrateLegacyCustomServerStorage();

      final userServers = await provider.getUserServers();
      expect(userServers.single.host, 'mainnet.foundationdevices.com');
    });
  });

  group('ElectrumServerProvider.setSelectedDefaultServer', () {
    setUp(() async {
      NetworkType.setNetworkType(NetworkType.mainnet);
      SharedPreferences.setMockInitialValues({});
      SharedPrefsRepository().setSharedPreferencesForTest(await SharedPreferences.getInstance());
    });

    test('serverName 참조로 저장하고, 이전에 남아있던 커스텀 서버 필드는 정리한다', () async {
      final provider = ElectrumServerProvider();
      await provider.setCustomElectrumServer('leftover.example.com', 1234, true, pinnedCertFingerprint: 'AA:BB');

      await provider.setSelectedDefaultServer('ACINQ');

      expect(SharedPrefsRepository().getString(SharedPrefKeys.kElectrumServerName), 'ACINQ');
      expect(SharedPrefsRepository().isContainsKey(SharedPrefKeys.kCustomElectrumHost), false);
      expect(provider.getElectrumServer().host, 'electrum.acinq.co');
    });
  });
}
