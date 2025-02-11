import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/model/stream/base_stream_state.dart';

/// @nodoc
abstract class NodeClient {
  int gapLimit = 20;

  Future<String> broadcast(String rawTransaction);

  Future<int> getNetworkMinimumFeeRate();

  Future<BlockTimestamp> getLatestBlock();

  Future<String> getTransaction(String transactionHash);

  Future<List<Transaction>> getPreviousTransactions(
      Transaction transaction, List<Transaction> existingTxList);

  Future<RecommendedFee> getRecommendedFees();

  Future<WalletBalance> getBalance(WalletBase wallet,
      {int receiveUsedIndex = 0, int changeUsedIndex = 0});

  Stream<BaseStreamState<BlockTimestamp>> fetchBlocksByHeight(Set<int> heights);

  /// [knownTransactionHashes]: already confirmed transaction hashes
  Stream<BaseStreamState<FetchTransactionResponse>> fetchTransactions(
      WalletBase wallet,
      {Set<String>? knownTransactionHashes,
      int receiveUsedIndex = 0,
      int changeUsedIndex = 0});

  Stream<BaseStreamState<Transaction>> fetchTransactionDetails(
      Set<String> transactionHashes);

  Stream<BaseStreamState<UtxoState>> fetchUtxos(WalletBase wallet,
      {int receiveUsedIndex = 0, int changeUsedIndex = 0});

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
