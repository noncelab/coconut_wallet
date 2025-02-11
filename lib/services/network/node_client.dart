import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/stream/base_stream_state.dart';
import 'package:coconut_wallet/utils/result.dart';

/// @nodoc
abstract class NodeClient {
  int gapLimit = 20;
  int get reqId;

  Future<Result<String, AppError>> broadcast(String rawTransaction);

  Future<Result<int, AppError>> getNetworkMinimumFeeRate();

  Future<Result<BlockTimestamp, AppError>> getLatestBlock();

  Future<Result<String, AppError>> getTransaction(String transactionHash);

  /// [knownTransactionHashes]: already confirmed transaction hashes
  Stream<BaseStreamState<FetchTransactionResponse>> fetchTransactions(
      WalletBase wallet,
      {Set<String>? knownTransactionHashes,
      int receiveUsedIndex = 0,
      int changeUsedIndex = 0});

  Stream<BaseStreamState<BlockTimestamp>> fetchBlocksByHeight(Set<int> heights);

  Future<Result<WalletBalance, AppError>> getBalance(WalletBase wallet,
      {int receiveUsedIndex = 0, int changeUsedIndex = 0});

  Stream<BaseStreamState<Transaction>> fetchTransactionDetails(
      Set<String> transactionHashes);

  Stream<BaseStreamState<UtxoState>> fetchUtxos(WalletBase wallet,
      {int receiveUsedIndex = 0, int changeUsedIndex = 0});

  Future<Result<List<Transaction>, AppError>> fetchPreviousTransactions(
      Transaction transaction, List<Transaction> existingTxList);

  void dispose();
}

/// Factory for creating NodeClient instances
abstract class NodeClientFactory {
  Future<NodeClient> create(String host, int port, {bool ssl = true});
}

/// Default implementation of NodeClientFactory that creates ElectrumApi instances
class ElectrumNodeClientFactory implements NodeClientFactory {
  @override
  Future<NodeClient> create(String host, int port, {bool ssl = true}) async {
    return ElectrumService.connectSync(host, port, ssl: ssl);
  }
}
