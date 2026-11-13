import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_lib/coconut_lib.dart' show NetworkType;
import 'package:collection/collection.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/notification/local_notification_service.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'dart:async';

import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/model/ark/ark_balance.dart';
import 'package:coconut_wallet/model/ark/ark_board.dart';
import 'package:coconut_wallet/model/ark/ark_exit.dart';
import 'package:coconut_wallet/model/ark/ark_fee_guide.dart';
import 'package:coconut_wallet/model/ark/ark_lightning_invoice.dart';
import 'package:coconut_wallet/model/ark/ark_movement.dart';
import 'package:coconut_wallet/model/ark/ark_payment.dart';
import 'package:coconut_wallet/model/ark/ark_refresh_due.dart';
import 'package:coconut_wallet/model/ark/ark_snapshot.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/ark_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/ark/ark_wallet_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/payment_request_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// The Ark (bark) side of hot wallets, for the UI.
///
/// - Screens read the Realm cache ([snapshot]), so balances, VTXOs and history show while a hot
///   wallet is locked.
/// - 아크는 사용자가 켠 핫월렛에만 있음([turnOn], [turnOff]). 켬 여부는 bark 데이터 폴더 유무로 판단
/// - A hot wallet's Ark wallet is opened once per app session ([open]), after the UI has unlocked
///   its seed, and stays open until the process ends. Wallets created or restored this session
///   are already open.
/// - 포그라운드에서 열린 지갑을 [syncInterval]마다, 결제를 기다리는 화면에서는 [fastSyncInterval]마다
///   동기화. 만료 [ArkRefreshDue.noticeBlocks] 전부터 [refreshDue]로 알리고 사용자 승인 후 [refreshDelegated].
///   bark 갱신 기한까지 갱신하지 않았고 자동 갱신에 동의한 지갑만 자금 보호를 위해 자동 갱신
class ArkProvider extends ChangeNotifier {
  ArkProvider(
    this._walletProvider,
    this._arkRepository, {
    ArkWalletService? arkWalletService,
    SharedPrefsRepository? sharedPrefsRepository,
    ValueListenable<BlockTimestamp?>? currentBlock,
    LocalNotificationService? notifications,
    this.syncInterval = const Duration(seconds: 60),
    this.fastSyncInterval = const Duration(seconds: 5),
    bool startTimer = true,
  }) : _currentBlock = currentBlock,
       _notifications = notifications,
       _arkWalletService = arkWalletService ?? ArkWalletService(),
       _sharedPrefs = sharedPrefsRepository ?? SharedPrefsRepository() {
    _walletProvider.walletItemListNotifier.addListener(_onWalletListChanged);
    _currentBlock?.addListener(_onCurrentBlockChanged);
    _walletProvider.setOffchainBalanceSource(totalSats);
    _walletProvider.setOffchainMovementsSource((walletId) => supportsArkById(walletId) ? movements(walletId) : null);
    cacheRevision.addListener(_walletProvider.notifyOffchainBalanceChanged);
    if (isEnabled) arkWalletsLoaded = _loadArkWallets();
    if (startTimer && isEnabled) _startTimer();
  }

  final WalletProvider _walletProvider;
  final ArkRepository _arkRepository;
  final ArkWalletService _arkWalletService;
  final SharedPrefsRepository _sharedPrefs;
  final Duration syncInterval;
  final Duration fastSyncInterval;

  /// Bumped whenever cached Ark data changes, for screens that show balances or history. Unlike
  /// [notifyListeners], it doesn't fire for sync progress.
  final ValueNotifier<int> cacheRevision = ValueNotifier(0);

  final Map<int, ArkSnapshot?> _snapshots = {};
  final Map<int, Future<bool>> _opening = {};
  final Map<int, DateTime> _lastSync = {};
  final Map<int, ArkRefreshDue> _refreshDue = {};

  /// 앱이 꺼져 있어도 만료 전에 알리는 로컬 알림, 테스트 등에서는 없음
  final LocalNotificationService? _notifications;
  final Map<int, String> _scheduledExpiryKeys = {};
  static const _expiryNotificationIdBase = 72000;
  static const arkExpiryPayloadPrefix = 'ark_expiry:';

  /// 만료까지 남은 블록 계산에 쓰는 현재 블록, 노드 동기화가 갱신함
  final ValueListenable<BlockTimestamp?>? _currentBlock;
  final Set<String> _arkOnFingerprints = {};

  /// 아크를 켠 지갑 목록을 다 읽었을 때 완료
  Future<void> arkWalletsLoaded = Future.value();

  /// 갱신을 요청한 VTXO와 요청 시각, 새 VTXO로 바뀌거나 [_refreshWaitLimit]이 지나면 지움
  late final Map<String, DateTime> _refreshingVtxoIds = _loadRefreshingVtxoIds();
  static const _refreshWaitLimit = Duration(minutes: 10);

  /// 갱신을 요청했지만 서버 처리가 끝나지 않고 대기에서 빠진 VTXO
  final Set<String> _failedRefreshVtxoIds = {};

  bool isRefreshFailedVtxo(String vtxoId) => _failedRefreshVtxoIds.contains(vtxoId);

  /// bark가 알려 주는 지갑별 라운드 대기 VTXO
  final Map<int, Set<String>> _pendingRoundVtxoIds = {};

  /// 갱신을 기다리던 VTXO가 새 VTXO로 바뀌지 않고 대기에서 빠졌을 때(서버 처리 실패)
  final ValueNotifier<({int walletId, int count})?> refreshIncomplete = ValueNotifier(null);
  final Set<int> _autoRefreshing = {};
  final Map<int, String> _syncErrors = {};
  final Set<int> _declined = {};
  final Set<int> _syncing = {};
  final Set<int> _syncAgain = {};
  final Map<int, ArkBoardFunding> _boardFunding = {};
  ArkBoardTerms? _boardTerms;
  final Map<int, int> _fastSync = {};

  /// 아크 서버 동기화가 연속으로 실패하기 시작한 시각
  final Map<int, DateTime> _syncFailingSince = {};

  /// 서버가 이만큼 연속으로 응답하지 않으면 직접 출금 진입점을 보여 줌(regtest는 시험용으로 짧게)
  static Duration get serverDownNoticeAfter =>
      NetworkType.currentNetworkType == NetworkType.regtest ? const Duration(minutes: 1) : const Duration(minutes: 30);

  /// 아크 서버가 [serverDownNoticeAfter] 넘게 계속 응답하지 않는지
  bool isServerDown(int walletId) {
    final since = _syncFailingSince[walletId];
    return since != null && DateTime.now().difference(since) >= serverDownNoticeAfter;
  }

  /// 보내기 실패나 직접 출금 화면에서 서버에 닿는지 바로 확인. 닿지 않으면 서버 장애가 시작된 것으로 기록
  Future<bool> isServerReachable(int walletId) async {
    final reachable = await _canReachServer();
    if (reachable) {
      _syncFailingSince.remove(walletId);
    } else {
      _syncFailingSince.putIfAbsent(walletId, DateTime.now);
    }
    _notify();
    return reachable;
  }

  /// 아크 서버 주소로 직접 연결해 응답이 오는지 봄(연결만 받고 멈춘 서버도 걸러 냄)
  static Future<bool> _canReachServer() async {
    final uri = Uri.tryParse(CoconutWalletApp.kArkServerUrl);
    if (uri == null || uri.host.isEmpty) return true;
    Socket? socket;
    try {
      const limit = Duration(seconds: 5);
      socket =
          uri.scheme == 'https'
              ? await SecureSocket.connect(uri.host, uri.port, timeout: limit)
              : await Socket.connect(uri.host, uri.port, timeout: limit);
      socket.write('HEAD / HTTP/1.1\r\nHost: ${uri.host}\r\nConnection: close\r\n\r\n');
      await socket.first.timeout(limit);
      return true;
    } catch (error) {
      Logger.error('ArkProvider: Ark server unreachable: $error');
      return false;
    } finally {
      socket?.destroy();
    }
  }

  /// 진행 중인 직접 출금이 있는지(시작한 세션이 끝나지 않았거나 bark 출금 내역이 끝나지 않음)
  bool hasPendingDirectExit(int walletId) =>
      (exitSession(walletId)?.isActive ?? false) ||
      (snapshot(walletId)?.movements ?? const []).any(
        (movement) => movement.subsystemName == 'bark.exit' && movement.status == ArkMovementStatus.pending,
      );

  late final Map<int, ArkExitSession> _exitSessions = _loadExitSessions();
  final Set<int> _advancingExits = {};
  final Map<int, DateTime> _lastExitAdvance = {};
  static const _exitAdvanceInterval = Duration(seconds: 15);
  static const _exitNotificationIdBase = 73000;
  static const arkExitPayloadPrefix = 'ark_exit:';
  final Map<int, ({int done, int total})> _exitTxProgress = {};

  /// 올릴 출금 거래 중 확정된 수, 남은 거래마다 블록 하나쯤 걸림
  ({int done, int total, Duration remaining})? exitTxProgress(int walletId) {
    final progress = _exitTxProgress[walletId];
    if (progress == null || progress.total == 0) return null;
    return (
      done: progress.done,
      total: progress.total,
      remaining: _blockInterval * max(1, progress.total - progress.done),
    );
  }

  /// 확인을 마친 직접 출금, 내역에서 관련 거래를 묶어 보여 주려고 남김
  late final List<ArkExitSession> _exitHistory = _loadExitHistory();

  /// [txid]가 딸린 아크 출금 내역
  ArkMovement? exitMovementForTxid(int walletId, String txid) => movements(walletId).firstWhereOrNull(
    (movement) =>
        movement.kind == ArkMovementKind.exit &&
        (movement.exitClaimTxid == txid || movement.exitRelatedTxids.contains(txid)),
  );

  /// 지갑의 아크 내역. 직접 출금에는 앱이 기록한 온체인 거래를 붙임
  List<ArkMovement> movements(int walletId) {
    final recorded = snapshot(walletId)?.movements ?? const <ArkMovement>[];
    final inFlight = _inFlightMovements(walletId, recorded);
    final movements = inFlight.isEmpty ? recorded : [...inFlight, ...recorded];
    final exits = [
      if (_exitSessions[walletId] case final active?) active,
      ..._exitHistory.where((session) => session.walletId == walletId),
    ];
    if (exits.isEmpty) return movements;
    ArkMovement attach(ArkMovement movement) {
      if (movement.kind != ArkMovementKind.exit) return movement;
      final exit = exits.firstWhereOrNull(
        (exit) => exit.vtxoIds.any((id) => movement.inputVtxoIds.contains(id) || movement.exitedVtxoIds.contains(id)),
      );
      return exit == null
          ? movement
          : movement.withExitTxids(
            claimTxid: exit.claimTxid,
            relatedTxids: exit.relatedTxids,
            destination: exit.destination,
          );
    }

    return [for (final movement in movements) attach(movement)];
  }

  /// 지갑의 직접 출금 세션, 완료·실패 후 사용자가 확인할 때까지 남김
  ArkExitSession? exitSession(int walletId) => _exitSessions[walletId];

  int? get _tipHeight => _currentBlock?.value?.height ?? _walletProvider.currentBlockHeightNotifier.value?.height;

  /// 받을 수 있게 될 때까지 남은 블록
  int? exitBlocksLeft(int walletId) {
    final claimable = exitSession(walletId)?.claimableHeight;
    final tip = _tipHeight;
    if (claimable == null || tip == null) return null;
    return max(0, claimable - tip);
  }

  /// 받을 수 있게 될 예상 시각
  DateTime? exitClaimableAt(int walletId) {
    final blocks = exitBlocksLeft(walletId);
    return blocks == null ? null : DateTime.now().add(_blockInterval * blocks);
  }

  /// 수수료 준비 거래를 보낸 뒤 호출. 그 거래가 확정되면 출금을 시작함
  Future<void> beginDirectExit(ArkExitSession session) async {
    _exitSessions[session.walletId] = session;
    await _saveExitSessions();
    _notify();
    unawaited(_advanceExit(session.walletId));
  }

  /// 끝난 출금 기록을 지움
  Future<void> dismissDirectExit(int walletId) async {
    final session = _exitSessions[walletId];
    if (session == null || session.isActive) return;
    _exitSessions.remove(walletId);
    _exitHistory.add(session);
    await _saveExitSessions();
    _notify();
  }

  Future<void> _advanceExit(int walletId) async {
    final session = _exitSessions[walletId];
    final fingerprint = _fingerprint(walletId);
    if (session == null || fingerprint == null || !_arkWalletService.isOpen(fingerprint)) return;
    if (!_exitNeedsFollowUp(walletId, session)) return;
    if (!_advancingExits.add(walletId)) return;
    _lastExitAdvance[walletId] = DateTime.now();
    try {
      final next = await _nextExitState(fingerprint, session);
      if (identical(next, session) || _exitSessions[walletId] != session) return;
      _exitSessions[walletId] = next;
      await _saveExitSessions();
      await _scheduleExitNotification(next);
      cacheRevision.value++;
    } catch (error) {
      Logger.error('ArkProvider: direct exit of wallet $walletId did not advance: $error');
    } finally {
      _advancingExits.remove(walletId);
      _notify();
    }
  }

  Future<ArkExitSession> _nextExitState(String fingerprint, ArkExitSession session) async {
    final tip = _tipHeight;
    final expired = tip != null && session.firstExpiryHeight != null && tip >= session.firstExpiryHeight!;
    switch (session.phase) {
      case ArkExitPhase.funding:
        if (expired) return _returnExitFee(fingerprint, _failExit(session, ArkExitFailure.expired));
        final balance = await _arkWalletService.exitFeeBalance(fingerprint);
        if (balance.confirmedSats < session.fundingSats) return session;
        await _arkWalletService.startExit(fingerprint, session.vtxoIds);
        return _progressExit(fingerprint, session.copyWith(phase: ArkExitPhase.exiting), expired);
      case ArkExitPhase.exiting:
      case ArkExitPhase.waiting:
        return _progressExit(fingerprint, session, expired);
      case ArkExitPhase.claiming:
        return _claimExit(fingerprint, session);
      case ArkExitPhase.done:
        // bark는 받은 거래가 확정된 뒤 출금 상태를 다시 읽어야 출금 내역을 끝냄
        await _arkWalletService.progressExits(fingerprint, feeRateSatPerVb: session.feeRateSatPerVb);
        unawaited(syncNow(session.walletId, withRounds: false));
        return _returnExitFee(fingerprint, session);
      case ArkExitPhase.failed:
        return _returnExitFee(fingerprint, session);
    }
  }

  Future<ArkExitSession> _progressExit(String fingerprint, ArkExitSession session, bool expired) async {
    final statuses = await _arkWalletService.progressExits(fingerprint, feeRateSatPerVb: session.feeRateSatPerVb);
    for (final status in statuses) {
      if (status.error != null) Logger.error('ArkProvider: exit of ${status.vtxoId}: ${status.error}');
    }
    final exits = {for (final exit in await _arkWalletService.exitVtxos(fingerprint)) exit.vtxoId: exit};
    final mine = [for (final id in session.vtxoIds) exits[id]];
    final txs = [
      for (final exit in mine)
        if (exit?.state case final bark.ProcessingExitState processing) ...processing.transactions,
    ];
    _exitTxProgress[session.walletId] = (
      done: txs.where((tx) => tx.status is bark.ConfirmedExitTxStatus).length,
      total: txs.length,
    );
    if (mine.any((exit) => exit?.state is bark.VtxoAlreadySpentExitState || exit?.state is bark.CanceledExitState)) {
      return _returnExitFee(fingerprint, _failExit(session, ArkExitFailure.spent));
    }
    final onChain = mine.every(
      (exit) =>
          exit != null &&
          (exit.state is bark.AwaitingDeltaExitState ||
              exit.state is bark.ClaimableExitState ||
              exit.state is bark.ClaimInProgressExitState ||
              exit.state is bark.ClaimedExitState),
    );
    // 출금 거래가 확정되기 전에 만료되면 서버가 회수함. bark는 이를 실패로 기록하지 않음
    if (!onChain) {
      return expired ? _returnExitFee(fingerprint, _failExit(session, ArkExitFailure.expired)) : session;
    }
    if (mine.every((exit) => exit!.isClaimable)) {
      return _claimExit(fingerprint, session.copyWith(phase: ArkExitPhase.claiming));
    }
    final claimableHeight = await _arkWalletService.exitsClaimableAtHeight(fingerprint);
    if (session.phase == ArkExitPhase.waiting && session.claimableHeight == claimableHeight) return session;
    return session.copyWith(phase: ArkExitPhase.waiting, claimableHeight: claimableHeight);
  }

  Future<ArkExitSession> _claimExit(String fingerprint, ArkExitSession session) async {
    final claim = await _arkWalletService.claimExits(
      fingerprint,
      session.destination,
      feeRateSatPerVb: session.feeRateSatPerVb,
    );
    final claimed = session.copyWith(
      phase: ArkExitPhase.done,
      claimTxid: claim.txid,
      receivedSats: session.amountSats - claim.feeSats,
    );
    try {
      return await _returnExitFee(fingerprint, claimed);
    } catch (error) {
      Logger.error('ArkProvider: claimed, but the leftover exit fee was not returned yet: $error');
      return claimed;
    }
  }

  bool _exitNeedsFollowUp(int walletId, ArkExitSession session) =>
      session.isActive ||
      !session.feeReturned ||
      (session.phase == ArkExitPhase.done &&
          (snapshot(walletId)?.movements ?? const []).any(
            (movement) => movement.subsystemName == 'bark.exit' && movement.status == ArkMovementStatus.pending,
          ));

  ArkExitSession _failExit(ArkExitSession session, ArkExitFailure failure) =>
      session.copyWith(phase: ArkExitPhase.failed, failure: failure);

  /// 남은 수수료를 받을 주소로 돌려보냄. 수수료 지갑에 미확정 거래가 있으면 다음에 다시
  Future<ArkExitSession> _returnExitFee(String fingerprint, ArkExitSession session) async {
    if (session.feeReturned) return session;
    final balance = await _arkWalletService.exitFeeBalance(fingerprint);
    if (balance.pendingSats > 0) return session;
    final txid = await _arkWalletService.returnExitFeeFunds(fingerprint, session.destination, session.feeRateSatPerVb);
    Logger.log('ArkProvider: leftover exit fee returned: ${txid ?? 'nothing to return'}');
    return session.copyWith(feeReturned: true, feeReturnTxid: txid);
  }

  Future<void> _scheduleExitNotification(ArkExitSession session) async {
    final notifications = _notifications;
    if (notifications == null) return;
    final id = _exitNotificationIdBase + session.walletId;
    try {
      await notifications.cancel(id);
      final at = exitClaimableAt(session.walletId);
      if (session.phase != ArkExitPhase.waiting || at == null || !at.isAfter(DateTime.now())) return;
      await notifications.schedule(
        id: id,
        channelId: 'ark_exit',
        channelName: t.ark.exit.notification_channel,
        channelDescription: t.ark.exit.notification_channel_description,
        title: t.ark.exit.notification_title,
        body: t.ark.exit.notification_body(wallet: _findWallet(session.walletId)?.name ?? ''),
        payload: '$arkExitPayloadPrefix${session.walletId}',
        at: at,
      );
    } catch (error) {
      Logger.error('ArkProvider: failed to schedule the exit notification of wallet ${session.walletId}: $error');
    }
  }

  Map<int, ArkExitSession> _loadExitSessions() {
    try {
      final raw = _sharedPrefs.getStringOrNull(SharedPrefKeys.kArkExitSessions);
      if (raw == null || raw.isEmpty) return {};
      final sessions = [
        for (final json in jsonDecode(raw) as List) ArkExitSession.fromJson(json as Map<String, dynamic>),
      ];
      return {for (final session in sessions) session.walletId: session};
    } catch (_) {
      return {};
    }
  }

  List<ArkExitSession> _loadExitHistory() {
    try {
      final raw = _sharedPrefs.getStringOrNull(SharedPrefKeys.kArkExitHistory);
      if (raw == null || raw.isEmpty) return [];
      return [for (final json in jsonDecode(raw) as List) ArkExitSession.fromJson(json as Map<String, dynamic>)];
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveExitSessions() async {
    try {
      await _sharedPrefs.setStringAndConfirm(
        SharedPrefKeys.kArkExitSessions,
        jsonEncode([for (final session in _exitSessions.values) session.toJson()]),
      );
      await _sharedPrefs.setStringAndConfirm(
        SharedPrefKeys.kArkExitHistory,
        jsonEncode([for (final session in _exitHistory) session.toJson()]),
      );
    } catch (error) {
      Logger.error('ArkProvider: failed to save direct exits: $error');
    }
  }

  /// 만든 인보이스가 결제되면 바로 수령하도록, 지갑별로 기다리는 결제 해시와 기한
  final Map<int, Map<String, DateTime>> _awaitedInvoices = {};
  static const _invoiceWatch = Duration(hours: 1);
  Timer? _timer;
  bool _isForeground = true;
  bool _disposed = false;

  bool get isEnabled => _arkWalletService.isEnabled;

  /// 아크를 켤 수 있는 지갑(핫월렛)
  bool canUseArk(WalletItemBase wallet) => isEnabled && wallet.hasLocalKey && wallet.hotWalletMetadata != null;

  /// 아크를 켠 지갑
  bool supportsArk(WalletItemBase wallet) =>
      canUseArk(wallet) && _arkOnFingerprints.contains(wallet.hotWalletMetadata!.masterFingerprint.toLowerCase());

  bool supportsArkById(int walletId) {
    final wallet = _findWallet(walletId);
    return wallet != null && supportsArk(wallet);
  }

  /// The cached Ark data of [walletId], or null if it has never synced (or isn't a hot wallet).
  ArkSnapshot? snapshot(int walletId) {
    if (!supportsArkById(walletId)) return null;
    return _snapshots.putIfAbsent(walletId, () => _arkRepository.getSnapshot(walletId));
  }

  ArkBalance? balance(int walletId) => snapshot(walletId)?.balance;

  /// The Ark part of the wallet's total balance, 0 without Ark.
  int totalSats(int walletId) {
    final balance = this.balance(walletId);
    if (balance == null) return 0;
    return balance.total - _doubleCountedInRound(walletId, balance);
  }

  /// bark 0.7.1은 서버가 아직 라운드에 넣지 않은 갱신 입력 VTXO를 쓸 수 있는 잔액과
  /// 라운드 처리 중 양쪽에 셈(#29). 갱신 대기 VTXO 중 잠기지 않은 것의 금액만큼 뺌.
  /// 이 상태는 `pendingRoundInputVtxos`에 나오지 않아 앱이 기억한 요청 목록도 씀
  int _doubleCountedInRound(int walletId, ArkBalance balance) {
    if (balance.pendingInRound == 0) return 0;
    final overlap = (snapshot(walletId)?.vtxos ?? const [])
        .where((vtxo) => isRefreshingVtxo(vtxo.id) && !vtxo.isLocked)
        .fold<int>(0, (sum, vtxo) => sum + vtxo.amountSats);
    return overlap < balance.pendingInRound ? overlap : balance.pendingInRound;
  }

  /// 아크·라이트닝으로 보낼 수 있는 잔액: 잠기지 않고 갱신 중이 아니며 만료되지 않은 VTXO
  int sendableSats(int walletId) {
    final tip = _currentBlock?.value?.height ?? _walletProvider.currentBlockHeightNotifier.value?.height;
    return (snapshot(walletId)?.vtxos ?? const [])
        .where((vtxo) => !vtxo.isLocked && !isRefreshingVtxo(vtxo.id) && (tip == null || vtxo.expiryHeight > tip))
        .fold<int>(0, (sum, vtxo) => sum + vtxo.amountSats);
  }

  /// 온체인으로 빼낼 수 있는 아크 잔액: 만료 VTXO까지 포함(오프보딩·갱신은 서버가 받아 주면 가능)
  int offboardableSats(int walletId) => (snapshot(walletId)?.vtxos ?? const [])
      .where((vtxo) => !vtxo.isLocked && !isRefreshingVtxo(vtxo.id))
      .fold<int>(0, (sum, vtxo) => sum + vtxo.amountSats);

  bool get hasHotWalletWithArkFunds => _walletProvider.walletItemList.any((wallet) => totalSats(wallet.id) > 0);

  bool isOpen(int walletId) {
    final fingerprint = _fingerprint(walletId);
    return fingerprint != null && _arkWalletService.isOpen(fingerprint);
  }

  bool isOpening(int walletId) => _opening.containsKey(walletId);
  bool isSyncing(int walletId) => _syncing.contains(walletId);
  String? syncError(int walletId) => _syncErrors[walletId];

  /// Whether entering [walletId] should prompt to unlock its Ark wallet: not when it is open or
  /// opening, nor after the user declined once this session.
  bool shouldAutoUnlock(int walletId) =>
      supportsArkById(walletId) && !isOpen(walletId) && !isOpening(walletId) && !_declined.contains(walletId);

  /// Opens the Ark wallet of [walletId] with the seed [unlockSeed] returns (null = the user
  /// cancelled), creating it with seed recovery if it has no data on disk yet. Returns whether
  /// the wallet is open afterwards. Concurrent calls share one attempt.
  Future<bool> open(int walletId, Future<String?> Function() unlockSeed) {
    if (isOpen(walletId)) return Future.value(true);
    return _opening[walletId] ??= _open(walletId, unlockSeed).whenComplete(() {
      _opening.remove(walletId);
      _notify();
    });
  }

  Future<bool> _open(int walletId, Future<String?> Function() unlockSeed) async {
    _notify();
    final seedHex = await unlockSeed();
    if (seedHex == null) {
      _declined.add(walletId);
      return false;
    }
    _declined.remove(walletId);
    // Only bark's open runs under the lifecycle lock, never the unlock prompt: a delete must not
    // wait behind a PIN sheet.
    final opened = await _walletProvider.runHotWalletLifecycleOperation(() async {
      final fingerprint = _fingerprint(walletId);
      if (fingerprint == null) return false; // Deleted while the prompt was up.
      if (!await _arkWalletService.exists(fingerprint)) return false;
      await _arkWalletService.open(fingerprint, seedHex);
      return true;
    });
    if (opened) unawaited(syncNow(walletId));
    return opened;
  }

  /// [walletId]에 아크를 켬. 같은 시드로 예전에 쓴 아크 자금이 있으면 bark 복구로 되찾음
  Future<bool> turnOn(int walletId, Future<String?> Function() unlockSeed) async {
    final wallet = _findWallet(walletId);
    if (wallet == null || !canUseArk(wallet) || supportsArk(wallet)) return false;
    final seedHex = await unlockSeed();
    if (seedHex == null) return false;
    final created = await _walletProvider.runHotWalletLifecycleOperation(() async {
      final current = _findWallet(walletId);
      if (current == null || !canUseArk(current)) return false;
      final fingerprint = current.hotWalletMetadata!.masterFingerprint;
      await _arkWalletService.create(fingerprint, seedHex, restore: true);
      _arkOnFingerprints.add(fingerprint.toLowerCase());
      return true;
    });
    _notify();
    if (created) unawaited(syncNow(walletId));
    return created;
  }

  /// 아크 잔액이 남아 있으면 끌 수 없음
  bool canTurnOff(int walletId) => supportsArkById(walletId) && totalSats(walletId) == 0;

  /// [walletId]의 아크를 끄고 bark 데이터와 캐시를 지움
  Future<void> turnOff(int walletId) async {
    if (!canTurnOff(walletId)) throw StateError('Ark of wallet $walletId still holds funds');
    await _walletProvider.runHotWalletLifecycleOperation(() async {
      final fingerprint = _fingerprint(walletId);
      if (fingerprint == null) return;
      await _arkWalletService.delete(fingerprint);
      _arkOnFingerprints.remove(fingerprint.toLowerCase());
    });
    await _arkRepository.deleteCache(walletId);
    _snapshots.remove(walletId);
    _refreshDue.remove(walletId);
    _lastSync.remove(walletId);
    cacheRevision.value++;
    _notify();
  }

  /// 아크 서버 수수료표, 서버에 닿지 못하면 null
  Future<ArkFeeGuide?> feeGuide() async {
    final schedule = await _arkWalletService.feeSchedule();
    return schedule == null ? null : ArkFeeGuide.fromSchedule(schedule);
  }

  /// 마지막 동기화 기준 갱신이 필요한 VTXO
  ArkRefreshDue refreshDue(int walletId) => _refreshDue[walletId] ?? ArkRefreshDue.none;

  Future<void> _loadArkWallets() async {
    try {
      final fingerprints = await _arkWalletService.listFingerprints();
      _arkOnFingerprints
        ..clear()
        ..addAll(fingerprints.map((fingerprint) => fingerprint.toLowerCase()));
      _snapshots.clear();
      cacheRevision.value++;
      _notify();
    } catch (error) {
      Logger.error('ArkProvider: failed to list Ark wallets: $error');
    }
  }

  /// Recreates the unused Ark wallet so bark's seed recovery runs again.
  Future<void> retryRecovery(int walletId, String seedHex) async {
    if (!(snapshot(walletId)?.canRetryRecovery ?? false)) return;
    await _walletProvider.runHotWalletLifecycleOperation(() async {
      final fingerprint = _fingerprint(walletId);
      if (fingerprint == null) return;
      await _arkWalletService.create(fingerprint, seedHex, restore: true);
    });
    await syncNow(walletId);
  }

  /// Syncs [walletId] and refreshes its cache. [withRounds]면 이미 참여한 라운드도 진행.
  /// Skipped when the wallet is locked or already syncing.
  Future<void> syncNow(int walletId, {bool withRounds = true}) async {
    final fingerprint = _fingerprint(walletId);
    if (fingerprint == null || !_arkWalletService.isOpen(fingerprint)) return;
    if (_syncing.contains(walletId)) {
      // Whatever asked (e.g. a move just made) must see a sync that starts after it.
      _syncAgain.add(walletId);
      return;
    }
    _syncing.add(walletId);
    _notify();
    try {
      try {
        if (withRounds) {
          await _arkWalletService.syncAndProgressRounds(fingerprint);
          _lastSync[walletId] = DateTime.now();
        } else {
          await _arkWalletService.sync(fingerprint);
        }
        _syncErrors.remove(walletId);
        // bark 동기화는 서버 장애에도 성공으로 끝남
        if (await _canReachServer()) {
          _syncFailingSince.remove(walletId);
        } else {
          _syncFailingSince.putIfAbsent(walletId, DateTime.now);
        }
      } catch (error) {
        // Offline or the server is down: still refresh the cache from bark's local state.
        Logger.error('ArkProvider: sync of wallet $walletId failed: $error');
        _syncErrors[walletId] = error.toString();
        _syncFailingSince.putIfAbsent(walletId, DateTime.now);
      }
      final previous = snapshot(walletId);
      final next = await _arkWalletService.snapshot(
        fingerprint,
        address: previous?.address,
        addressIndex: previous?.addressIndex,
      );
      if (previous == null || !previous.hasSameContent(next)) {
        if (await _arkRepository.saveSnapshot(walletId, next)) {
          _snapshots[walletId] = next;
          _refreshingVtxoIds.removeWhere((id, _) => !next.vtxos.any((vtxo) => vtxo.id == id) || !isRefreshingVtxo(id));
          _saveRefreshingVtxoIds();
          cacheRevision.value++;
        }
      }
      _pruneAwaitedInvoices(walletId);
      await _updatePendingRound(walletId, fingerprint);
      await _updateRefreshDue(walletId, fingerprint);
    } catch (error) {
      Logger.error('ArkProvider: failed to refresh the Ark cache of wallet $walletId: $error');
      _syncErrors[walletId] = error.toString();
    } finally {
      _syncing.remove(walletId);
      _notify();
      if (_syncAgain.remove(walletId)) unawaited(syncNow(walletId, withRounds: false));
    }
  }

  Future<void> _updatePendingRound(int walletId, String fingerprint) async {
    final Set<String> pending;
    try {
      pending = (await _arkWalletService.pendingRoundVtxoIds(fingerprint)).toSet();
    } catch (error) {
      Logger.error('ArkProvider: failed to read pending round VTXOs of wallet $walletId: $error');
      return;
    }
    final previous = _pendingRoundVtxoIds[walletId] ?? const <String>{};
    final vtxoIds = {for (final vtxo in snapshot(walletId)?.vtxos ?? const []) vtxo.id};
    final incomplete = previous.where((id) => !pending.contains(id) && vtxoIds.contains(id)).toList();
    if (setEquals(previous, pending) && incomplete.isEmpty) return;
    _pendingRoundVtxoIds[walletId] = pending;
    for (final id in incomplete) {
      _refreshingVtxoIds.remove(id);
      _failedRefreshVtxoIds.add(id);
    }
    _failedRefreshVtxoIds.removeWhere((id) => !vtxoIds.contains(id) && (snapshot(walletId)?.vtxos.isNotEmpty ?? false));
    _refreshingVtxoIds.removeWhere((id, _) => pending.contains(id));
    _saveRefreshingVtxoIds();
    if (incomplete.isNotEmpty) refreshIncomplete.value = (walletId: walletId, count: incomplete.length);
    cacheRevision.value++;
  }

  Future<void> _updateRefreshDue(int walletId, String fingerprint) async {
    final tip = _currentBlock?.value?.height ?? _walletProvider.currentBlockHeightNotifier.value?.height;
    final vtxos = snapshot(walletId)?.vtxos ?? const [];
    final expiries = vtxos.map((vtxo) => vtxo.expiryHeight);
    final next = ArkRefreshDue(
      vtxoIds:
          tip == null
              ? const []
              : [
                for (final vtxo in vtxos)
                  if (!vtxo.isLocked &&
                      !isRefreshingVtxo(vtxo.id) &&
                      vtxo.expiryHeight - tip <= ArkRefreshDue.noticeBlocks)
                    vtxo.id,
              ],
      firstExpiryHeight: expiries.isEmpty ? null : expiries.reduce((a, b) => a < b ? a : b),
      tipHeight: tip,
    );
    final previous = refreshDue(walletId);
    if (previous.firstExpiryHeight != next.firstExpiryHeight ||
        previous.tipHeight != next.tipHeight ||
        !listEquals(previous.vtxoIds, next.vtxoIds)) {
      _refreshDue[walletId] = next;
      cacheRevision.value++;
    }
    await _autoRefreshIfOverdue(walletId, fingerprint, tip);
    await _scheduleExpiryNotifications(walletId, tip);
  }

  /// 만료 1,008블록·144블록 전(메인넷 약 7일·1일)에 앱을 열어 갱신하라고 알림
  ({int height, DateTime at})? _firstSeenBlock;
  ({int height, DateTime at})? _lastSeenBlock;

  /// 메인넷은 10분, 그 밖의 네트워크는 앱이 본 블록 높이 변화로 잰 간격
  Duration get _blockInterval {
    const mainnet = Duration(minutes: 10);
    if (NetworkType.currentNetworkType == NetworkType.mainnet) return mainnet;
    final first = _firstSeenBlock;
    final last = _lastSeenBlock;
    if (first == null || last == null || last.height - first.height < 3) return mainnet;
    return last.at.difference(first.at) ~/ (last.height - first.height);
  }

  void _onCurrentBlockChanged() {
    final height = _currentBlock?.value?.height;
    if (height == null) return;
    final now = DateTime.now();
    _firstSeenBlock ??= (height: height, at: now);
    if (_lastSeenBlock?.height != height) _lastSeenBlock = (height: height, at: now);
  }

  Future<void> _scheduleExpiryNotifications(int walletId, int? tip) async {
    final notifications = _notifications;
    if (notifications == null || tip == null) return;
    final expiries = [
      for (final vtxo in snapshot(walletId)?.vtxos ?? const [])
        if (!isRefreshingVtxo(vtxo.id)) vtxo.expiryHeight,
    ];
    final earliest = expiries.isEmpty ? null : expiries.reduce((a, b) => a < b ? a : b);
    final key = '$earliest:${_blockInterval.inSeconds}';
    if (_scheduledExpiryKeys[walletId] == key) return;
    _scheduledExpiryKeys[walletId] = key;
    final ids = [_expiryNotificationIdBase + walletId * 2, _expiryNotificationIdBase + walletId * 2 + 1];
    try {
      for (final id in ids) {
        await notifications.cancel(id);
      }
      if (earliest == null) return;
      final walletName = _findWallet(walletId)?.name ?? '';
      final isMainnet = NetworkType.currentNetworkType == NetworkType.mainnet;
      DateTime atBlocksBefore(int blocks) => DateTime.now().add(_blockInterval * (earliest - tip - blocks));
      final plans = [
        (
          ids[0],
          atBlocksBefore(ArkRefreshDue.noticeBlocks),
          isMainnet
              ? t.ark.notification.body_week(wallet: walletName)
              : t.ark.notification.body_soon(wallet: walletName),
        ),
        (
          ids[1],
          atBlocksBefore(ArkRefreshDue.urgentBlocks),
          isMainnet
              ? t.ark.notification.body_day(wallet: walletName)
              : t.ark.notification.body_urgent(wallet: walletName),
        ),
      ];
      for (final (id, at, body) in plans) {
        if (!at.isAfter(DateTime.now())) continue;
        await notifications.schedule(
          id: id,
          channelId: 'ark_expiry',
          channelName: t.ark.notification.channel_name,
          channelDescription: t.ark.notification.channel_description,
          title: t.ark.notification.title,
          body: body,
          payload: '$arkExpiryPayloadPrefix$walletId',
          at: at,
        );
      }
    } catch (error) {
      Logger.error('ArkProvider: failed to schedule expiry notifications of wallet $walletId: $error');
    }
  }

  /// 홈 지갑 카드에 경고를 띄울 만큼 갱신이 급한지: 만료, 144블록 안, 또는 자동 갱신을 끈 채 1,008블록 안
  /// 보여 줄 아크 만료 안내 단계, 없으면 null. 지갑 상세 배너와 지갑 카드 점이 같은 기준을 씀
  ArkRefreshNotice? refreshNotice(int walletId) {
    if (!supportsArkById(walletId)) return null;
    final due = refreshDue(walletId);
    if (!due.isDue) return null;
    if (due.isExpired) return ArkRefreshNotice.expired;
    final blocksLeft = due.blocksLeft;
    if (blocksLeft != null && blocksLeft <= ArkRefreshDue.urgentBlocks) return ArkRefreshNotice.urgent;
    if (!isOpen(walletId) && !isOpening(walletId)) return ArkRefreshNotice.locked;
    if (isAutoRefreshOn(walletId)) return null;
    return ArkRefreshNotice.notice;
  }

  /// [vtxoId]를 만든 내역부터 그 입력을 만든 내역으로 거슬러 올라간 이력, 최근 것이 먼저
  List<ArkMovement> vtxoHistory(int walletId, String vtxoId) {
    final movements = snapshot(walletId)?.movements ?? const <ArkMovement>[];
    final result = <ArkMovement>[];
    final seen = <int>{};
    var frontier = {vtxoId};
    while (frontier.isNotEmpty && result.length < 50) {
      final next = <String>{};
      for (final movement in movements) {
        if (seen.contains(movement.id) || !movement.outputVtxoIds.any(frontier.contains)) continue;
        seen.add(movement.id);
        result.add(movement);
        next.addAll(movement.inputVtxoIds);
      }
      frontier = next;
    }
    return result..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  bool isAutoRefreshOn(int walletId) {
    try {
      return _sharedPrefs.isWalletArkAutoRefreshOn(walletId);
    } catch (_) {
      return true;
    }
  }

  /// 지갑 화면에 온체인·아크 잔액을 나눠 보여 줄지
  bool showsBalanceBreakdown(int walletId) {
    if (!supportsArkById(walletId)) return false;
    try {
      return _sharedPrefs.isWalletBalanceBreakdown(walletId);
    } catch (_) {
      return false;
    }
  }

  Future<void> setBalanceBreakdown(int walletId, bool shown) async {
    await _sharedPrefs.setWalletBalanceBreakdown(walletId, shown);
    cacheRevision.value++;
    _notify();
  }

  Future<void> setAutoRefreshOn(int walletId, bool on) async {
    await _sharedPrefs.setWalletArkAutoRefreshOn(walletId, on);
    _notify();
  }

  /// bark 갱신 기한(만료 직전)을 넘긴 VTXO만 위임 갱신, 이미 라운드에 들어간 것은 bark가 제외
  Future<void> _autoRefreshIfOverdue(int walletId, String fingerprint, int? tip) async {
    if (tip == null || !isAutoRefreshOn(walletId) || _autoRefreshing.contains(walletId)) return;
    _autoRefreshing.add(walletId);
    try {
      final requiredHeight = await _arkWalletService.nextRequiredRefreshHeight(fingerprint);
      if (requiredHeight == null || tip < requiredHeight) return;
      final overdue = withoutRefreshing(await _arkWalletService.vtxoIdsToRefresh(fingerprint));
      if (overdue.isEmpty) return;
      Logger.log('ArkProvider: auto-refreshing ${overdue.length} VTXOs of wallet $walletId near expiry');
      await _arkWalletService.refreshDelegated(fingerprint, overdue);
      _markRefreshing(overdue);
    } catch (error) {
      Logger.error('ArkProvider: auto refresh of wallet $walletId failed: $error');
    } finally {
      _autoRefreshing.remove(walletId);
    }
  }

  /// Whether [txid] funds a board into one of the hot wallets' Ark wallets. Such a transaction
  /// must not be replaced (RBF): bark only tracks the txid the board was registered with.
  bool fundsBoard(String txid) => _walletProvider.walletItemList.any(
    (wallet) =>
        snapshot(
          wallet.id,
        )?.movements.any((movement) => movement.kind == ArkMovementKind.board && movement.linkedTxid == txid) ??
        false,
  );

  /// The Ark server's board limits (cached for the session).
  Future<ArkBoardTerms> boardTerms(int walletId) async {
    final cached = _boardTerms;
    if (cached != null) return cached;
    final info = await _arkWalletService.arkInfo(_requireFingerprint(walletId));
    if (info == null) throw StateError('The Ark server is not reachable');
    return _boardTerms = ArkBoardTerms(
      minAmountSats: info.minBoardAmountSats,
      maxAmountSats: info.maxVtxoAmountSats,
      requiredConfirmations: info.requiredBoardConfirmations,
    );
  }

  /// The address to fund a board into [walletId]'s Ark wallet. The same one is returned until a
  /// board succeeds: each new one uses up a key of the Ark keychain.
  Future<ArkBoardFunding> boardFunding(int walletId) async {
    final cached = _boardFunding[walletId];
    if (cached != null) return cached;
    final info = await _arkWalletService.boardFundingAddress(_requireFingerprint(walletId));
    return _boardFunding[walletId] = ArkBoardFunding(
      address: info.address,
      expiryHeight: info.expiryHeight,
      keypairIndex: info.keypairIndex,
    );
  }

  Future<int> estimateBoardFee(int walletId, int amountSats) async =>
      (await _arkWalletService.estimateBoardFee(_requireFingerprint(walletId), amountSats)).feeSats;

  /// Registers a board of [funding]'s address with the Ark server. [unsignedPsbtBase64] is the
  /// funding transaction before signing: bark then leaves broadcasting it to the caller and
  /// watches for it on-chain. Its txid is final from here on, so it must not be replaced (RBF).
  Future<void> board(int walletId, {required String unsignedPsbtBase64, required ArkBoardFunding funding}) async {
    await _arkWalletService.boardPsbt(
      _requireFingerprint(walletId),
      psbtBase64: unsignedPsbtBase64,
      keypairIndex: funding.keypairIndex,
      expiryHeight: funding.expiryHeight,
    );
    _boardFunding.remove(walletId);
    unawaited(syncNow(walletId, withRounds: false));
  }

  /// Broadcasts a raw transaction through bark's chain source, as a fallback for Coconut's own.
  Future<String> broadcastTx(int walletId, String txHex) =>
      _arkWalletService.broadcastTx(_requireFingerprint(walletId), txHex);

  /// The fee to move Ark funds to [address]: everything when [amountSats] is null (taken out of
  /// it), or [amountSats] (on top).
  Future<int> estimateMoveOnchainFee(int walletId, String address, {int? amountSats}) async {
    final fingerprint = _requireFingerprint(walletId);
    final estimate =
        amountSats == null
            ? await _arkWalletService.estimateOffboardAllFee(fingerprint, address)
            : await _arkWalletService.estimateSendOnchainFee(fingerprint, address, amountSats);
    return estimate.feeSats;
  }

  /// Moves Ark funds to [address] on-chain: everything (an offboard) when [amountSats] is null,
  /// else that amount with the rest staying in Ark. Returns the txid. Throws
  /// [ArkMovePendingException] when bark accepted the move but has to finish it on a later sync.
  Future<String> moveOnchain(int walletId, String address, {int? amountSats}) async {
    final fingerprint = _requireFingerprint(walletId);
    try {
      return amountSats == null
          ? await _arkWalletService.offboardAll(fingerprint, address)
          : await _arkWalletService.sendOnchain(fingerprint, address, amountSats);
    } catch (error) {
      if (error.toString().contains('remains pending')) throw ArkMovePendingException(error.toString());
      rethrow;
    } finally {
      unawaited(syncNow(walletId, withRounds: false));
    }
  }

  /// Creates a BOLT11 invoice for [amountSats] (bark can't make amountless ones). The payment is
  /// claimed by the wallet's next sync, so keep [setFastSync] on while waiting for it.
  Future<ArkLightningInvoice> createLightningInvoice(int walletId, int amountSats, {String? memo}) async {
    final fingerprint = _requireFingerprint(walletId);
    final fee = await _arkWalletService.estimateLightningReceiveFee(fingerprint, amountSats);
    final invoice = await _arkWalletService.createLightningInvoice(fingerprint, amountSats, description: memo);
    _awaitedInvoices.putIfAbsent(walletId, () => {})[invoice.paymentHash] = DateTime.now().add(_invoiceWatch);
    return ArkLightningInvoice(
      invoice: invoice.invoice,
      paymentHash: invoice.paymentHash,
      amountSats: invoice.amountSats,
      feeSats: fee.feeSats,
    );
  }

  /// [vtxoId]'s full encoding in hex, to back it up or import it again.
  Future<String> vtxoEncoded(int walletId, String vtxoId) =>
      _arkWalletService.vtxoEncoded(_requireFingerprint(walletId), vtxoId);

  /// Imports a VTXO from its encoding, then syncs so it shows. Only this wallet's own VTXOs (its
  /// keys come from the seed) can be imported. Returns the ids bark now holds from it.
  Future<List<String>> importVtxo(int walletId, String encoded) async {
    final ids = await _arkWalletService.importVtxos(_requireFingerprint(walletId), [encoded.trim()]);
    await syncNow(walletId, withRounds: false);
    return ids;
  }

  /// The on-chain cost of exiting [vtxoId] on its own at [feeRateSatPerVb]: broadcasting its exit
  /// transactions (already-confirmed ones cost nothing) and claiming the output.
  /// 직접 출금 확인 정보: 출금할 VTXO, 만료 잔액, 추정 수수료
  Future<ArkExitEstimate> estimateDirectExit(int walletId) async {
    final fingerprint = _requireFingerprint(walletId);
    final tip = _currentBlock?.value?.height ?? _walletProvider.currentBlockHeightNotifier.value?.height;
    final usable = (snapshot(walletId)?.vtxos ?? const []).where(
      (vtxo) => !vtxo.isLocked && !isRefreshingVtxo(vtxo.id),
    );
    final live = [
      for (final vtxo in usable)
        if (tip == null || vtxo.expiryHeight > tip) vtxo,
    ];
    final expiredSats = usable.where((vtxo) => !live.contains(vtxo)).fold<int>(0, (sum, v) => sum + v.amountSats);
    final feeRate = await _arkWalletService.exitFeeRate(fingerprint);
    var feeSats = 0;
    var txCount = 0;
    if (live.isNotEmpty) {
      final estimate = await _arkWalletService.estimateExitFee(fingerprint, [for (final v in live) v.id], feeRate);
      feeSats = estimate.totalFeeSats;
      txCount = estimate.txsToBroadcast;
    }
    final firstExpiry = live.isEmpty ? null : live.map((v) => v.expiryHeight).reduce((a, b) => a < b ? a : b);
    return ArkExitEstimate(
      vtxoIds: [for (final v in live) v.id],
      amountSats: live.fold<int>(0, (sum, v) => sum + v.amountSats),
      expiredSats: expiredSats,
      feeSats: feeSats,
      txCount: txCount,
      feeRateSatPerVb: feeRate,
      blocksUntilFirstExpiry: firstExpiry == null || tip == null ? null : firstExpiry - tip,
      firstExpiryHeight: firstExpiry,
    );
  }

  /// 직접 출금 수수료를 옮겨 둘 내장 지갑 주소
  Future<String> directExitFeeAddress(int walletId) => _arkWalletService.exitFeeAddress(_requireFingerprint(walletId));

  Future<int> estimateExitFee(int walletId, String vtxoId, int feeRateSatPerVb) async =>
      (await _arkWalletService.estimateExitFee(_requireFingerprint(walletId), [vtxoId], feeRateSatPerVb)).totalFeeSats;

  /// VTXOs bark wants refreshed now (close to expiry, or past the server's chain-depth limit).
  Future<List<String>> vtxoIdsToRefresh(int walletId) =>
      _arkWalletService.vtxoIdsToRefresh(_requireFingerprint(walletId));

  /// The block height by which some VTXO must be refreshed, if any.
  Future<int?> nextRequiredRefreshHeight(int walletId) =>
      _arkWalletService.nextRequiredRefreshHeight(_requireFingerprint(walletId));

  Future<int> estimateRefreshFee(int walletId, List<String> vtxoIds) async =>
      (await _arkWalletService.estimateRefreshFee(_requireFingerprint(walletId), vtxoIds)).feeSats;

  /// Refreshes [vtxoIds] in a delegated round: the server completes it without the app staying
  /// online, and the new VTXOs arrive with a later sync.
  /// 갱신을 요청해 라운드를 기다리는 VTXO
  bool isRefreshingVtxo(String vtxoId) {
    if (_pendingRoundVtxoIds.values.any((ids) => ids.contains(vtxoId))) return true;
    final requestedAt = _refreshingVtxoIds[vtxoId];
    return requestedAt != null && DateTime.now().difference(requestedAt) < _refreshWaitLimit;
  }

  /// 이미 갱신을 요청해 기다리는 VTXO를 빼서 수수료가 두 번 나가지 않게 함
  List<String> withoutRefreshing(List<String> vtxoIds) => [
    for (final id in vtxoIds)
      if (!isRefreshingVtxo(id)) id,
  ];

  void _markRefreshing(List<String> vtxoIds) {
    final now = DateTime.now();
    for (final id in vtxoIds) {
      _refreshingVtxoIds[id] = now;
      _failedRefreshVtxoIds.remove(id);
    }
    _saveRefreshingVtxoIds();
  }

  /// [walletId]가 발급한 아크 주소이거나 아직 받지 않은 자기 인보이스면 true
  Future<bool> isOwnPaymentRequest(int walletId, PaymentRequest request) async {
    final fingerprint = _fingerprint(walletId);
    if (fingerprint == null || !_arkWalletService.isOpen(fingerprint)) return false;
    try {
      if (request.lightningInvoice case final invoice?) {
        final hash = PaymentRequest.bolt11PaymentHash(invoice);
        if (hash != null &&
            (_awaitedInvoices[walletId]?.containsKey(hash) == true ||
                (await _arkWalletService.pendingLightningReceiveHashes(fingerprint)).contains(hash))) {
          return true;
        }
      }
      if (request.arkAddress case final address?) {
        final lastIndex = snapshot(walletId)?.addressIndex ?? 0;
        final issued = await _arkWalletService.issuedAddresses(fingerprint, lastIndex);
        return issued.any((own) => own.toLowerCase() == address.toLowerCase());
      }
    } catch (error) {
      Logger.error('ArkProvider: own payment request check failed: $error');
    }
    return false;
  }

  /// 라이트닝 주소로 보낼 때 붙인 메모, bark가 기록하지 않아 기기에 보관
  String? paymentMemo(int walletId, int movementId) => _loadPaymentMemos()['$walletId:$movementId'];

  void _savePaymentMemo(int walletId, int movementId, String memo) {
    try {
      final memos = _loadPaymentMemos()..['$walletId:$movementId'] = memo;
      unawaited(_sharedPrefs.setStringAndConfirm(SharedPrefKeys.kArkPaymentMemos, jsonEncode(memos)));
    } catch (_) {}
  }

  Map<String, String> _loadPaymentMemos() {
    try {
      final raw = _sharedPrefs.getStringOrNull(SharedPrefKeys.kArkPaymentMemos);
      if (raw == null || raw.isEmpty) return {};
      return (jsonDecode(raw) as Map<String, dynamic>).map((key, value) => MapEntry(key, value as String));
    } catch (_) {
      return {};
    }
  }

  Map<String, DateTime> _loadRefreshingVtxoIds() {
    try {
      final raw = _sharedPrefs.getStringOrNull(SharedPrefKeys.kArkRefreshingVtxos);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final entry in decoded.entries) entry.key: DateTime.fromMillisecondsSinceEpoch(entry.value as int)};
    } catch (_) {
      return {};
    }
  }

  void _saveRefreshingVtxoIds() {
    try {
      unawaited(
        _sharedPrefs.setStringAndConfirm(
          SharedPrefKeys.kArkRefreshingVtxos,
          jsonEncode({for (final entry in _refreshingVtxoIds.entries) entry.key: entry.value.millisecondsSinceEpoch}),
        ),
      );
    } catch (_) {}
  }

  Future<void> refreshDelegated(int walletId, List<String> vtxoIds) async {
    final ids = withoutRefreshing(vtxoIds);
    if (ids.isEmpty) return;
    await _arkWalletService.refreshDelegated(_requireFingerprint(walletId), ids);
    _markRefreshing(ids);
    await syncNow(walletId, withRounds: false);
  }

  /// The Ark server's fee to pay [amountSats] over [rail].
  Future<int> estimatePaymentFee(
    int walletId,
    ArkPaymentRail rail, {
    required String destination,
    required int amountSats,
  }) async {
    final fingerprint = _requireFingerprint(walletId);
    final estimate = switch (rail) {
      ArkPaymentRail.ark => await _arkWalletService.estimateArkoorPaymentFee(fingerprint, amountSats),
      ArkPaymentRail.lightningInvoice ||
      ArkPaymentRail.lightningAddress => await _arkWalletService.estimateLightningSendFee(fingerprint, amountSats),
      ArkPaymentRail.onchain => await _arkWalletService.estimateSendOnchainFee(fingerprint, destination, amountSats),
    };
    return estimate.feeSats;
  }

  /// Whether bark accepts [address] as an Ark address for this wallet's server and network.
  Future<bool> validateArkAddress(int walletId, String address) =>
      _arkWalletService.validateArkoorAddress(_requireFingerprint(walletId), address);

  /// Pays from [walletId]'s Ark balance and returns the id of the movement it created (null if
  /// bark recorded none). Lightning payments finish on later syncs: keep [setFastSync] on while
  /// showing one. For an invoice that carries its amount, pass [invoiceHasAmount] so bark uses
  /// it. Throws [ArkPaymentException] on failure, or [ArkMovePendingException] when bark
  /// accepted an on-chain payment it has to finish later.
  Future<int?> pay(
    int walletId,
    ArkPaymentRail rail, {
    required String destination,
    required int amountSats,
    bool invoiceHasAmount = false,
    String? comment,
  }) async {
    final fingerprint = _requireFingerprint(walletId);
    final isLightning = rail == ArkPaymentRail.lightningInvoice || rail == ArkPaymentRail.lightningAddress;
    final inFlight = (
      id: --_lastInFlightId,
      startedAt: DateTime.now(),
      amountSats: amountSats,
      destination: destination,
      rail: rail,
    );
    (_inFlightPayments[walletId] ??= []).add(inFlight);
    var keepInFlight = false;
    var succeeded = false;
    try {
      for (var attempt = 0; ; attempt++) {
        if (isLightning) await _syncChainTipIgnoringFailure(fingerprint);
        try {
          final movementId = switch (rail) {
            ArkPaymentRail.ark => await _arkWalletService.sendArkoorPayment(fingerprint, destination, amountSats),
            ArkPaymentRail.lightningInvoice => await _arkWalletService.payLightningInvoice(
              fingerprint,
              destination,
              amountSats: invoiceHasAmount ? null : amountSats,
            ),
            ArkPaymentRail.lightningAddress => await _arkWalletService.payLightningAddress(
              fingerprint,
              destination,
              amountSats,
              comment: comment,
            ),
            ArkPaymentRail.onchain => await _arkWalletService.sendOnchainTracked(fingerprint, destination, amountSats),
          };
          if (comment != null && comment.isNotEmpty && movementId != null) {
            _savePaymentMemo(walletId, movementId, comment);
          }
          succeeded = true;
          return movementId;
        } on ArkPaymentException catch (error) {
          // The server rejects a Lightning payment whose HTLC expiry, set from the wallet's chain
          // tip, is more than a block behind its own. Nothing was locked, so retry after a sync.
          if (!isLightning || attempt >= 2 || !error.toString().contains('requested expiry is too low')) rethrow;
          Logger.log('ArkProvider: Lightning payment rejected for a stale chain tip, retrying');
        }
      }
    } on ArkPaymentException catch (error) {
      if (rail == ArkPaymentRail.onchain && error.toString().contains('remains pending')) {
        throw ArkMovePendingException(error.toString());
      }
      keepInFlight = !await _canReachServer();
      rethrow;
    } catch (_) {
      keepInFlight = !await _canReachServer();
      rethrow;
    } finally {
      // 성공하면 bark 기록이 목록에 들어올 때 바꿔 끼움, 서버가 닿지 않는 실패는 나중에 처리될 수 있어 남김
      if (succeeded) {
        _settledInFlight[inFlight.id] = DateTime.now();
      } else if (!keepInFlight) {
        _inFlightPayments[walletId]?.remove(inFlight);
      }
      cacheRevision.value++;
      unawaited(syncNow(walletId, withRounds: false));
    }
  }

  /// bark에 넘겼지만 서버가 응답하지 않아 아직 bark 기록이 없는 결제. 앱이 켜져 있는 동안만 bark가
  /// 다시 연결해 보내므로 메모리에만 둠
  final Map<int, List<({int id, DateTime startedAt, int amountSats, String destination, ArkPaymentRail rail})>>
  _inFlightPayments = {};
  int _lastInFlightId = 0;

  /// bark가 성공을 돌려준 결제와 그 시각, 기록이 끝내 안 들어와도 1분 뒤 지움
  final Map<int, DateTime> _settledInFlight = {};

  /// 아직 bark 기록이 없는 결제를 대기 중인 보내기 기록으로
  List<ArkMovement> _inFlightMovements(int walletId, List<ArkMovement> movements) {
    final payments = _inFlightPayments[walletId];
    if (payments == null || payments.isEmpty) return const [];
    final now = DateTime.now();
    payments.removeWhere(
      (payment) =>
          (_settledInFlight[payment.id]?.isBefore(now.subtract(const Duration(minutes: 1))) ?? false) ||
          movements.any(
            (movement) =>
                movement.effectiveBalanceSats < 0 &&
                movement.kind != ArkMovementKind.refresh &&
                movement.kind != ArkMovementKind.exit &&
                !movement.createdAt.isBefore(payment.startedAt.subtract(const Duration(seconds: 5))),
          ),
    );
    return [
      for (final payment in payments)
        ArkMovement(
          id: payment.id,
          status: ArkMovementStatus.pending,
          subsystemName: switch (payment.rail) {
            ArkPaymentRail.ark => 'bark.arkoor',
            ArkPaymentRail.onchain => 'bark.offboard',
            _ => 'bark.lightning_send',
          },
          subsystemKind: payment.rail == ArkPaymentRail.onchain ? 'send_onchain' : 'send',
          metadataJson: '{}',
          intendedBalanceSats: -payment.amountSats,
          effectiveBalanceSats: -payment.amountSats,
          offchainFeeSats: 0,
          sentTo: [
            jsonEncode({
              'type': switch (payment.rail) {
                ArkPaymentRail.ark => 'ark',
                ArkPaymentRail.onchain => 'bitcoin',
                ArkPaymentRail.lightningInvoice => 'invoice',
                ArkPaymentRail.lightningAddress => 'lightning-address',
              },
              'value': payment.destination,
            }),
          ],
          receivedOn: const [],
          inputVtxoIds: const [],
          outputVtxoIds: const [],
          exitedVtxoIds: const [],
          createdAt: payment.startedAt,
          updatedAt: payment.startedAt,
        ),
    ];
  }

  /// bark sets a Lightning payment's HTLC expiry from its last known chain tip; a sync refreshes it.
  Future<void> _syncChainTipIgnoringFailure(String fingerprint) async {
    try {
      await _arkWalletService.sync(fingerprint);
    } catch (error) {
      Logger.error('ArkProvider: sync before a Lightning payment failed: $error');
    }
  }

  /// Syncs every few seconds while a screen waits for a payment to [walletId] (e.g. a Lightning
  /// invoice on the receive screen). Calls nest; each `true` needs a matching `false`.
  void setFastSync(int walletId, bool enabled) {
    final count = (_fastSync[walletId] ?? 0) + (enabled ? 1 : -1);
    if (count > 0) {
      _fastSync[walletId] = count;
    } else {
      _fastSync.remove(walletId);
    }
  }

  /// 수령했거나 실패했거나 기한이 지난 인보이스는 그만 기다림
  void _pruneAwaitedInvoices(int walletId) {
    final awaited = _awaitedInvoices[walletId];
    if (awaited == null) return;
    final now = DateTime.now();
    final finished = {
      for (final movement in snapshot(walletId)?.movements ?? const [])
        if (movement.paymentHash != null && movement.status != ArkMovementStatus.pending) movement.paymentHash!,
    };
    awaited.removeWhere((hash, until) => now.isAfter(until) || finished.contains(hash));
    if (awaited.isEmpty) _awaitedInvoices.remove(walletId);
  }

  void onPause() {
    _isForeground = false;
    _timer?.cancel();
    _timer = null;
  }

  void onResume() {
    if (_isForeground && _timer != null) return;
    _isForeground = true;
    if (!isEnabled || _disposed) return;
    // Unlock prompts briefly pause the app too; the tick below only syncs what is due.
    _startTimer();
    _tick();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(fastSyncInterval, (_) => _tick());
  }

  void _tick() {
    if (!_isForeground || _disposed) return;
    final now = DateTime.now();
    for (final wallet in _walletProvider.walletItemList) {
      if (!supportsArk(wallet) || !isOpen(wallet.id)) continue;
      final exit = _exitSessions[wallet.id];
      final lastExitAdvance = _lastExitAdvance[wallet.id];
      if (exit != null &&
          _exitNeedsFollowUp(wallet.id, exit) &&
          (lastExitAdvance == null || now.difference(lastExitAdvance) >= _exitAdvanceInterval)) {
        unawaited(_advanceExit(wallet.id));
      }
      if (_syncing.contains(wallet.id)) continue;
      final last = _lastSync[wallet.id];
      if (last == null || now.difference(last) >= syncInterval) {
        unawaited(syncNow(wallet.id));
      } else if (_fastSync.containsKey(wallet.id) || _awaitedInvoices.containsKey(wallet.id)) {
        unawaited(syncNow(wallet.id, withRounds: false));
      }
    }
  }

  void _onWalletListChanged() {
    final ids = _walletProvider.walletItemList.map((wallet) => wallet.id).toSet();
    _snapshots.removeWhere((id, _) => !ids.contains(id));
    _lastSync.removeWhere((id, _) => !ids.contains(id));
    _refreshDue.removeWhere((id, _) => !ids.contains(id));
    if (isEnabled) arkWalletsLoaded = _loadArkWallets();
    _declined.removeWhere((id) => !ids.contains(id));
    // A wallet created or restored just now is open but has nothing cached yet.
    if (_isForeground) _tick();
    _notify();
  }

  WalletItemBase? _findWallet(int walletId) {
    for (final wallet in _walletProvider.walletItemList) {
      if (wallet.id == walletId) return wallet;
    }
    return null;
  }

  String _requireFingerprint(int walletId) {
    final fingerprint = _fingerprint(walletId);
    if (fingerprint == null) throw StateError('Wallet $walletId has no Ark wallet');
    return fingerprint;
  }

  String? _fingerprint(int walletId) {
    final wallet = _findWallet(walletId);
    if (wallet == null || !supportsArk(wallet)) return null;
    return wallet.hotWalletMetadata!.masterFingerprint;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _currentBlock?.removeListener(_onCurrentBlockChanged);
    refreshIncomplete.dispose();
    _timer?.cancel();
    _walletProvider.walletItemListNotifier.removeListener(_onWalletListChanged);
    _walletProvider.setOffchainBalanceSource(null);
    _walletProvider.setOffchainMovementsSource(null);
    cacheRevision.removeListener(_walletProvider.notifyOffchainBalanceChanged);
    cacheRevision.dispose();
    super.dispose();
  }
}

extension ArkProviderContext on BuildContext {
  /// 아크 프로바이더가 없는 구성(테스트 등)에서는 null
  ArkProvider? readArkProviderOrNull() {
    try {
      return Provider.of<ArkProvider>(this, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }
}
