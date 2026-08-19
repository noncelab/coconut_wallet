import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// [NodeProvider.isChainGenesisMismatch]가 [DefaultElectrumServer]의 실제 서버 구성 기준으로
/// regtest <-> mainnet 양방향 전환을 정확히 "호환 불가"로 판단하는지 검증한다.
///
/// 실제 소켓 연결/isolate를 동반하는 NodeProvider 전체를 테스트하는 대신, 서버 변경 시
/// 체인 불일치를 판단하는 순수 로직만 분리해서 검증한다(네트워크 의존성 없이 결정론적으로 실행).
void main() {
  group('NodeProvider.isChainGenesisMismatch 테스트', () {
    // 비트코인 mainnet의 실제 genesis block hash (고정된 공개 값).
    const mainnetGenesisHash = '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f';
    // regtest는 배포마다 genesis hash가 다르므로 coconut 팀의 실제 regtest 서버 값을
    // 재현하지는 않는다. 여기서는 "mainnet과 명백히 다른 체인"을 나타내는 값으로만 사용한다.
    const regtestGenesisHash = '0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206';

    test('DefaultElectrumServer에 mainnet/regtest 서버가 실제로 정의되어 있다', () {
      expect(DefaultElectrumServer.mainnetServers, isNotEmpty);
      expect(DefaultElectrumServer.regtestServers, isNotEmpty);
    });

    test('regtest로 동기화된 상태에서 mainnet 서버로 전환하려 하면 호환되지 않는다고 판단한다', () {
      final mainnetServer = DefaultElectrumServer.mainnetServers.first;

      final mismatch = NodeProvider.isChainGenesisMismatch(
        baselineGenesisHash: regtestGenesisHash,
        newGenesisHash: mainnetGenesisHash,
      );

      expect(mismatch, true, reason: 'regtest로 동기화된 상태에서 mainnet 서버(${mainnetServer.host})로의 전환은 차단되어야 한다.');
    });

    test('mainnet으로 동기화된 상태에서 regtest 서버로 전환하려 하면 호환되지 않는다고 판단한다', () {
      final regtestServer = DefaultElectrumServer.regtestServers.first;

      final mismatch = NodeProvider.isChainGenesisMismatch(
        baselineGenesisHash: mainnetGenesisHash,
        newGenesisHash: regtestGenesisHash,
      );

      expect(mismatch, true, reason: 'mainnet으로 동기화된 상태에서 regtest 서버(${regtestServer.host})로의 전환은 차단되어야 한다.');
    });

    test('같은 체인의 서버로 전환하는 것은 호환된다고 판단한다', () {
      final mismatch = NodeProvider.isChainGenesisMismatch(
        baselineGenesisHash: mainnetGenesisHash,
        newGenesisHash: mainnetGenesisHash,
      );

      expect(mismatch, false);
    });

    test('기존에 기록된 genesis hash가 없으면(최초 연결) 항상 통과시킨다', () {
      final mismatch = NodeProvider.isChainGenesisMismatch(
        baselineGenesisHash: null,
        newGenesisHash: regtestGenesisHash,
      );

      expect(mismatch, false);
    });
  });

  group('NodeProvider.isBuildNetworkGenesisMismatch 테스트', () {
    // 비트코인 mainnet/testnet의 실제 genesis block hash (고정된 공개 값).
    const mainnetGenesisHash = '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f';
    const testnetGenesisHash = '000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943';
    const someRegtestGenesisHash = '0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206';

    // SharedPref에 저장된 "마지막 기준값"이 과거에(검증 없이) 잘못 기록되어 있어도,
    // 이 검사는 SharedPref를 전혀 참조하지 않으므로 영향받지 않아야 한다.
    test('regtest 빌드에서 실제 mainnet 서버(genesis 일치)는 항상 잘못된 체인으로 판단한다', () {
      final wrongChain = NodeProvider.isBuildNetworkGenesisMismatch(
        buildNetworkType: NetworkType.regtest,
        genesisHash: mainnetGenesisHash,
      );

      expect(wrongChain, true, reason: 'regtest 빌드가 실제 mainnet 서버에 연결하는 것은 SharedPref 상태와 무관하게 차단되어야 한다.');
    });

    test('regtest 빌드에서 실제 testnet 서버(genesis 일치)도 잘못된 체인으로 판단한다', () {
      final wrongChain = NodeProvider.isBuildNetworkGenesisMismatch(
        buildNetworkType: NetworkType.regtest,
        genesisHash: testnetGenesisHash,
      );

      expect(wrongChain, true);
    });

    test('regtest 빌드에서 mainnet/testnet과 무관한 임의의 regtest genesis는 통과시킨다', () {
      final wrongChain = NodeProvider.isBuildNetworkGenesisMismatch(
        buildNetworkType: NetworkType.regtest,
        genesisHash: someRegtestGenesisHash,
      );

      expect(wrongChain, false, reason: 'regtest는 배포마다 genesis가 달라서 mainnet/testnet과만 겹치지 않으면 통과해야 한다.');
    });

    test('mainnet 빌드에서 실제 mainnet genesis는 통과시킨다', () {
      final wrongChain = NodeProvider.isBuildNetworkGenesisMismatch(
        buildNetworkType: NetworkType.mainnet,
        genesisHash: mainnetGenesisHash,
      );

      expect(wrongChain, false);
    });

    test('mainnet 빌드에서 mainnet genesis가 아니면 SharedPref 기록 여부와 무관하게 잘못된 체인으로 판단한다', () {
      final wrongChain = NodeProvider.isBuildNetworkGenesisMismatch(
        buildNetworkType: NetworkType.mainnet,
        genesisHash: someRegtestGenesisHash,
      );

      expect(wrongChain, true);
    });

    test('testnet 빌드에서 실제 testnet genesis는 통과시킨다', () {
      final wrongChain = NodeProvider.isBuildNetworkGenesisMismatch(
        buildNetworkType: NetworkType.testnet,
        genesisHash: testnetGenesisHash,
      );

      expect(wrongChain, false);
    });
  });
}
