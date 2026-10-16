import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/floresta_sync_info.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/services/floresta_node_controller.dart';
import 'package:coconut_wallet/services/floresta_node_session.dart';
import 'package:coconut_wallet/services/floresta_rpc_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeController implements FlorestaNodeController {
  int stopCount = 0;
  FlorestaNodeConfig? lastConfig;

  @override
  Future<int> start(FlorestaNodeConfig config) async {
    lastConfig = config;
    return 42;
  }

  @override
  Future<void> stop(int handle) async {
    stopCount++;
  }

  @override
  bool isRunning(int handle) => false;
}

class _FakeRpc implements FlorestaRpcClient {
  _FakeRpc(this.ibd, {this.newDescriptors = true});

  bool ibd;
  bool newDescriptors;

  @override
  Future<bool> checkConnection({Duration timeout = const Duration(seconds: 5)}) async => true;

  @override
  Future<FlorestaSyncInfo> getBlockchainInfo({Duration timeout = const Duration(seconds: 5)}) async {
    return FlorestaSyncInfo(
      blocks: 100,
      headers: 100,
      verificationProgress: 1,
      initialBlockDownload: ibd,
    );
  }

  @override
  Future<bool> loadDescriptor(String descriptor) async => newDescriptors;

  @override
  Future<List<Map<String, dynamic>>> listDescriptors() async => const [];

  @override
  Future<void> rescan({int? startHeight}) async {}

  @override
  void close() {}

  // 이 테스트가 쓰지 않는 RPC는 구현하지 않는다.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wallet extends Fake implements WalletItemBase {
  _Wallet(this.id);

  @override
  final int id;

  @override
  final String descriptor = 'wpkh(tpubD6NzVbkrYhZ4Yexample/0/*)';
}

void main() {
  // IBD 폴링 간격(5초)이 지나야 이벤트가 나오므로 여유 있게 대기한다.
  const waitPastFirstPoll = Duration(seconds: 6);

  const peers = ['10.0.0.1:18444'];

  FlorestaNodeSession buildSession(_FakeController controller, _FakeRpc rpc) {
    return FlorestaNodeSession(
      host: '127.0.0.1',
      electrumPort: 50001,
      rpcPort: 8332,
      networkType: NetworkType.regtest,
      fixedPeers: peers,
      dataDir: '/tmp/floresta-session-test',
      controller: controller,
      rpc: rpc,
    );
  }

  test('신규 디스크립터 등록 후 IBD가 끝나면 needsWalletRefresh를 한 번 발행한다', () async {
    final rpc = _FakeRpc(false); // IBD 아님 → 첫 폴링(5초)에서 바로 종료
    final controller = _FakeController();
    final session = buildSession(controller, rpc);
    final refreshes = <void>[];
    session.needsWalletRefresh.listen(refreshes.add);

    await session.start();
    await session.prepareWallets([_Wallet(1)]);
    await Future<void>.delayed(waitPastFirstPoll);

    expect(refreshes, hasLength(1));
    expect(controller.lastConfig?.fixedPeers, peers);
    await session.stop();
  });

  test('이미 캐시된 디스크립터면 IBD 대기 없이 아무 이벤트도 발행하지 않는다', () async {
    final rpc = _FakeRpc(false, newDescriptors: false);
    final session = buildSession(_FakeController(), rpc);
    final refreshes = <void>[];
    session.needsWalletRefresh.listen(refreshes.add);

    await session.start();
    await session.prepareWallets([_Wallet(1)]);
    await Future<void>.delayed(waitPastFirstPoll);

    expect(refreshes, isEmpty);
    await session.stop();
  });

  test('stop()은 진행 중인 IBD 대기를 취소해 이벤트를 발행하지 않는다', () async {
    final rpc = _FakeRpc(true); // IBD 유지
    final controller = _FakeController();
    final session = buildSession(controller, rpc);
    final refreshes = <void>[];
    session.needsWalletRefresh.listen(refreshes.add);

    await session.start();
    await session.prepareWallets([_Wallet(1)]);
    await session.stop(); // IBD 폴링 도중 종료

    expect(controller.stopCount, 1);
    await Future<void>.delayed(waitPastFirstPoll);
    expect(refreshes, isEmpty);
  });
}
