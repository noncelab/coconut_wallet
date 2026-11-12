import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:dio/dio.dart';

/// Looks up any transaction on the block explorer's API (mempool's Esplora endpoints), for
/// transactions that aren't the wallet's own: an Ark server's offboard, whose inputs are the
/// server's coins. Coconut's node lookup can't describe those (it needs every script to be an
/// address the wallet knows how to encode; an offboard can carry an anchor output).
class MempoolTransactionService {
  MempoolTransactionService(this._explorerUrl);

  /// The block explorer's base URL, e.g. `BlockExplorerProvider.blockExplorerUrl`.
  final String _explorerUrl;
  final Dio _dio = Dio();

  /// The transaction as the transaction detail screen shows one: inputs and outputs with their
  /// addresses (or script type) and amounts, the fee, size and block. Throws when it can't be
  /// fetched.
  Future<TransactionRecord> fetch(String txid) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_explorerUrl/api/tx/$txid',
      options: Options(sendTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 8)),
    );
    final json = response.data!;
    TransactionAddress address(Map<String, dynamic>? output) => TransactionAddress(
      (output?['scriptpubkey_address'] ?? output?['scriptpubkey_type'] ?? '-') as String,
      (output?['value'] as num?)?.toInt() ?? 0,
    );
    final status = json['status'] as Map<String, dynamic>? ?? const {};
    final confirmed = status['confirmed'] == true;
    final blockTime = status['block_time'] as int?;
    return TransactionRecord.fromTransactions(
      transactionHash: txid,
      timestamp:
          confirmed && blockTime != null ? DateTime.fromMillisecondsSinceEpoch(blockTime * 1000) : DateTime.now(),
      blockHeight: confirmed ? (status['block_height'] as num?)?.toInt() ?? 0 : 0,
      transactionType: TransactionType.sent,
      amount: 0,
      fee: (json['fee'] as num?)?.toInt() ?? 0,
      inputAddressList: [
        for (final input in json['vin'] as List<dynamic>? ?? const [])
          address((input as Map<String, dynamic>)['prevout'] as Map<String, dynamic>?),
      ],
      outputAddressList: [
        for (final output in json['vout'] as List<dynamic>? ?? const []) address(output as Map<String, dynamic>),
      ],
      vSize: ((json['weight'] as num?)?.toDouble() ?? 0) / 4,
    );
  }
}
