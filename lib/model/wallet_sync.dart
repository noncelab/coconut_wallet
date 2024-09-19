import 'dart:convert';
import 'package:coconut_lib/coconut_lib.dart';

class WalletSync {
  final String _name;
  final int _colorIndex;
  final int _iconIndex;
  late Descriptor _descriptor;

  WalletSync(this._name, this._colorIndex, this._iconIndex, String descriptor) {
    _descriptor = Descriptor.parse(descriptor);
  }

  String get name => _name;
  int get colorIndex => _colorIndex;
  int get iconIndex => _iconIndex;
  String get descriptor => _descriptor.serialize();
  String get scriptType => _descriptor.scriptType;

  String toJson() {
    Map<String, dynamic> json = {
      'name': _name,
      'colorIndex': _colorIndex,
      'iconIndex': _iconIndex,
      'descriptor': _descriptor.serialize()
    };
    return jsonEncode(json);
  }

  factory WalletSync.fromJson(Map<String, dynamic> json) {
    return WalletSync(
      json['name'],
      json['colorIndex'],
      json['iconIndex'],
      json['descriptor'],
    );
  }
}
