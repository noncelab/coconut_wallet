import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class PinKdfParameters {
  final int memory;
  final int iterations;
  final int parallelism;
  const PinKdfParameters({this.memory = 19456, this.iterations = 2, this.parallelism = 1});
  static const current = PinKdfParameters();
}

abstract interface class PinKdf {
  Future<Uint8List> derive(Uint8List pin, Uint8List salt, PinKdfParameters parameters);
}

/// Only bytes cross the isolate boundary; the caller and worker clear their owned buffers.
class Argon2PinKdf implements PinKdf {
  const Argon2PinKdf();

  @override
  Future<Uint8List> derive(Uint8List pin, Uint8List salt, PinKdfParameters parameters) {
    final payload = (pin, salt, parameters);
    return Isolate.run(() => _derive(payload));
  }

  static Future<Uint8List> _derive((Uint8List, Uint8List, PinKdfParameters) payload) async {
    final (pin, salt, parameters) = payload;
    final key = SecretKeyData(pin, overwriteWhenDestroyed: true);
    SecretKey? derived;
    try {
      derived = await Argon2id(
        memory: parameters.memory,
        iterations: parameters.iterations,
        parallelism: parameters.parallelism,
        hashLength: 32,
      ).deriveKey(secretKey: key, nonce: salt);
      return Uint8List.fromList(await derived.extractBytes());
    } finally {
      key.destroy();
      derived?.destroy();
      pin.fillRange(0, pin.length, 0);
      salt.fillRange(0, salt.length, 0);
    }
  }
}
