import 'dart:io';

import 'package:coconut_wallet/services/floresta_node.dart';
import 'package:coconut_wallet/services/floresta_process_node.dart';

/// 임베드 Floresta 노드 구동에 필요한 설정.
class FlorestaNodeConfig {
  /// `bitcoin|testnet|signet|regtest`
  final String network;
  final String dataDir;
  final String? electrumAddress;
  final String? jsonRpcAddress;
  final String? proxy;
  final List<String>? fixedPeers;

  /// 컴팩트 필터 스캔 시작 높이(음수면 tip 기준 상대값). null이면 genesis.
  final int? filtersStartHeight;

  const FlorestaNodeConfig({
    required this.network,
    required this.dataDir,
    this.electrumAddress,
    this.jsonRpcAddress,
    this.proxy,
    this.fixedPeers,
    this.filtersStartHeight,
  });
}

/// Floresta 노드 구동 추상화.
///
/// 플랫폼별 구현:
/// - Android: [FlorestaProcessController] — `florestad` 실행파일을 자식 프로세스로 spawn
///   (크래시 격리, 정적 libc 문제 회피, NDK/Rust 툴체인 결합 제거)
/// - iOS/데스크톱: [FlorestaFfiController] — in-process FFI (iOS는 spawn 불가)
///
/// 앱은 이 인터페이스만 알고, 체인 질의는 동일하게 `127.0.0.1` Electrum/RPC로 붙는다.
abstract class FlorestaNodeController {
  Future<int> start(FlorestaNodeConfig config);
  Future<void> stop(int handle);
  bool isRunning(int handle);

  factory FlorestaNodeController.create() {
    if (Platform.isAndroid) return FlorestaProcessController();
    return FlorestaFfiController();
  }
}

/// iOS/데스크톱용 in-process FFI 구현.
class FlorestaFfiController implements FlorestaNodeController {
  @override
  Future<int> start(FlorestaNodeConfig c) async {
    return FlorestaNode.instance.start(
      network: c.network,
      dataDir: c.dataDir,
      electrumAddress: c.electrumAddress,
      jsonRpcAddress: c.jsonRpcAddress,
      proxy: c.proxy,
      fixedPeers: c.fixedPeers,
      filtersStartHeight: c.filtersStartHeight,
    );
  }

  @override
  Future<void> stop(int handle) async {
    FlorestaNode.instance.shutdown(handle);
  }

  @override
  bool isRunning(int handle) => FlorestaNode.instance.isRunning(handle);
}
