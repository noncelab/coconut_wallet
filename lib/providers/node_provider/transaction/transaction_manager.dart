import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_fetcher.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_processor.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_manager.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager_interface.dart';

/// NodeProvider의 트랜잭션 관련 기능을 담당하는 매니저 클래스
class TransactionManager {
  final ElectrumService _electrumService;
  final StateManagerInterface _stateManager;
  final TransactionRepository _transactionRepository;
  final UtxoManager _utxoManager;
  final AddressRepository _addressRepository;
  late final TransactionProcessor _transactionProcessor;
  late final TransactionFetcher _transactionFetcher;

  /// 트랜잭션 처리 상태를 추적하는 맵
  /// 키: 스크립트 고유 식별자(지갑ID + 경로), 값: 처리 완료 여부
  final Map<String, bool> _completedTransactions = {};

  /// 트랜잭션 처리 후 호출할 콜백 함수 맵
  /// 키: 스크립트 고유 식별자(지갑ID + 경로), 값: 콜백 함수 리스트
  final Map<String, List<Future<void> Function()>> _transactionCallbacks = {};

  TransactionManager(
    this._electrumService,
    this._stateManager,
    this._transactionRepository,
    this._utxoManager,
    this._addressRepository,
  ) {
    _transactionProcessor = TransactionProcessor(_electrumService, _addressRepository);
    _transactionFetcher = TransactionFetcher(
      _electrumService,
      _transactionRepository,
      _transactionProcessor,
      _stateManager,
      _utxoManager,
    );
  }

  /// 스크립트의 고유 식별자를 생성합니다.
  String _getScriptKey(WalletListItemBase walletItem, ScriptStatus scriptStatus) {
    return '${walletItem.id}:${scriptStatus.derivationPath}';
  }

  /// 특정 스크립트의 트랜잭션 처리가 완료되었는지 확인합니다.
  bool isTransactionProcessComplete(WalletListItemBase walletItem, ScriptStatus scriptStatus) {
    final scriptKey = _getScriptKey(walletItem, scriptStatus);
    return _completedTransactions[scriptKey] == true;
  }

  /// 트랜잭션 처리 후 실행할 콜백을 등록합니다.
  /// 이미 처리가 완료된 경우 즉시 콜백을 실행합니다.
  Future<void> registerTransactionCallback(
    WalletListItemBase walletItem,
    ScriptStatus scriptStatus,
    Future<void> Function() callback,
  ) async {
    final scriptKey = _getScriptKey(walletItem, scriptStatus);

    // 이미 처리가 완료된 경우 즉시 콜백 실행
    if (_completedTransactions[scriptKey] == true) {
      Logger.log('트랜잭션 처리가 완료된 경우 즉시 콜백 실행');
      await callback();
      return;
    }

    // 콜백 등록
    _transactionCallbacks.putIfAbsent(scriptKey, () => []).add(callback);
  }

  /// 콜백 실행 및 상태 업데이트
  Future<void> _executeCallbacks(String scriptKey) async {
    // 상태 업데이트
    _completedTransactions[scriptKey] = true;

    // 등록된 콜백이 있으면 실행
    Logger.log('트랜잭션 처리 완료 후 콜백 실행');
    if (_transactionCallbacks.containsKey(scriptKey)) {
      final callbacks = List<Future<void> Function()>.from(_transactionCallbacks[scriptKey]!);
      _transactionCallbacks.remove(scriptKey);

      await Future.wait(callbacks.map((callback) => callback())).catchError((e) {
        Logger.error('트랜잭션 콜백 실행 중 오류 발생: $e');
      });
    }
  }

  /// 특정 스크립트의 트랜잭션을 조회하고 업데이트합니다.
  Future<void> fetchScriptTransaction(
    WalletListItemBase walletItem,
    ScriptStatus scriptStatus, {
    DateTime? now,
    bool inBatchProcess = false,
  }) async {
    final scriptKey = _getScriptKey(walletItem, scriptStatus);

    // 트랜잭션 처리 시작 전 상태 초기화
    _completedTransactions[scriptKey] = false;

    await _transactionFetcher.fetchScriptTransaction(
      walletItem,
      scriptStatus,
      now: now,
      inBatchProcess: inBatchProcess,
      onComplete: () {
        _executeCallbacks(scriptKey);
      },
    );
  }

  /// 트랜잭션을 브로드캐스트합니다.
  Future<Result<String>> broadcast(Transaction signedTx) async {
    try {
      final txHash = await _electrumService.broadcast(signedTx.serialize());

      // 브로드캐스트 시간 기록
      _transactionRepository
          .recordTemporaryBroadcastTime(signedTx.transactionHash, DateTime.now())
          .catchError((e) {
        Logger.error(e);
      });

      return Result.success(txHash);
    } catch (e) {
      return Result.failure(ErrorCodes.broadcastErrorWithMessage(e.toString()));
    }
  }

  /// 특정 트랜잭션을 조회합니다.
  Future<Result<String>> getTransaction(String txHash) async {
    try {
      final tx = await _electrumService.getTransaction(txHash);
      return Result.success(tx);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }
}
