import 'package:json_annotation/json_annotation.dart';

part 'electrum_response_types.g.dart';

class ElectrumResponse<T> {
  int? id;
  String? jsonrpc;
  T result;

  ElectrumResponse({required this.result, this.jsonrpc, this.id});
}

@JsonSerializable()
class ServerFeaturesRes {
  @JsonKey(name: 'server_version')
  String serverVersion;
  @JsonKey(name: 'genesis_hash')
  String genesisHash;
  @JsonKey(name: 'protocol_min')
  String protocolMin;
  @JsonKey(name: 'protocol_max')
  String protocolMax;
  @JsonKey(name: 'hash_function')
  String? hashFunction;
  @JsonKey(name: 'pruning')
  int? pruning;
  @JsonKey(name: 'hosts')
  Map<String, HostsPort> hosts;

  ServerFeaturesRes({
    required this.serverVersion,
    required this.genesisHash,
    required this.protocolMin,
    required this.protocolMax,
    required this.hosts,
    this.hashFunction,
    this.pruning,
  });

  factory ServerFeaturesRes.fromJson(Map<String, dynamic> json) =>
      _$ServerFeaturesResFromJson(json);
}

@JsonSerializable()
class HostsPort {
  @JsonKey(name: 'ssl_port')
  int? sslPort;
  @JsonKey(name: 'tcp_port')
  int? tcpPort;

  HostsPort({this.sslPort, this.tcpPort});

  factory HostsPort.fromJson(Map<String, dynamic> json) => _$HostsPortFromJson(json);
}

@JsonSerializable()
class GetHistoryRes {
  int height;
  @JsonKey(name: 'tx_hash')
  String txHash;

  GetHistoryRes({required this.height, required this.txHash});

  factory GetHistoryRes.fromJson(Map<String, dynamic> json) => _$GetHistoryResFromJson(json);

  @override
  bool operator ==(covariant GetHistoryRes other) {
    return txHash == other.txHash && height == other.height;
  }

  @override
  int get hashCode => Object.hash(txHash, height);
}

@JsonSerializable()
class GetMempoolRes {
  int height;
  @JsonKey(name: 'tx_hash')
  String txHash;
  int fee;

  GetMempoolRes({required this.height, required this.txHash, required this.fee});

  factory GetMempoolRes.fromJson(Map<String, dynamic> json) => _$GetMempoolResFromJson(json);
}

@JsonSerializable()
class ListUnspentRes {
  int height;
  @JsonKey(name: 'tx_hash')
  String txHash;
  @JsonKey(name: 'tx_pos')
  int txPos;
  int value;

  ListUnspentRes({
    required this.height,
    required this.txHash,
    required this.txPos,
    required this.value,
  });

  factory ListUnspentRes.fromJson(Map<String, dynamic> json) => _$ListUnspentResFromJson(json);
}

@JsonSerializable()
class GetBalanceRes {
  int confirmed;
  int unconfirmed;

  GetBalanceRes({
    required this.confirmed,
    required this.unconfirmed,
  });

  factory GetBalanceRes.fromJson(Map<String, dynamic> json) {
    return _$GetBalanceResFromJson(json);
  }
}

@JsonSerializable()
class BlockHeaderSubscribe {
  int height;
  String hex;

  BlockHeaderSubscribe({required this.height, required this.hex});

  factory BlockHeaderSubscribe.fromJson(Map<String, dynamic> json) {
    return _$BlockHeaderSubscribeFromJson(json);
  }
}
