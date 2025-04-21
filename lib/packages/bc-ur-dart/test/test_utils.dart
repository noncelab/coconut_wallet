import 'dart:typed_data';
import 'package:ur/xoshiro256.dart';
import 'package:ur/cbor_lite.dart';
import 'package:ur/ur.dart';

Uint8List makeMessage(int length, {String seed = "Wolf"}) {
  var rng = Xoshiro256.fromString(seed);
  return rng.nextData(length);
}

UR makeMessageUR(int length, {String seed = "Wolf"}) {
  var message = makeMessage(length, seed: seed);
  var encoder = CBOREncoder();
  encoder.encodeBytes(message);

  return UR("bytes", encoder.getBytes());
}
