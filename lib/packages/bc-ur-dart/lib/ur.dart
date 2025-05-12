import 'dart:typed_data';
import 'package:ur/utils.dart';

class InvalidType implements Exception {
  String message;
  InvalidType([this.message = 'Invalid type']);
}

class UR {
  final String type;
  final Uint8List cbor;

  UR(this.type, this.cbor) {
    if (!isUrType(type)) {
      throw InvalidType();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UR && other.type == type && _listEquals(other.cbor, cbor);
  }

  @override
  int get hashCode => type.hashCode ^ cbor.hashCode;

  // Helper method to compare Uint8List
  bool _listEquals(Uint8List? a, Uint8List? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
