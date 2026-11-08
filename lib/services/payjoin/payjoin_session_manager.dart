import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/payjoin_session_repository.dart';
import 'package:coconut_wallet/services/payjoin/ohttp_relay_pool.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_config.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_receiver.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_send_attempt.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_sender.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_wallet_adapter.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

/// Keeps the app's payjoin sessions moving.
///
/// The app has no background execution, so sessions advance only while it is
/// in the foreground: receive sessions poll the directory every few seconds
/// and pick up where their event log left off after a restart. A send session
/// still open when the app starts lost the screen that was driving it; it is
/// settled by broadcasting its Original, which the receiver also accepts.
class PayjoinSessionManager extends ChangeNotifier {
  PayjoinSessionManager({
    required PayjoinSessionRepository sessions,
    required WalletProvider wallets,
    required NodeProvider node,
  }) : _sessions = sessions,
       _wallets = wallets,
       _node = node {
    _syncSubscription = node.syncStateStream.listen((state) {
      if (state == NodeSyncState.completed) _onSynced();
    });
    _lifecycle = AppLifecycleListener(onResume: _startPolling, onPause: _stopPolling);
  }

  final PayjoinSessionRepository _sessions;
  final WalletProvider _wallets;
  final NodeProvider _node;
  late final StreamSubscription<NodeSyncState> _syncSubscription;
  late final AppLifecycleListener _lifecycle;
  late final OhttpRelayPool _relays = OhttpRelayPool(PayjoinConfig.current.ohttpRelayUrls);

  final Map<String, PayjoinReceiveProgress> _progress = {};
  final Map<String, Object> _errors = {};
  final Set<String> _stepping = {};
  Timer? _timer;
  bool _synced = false;

  PayjoinReceiver get _receiver => PayjoinReceiver(
    store: _sessions,
    relays: _relays,
    directoryUrls: PayjoinConfig.current.directoryUrls,
    directoryCertificate: PayjoinConfig.current.directoryCertificate,
  )..onTransitionError = (sessionId, error) => Logger.error('Payjoin receive $sessionId refused: $error');

  PayjoinReceiveProgress? receiveProgress(String sessionId) => _progress[sessionId];

  Object? receiveError(String sessionId) => _errors[sessionId];

  /// The open receive session for [address], so the receive screen reuses
  /// it instead of opening another.
  String? openReceiveSession(int walletId, String address) {
    for (final session in _sessions.openSessions(role: PayjoinRole.receive, walletId: walletId)) {
      if (_sessions.readValue(session.id, _addressKey) == address) return session.id;
    }
    return null;
  }

  String pjUri(String sessionId) => _receiver.pjUri(sessionId);

  /// Opens a receive session paying [address] and returns its id.
  Future<String> startReceive({required int walletId, required String address, int? amountSats}) async {
    final sessionId = const Uuid().v4();
    _sessions.create(id: sessionId, walletId: walletId, role: PayjoinRole.receive);
    _sessions.writeValue(sessionId, _addressKey, address);
    try {
      await _receiver.begin(
        sessionId: sessionId,
        address: address,
        amountSats: amountSats,
        expiry: PayjoinConfig.sessionExpiry,
      );
    } catch (_) {
      _sessions.markClosed(sessionId);
      rethrow;
    }
    _progress[sessionId] = const PayjoinReceiveWaiting();
    notifyListeners();
    _startPolling();
    return sessionId;
  }

  /// Ends a receive session. If the sender's Original already arrived it is
  /// broadcast, since it pays this wallet.
  Future<void> cancelReceive(String sessionId) async {
    final session = _sessions.find(sessionId);
    if (session == null || session.isClosed) return;
    final fallback = _receiver.cancel(sessionId);
    final adapter = _adapter(session);
    try {
      if (fallback != null) await adapter.broadcast(fallback);
    } finally {
      await adapter.releaseReservedInput();
      _progress[sessionId] = PayjoinReceiveClosed(fallbackBroadcast: fallback != null);
      notifyListeners();
    }
  }

  void _onSynced() {
    if (!_synced) {
      _synced = true;
      unawaited(_settleOrphanedSends());
    }
    _startPolling();
  }

  void _startPolling() {
    if (!_synced) return;
    _timer ??= Timer.periodic(PayjoinConfig.pollInterval, (_) => _tick());
    _tick();
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    final open = _sessions.openSessions(role: PayjoinRole.receive);
    if (open.isEmpty) {
      _stopPolling();
      return;
    }
    for (final session in open) {
      if (!_stepping.add(session.id)) continue;
      unawaited(_stepReceive(session).whenComplete(() => _stepping.remove(session.id)));
    }
  }

  Future<void> _stepReceive(RealmPayjoinSession session) async {
    final sessionId = session.id;
    final adapter = _adapter(session);
    try {
      final progress = await _receiver.step(sessionId, adapter);
      _progress[sessionId] = progress;
      _errors.remove(sessionId);
      if (progress is PayjoinReceiveClosed && progress.payjoinTxid == null) {
        await adapter.releaseReservedInput();
      }
    } on NoOhttpRelayAvailableException catch (e) {
      // Relays come back; the next tick tries again.
      _errors[sessionId] = e;
    } on PayjoinNoInputToContribute catch (e) {
      // Nothing to add: take the sender's Original as is.
      Logger.log('Payjoin receive $sessionId: $e');
      await cancelReceive(sessionId);
    } catch (e, stack) {
      Logger.error('Payjoin receive $sessionId failed: $e\n$stack');
      _errors[sessionId] = e;
    }
    notifyListeners();
  }

  Future<void> _settleOrphanedSends() async {
    for (final session in _sessions.openSessions(role: PayjoinRole.send)) {
      final sessionId = session.id;
      if (_sessions.readValue(sessionId, PayjoinSendValues.broadcastTxid) == null) {
        final originalHex = _sessions.readValue(sessionId, PayjoinSendValues.originalTx);
        if (originalHex != null) {
          final result = await _node.broadcast(Transaction.parse(originalHex));
          // Already broadcast or spent by the payjoin: either way it is settled.
          Logger.log(
            'Payjoin send $sessionId settled with its Original: ${result.isSuccess ? result.value : result.error}',
          );
        }
      }
      PayjoinSender(store: _sessions, relays: _relays).cancel(sessionId);
      _sessions.markClosed(sessionId);
    }
  }

  WalletPayjoinReceiver _adapter(RealmPayjoinSession session) => WalletPayjoinReceiver(
    walletId: session.walletId,
    sessionId: session.id,
    wallets: _wallets,
    node: _node,
    sessions: _sessions,
  );

  static const _addressKey = 'address';

  @override
  void dispose() {
    _stopPolling();
    _syncSubscription.cancel();
    _lifecycle.dispose();
    super.dispose();
  }
}
