import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_manager.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  bool online = true;

  @override
  bool get isInternetOn => online;
  @override
  bool get isInternetOff => !online;

  void setOnline(bool value) {
    online = value;
    notifyListeners();
  }
}

class _Wallet extends Fake implements WalletItemBase {
  @override
  int get id => 1;
  @override
  bool get hasLocalKey => false;
  @override
  WalletType get walletType => WalletType.singleSignature;
  @override
  String get name => 'test wallet';
}

class _Isolate extends Fake implements IsolateManager {
  bool initialized = false;
  final stateController = StreamController<IsolateStateMessage>.broadcast();
  Future<void> Function()? onInitialize;
  int initializationCount = 0;

  @override
  void Function()? onUnexpectedExit;

  @override
  Stream<IsolateStateMessage> get stateStream => stateController.stream;

  @override
  Future<void> initialize(
    String host,
    int port,
    bool ssl,
    NetworkType networkType, [
    String? pinnedCertFingerprint,
  ]) async {
    initializationCount++;
    if (onInitialize != null) await onInitialize!();
    initialized = true;
  }

  @override
  Future<Result<bool>> subscribeWallets(List<WalletItemBase> wallets) async => Result.success(true);

  @override
  Future<Result<bool>> subscribeWallet(WalletItemBase wallet) async =>
      initialized ? Result.success(true) : Result.failure(ErrorCodes.nodeIsolateError);

  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async =>
      initialized ? Result.success(BlockTimestamp(1, DateTime(2026))) : Result.failure(ErrorCodes.nodeIsolateError);

  @override
  Future<void> closeIsolate() async => initialized = false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 작업 isolate가 죽은 직후 인터넷이 끊겨 다시 띄우기 예약이 오프라인에서 지나가고, 인터넷이 돌아왔을 때의 첫 초기화가
  // 실패해도, 서버가 되살아나면 평소 재연결로 다시 연결해야 한다(죽은 표시가 남아 재연결을 막으면 안 된다).
  for (final exited in [false, true]) {
    testWidgets('네트워크가 끊겼다 돌아와 첫 초기화가 실패해도 다시 연결한다 (작업 isolate가 먼저 죽음=$exited)', (tester) async {
      final connectivity = _Connectivity();
      final isolate = _Isolate();
      final load = ValueNotifier(WalletLoadState.loadCompleted);
      final wallets = ValueNotifier<List<WalletItemBase>>([_Wallet()]);
      final node = NodeProvider(
        const ElectrumServer('unused.example', 50002, true),
        NetworkType.mainnet,
        connectivity,
        load,
        wallets,
        null,
        isolateManager: isolate,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(isolate.initializationCount, 1);
      if (exited) {
        isolate.initialized = false;
        isolate.onUnexpectedExit!();
      }
      connectivity.setOnline(false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 13)); // 다시 띄우기 예약이 오프라인에서 지나감
      expect(isolate.initializationCount, 1);
      isolate.onInitialize = () async => throw StateError('one transient failure on network restoration');
      connectivity.setOnline(true);
      await tester.pump();
      expect(isolate.initializationCount, 2);
      expect(node.hasConnectionError, isTrue);
      isolate.onInitialize = null; // 이제 다시 시도하면 성공
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 10));
      }
      final attempts = isolate.initializationCount;
      final connectionError = node.hasConnectionError;
      await node.closeConnection();
      node.dispose();
      await isolate.stateController.close();
      load.dispose();
      wallets.dispose();
      connectivity.dispose();
      await tester.pump();
      expect(attempts, greaterThan(2), reason: '한 번 실패한 뒤에도 살아난 서버로 다시 연결해야 한다');
      expect(connectionError, isFalse);
    });
  }
}
