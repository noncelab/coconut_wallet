import 'dart:io';
import 'dart:typed_data';

class PayjoinHttpException implements Exception {
  const PayjoinHttpException(this.url, this.statusCode);

  final String url;
  final int statusCode;

  @override
  String toString() => 'Payjoin HTTP $statusCode from $url';
}

/// Posts an OHTTP-encapsulated request to a relay and returns the raw body.
///
/// A non-2xx status is an error so the caller can try another relay; the
/// directory's own replies (including "nothing yet") arrive inside a 200.
Future<Uint8List> postPayjoinRequest(
  String url,
  Uint8List body,
  String contentType, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.postUrl(Uri.parse(url)).timeout(timeout);
    request.headers.contentType = ContentType.parse(contentType);
    request.contentLength = body.length;
    request.add(body);
    final response = await request.close().timeout(timeout);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(timeout)) {
      bytes.add(chunk);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PayjoinHttpException(url, response.statusCode);
    }
    return bytes.toBytes();
  } finally {
    client.close(force: true);
  }
}
