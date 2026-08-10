import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';

abstract class ChainSource {
  //1. connect & close
  Future<bool> connect(String host, int port, {bool ssl = true});
  Future<void> close();
  void setOnConnectionLostCallback(void Function() callback);
  SocketConnectionStatus get connectionStatus;

  //2. block / chain
  Future<BlockHeaderSubscribe> getCurrentBlock();
  Future<BlockTimestamp> getBlockTimestamp(int height);
  Future<Map<int, BlockTimestamp>> fetchBlocksByHeight(Set<int> heights);

  //3. script query
  Future<GetBalanceRes> getBalance(AddressType addressType, String address);
  Future<List<GetTxHistoryRes>> getHistory(AddressType addressType, String address);
  Future<List<ListUnspentRes>> getUnspentList(AddressType addressType, String address);
  Future<String?> subscribeScript(
    AddressType addressType,
    String address, {
    required Function(String, String?) onUpdate,
  });
  Future<bool> unsubscribeScript(AddressType addressType, String address);

  //4. transaction
  Future<String> getTransaction(
    String txHash, {
    bool? verbose,
    Duration timeout = const Duration(seconds: 5),
  });
  Future<List<Transaction>> getPreviousTransactions(
    Transaction transaction, {
    List<Transaction>? existingTxList,
  });
  Future<String> broadcast(String rawTransaction);

  //5. fee
  Future<num> estimateFee(int targetConfirmation);
  Future<List<List<num>>> getMempoolFeeHistogram();
}
