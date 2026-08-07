import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:flutter/foundation.dart';

/// Fetches previous transaction hex for each PSBT input from Electrum
/// and delivers them to [onPrevTxHex] for hardware wallet injection.
///
/// Used by both Trezor and BitBox02 sign flows where the PSBT from
/// coconut_lib only contains WITNESS_UTXO (no NON_WITNESS_UTXO).
/// Hardware wallets require full previous transactions to verify
/// input amounts and prevent fee attacks.
class PrevTxFetcher {
  PrevTxFetcher._();

  /// Resolves the Electrum server from shared preferences (or defaults).
  static ({String host, int port, bool ssl}) _resolveElectrumServer() {
    final prefs = SharedPrefsRepository();
    final serverName = prefs.getString(SharedPrefKeys.kElectrumServerName);
    final customHost = prefs.getString(SharedPrefKeys.kCustomElectrumHost);
    final customPort = prefs.getInt(SharedPrefKeys.kCustomElectrumPort);
    final customSsl = prefs.getBool(SharedPrefKeys.kCustomElectrumIsSsl);

    if (serverName == 'CUSTOM') {
      return (host: customHost, port: customPort, ssl: customSsl);
    } else if (serverName.isNotEmpty) {
      final defServer = DefaultElectrumServer.fromServerType(serverName);
      return (host: defServer.server.host, port: defServer.server.port, ssl: defServer.server.ssl);
    }

    final net = NetworkType.currentNetworkType;
    final defServer = net == NetworkType.mainnet ? DefaultElectrumServer.coconut : DefaultElectrumServer.regtest;
    return (host: defServer.server.host, port: defServer.server.port, ssl: defServer.server.ssl);
  }

  /// Fetches raw transaction hex for every input in [psbtBase64] from
  /// Electrum and calls [onPrevTxHex] with (inputIndex, rawTxHex).
  ///
  /// Errors are logged but do not abort the loop — partial injection is
  /// better than none. The caller decides how to handle missing prev txs.
  static Future<void> fetchAndInject({
    required String psbtBase64,
    required Future<void> Function(int inputIndex, String rawTxHex) onPrevTxHex,
  }) async {
    try {
      final psbtParsed = Psbt.parse(psbtBase64);
      final unsignedTx = psbtParsed.unsignedTransaction;
      if (unsignedTx == null || unsignedTx.inputs.isEmpty) return;

      final server = _resolveElectrumServer();
      debugPrint('PREV_TX_FETCHER electrum: ${server.host}:${server.port} ssl=${server.ssl}');

      final electrum = ElectrumService();
      try {
        final connected = await electrum.connect(server.host, server.port, ssl: server.ssl);
        if (!connected) {
          debugPrint('PREV_TX_FETCHER electrum connect failed');
          return;
        }
        for (int i = 0; i < unsignedTx.inputs.length; i++) {
          final txid = unsignedTx.inputs[i].transactionHash;
          debugPrint('PREV_TX_FETCHER fetching prevtx[$i]: $txid');
          try {
            final rawTxHex = await electrum.getTransaction(txid);
            await onPrevTxHex(i, rawTxHex);
            debugPrint('PREV_TX_FETCHER prevtx[$i] loaded (${rawTxHex.length} chars)');
          } catch (e) {
            debugPrint('PREV_TX_FETCHER prevtx[$i] fetch failed: $e');
          }
        }
      } finally {
        await electrum.close();
      }
    } catch (e) {
      debugPrint('PREV_TX_FETCHER failed: $e');
    }
  }
}
