import 'dart:convert';

import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_session_persister.dart';

enum PayjoinRole { send, receive }

/// Payjoin sessions stored in Realm.
///
/// Writes are synchronous so an event is committed before payjoin hands the
/// caller the state it produced.
class PayjoinSessionRepository extends BaseRepository implements PayjoinEventStore {
  PayjoinSessionRepository(super.realmManager);

  void create({required String id, required int walletId, required PayjoinRole role}) {
    realm.write(() {
      realm.add(RealmPayjoinSession(id, walletId, role.name, DateTime.now(), events: const []), update: false);
    });
  }

  RealmPayjoinSession? find(String id) => realm.find<RealmPayjoinSession>(id);

  List<RealmPayjoinSession> openSessions({PayjoinRole? role, int? walletId}) {
    final filters = ['isClosed == false'];
    final args = <Object>[];
    if (role != null) {
      filters.add('role == \$${args.length}');
      args.add(role.name);
    }
    if (walletId != null) {
      filters.add('walletId == \$${args.length}');
      args.add(walletId);
    }
    return realm.query<RealmPayjoinSession>('${filters.join(' AND ')} SORT(createdAt ASC)', args).toList();
  }

  @override
  List<String> loadEvents(String sessionId) => List.of(_require(sessionId).events);

  @override
  void appendEvent(String sessionId, String event) {
    final session = _require(sessionId);
    realm.write(() => session.events.add(event));
  }

  @override
  void markClosed(String sessionId) {
    final session = _require(sessionId);
    realm.write(() => session.isClosed = true);
  }

  @override
  String? readValue(String sessionId, String key) => _values(_require(sessionId))[key];

  @override
  void writeValue(String sessionId, String key, String value) {
    final session = _require(sessionId);
    final values = _values(session)..[key] = value;
    realm.write(() => session.valuesJson = jsonEncode(values));
  }

  /// Records [outpoint] as offered by a sender; true if it had been offered
  /// before.
  bool markInputSeen(String outpoint) {
    if (realm.find<RealmPayjoinSeenInput>(outpoint) != null) return true;
    realm.write(() => realm.add(RealmPayjoinSeenInput(outpoint)));
    return false;
  }

  RealmPayjoinSession _require(String sessionId) {
    final session = find(sessionId);
    if (session == null) throw StateError('No payjoin session $sessionId');
    return session;
  }

  Map<String, String> _values(RealmPayjoinSession session) =>
      (jsonDecode(session.valuesJson) as Map<String, dynamic>).cast<String, String>();
}
