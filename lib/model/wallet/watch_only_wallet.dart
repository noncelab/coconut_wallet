import 'dart:convert';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';

class WatchOnlyWallet {
  final String _name;
  final int _colorIndex;
  final int _iconIndex;
  late Descriptor _descriptor;
  int? _requiredSignatureCount;
  List<MultisigSigner>? _signers;

  WatchOnlyWallet(
    this._name,
    this._colorIndex,
    this._iconIndex,
    String descriptor,
    this._requiredSignatureCount,
    this._signers,
  ) {
    _descriptor = Descriptor.parse(descriptor);
  }

  String get name => _name;
  int get colorIndex => _colorIndex;
  int get iconIndex => _iconIndex;
  String get descriptor => _descriptor.serialize();
  String get scriptType => _descriptor.scriptType;
  int? get requiredSignatureCount => _requiredSignatureCount;
  List<MultisigSigner>? get signers => _signers;

  String toJson() {
    Map<String, dynamic> json = {
      'name': _name,
      'colorIndex': _colorIndex,
      'iconIndex': _iconIndex,
      'descriptor': _descriptor.serialize(),
      'requiredSignatureCount': _requiredSignatureCount,
      'signers': _signers,
    };
    return jsonEncode(json);
  }

  factory WatchOnlyWallet.fromJson(Map<String, dynamic> json) {
    return WatchOnlyWallet(
      json['name'],
      json['colorIndex'] ?? 0,
      json['iconIndex'] ?? 0,
      json['descriptor'],
      json['requiredSignatureCount'] ?? 0,
      json['signers'] != null
          ? (json['signers'] as List<dynamic>)
              .map((e) => MultisigSigner.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }
}
