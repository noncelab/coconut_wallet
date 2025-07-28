part of '../../electrum_service.dart';

abstract class _ElectrumRequest {
  String get method;
  dynamic get params;
}

// server.ping
class _PingReq extends _ElectrumRequest {
  @override
  String get method => 'server.ping';

  @override
  List<String> get params => [];
}

// server.features
class _FeatureReq extends _ElectrumRequest {
  @override
  String get method => 'server.features';

  @override
  List<String> get params => [];
}

// server.version
class _VersionReq extends _ElectrumRequest {
  @override
  String get method => 'server.version';

  @override
  List<dynamic> get params => [
        "coconut-wallet",
        ["1.4", "1.4"]
      ];
}

// blockchain.block.header
class _BlockchainBlockHeaderReq extends _ElectrumRequest {
  final int _height;

  _BlockchainBlockHeaderReq(this._height) {
    if (_height < 0) {
      throw Exception('Only numbers greater than 0 are available');
    }
  }

  @override
  String get method => 'blockchain.block.header';

  @override
  List<int> get params => [_height];
}

// blockchain.estimatefee
class _BlockchainEstimateFeeReq extends _ElectrumRequest {
  final int _targetConfirmation;

  _BlockchainEstimateFeeReq(this._targetConfirmation) {
    if (_targetConfirmation < 0) {
      throw Exception('Only numbers greater than 0 are available');
    }
  }

  @override
  String get method => 'blockchain.estimatefee';

  @override
  List<int> get params => [_targetConfirmation];
}

// blockchain.scripthash.get_balance
class _BlockchainScripthashGetBalanceReq extends _ElectrumRequest {
  final String _scriptHash;

  _BlockchainScripthashGetBalanceReq(this._scriptHash);

  @override
  String get method => 'blockchain.scripthash.get_balance';

  @override
  List<String> get params => [_scriptHash];
}

// blockchain.scripthash.get_history
class _BlockchainScripthashGetHistoryReq extends _ElectrumRequest {
  final String _scriptHash;

  _BlockchainScripthashGetHistoryReq(this._scriptHash);
  @override
  String get method => 'blockchain.scripthash.get_history';

  @override
  List<String> get params => [_scriptHash];
}

// blockchain.scripthash.get_mempool
class _BlockchainScripthashGetMempoolReq extends _ElectrumRequest {
  final String _scriptHash;

  _BlockchainScripthashGetMempoolReq(this._scriptHash);

  @override
  String get method => 'blockchain.scripthash.get_mempool';

  @override
  List<String> get params => [_scriptHash];
}

// blockchain.scripthash.listunspent
class _BlockchainScripthashListUnspentReq extends _ElectrumRequest {
  final String _scriptHash;

  _BlockchainScripthashListUnspentReq(this._scriptHash);
  @override
  String get method => 'blockchain.scripthash.listunspent';

  @override
  List<String> get params => [_scriptHash];
}

// blockchain.headers.subscribe
class _BlockchainHeadersSubscribeReq extends _ElectrumRequest {
  @override
  String get method => 'blockchain.headers.subscribe';

  @override
  List<String> get params => [];
}

// blockchain.scripthash.subscribe
class _BlockchainScripthashSubscribeReq extends _ElectrumRequest {
  final String _scriptHash;

  _BlockchainScripthashSubscribeReq(this._scriptHash);

  @override
  String get method => 'blockchain.scripthash.subscribe';

  @override
  List<String> get params => [_scriptHash];
}

// blockchain.scripthash.unsubscribe
class _BlockchainScripthashUnsubscribeReq extends _ElectrumRequest {
  final String _scriptHash;

  _BlockchainScripthashUnsubscribeReq(this._scriptHash);

  @override
  String get method => 'blockchain.scripthash.unsubscribe';

  @override
  List<String> get params => [_scriptHash];
}

// blockchain.transaction.broadcast
class _BroadcastReq extends _ElectrumRequest {
  final String _rawHexStringList;

  _BroadcastReq(this._rawHexStringList);

  @override
  String get method => 'blockchain.transaction.broadcast';

  @override
  get params => [_rawHexStringList];
}

// blockchain.transaction.get
class _BlockchainTransactionGetReq extends _ElectrumRequest {
  final String _txHash;
  final bool? _verbose;

  _BlockchainTransactionGetReq(this._txHash, {bool? verbose}) : _verbose = verbose;

  @override
  String get method => 'blockchain.transaction.get';

  @override
  List<dynamic> get params => _verbose == null ? [_txHash] : [_txHash, _verbose];
}

// mempool.get_fee_histogram
class _MempoolGetFeeHistogramReq extends _ElectrumRequest {
  _MempoolGetFeeHistogramReq();

  @override
  String get method => 'mempool.get_fee_histogram';

  @override
  get params => [];
}
