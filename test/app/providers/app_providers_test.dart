import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app/providers/app_providers.dart';
import '../../repository/realm/test_realm_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/single_child_widget.dart';

void main() {
  late TestRealmManager realmManager;

  setUp(() {
    NetworkType.setNetworkType(NetworkType.testnet);
    realmManager = TestRealmManager();
  });

  tearDown(() {
    realmManager.dispose();
  });

  group('buildAppProviders - Provider 등록 완전성', () {
    test('isMainFlow=false일 때 기본 provider들이 모두 등록된다', () {
      final providers = buildAppProviders(
        realmManager: realmManager,
        isMainFlow: false,
        isFirebaseAnalyticsUsed: false,
        networkType: NetworkType.testnet,
      );

      final providerTypes = _extractProviderTypes(providers);

      // 항상 등록되어야 하는 provider들
      expect(providerTypes, contains('VisibilityProvider'));
      expect(providerTypes, contains('ConnectivityProvider'));
      expect(providerTypes, contains('AuthProvider'));
      expect(providerTypes, contains('FeatureSettingsProvider'));
      expect(providerTypes, contains('RealmManager'));
      expect(providerTypes, contains('AnalyticsService'));
      expect(providerTypes, contains('AddressRepository'));
      expect(providerTypes, contains('TransactionRepository'));
      expect(providerTypes, contains('UtxoRepository'));
      expect(providerTypes, contains('TransactionDraftRepository'));
      expect(providerTypes, contains('WalletRepository'));
      expect(providerTypes, contains('SubscriptionRepository'));
      expect(providerTypes, contains('WalletPreferencesRepository'));
      expect(providerTypes, contains('ElectrumServerProvider'));
      expect(providerTypes, contains('BlockExplorerProvider'));
      expect(providerTypes, contains('PreferenceProvider'));
      expect(providerTypes, contains('PriceProvider'));
      expect(providerTypes, contains('UtxoTagProvider'));
      expect(providerTypes, contains('TransactionProvider'));

      // isMainFlow=false일 때는 미등록
      expect(providerTypes, isNot(contains('SendInfoProvider')));
      expect(providerTypes, isNot(contains('WalletProvider')));
      expect(providerTypes, isNot(contains('NodeProvider')));
    });

    test('isMainFlow=true일 때 모든 provider가 등록된다', () {
      final providers = buildAppProviders(
        realmManager: realmManager,
        isMainFlow: true,
        isFirebaseAnalyticsUsed: false,
        networkType: NetworkType.testnet,
      );

      final providerTypes = _extractProviderTypes(providers);

      expect(providerTypes, contains('SendInfoProvider'));
      expect(providerTypes, contains('WalletProvider'));
      expect(providerTypes, contains('NodeProvider'));
    });

    test('AnalyticsService가 항상 등록된다 (regtest 환경에서도 누락되지 않음)', () {
      // 이 테스트는 Provider<AnalyticsService>가 주석 처리되었을 때 실패한다.
      // regtest flavor에서 context.read<AnalyticsService>() 호출 시
      // "ProviderNotFoundException"이 발생하는 버그를 방지한다.
      final providers = buildAppProviders(
        realmManager: realmManager,
        isMainFlow: false,
        isFirebaseAnalyticsUsed: false,
        networkType: NetworkType.testnet,
      );

      final providerTypes = _extractProviderTypes(providers);
      expect(providerTypes, contains('AnalyticsService'));
    });
  });

  group('buildAppProviders - AnalyticsService 설정', () {
    test('isFirebaseAnalyticsUsed=false일 때 AnalyticsService provider가 등록된다', () {
      final providers = buildAppProviders(
        realmManager: realmManager,
        isMainFlow: false,
        isFirebaseAnalyticsUsed: false,
        networkType: NetworkType.testnet,
      );

      final providerTypes = _extractProviderTypes(providers);
      expect(providerTypes, contains('AnalyticsService'));
    });

    test('isFirebaseAnalyticsUsed=true일 때 AnalyticsService provider가 등록된다', () {
      final providers = buildAppProviders(
        realmManager: realmManager,
        isMainFlow: false,
        isFirebaseAnalyticsUsed: true,
        networkType: NetworkType.testnet,
      );

      final providerTypes = _extractProviderTypes(providers);
      expect(providerTypes, contains('AnalyticsService'));
    });
  });
}

/// provider 리스트에서 각 provider가 제공하는 타입 이름을 추출한다.
/// Provider<T> 또는 ChangeNotifierProvider<T> 형태에서 제네릭 타입 인자 T의 이름을 추출한다.
/// Provider.value의 경우 runtimeType에 제네릭이 포함되지 않으므로 별도 처리한다.
Set<String> _extractProviderTypes(List<SingleChildWidget> providers) {
  final types = <String>{};
  for (final provider in providers) {
    final typeStr = provider.runtimeType.toString();
    final match = RegExp(r'<(.+)>').firstMatch(typeStr);
    if (match != null) {
      types.add(match.group(1)!);
    } else if (typeStr == 'Provider.value') {
      // Provider.value는 제네릭 타입이 runtimeType에 나타나지 않으므로
      // 실제 값의 타입으로 유추할 수 없음 - 건너뜀
    }
  }
  return types;
}
