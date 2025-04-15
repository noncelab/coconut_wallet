import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_handler_util.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/transaction_processing_state.dart';

class ScriptCallbackManager {
  /// 스크립트별 트랜잭션 조회 후 콜백 함수 실행 시 선행 트랜잭션 조회 여부 확인용
  /// 해당 스크립트별 조회가 필요한 트랜잭션 해시 목록이며 값이 비어있으면 해당 스크립트에 대한 콜백 함수는 실행 가능한 상태로 간주함
  /// key: ScriptKey, value: TxHash 목록
  final Map<String, List<String>> _scriptDependency = <String, List<String>>{};

  /// 스크립트별 트랜잭션 조회 후 fetchUtxos 콜백 함수
  /// key: ScriptKey, value: Function
  final Map<String, List<Future<void> Function()>> _fetchUtxosCallback =
      <String, List<Future<void> Function()>>{};

  /// 현재 처리 중인 트랜잭션 해시와 처리 시작 시간을 추적하기 위한 맵
  /// key: TxHashKey "walletId:txHash", value: ({DateTime startTime, bool isConfirmed, bool isCompleted})
  final Map<String, TransactionProcessingState> _processingTransactions = {};

  /// 트랜잭션의 처리 가능 여부를 확인합니다.
  ///
  /// 다음 조건 중 하나라도 만족하면 `true`를 반환합니다:
  /// - 등록된 트랜잭션이 없는 경우
  /// - 트랜잭션이 언컨펌에서 컨펌 상태로 변경된 경우
  ///
  /// 위 조건을 만족하지 않으면 `false`를 반환합니다.
  bool isTransactionProcessable({required String txHashKey, required bool isConfirmed}) {
    if (!_processingTransactions.containsKey(txHashKey)) {
      return true;
    }

    final processInfo = _processingTransactions[txHashKey]!;

    // 컨펌 여부가 다른 경우는 컨펌된 경우밖에 없음
    if (processInfo.isConfirmed != isConfirmed) {
      processInfo.setConfirmed();
      return true;
    }

    return false;
  }

  /// 트랜잭션의 처리를 시작합니다.
  void registerTransactionProcessing(int walletId, String txHash, bool isConfirmed) {
    final txHashKey = getTxHashKey(walletId, txHash);
    _processingTransactions[txHashKey] = TransactionProcessingState(
      isConfirmed,
      false,
    );
  }

  /// fetchUtxos 콜백 함수 등록
  void registerFetchUtxosCallback(String scriptKey, Future<void> Function() callback) {
    (_fetchUtxosCallback[scriptKey] ??= []).add(callback);
  }

  /// fetchTransactions 종료 후 반환된 트랜잭션 해시 목록을 기반으로 스크립트 종속성 등록.
  /// 만약 모든 트랜잭션이 처리 완료되었으면 스크립트 종속성 등록 없이 바로 fetchUtxos 함수 실행
  Future<void> registerTransactionDependency(
    WalletListItemBase walletItem,
    ScriptStatus status,
    List<String> txHashes,
  ) async {
    final scriptKey = getScriptKey(walletItem.id, status.derivationPath);

    // 모든 트랜잭션이 처리 완료되었으면 fetchUtxos 함수 실행
    if (areAllTransactionsCompleted(walletItem.id, txHashes)) {
      callFetchUtxosCallback(scriptKey);
      return;
    }

    final processingTxHashes = txHashes.where((txHash) {
      final txHashKey = getTxHashKey(walletItem.id, txHash);
      return !(_processingTransactions[txHashKey]?.isCompleted ?? false);
    }).toList();

    // 처리 중인 트랜잭션만 종속성으로 등록
    if (processingTxHashes.isNotEmpty) {
      _scriptDependency[scriptKey] = processingTxHashes;
      return;
    }
  }

  /// 트랜잭션의 처리를 완료 상태로 변경합니다.
  void registerTransactionCompletion(int walletId, Set<String> txHashes) {
    // 먼저 모든 트랜잭션 상태를 완료로 변경
    for (final txHash in txHashes) {
      final txHashKey = getTxHashKey(walletId, txHash);
      if (_processingTransactions.containsKey(txHashKey)) {
        _processingTransactions[txHashKey]!.setCompleted();
      }
    }

    // 모든 종속성 한 번에 처리
    _deleteTransactionDependencies(txHashes);
  }

  /// 여러 트랜잭션 해시에 대한 종속성을 일괄 제거
  void _deleteTransactionDependencies(Set<String> txHashes) {
    // 영향 받는 스크립트와 제거할 트랜잭션 매핑 생성
    final Map<String, List<String>> affectedScripts = {};

    for (final scriptKey in _scriptDependency.keys) {
      final deps = _scriptDependency[scriptKey];
      if (deps == null || deps.isEmpty) continue;

      // 이 스크립트에 영향을 주는 트랜잭션 목록
      final toRemove = deps.where(txHashes.contains).toList();
      if (toRemove.isNotEmpty) {
        affectedScripts[scriptKey] = toRemove;
      }
    }

    // 영향 받는 스크립트에서 트랜잭션 제거하고 콜백 호출
    for (final scriptKey in affectedScripts.keys) {
      final toRemove = affectedScripts[scriptKey]!;
      final deps = _scriptDependency[scriptKey]!;

      deps.removeWhere(toRemove.contains);

      // 종속성이 모두 제거되었다면 fetchUtxos 콜백 실행
      if (deps.isEmpty) {
        callFetchUtxosCallback(scriptKey);
      }
    }
  }

  /// fetchUtxos 콜백 함수 실행
  void callFetchUtxosCallback(String scriptKey) {
    final callbackList = _fetchUtxosCallback[scriptKey];
    if (callbackList == null) {
      return;
    }
    if (callbackList.isNotEmpty) {
      callbackList.first().then((_) {
        if (callbackList.isNotEmpty) {
          callbackList.removeAt(0);
        }
      });
    }
  }

  /// 모든 트랜잭션이 처리 완료되었는지 확인합니다.
  bool areAllTransactionsCompleted(int walletId, List<String> txHashes) {
    return txHashes.every((txHash) {
      final txHashKey = getTxHashKey(walletId, txHash);
      return _processingTransactions[txHashKey]?.isCompleted ?? false;
    });
  }
}
