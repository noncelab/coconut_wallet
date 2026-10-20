import 'dart:async';
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:http/http.dart' as http;

class MempoolApi {
  final Uri _baseUrl;
  final http.Client _client;

  MempoolApi({http.Client? client}) : _client = client ?? http.Client(), _baseUrl = _resolveBaseUrl();

  static Uri _resolveBaseUrl() {
    final networkType = NetworkType.currentNetworkType;
    final mempoolApi =
        networkType == NetworkType.mainnet
            ? DEFAULT_EXPLORER_URL_MAINNET
            : networkType == NetworkType.testnet
            ? DEFAULT_EXPLORER_URL_TESTNET
            : DEFAULT_EXPLORER_URL_REGTEST;
    return Uri.parse(mempoolApi);
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

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

  Future<Map<String, dynamic>> fetchTx(String txid, {Duration timeout = const Duration(seconds: 15)}) async {
    _validateTxid(txid);

    final uri = _uri('/api/tx/$txid');
    final res = await _client
        .get(uri, headers: {'Accept': 'application/json', 'User-Agent': 'coconut-wallet/1.0'})
        .timeout(timeout);

    if (res.statusCode == 200) {
      final body = res.body.trim();
      if (body.isEmpty) throw Exception('Empty response');
      return Map<String, dynamic>.from(jsonDecode(body) as Map);
    }

    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  /// 출력마다 `{spent, txid?, vin?, status?}` (멤풀 자손 거래 찾기)
  Future<List<Map<String, dynamic>>> fetchOutspends(
    String txid, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _validateTxid(txid);

    final uri = _uri('/api/tx/$txid/outspends');
    final res = await _client
        .get(uri, headers: {'Accept': 'application/json', 'User-Agent': 'coconut-wallet/1.0'})
        .timeout(timeout);

    if (res.statusCode == 200) {
      final body = res.body.trim();
      if (body.isEmpty) throw Exception('Empty response');
      final decoded = jsonDecode(body);
      if (decoded is! List) throw const FormatException('Outspends must be a list');
      return [for (final e in decoded) _checkOutspend(e)];
    }

    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  /// 쓰였으면 쓴 거래 txid(64 hex)와 입력 번호가 있어야 한다. 아니면 FormatException(자손 조회 실패로 처리)
  static Map<String, dynamic> _checkOutspend(Object? entry) {
    if (entry is! Map || entry['spent'] is! bool) throw const FormatException('Invalid outspend');
    if (entry['spent'] == true) {
      final txid = entry['txid'], vin = entry['vin'];
      if (txid is! String || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(txid) || vin is! int || vin < 0) {
        throw const FormatException('Invalid outspend spender');
      }
    }
    return Map<String, dynamic>.from(entry);
  }

  void close() => _client.close();

  void _validateTxid(String txid) {
    final ok = RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(txid);
    if (!ok) throw ArgumentError('Invalid txid: $txid');
  }
}
