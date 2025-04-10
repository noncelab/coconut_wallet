import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_manager.dart';
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
  final ScriptCallbackManager _scriptCallbackManager;
  late final TransactionProcessor _transactionProcessor;
  late final TransactionFetcher _transactionFetcher;

  TransactionManager(
    this._electrumService,
    this._stateManager,
    this._transactionRepository,
    this._utxoManager,
    this._addressRepository,
    this._scriptCallbackManager,
  ) {
    _transactionProcessor = TransactionProcessor(_electrumService, _addressRepository);
    _transactionFetcher = TransactionFetcher(_electrumService, _transactionRepository,
        _transactionProcessor, _stateManager, _utxoManager, _scriptCallbackManager);
  }

  /// 특정 스크립트의 트랜잭션을 조회하고 업데이트합니다.
  Future<List<String>> fetchScriptTransaction(
    WalletListItemBase walletItem,
    ScriptStatus scriptStatus, {
    DateTime? now,
    bool inBatchProcess = false,
  }) async {
    return _transactionFetcher.fetchScriptTransaction(
      walletItem,
      scriptStatus,
      now: now,
      inBatchProcess: inBatchProcess,
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
