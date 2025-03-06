import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/services/network/electrum/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/model/response/subscribe_wallet_response.dart';
import 'package:coconut_wallet/services/model/stream/base_stream_state.dart';

/// @nodoc
abstract class NodeClient {
  int gapLimit = 20;

  Future<String> broadcast(String rawTransaction);

  Future<int> getNetworkMinimumFeeRate();

  Future<BlockTimestamp> getLatestBlock();

  Future<String> getTransaction(String transactionHash, {bool verbose = false});

  Future<List<Transaction>> getPreviousTransactions(
      Transaction transaction, List<Transaction> existingTxList);

  Future<RecommendedFee> getRecommendedFees();

  Future<
          (
            List<AddressBalance> receiveBalanceList,
            List<AddressBalance> changeBalanceList,
            Balance total
          )>
      getBalance(WalletBase wallet,
          {int receiveUsedIndex = -1, int changeUsedIndex = -1});

  Future<Map<int, BlockTimestamp>> getBlocksByHeight(Set<int> heights);

  Future<List<FetchTransactionResponse>> getFetchTransactionResponses(
      ScriptStatus scriptStatus, Set<String> knownTransactionHashes);

  Stream<BaseStreamState<Transaction>> fetchTransactions(
      Set<String> transactionHashes);

  Future<SubscribeWalletResponse> subscribeWallet(
      WalletListItemBase walletItem,
      StreamController<SubscribeScriptStreamDto> scriptStatusController,
      WalletProvider walletProvider);

  Future<bool> unsubscribeWallet(WalletListItemBase walletItem);

  void dispose();

  Future<List<UtxoState>> getUtxoStateList(ScriptStatus scriptStatus);

  Future<Balance> getAddressBalance(String script);
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
