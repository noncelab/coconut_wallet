import 'dart:async';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:http/http.dart' as http;

class MempoolApi {
  final Uri _baseUrl;
  final http.Client _client;

  MempoolApi({http.Client? client}) : _client = client ?? http.Client(), _baseUrl = _resolveBaseUrl();

  static Uri _resolveBaseUrl() {
    final mempoolApi =
        NetworkType.currentNetworkType == NetworkType.mainnet
            ? 'https://mempool.space'
            : 'https://regtest-mempool.coconut.onl';
    return Uri.parse(mempoolApi);
  }

  Uri _uri(String path) => _baseUrl.replace(path: path);

  Future<String> fetchTxHex(String txid, {Duration timeout = const Duration(seconds: 15)}) async {
    _validateTxid(txid);

    final uri = _uri('/api/tx/$txid/hex');
    final res = await _client
        .get(uri, headers: {'Accept': 'text/plain', 'User-Agent': 'coconut-wallet/1.0'})
        .timeout(timeout);

    if (res.statusCode == 200) {
      final hex = res.body.trim();
      if (hex.isEmpty) throw Exception('Empty tx hex');
      return hex;
    }

    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  void close() => _client.close();

  void _validateTxid(String txid) {
    final ok = RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(txid);
    if (!ok) throw ArgumentError('Invalid txid: $txid');
  }
}
