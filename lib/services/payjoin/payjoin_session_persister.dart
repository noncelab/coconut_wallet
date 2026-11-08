import 'package:payjoin/payjoin.dart' as pj;

/// Durable storage for payjoin session event logs.
///
/// payjoin drives each session as a typestate machine and hands every
/// transition to a persister as a JSON event before the caller may act on the
/// new state. Replaying the stored events reconstructs the session, so an app
/// that is killed between two steps resumes exactly where it stopped.
abstract class PayjoinEventStore {
  List<String> loadEvents(String sessionId);

  /// Must be durable when it returns: payjoin acts on the next state only
  /// after the event that produced it has been saved.
  void appendEvent(String sessionId, String event);

  void markClosed(String sessionId);

  /// Small values the app keeps beside a session's events, such as the txid
  /// of the proposal it posted.
  String? readValue(String sessionId, String key);

  void writeValue(String sessionId, String key, String value);
}

class StoredReceiverSessionPersister implements pj.JsonReceiverSessionPersister {
  StoredReceiverSessionPersister(this._store, this.sessionId);

  final PayjoinEventStore _store;
  final String sessionId;

  @override
  void save(String event) => _store.appendEvent(sessionId, event);

  @override
  List<String> load() => _store.loadEvents(sessionId);

  @override
  void close() => _store.markClosed(sessionId);
}

class StoredSenderSessionPersister implements pj.JsonSenderSessionPersister {
  StoredSenderSessionPersister(this._store, this.sessionId);

  final PayjoinEventStore _store;
  final String sessionId;

  @override
  void save(String event) => _store.appendEvent(sessionId, event);

  @override
  List<String> load() => _store.loadEvents(sessionId);

  @override
  void close() => _store.markClosed(sessionId);
}

/// Keeps event logs in memory, for tests and for building a session before it
/// has an identity worth storing.
class InMemoryPayjoinEventStore implements PayjoinEventStore {
  final Map<String, List<String>> events = {};
  final Set<String> closed = {};
  final Map<String, Map<String, String>> values = {};

  @override
  List<String> loadEvents(String sessionId) => List.of(events[sessionId] ?? const []);

  @override
  void appendEvent(String sessionId, String event) => events.putIfAbsent(sessionId, () => []).add(event);

  @override
  void markClosed(String sessionId) => closed.add(sessionId);

  @override
  String? readValue(String sessionId, String key) => values[sessionId]?[key];

  @override
  void writeValue(String sessionId, String key, String value) => (values[sessionId] ??= {})[key] = value;
}
