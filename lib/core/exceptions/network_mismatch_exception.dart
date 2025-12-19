class NetworkMismatchException implements Exception {
  final String message;

  NetworkMismatchException({String? message}) : message = message ?? 'Network mismatch';

  @override
  String toString() => message;
}
