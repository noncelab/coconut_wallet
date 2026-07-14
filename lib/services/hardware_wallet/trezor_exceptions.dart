class TrezorException implements Exception {
  final String code;
  final String message;

  const TrezorException(this.code, this.message);

  @override
  String toString() => 'TrezorException($code): $message';
}

class TrezorConnectException extends TrezorException {
  const TrezorConnectException(super.code, super.message);
}

class TrezorPairingException extends TrezorException {
  const TrezorPairingException(super.code, super.message);
}

class TrezorPairingCodeWrongException extends TrezorException {
  const TrezorPairingCodeWrongException(super.code, super.message);
}

class TrezorXPubException extends TrezorException {
  const TrezorXPubException(super.code, super.message);
}
