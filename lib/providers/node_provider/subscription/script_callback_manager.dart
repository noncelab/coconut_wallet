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
  final Map<String, Future<void> Function()> _fetchUtxosCallback =
      <String, Future<void> Function()>{};

  /// 현재 처리 중인 트랜잭션 해시와 처리 시작 시간을 추적하기 위한 맵
  /// key: "txHash", value: ({DateTime startTime, bool isConfirmed, bool isCompleted})
  final Map<String, TransactionProcessingState> _processingTransactions = {};

  /// 트랜잭션의 처리 가능 여부를 확인합니다.
  ///
  /// 다음 조건 중 하나라도 만족하면 `true`를 반환합니다:
  /// - 등록된 트랜잭션이 없는 경우
  /// - 트랜잭션 처리 타임아웃이 지난 경우
  /// - 트랜잭션이 언컨펌에서 컨펌 상태로 변경된 경우
  ///
  /// 위 조건을 만족하지 않으면 `false`를 반환합니다.
  bool isTransactionProcessable({required String txHash, required bool isConfirmed}) {
    if (!_processingTransactions.containsKey(txHash)) return true;

    final processInfo = _processingTransactions[txHash]!;

    if (processInfo.isProcessable()) {
      _processingTransactions.remove(txHash);
      return true;
    }

    // 컨펌 여부가 다른 경우는 컨펌된 경우밖에 없음
    if (processInfo.isConfirmed != isConfirmed) {
      processInfo.setConfirmed();
      return true;
    }

    return false;
  }

  /// 트랜잭션의 처리를 시작합니다.
  void registerTransactionProcessing(String txHash, bool isConfirmed) {
    _processingTransactions[txHash] = TransactionProcessingState(
      DateTime.now(),
      isConfirmed,
      false,
    );
  }

  /// fetchUtxos 콜백 함수 등록
  void registerFetchUtxosCallback(String scriptKey, Future<void> Function() callback) {
    _fetchUtxosCallback[scriptKey] = callback;
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
    if (areAllTransactionsCompleted(txHashes)) {
      callFetchUtxosCallback(scriptKey);
      return;
    }

    final processingTxHashes = txHashes
        .where((txHash) => !(_processingTransactions[txHash]?.isCompleted ?? false))
        .toList();

    // 처리 중인 트랜잭션만 종속성으로 등록
    if (processingTxHashes.isNotEmpty) {
      _scriptDependency[scriptKey] = processingTxHashes;
      return;
    }
  }

  /// 트랜잭션의 처리를 완료 상태로 변경합니다.
  void registerTransactionCompletion(String txHash) {
    if (_processingTransactions.containsKey(txHash)) {
      _processingTransactions[txHash]!.setCompleted();
    }
  }

  /// 모든 스크립트 종속성에서 해당 트랜잭션 해시를 제거
  void deleteTransactionDependency(String txHash) {
    for (final scriptKey in _scriptDependency.keys.toList()) {
      if (_scriptDependency[scriptKey]?.contains(txHash) ?? false) {
        _scriptDependency[scriptKey]?.remove(txHash);

        // 종속성이 모두 제거되었다면 fetchUtxos 콜백 실행
        if (_scriptDependency[scriptKey]?.isEmpty ?? false) {
          callFetchUtxosCallback(scriptKey);
        }
      }
    }
  }

  /// fetchUtxos 콜백 함수 실행
  void callFetchUtxosCallback(String scriptKey) {
    final callback = _fetchUtxosCallback[scriptKey];
    if (callback != null) {
      callback();
      _fetchUtxosCallback.remove(scriptKey);
    }
  }

  /// 모든 트랜잭션이 처리 완료되었는지 확인합니다.
  bool areAllTransactionsCompleted(List<String> txHashes) {
    return txHashes.every((txHash) => _processingTransactions[txHash]?.isCompleted ?? false);
  }
}
