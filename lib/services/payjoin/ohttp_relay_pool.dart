import 'dart:io' show InternetAddress;
import 'dart:math';
import 'dart:typed_data';

class NoOhttpRelayAvailableException implements Exception {
  const NoOhttpRelayAvailableException(this.lastError);

  final Object? lastError;

  @override
  String toString() => 'No OHTTP relay available (last error: $lastError)';
}

/// Every relay is run by the operator of [directoryUrl], so no request may go
/// to that directory. Unlike [NoOhttpRelayAvailableException] this does not
/// pass with time.
class NoIndependentRelayException implements Exception {
  const NoIndependentRelayException(this.directoryUrl);

  final String directoryUrl;

  @override
  String toString() => 'No OHTTP relay is run apart from the directory $directoryUrl';
}

/// Who runs the server at [url], as far as the URL can tell.
///
/// A relay sees the client's IP address and the directory sees which mailbox
/// it reads. One operator running both for the same session could link the
/// two, so a session's relay and directory must come from different
/// registrable domains (https://payjoin.org/mailroom).
///
/// The app has no public suffix list, so the registrable domain is taken to
/// be the host's last two labels. A registrable domain is a public suffix of
/// at least one label plus one more label, so two hosts in the same
/// registrable domain always share their last two labels: the rule never
/// treats one operator as two. It can treat two operators as one
/// (`a.co.uk` and `b.co.uk` both give `co.uk`), which only excludes a relay
/// that was safe to use.
///
/// An IP address stands for itself. A loopback host can only be a local test
/// setup, where one machine plays every operator, so each of its ports counts
/// as a separate operator.
String payjoinOperator(String url) {
  final uri = Uri.parse(url);
  var host = uri.host;
  if (host.endsWith('.')) host = host.substring(0, host.length - 1);
  final address = InternetAddress.tryParse(host);
  if (host == 'localhost' || (address?.isLoopback ?? false)) return '$host:${uri.port}';
  if (address != null) return address.address;
  final labels = host.split('.');
  return labels.length <= 2 ? host : labels.sublist(labels.length - 2).join('.');
}

/// Picks OHTTP relays for directory requests.
///
/// A relay is chosen at random for every request so no single relay sees all of
/// a session's traffic. A request never goes through a relay run by the
/// directory's own operator (see [payjoinOperator]). A relay that fails is
/// skipped until every eligible relay has failed, then all of them become
/// eligible again for the next attempt.
class OhttpRelayPool {
  OhttpRelayPool(List<String> relays, {Random? random})
    : _relays = List.unmodifiable(relays),
      _random = random ?? Random.secure() {
    if (_relays.isEmpty) {
      throw ArgumentError.value(relays, 'relays', 'at least one OHTTP relay is required');
    }
  }

  final List<String> _relays;
  final Random _random;
  final Set<String> _failed = {};

  List<String> get relays => _relays;
  Set<String> get failedRelays => Set.unmodifiable(_failed);

  /// Whether some relay is run apart from the operator of [directoryUrl].
  bool serves(String directoryUrl) => _apartFrom(directoryUrl).isNotEmpty;

  /// A random relay for a request to [directoryUrl] that has not failed, or
  /// null when all of them have. Throws [NoIndependentRelayException] when
  /// [serves] is false for that directory.
  String? choose(String directoryUrl) {
    final eligible = _apartFrom(directoryUrl);
    if (eligible.isEmpty) throw NoIndependentRelayException(directoryUrl);
    final remaining = eligible.where((relay) => !_failed.contains(relay)).toList();
    if (remaining.isEmpty) return null;
    return remaining[_random.nextInt(remaining.length)];
  }

  void markFailed(String relay) => _failed.add(relay);

  void clearFailed() => _failed.clear();

  List<String> _apartFrom(String directoryUrl) {
    final directoryOperator = payjoinOperator(directoryUrl);
    return _relays.where((relay) => payjoinOperator(relay) != directoryOperator).toList();
  }
}

/// An encapsulated request ready to post to a relay, plus the context needed
/// to decrypt its response.
class RelayRequest<C> {
  const RelayRequest({required this.url, required this.body, required this.contentType, required this.context});

  final String url;
  final Uint8List body;
  final String contentType;
  final C context;
}

typedef PayjoinHttpPost = Future<Uint8List> Function(String url, Uint8List body, String contentType);

/// Builds a fresh request to the session's [directoryUrl] for each relay
/// attempt and posts it, moving to another relay when one fails.
///
/// Each attempt needs its own request because OHTTP encapsulation is bound to
/// a single relay round trip. Errors thrown by [build] (for example an expired
/// session) are not relay failures and propagate to the caller unchanged.
Future<(Uint8List, C)> postViaRelay<C>(
  OhttpRelayPool pool,
  String directoryUrl,
  RelayRequest<C> Function(String relay) build,
  PayjoinHttpPost post,
) async {
  Object? lastError;
  while (true) {
    final relay = pool.choose(directoryUrl);
    if (relay == null) {
      // Let the next poll start from the full list again; a relay that was
      // down a moment ago may be back by then.
      pool.clearFailed();
      throw NoOhttpRelayAvailableException(lastError);
    }
    final request = build(relay);
    try {
      final response = await post(request.url, request.body, request.contentType);
      return (response, request.context);
    } catch (e) {
      lastError = e;
      pool.markFailed(relay);
    }
  }
}
