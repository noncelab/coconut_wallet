import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/chain_backend_config.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/model/node/floresta_sync_info.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/services/floresta_node_session.dart';
import 'package:coconut_wallet/utils/logger.dart';

/// 임베드 노드 생명주기 seam.
///
/// [NodeProvider]는 모드 분기 없이 이 인터페이스만 무조건 호출한다.
/// Electrum/외부 서버에서는 모든 메서드가 no-op이고, 임베드 Floresta에서만 실제 노드를 띄운다.
/// Floresta 생명주기 변경은 이 구현 안에서 끝나고 NodeProvider는 건드리지 않는다.
abstract class NodeLifecycle {
  /// 서버가 임베드 Floresta면 (필요 시) 노드를 기동한다. 그 외에는 no-op.
  Future<void> ensureStartedFor(ElectrumServer server, ChainBackendConfig backend);

  /// 지갑 디스크립터 등록. 세션이 없으면 no-op.
  Future<void> prepareWallets(List<WalletItemBase> wallets);

  /// 기동된 임베드 노드를 종료한다.
  Future<void> stop();

  /// IBD 종료 등으로 지갑 재조회가 필요할 때 발행.
  Stream<void> get needsWalletRefresh;

  void dispose();
}

/// Floresta 상태 조회 전용. 코어 seam(NodeLifecycle)이 Floresta 타입을 노출하지 않도록 분리.
abstract class FlorestaNodeStatus {
  /// 현재 임베드 세션(디버그/상태 표시용). 없으면 null.
  FlorestaNodeSession? get session;

  FlorestaSyncInfo? get syncInfo;
  Stream<FlorestaSyncInfo> get syncInfoStream;

  /// 노드 기동 실패 사유(포트 사용 중 등). 성공이거나 세션이 없으면 null.
  String? get startError;
}

/// [FlorestaNodeSession]으로 임베드 노드를 관리하는 구현.
///
/// 비-Floresta 서버에 대해서는 no-op이라 외부 Floresta/일렉트럼 모드에서도 안전하게 호출할 수 있다.
class FlorestaNodeLifecycle implements NodeLifecycle, FlorestaNodeStatus {
  FlorestaNodeLifecycle({
    required NetworkType networkType,
    String? dataDir,
    List<String> fixedPeers = const [],
    int? filtersStartHeight,
  }) : _networkType = networkType,
       _dataDir = dataDir,
       _fixedPeers = fixedPeers,
       _filtersStartHeight = filtersStartHeight;

  final NetworkType _networkType;
  final String? _dataDir;
  final List<String> _fixedPeers;
  final int? _filtersStartHeight;

  final _refreshController = StreamController<void>.broadcast();
  /// 세션 교체에도 살아남는 안정 스트림. 화면이 한 번 구독하면 노드 재기동/모드 전환 후에도
  /// IBD/sync 갱신을 계속 받는다(세션 스트림을 직접 구독하면 교체 시 죽는다).
  final _syncController = StreamController<FlorestaSyncInfo>.broadcast();
  FlorestaNodeSession? _session;
  ElectrumServer? _runningServer;
  ChainBackendConfig? _runningBackend;
  StreamSubscription<void>? _sessionRefreshSub;
  StreamSubscription<FlorestaSyncInfo>? _sessionSyncSub;

  @override
  Future<void> ensureStartedFor(ElectrumServer server, ChainBackendConfig backend) async {
    if (!backend.isEmbedded) return;
    final running = _runningServer;
    if (_session != null &&
        running != null &&
        running.host == server.host &&
        running.port == server.port &&
        _runningBackend?.rpcPort == backend.rpcPort) {
      return;
    }
    await _restart(server, backend);
  }

  Future<void> _restart(ElectrumServer server, ChainBackendConfig backend) async {
    await _sessionRefreshSub?.cancel();
    _sessionRefreshSub = null;
    await _sessionSyncSub?.cancel();
    _sessionSyncSub = null;
    await _session?.stop();
    _session = null;
    _runningServer = null;
    _runningBackend = null;

    final session = FlorestaNodeSession(
      host: server.host,
      electrumPort: server.port,
      rpcPort: backend.rpcPort,
      networkType: _networkType,
      dataDir: _dataDir,
      fixedPeers: _fixedPeers,
      filtersStartHeight: _filtersStartHeight,
    );
    _session = session;
    _runningServer = server;
    _runningBackend = backend;
    _sessionRefreshSub = session.needsWalletRefresh.listen((_) {
      if (!_refreshController.isClosed) _refreshController.add(null);
    });
    _sessionSyncSub = session.syncInfoStream.listen((info) {
      if (!_syncController.isClosed) _syncController.add(info);
    });
    Logger.log(
      'FlorestaNodeLifecycle: 세션 시작 ${server.host}:${server.port} rpc=${backend.rpcPort} peers=$_fixedPeers',
    );
    await session.start();
  }

  @override
  Future<void> prepareWallets(List<WalletItemBase> wallets) async {
    await _session?.prepareWallets(wallets);
  }

  @override
  Future<void> stop() async {
    await _sessionRefreshSub?.cancel();
    _sessionRefreshSub = null;
    await _sessionSyncSub?.cancel();
    _sessionSyncSub = null;
    await _session?.stop();
    _session = null;
    _runningServer = null;
    _runningBackend = null;
  }

  @override
  Stream<void> get needsWalletRefresh => _refreshController.stream;

  @override
  FlorestaNodeSession? get session => _session;

  @override
  FlorestaSyncInfo? get syncInfo => _session?.syncInfo;

  @override
  Stream<FlorestaSyncInfo> get syncInfoStream => _syncController.stream;

  @override
  String? get startError => _session?.startError;

  @override
  void dispose() {
    _sessionRefreshSub?.cancel();
    _sessionRefreshSub = null;
    _sessionSyncSub?.cancel();
    _sessionSyncSub = null;
    unawaited(_session?.stop());
    _session = null;
    if (!_refreshController.isClosed) _refreshController.close();
    if (!_syncController.isClosed) _syncController.close();
  }
}
