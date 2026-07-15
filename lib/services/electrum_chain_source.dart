import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/chain_source.dart';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';

class ElectrumChainSource implements ChainSource {
  final ElectrumService _electrum;

  ElectrumChainSource(this._electrum);

  //1. connect & close
  @override
  Future<bool> connect(String host, int port, {bool ssl = true}) {
    return _electrum.connect(host, port, ssl: ssl);
  }

  @override
  Future<void> close() {
    return _electrum.close();
  }

  @override
  void setOnConnectionLostCallback(void Function() callback) {
    _electrum.setOnConnectionLostCallback(callback);
  }

  @override
  SocketConnectionStatus get connectionStatus {
    return _electrum.connectionStatus;
  }

  //2.block  / chain
  @override
  Future<BlockHeaderSubscribe> getCurrentBlock() {
    return _electrum.getCurrentBlock();
  }

  @override
  Future<BlockTimestamp> getBlockTimestamp(int height) {
    return _electrum.getBlockTimestamp(height);
  }

  @override
  Future<Map<int, BlockTimestamp>> fetchBlocksByHeight(Set<int> heights) {
    return _electrum.fetchBlocksByHeight(heights);
  }

  //3. script query
  @override
  Future<GetBalanceRes> getBalance(AddressType addressType, String address) {
    return _electrum.getBalance(addressType, address);
  }

  @override
  Future<List<GetTxHistoryRes>> getHistory(AddressType addressType, String address) {
    return _electrum.getHistory(addressType, address);
  }

  @override
  Future<List<ListUnspentRes>> getUnspentList(AddressType addressType, String address) {
    return _electrum.getUnspentList(addressType, address);
  }

  @override
  Future<String?> subscribeScript(
    AddressType addressType,
    String address, {
    required Function(String, String?) onUpdate,
  }) {
    return _electrum.subscribeScript(addressType, address, onUpdate: onUpdate);
  }

  @override
  Future<bool> unsubscribeScript(AddressType addressType, String address) {
    return _electrum.unsubscribeScript(addressType, address);
  }

  //4. transaction
  @override
  Future<String> getTransaction(
    String txHash, {
    bool? verbose,
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _electrum.getTransaction(txHash, verbose: verbose, timeout: timeout);
  }

  @override
  Future<List<Transaction>> getPreviousTransactions(
    Transaction transaction, {
    List<Transaction>? existingTxList,
  }) {
    return _electrum.getPreviousTransactions(transaction, existingTxList: existingTxList);
  }

  @override
  Future<String> broadcast(String rawTransaction) {
    return _electrum.broadcast(rawTransaction);
  }

  //5. fee
  @override
  Future<num> estimateFee(int targetConfirmation) {
    return _electrum.estimateFee(targetConfirmation);
  }

  @override
  Future<List<List<num>>> getMempoolFeeHistogram() {
    return _electrum.getMempoolFeeHistogram();
  }
}
