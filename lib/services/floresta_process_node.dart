import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:coconut_wallet/services/floresta_node.dart';
import 'package:coconut_wallet/services/floresta_node_controller.dart';
import 'package:coconut_wallet/utils/logger.dart';

/// Android용 Floresta 노드 컨트롤러.
///
/// `florestad`를 앱의 native lib 디렉터리에 `libflorestad.so`로 번들해 두면
/// Android가 exec 가능한 위치(`/data/app/.../lib/<abi>/`)로 추출한다. 이를 자식 프로세스로
/// spawn한다. 노드가 죽어도 앱은 살아있고, 노드만 재시작할 수 있다.
class FlorestaProcessController implements FlorestaNodeController {
  static const MethodChannel _channel = MethodChannel('onl.coconut.wallet/os');

  @override
  Future<int> start(FlorestaNodeConfig config) async {
    final libDir = await _channel.invokeMethod<String>('nativeLibraryDir');
    if (libDir == null || libDir.isEmpty) {
      throw FlorestaNodeException('nativeLibraryDir를 가져올 수 없습니다');
    }

    final binPath = '$libDir/libflorestad.so';
    final args = buildArgs(config);
    Logger.log('FlorestaProcess: start $binPath ${args.join(' ')}');

    final process = await Process.start(binPath, args, mode: ProcessStartMode.detached);
    return process.pid;
  }

  @visibleForTesting
  List<String> buildArgs(FlorestaNodeConfig c) {
    // Flutter는 assume-utreexo 기본 ON(플래그 없음). backfill은 과거 전체 재검증이라 끄고
    // assume-utreexo 체크포인트 이후만 다룬다(수 분 내 사용 가능).
    final args = <String>['-n', c.network, '--data-dir', c.dataDir, '--no-backfill'];
    if (c.electrumAddress != null) args.addAll(['--electrum-address', c.electrumAddress!]);
    if (c.jsonRpcAddress != null) args.addAll(['--rpc-address', c.jsonRpcAddress!]);
    if (c.proxy != null) args.addAll(['--proxy', c.proxy!]);
    if (c.filtersStartHeight != null) args.addAll(['--filters-start-height', '${c.filtersStartHeight}']);
    // 로컬 florestad(v0.9.x dev)는 --connect를 여러 번 받을 수 있다.
    for (final peer in c.fixedPeers ?? const <String>[]) {
      args.addAll(['--connect', peer]);
    }
    return args;
  }

  @override
  Future<void> stop(int handle) async {
    try {
      Process.killPid(handle, ProcessSignal.sigterm);
    } catch (e) {
      Logger.error('FlorestaProcess: stop($handle) 실패: $e');
    }
  }

  @override
  bool isRunning(int handle) => Directory('/proc/$handle').existsSync();
}
