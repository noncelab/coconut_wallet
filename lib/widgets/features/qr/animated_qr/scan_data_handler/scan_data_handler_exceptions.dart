/// 잘못된 QR 포맷의 데이터가 들어왔을 때 발생.
class InvalidQrFormatException implements Exception {
  final String message;
  InvalidQrFormatException([this.message = 'Invalid QR format']);

  @override
  String toString() => 'InvalidQrFormatException: $message';
}

/// 이전에 결정된 sequenceLength와 다른 값이 들어왔을 때 발생.
class SequenceLengthMismatchException implements Exception {
  final String message;
  SequenceLengthMismatchException([this.message = 'Sequence length mismatch']);

  @override
  String toString() => 'SequenceLengthMismatchException: $message';
}

/// sequenceLength가 아직 초기화되지 않은 상태에서 접근했을 때 발생.
class SequenceLengthNotInitializedException implements Exception {
  final String message;
  SequenceLengthNotInitializedException([this.message = 'Sequence length not initialized']);

  @override
  String toString() => 'SequenceLengthNotInitializedException: $message';
}
