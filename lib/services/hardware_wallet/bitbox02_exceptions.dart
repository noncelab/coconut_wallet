class BitBox02Exception implements Exception {
  final String code;
  final String message;

  const BitBox02Exception(this.code, this.message);

  @override
  String toString() => 'BitBox02Exception($code): $message';
}

class BitBox02ConnectException extends BitBox02Exception {
  const BitBox02ConnectException(super.code, super.message);
}

class BitBox02InitException extends BitBox02Exception {
  const BitBox02InitException(super.code, super.message);
}

class BitBox02SignException extends BitBox02Exception {
  const BitBox02SignException(super.code, super.message);
}

class BitBox02ConfigException extends BitBox02Exception {
  const BitBox02ConfigException(super.code, super.message);
}

class BitBox02DeviceNotFoundException extends BitBox02Exception {
  const BitBox02DeviceNotFoundException()
      : super('NO_DEVICE', 'BitBox02 Nova not found. Connect via USB or BLE.');
}
