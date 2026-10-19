import 'dart:async';
import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/floresta_sync_info.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/services/floresta_node_controller.dart';
import 'package:coconut_wallet/services/floresta_rpc_client.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:path_provider/path_provider.dart';

/// 임베드 Floresta 노드의 **생명주기** 소유자.
///
/// 질의(잔액/이력/UTXO/broadcast)는 이 클래스가 아니라 워커 isolate의 `ChainSource`가 담당한다.
/// 이 클래스가 흡수하는 것은 "노드가 질의 가능해질 때까지"의 상태 전이뿐이다:
/// 프로세스 기동 → JSON-RPC ready → 디스크립터 등록 → IBD 종료 → 지갑 재조회 통지.
///
/// Electrum 모드에는 이 생명주기가 없으므로 [NodeProvider]는 이 객체를 null로 두고 `?.`로
/// 단락한다. 그래서 별도의 Electrum 구현(no-op)이 필요 없다.
///
/// 단일 사용(single-use): [stop]이 스트림까지 닫는다. 재기동은 새 인스턴스로 한다.
class FlorestaNodeSession {
  FlorestaNodeSession({
    required String host,
    required int electrumPort,
    required int rpcPort,
    required NetworkType networkType,
    required List<String> fixedPeers,
    String? dataDir,
    int? filtersStartHeight,
    FlorestaNodeController? controller,
    FlorestaRpcClient? rpc,
    Duration syncPollInterval = _defaultSyncPollInterval,
  }) : _electrumPort = electrumPort,
       _rpcPort = rpcPort,
       _networkType = networkType,
       _fixedPeers = fixedPeers,
       _dataDir = dataDir,
       _filtersStartHeight = filtersStartHeight,
       _syncPollInterval = syncPollInterval,
       _controller = controller ?? FlorestaNodeController.create(),
       _rpc = rpc ?? (rpcPort > 0 ? FlorestaRpcClient(host, rpcPort, false) : null);

  static const _readyPollInterval = Duration(milliseconds: 500);
  static const _readyPollAttempts = 30; // 최대 ~15초
  static const _defaultSyncPollInterval = Duration(seconds: 10);
  static const _ibdPollInterval = Duration(seconds: 5);
  // mainnet 첫 IBD는 assume-utreexo 체크포인트~tip 구간 utreexo 검증으로 수 시간 걸린다.
  // 30분 cap으로는 중간에 포기했으므로 24시간까지 기다린다(5초 간격).
  static const _ibdPollAttempts = 24 * 60 * 60 ~/ 5;

  /// 임베드 노드가 Electrum/RPC를 바인딩하는 로컬 주소(전 플랫폼 공통).
  static const _kLoopbackHost = '127.0.0.1';

  final int _electrumPort;
  final int _rpcPort;
  final NetworkType _networkType;
  final List<String> _fixedPeers;
  final String? _dataDir;
  final int? _filtersStartHeight;
  final Duration _syncPollInterval;

  final FlorestaNodeController _controller;
  final _syncController = StreamController<FlorestaSyncInfo>.broadcast();
  final _refreshController = StreamController<void>.broadcast();

  FlorestaRpcClient? _rpc;
  int? _handle;
  Timer? _syncTimer;
  bool _stopped = false;
  bool _watchingIbd = false;
  FlorestaSyncInfo? _syncInfo;
  String? _resolvedDataDir;
  String? _startError;
  // IBD 속도 계측(iOS/Android 비교용). Flutter 로그만으로 완료시각·속도를 분석한다.
  DateTime? _ibdStartedAt;
  int? _ibdLastBlocks;
  DateTime? _ibdLastAt;
  bool _ibdCompleteLogged = false;

  FlorestaSyncInfo? get syncInfo => _syncInfo;

  /// 노드가 RPC 준비에 실패했을 때의 사유(포트 사용 중 등). 성공 시 null.
  String? get startError => _startError;
  Stream<FlorestaSyncInfo> get syncInfoStream => _syncController.stream;

  /// 노드 프로세스가 살아 있고 종료되지 않았는지.
  bool get isRunning => !_stopped && _handle != null;

  /// 플랫폼 컨트롤러가 돌려준 노드 핸들(디버그 표시용).
  int? get nodeHandle => _handle;

  /// 노드 데이터 디렉터리(디버그 표시용).
  String? get dataDir => _resolvedDataDir;

  /// 신규 디스크립터 등록 후 노드가 IBD를 끝냈을 때 발행. 구독측은 지갑을 다시 조회하면 된다.
  Stream<void> get needsWalletRefresh => _refreshController.stream;

  /// 노드 프로세스를 기동하고 JSON-RPC가 응답할 때까지 기다린다.
  Future<void> start() async {
    if (_stopped) return;

    final dataDir = await _resolveDataDir();
    if (dataDir == null || _stopped) return;

    Logger.log(
      'FlorestaNodeSession: start network=${_networkName()} dataDir=$dataDir '
      'electrum=$_kLoopbackHost:$_electrumPort rpc=${_rpcPort > 0 ? '$_kLoopbackHost:$_rpcPort' : 'none'} '
      'fixedPeers=$_fixedPeers',
    );

    final int handle;
    try {
      handle = await _controller.start(
        FlorestaNodeConfig(
          network: _networkName(),
          dataDir: dataDir,
          electrumAddress: '$_kLoopbackHost:$_electrumPort',
          jsonRpcAddress: _rpcPort > 0 ? '$_kLoopbackHost:$_rpcPort' : null,
          fixedPeers: _fixedPeers.isEmpty ? null : _fixedPeers,
          filtersStartHeight: _filtersStartHeight,
        ),
      );
    } catch (e) {
      Logger.error('FlorestaNodeSession: 노드 기동 실패: $e');
      return;
    }

    // 기동 중 stop()이 들어온 경우 즉시 정리한다.
    if (_stopped) {
      await _controller.stop(handle).catchError((Object e) => Logger.error('FlorestaNodeSession: 노드 종료 실패: $e'));
      return;
    }
    _handle = handle;
    Logger.log('FlorestaNodeSession: 노드 프로세스 기동 handle=$handle');

    final ready = await _waitUntilReady();
    if (_stopped) return;
    if (!ready) {
      _startError =
          '노드 RPC($_kLoopbackHost:$_rpcPort)가 응답하지 않습니다. 포트가 이미 사용 중이거나 노드 기동에 실패했습니다.';
      Logger.error('FlorestaNodeSession: $_startError');
    } else {
      Logger.log('FlorestaNodeSession: start 완료 (RPC ready, 동기화 폴링 시작)');
      _ibdStartedAt = DateTime.now();
      Logger.log(
        'FlorestaNodeSession: IBD START platform=${Platform.operatingSystem} dataDir=$dataDir '
        'electrum=$_kLoopbackHost:$_electrumPort rpc=$_rpcPort peers=$_fixedPeers',
      );
    }
    _startSyncPolling();
  }

  /// 지갑 디스크립터를 노드에 등록한다. 신규 등록이 있었으면 IBD 종료 후
  /// [needsWalletRefresh]를 발행한다. 이미 캐시된 경우(노드 재시작)는 아무 것도 하지 않는다.
  ///
  /// 디스크립터는 [WalletItemBase.descriptor]에 있으므로 워커 isolate를 거치지 않고
  /// 메인 isolate에서 이 세션의 RPC 클라이언트로 직접 등록한다(JSON-RPC는 stateless HTTP).
  Future<void> prepareWallets(List<WalletItemBase> wallets) async {
    if (_stopped || wallets.isEmpty) return;
    final rpc = _rpc;
    if (rpc == null) return;
    Logger.log('FlorestaNodeSession: prepareWallets count=${wallets.length}');

    var anyNew = false;
    try {
      for (final wallet in wallets) {
        final descriptor = wallet.descriptor;
        if (descriptor.isEmpty) continue;
        final added = await rpc.loadDescriptor(descriptor);
        anyNew = anyNew || added;
      }
    } catch (e) {
      Logger.error('FlorestaNodeSession: 디스크립터 등록 실패: $e');
      return;
    }
    if (_stopped) return;

    // florestad의 rescanblockchain은 이미 인덱싱된 UTXO를 중복 적재하는 버그가 있어 쓰지 않는다.
    // 노드 월렛이 IBD 중 스스로 인덱싱하므로, IBD 종료 후 지갑만 다시 조회하면 된다.
    if (!anyNew) {
      Logger.log('FlorestaNodeSession: 디스크립터 캐시됨, IBD 재조회 생략');
      return;
    }
    Logger.log('FlorestaNodeSession: 신규 디스크립터 등록, IBD 종료 대기');
    unawaited(_watchIbd());
  }

  /// 노드를 종료하고 진행 중인 IBD 대기/동기화 폴링을 중단시킨다(누수 차단). 스트림까지 닫는다.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    Logger.log('FlorestaNodeSession: stop 요청 (handle=$_handle)');

    _syncTimer?.cancel();
    _syncTimer = null;

    final handle = _handle;
    _handle = null;
    if (handle != null) {
      try {
        await _controller.stop(handle);
      } catch (e) {
        Logger.error('FlorestaNodeSession: 노드 종료 실패: $e');
      }
    }

    _rpc?.close();
    _rpc = null;
    if (!_syncController.isClosed) _syncController.close();
    if (!_refreshController.isClosed) _refreshController.close();
    Logger.log('FlorestaNodeSession: 종료 완료');
  }

  Future<String?> _resolveDataDir() async {
    final configured = _dataDir;
    if (configured != null) {
      _resolvedDataDir = configured;
      return configured;
    }
    // 부트스트랩에서 별도 전달이 없으면 앱 샌드박스에 노드 데이터를 둔다.
    try {
      final support = await getApplicationSupportDirectory();
      final dataDir = '${support.path}/floresta';
      await Directory(dataDir).create(recursive: true);
      _resolvedDataDir = dataDir;
      return dataDir;
    } catch (e) {
      Logger.error('FlorestaNodeSession: dataDir 생성 실패: $e');
      return null;
    }
  }

  /// 노드의 JSON-RPC가 응답할 때까지 잠시 대기한다.
  Future<bool> _waitUntilReady() async {
    final rpc = _rpc;
    if (rpc == null) return true; // RPC 포트가 없으면 대기할 것이 없다.
    for (var i = 0; i < _readyPollAttempts; i++) {
      if (_stopped) return false;
      if (await rpc.checkConnection(timeout: const Duration(seconds: 2))) {
        Logger.log('FlorestaNodeSession: JSON-RPC ready (시도 ${i + 1})');
        return true;
      }
      await Future<void>.delayed(_readyPollInterval);
    }
    return false;
  }

  void _startSyncPolling() {
    if (_rpc == null) return;
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncPollInterval, (_) => unawaited(_pollSync()));
    unawaited(_pollSync());
  }

  Future<void> _pollSync() async {
    final rpc = _rpc;
    if (rpc == null || _stopped) return;
    try {
      final info = await rpc.getBlockchainInfo();
      if (_stopped) return;
      _syncInfo = info;
      _logIbdProgress(info);
      if (!_syncController.isClosed) _syncController.add(info);
    } catch (_) {
      // 노드가 아직 준비 중이거나 종료 중일 수 있다. 다음 폴링에서 재시도.
    }
  }

  /// IBD 진행/완료를 구조화된 Flutter 로그로 남긴다(플랫폼 간 속도 비교용).
  ///
  /// 로그 예: `FlorestaNodeSession: IBD elapsed=30.0s blocks=120 headers=5000 ... avg=4.00b/s now=3.50b/s`
  void _logIbdProgress(FlorestaSyncInfo info) {
    final start = _ibdStartedAt;
    if (start == null) return;
    final now = DateTime.now();
    final elapsed = now.difference(start).inMilliseconds / 1000.0;
    if (elapsed <= 0) return;

    final lastAt = _ibdLastAt;
    final lastBlocks = _ibdLastBlocks;
    _ibdLastAt = now;
    _ibdLastBlocks = info.blocks;

    final avgRate = info.blocks / elapsed;
    final windowSec = lastAt == null ? 0.0 : now.difference(lastAt).inMilliseconds / 1000.0;
    final windowRate = (lastAt == null || windowSec <= 0) ? avgRate : (info.blocks - (lastBlocks ?? 0)) / windowSec;

    if (info.isSynced) {
      if (_ibdCompleteLogged) return;
      _ibdCompleteLogged = true;
      Logger.log(
        'FlorestaNodeSession: IBD COMPLETE elapsed=${elapsed.toStringAsFixed(1)}s '
        'blocks=${info.blocks} headers=${info.headers} avg=${avgRate.toStringAsFixed(2)}b/s',
      );
      return;
    }
    Logger.log(
      'FlorestaNodeSession: IBD elapsed=${elapsed.toStringAsFixed(1)}s '
      'blocks=${info.blocks} headers=${info.headers} '
      'progress=${(info.verificationProgress * 100).toStringAsFixed(1)}% '
      'avg=${avgRate.toStringAsFixed(2)}b/s now=${windowRate.toStringAsFixed(2)}b/s',
    );
  }

  /// 신규 디스크립터를 등록한 뒤, 노드가 IBD를 끝내면 [needsWalletRefresh]를 발행한다.
  ///
  /// IBD 중에는 노드 월렛이 아직 모든 과거 트랜잭션을 인덱싱하지 않아 잔액이 0이나 부분값으로
  /// 캐시될 수 있다. IBD 종료 후 구독측이 지갑을 처음부터 다시 조회한다.
  Future<void> _watchIbd() async {
    final rpc = _rpc;
    if (rpc == null || _watchingIbd) return;
    _watchingIbd = true;
    Logger.log('FlorestaNodeSession: IBD 감시 시작');
    try {
      // ponytail: 5초 간격 최대 ~30분. mainnet 첫 IBD가 이보다 길면 늘릴 것.
      for (var i = 0; i < _ibdPollAttempts; i++) {
        await Future<void>.delayed(_ibdPollInterval);
        if (_stopped) return;
        try {
          final info = await rpc.getBlockchainInfo();
          if (_stopped) return;
          if (!info.initialBlockDownload) break;
        } catch (_) {
          // 노드가 아직 준비 중일 수 있다. 다음 폴링에서 재시도.
        }
      }
      if (_stopped) return;
      Logger.log('FlorestaNodeSession: IBD 종료 감지 → needsWalletRefresh 발행');
      if (!_refreshController.isClosed) _refreshController.add(null);
    } finally {
      _watchingIbd = false;
    }
  }

  String _networkName() {
    if (_networkType == NetworkType.mainnet) return 'bitcoin';
    if (_networkType == NetworkType.testnet) return 'testnet';
    if (_networkType == NetworkType.regtest) return 'regtest';
    return 'bitcoin';
  }
}
