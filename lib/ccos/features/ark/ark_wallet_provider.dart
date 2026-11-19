import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_board.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_exit.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_expiry_reminder.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_vtxo.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_backend.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_store.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum ArkWalletState { none, opening, open, failed }

enum ArkCreateStep { keys, connecting, restoring, findingFunds, ready }

enum ArkSendOutcome { sent, pending, failed }

class ArkSendResult {
  const ArkSendResult(this.outcome, {this.movementId, this.error});

  final ArkSendOutcome outcome;
  final int? movementId;
  final Object? error;
}

Uint8List _randomMnemonic(int wordCount) {
  final seed = Seed.random(mnemonicLength: wordCount, passphrase: Uint8List(0));
  try {
    return Uint8List.fromList(seed.mnemonic);
  } finally {
    seed.wipe();
  }
}

Future<Uint8List> _generateMnemonicInIsolate() => compute(_randomMnemonic, 12);

/// 앱의 아크 지갑 하나. 앱이 켜져 있는 동안 bark 지갑을 열어 둠
class ArkWalletProvider extends ChangeNotifier {
  ArkWalletProvider({
    required ArkWalletStore store,
    required ArkWalletBackend backend,
    Future<Uint8List> Function()? generateMnemonic,
    ArkExpiryReminder? reminder,
    bool autoSync = true,
  }) : _store = store,
       _reminder = reminder,
       _autoSync = autoSync,
       _backend = backend,
       _generateMnemonic = generateMnemonic ?? _generateMnemonicInIsolate,
       _info = store.read(),
       _exit = store.readExit(),
       _exitHistory = store.readExitHistory(),
       _unit = store.readUnit();

  final ArkWalletStore _store;
  final ArkWalletBackend _backend;
  final Future<Uint8List> Function() _generateMnemonic;
  final bool _autoSync;
  final ArkExpiryReminder? _reminder;

  /// 알림을 맞춘 가장 이른 만료 높이, 지운 뒤면 0
  int? _remindedExpiry;

  ArkWalletInfo? _info;
  BitcoinUnit _unit;
  ArkExitSession? _exit;
  List<ArkExitSession> _exitHistory;
  bool _advancingExit = false;
  ArkWalletState _state = ArkWalletState.none;
  ArkCreateStep? _step;
  ArkBalance _balance = ArkBalance.zero;
  bool _isRecoveryPending = false;
  List<ArkMovement> _movements = const [];
  String? _arkAddress;
  ArkLightningInvoice? _awaitedInvoice;
  Timer? _syncTimer;
  AppLifecycleListener? _lifecycle;
  List<ArkVtxo> _vtxos = const [];
  int? _tipHeight;
  int? _vtxoLifetime;
  List<String> _expiringIds = const [];
  Set<String> _renewingIds = const {};
  Map<int, String>? _memos;
  ArkBoardTerms? _boardTerms;
  ArkBoardFunding? _boardFunding;
  Set<int>? _settledIncomingIds;
  final StreamController<ArkMovement> _received = StreamController.broadcast();

  static const _normalSync = Duration(seconds: 30);
  static const _invoiceSync = Duration(seconds: 3);

  /// 자동 갱신이 이만큼 남을 때까지 안 되면 직접 갱신하라고 안내, 메인넷 약 하루(Noah와 같음)
  static const renewWindowBlocks = 144;

  ArkWalletInfo? get info => _info;

  /// 서버 없이 출금 중이거나 끝난 기록
  ArkExitSession? get exit => _exit;
  bool get hasActiveExit => _exit?.isActive ?? false;

  /// 출금 거래(bark movement)의 VTXO로 찾은 출금 기록. 기록 전에 한 출금은 없음
  ArkExitSession? exitOf(ArkMovement movement) {
    final ids = movement.inputVtxoIds.toSet();
    for (final exit in [if (_exit != null) _exit!, ..._exitHistory]) {
      if (exit.vtxoIds.any(ids.contains)) return exit;
    }
    return null;
  }

  /// 아크 지갑 화면의 금액 단위. 잔액을 누르면 sats와 ₿ 사이를 오감
  BitcoinUnit get unit => _unit;

  Future<void> toggleUnit() async {
    _unit = _unit == BitcoinUnit.sats ? BitcoinUnit.bip177 : BitcoinUnit.sats;
    notifyListeners();
    await _store.setUnit(_unit);
  }

  bool get hasWallet => _info != null;
  ArkWalletState get state => _state;
  ArkCreateStep? get step => _step;
  ArkBalance get balance => _balance;
  bool get needsBackup => _info != null && !_info!.backupVerified;
  bool get isRecoveryPending => _isRecoveryPending;

  /// 지갑을 연 뒤 새로 들어와 끝난 입금
  Stream<ArkMovement> get received => _received.stream;

  /// 보여 줄 거래, 최신순
  List<ArkMovement> get movements => _movements;
  String? get arkAddress => _arkAddress;
  bool get isSyncing => _syncTimer != null;

  /// 만료가 이른 순
  List<ArkVtxo> get vtxos => _vtxos;
  int? get tipHeight => _tipHeight;
  bool isRenewing(String vtxoId) => _renewingIds.contains(vtxoId);

  /// 하루 안에 만료되는데 아직 갱신되지 않은 VTXO. 이미 만료된 것도 넣음(서버가 받아 주면 갱신으로 되찾음)
  List<ArkVtxo> get vtxosToRenew => [
    for (final vtxo in _vtxos)
      if (_expiringIds.contains(vtxo.id) && !vtxo.isLocked && !isRenewing(vtxo.id)) vtxo,
  ];
  bool get hasExpiredToRenew => vtxosToRenew.any((vtxo) => (vtxo.blocksLeft(_tipHeight) ?? 1) <= 0);

  /// 서버가 새 VTXO에 주는 수명(블록), 수명 막대에 씀
  int? get vtxoLifetime => _vtxoLifetime;
  int get renewAmount => vtxosToRenew.fold(0, (sum, vtxo) => sum + vtxo.amountSats);

  /// 갱신이 필요한 VTXO만으로 갱신할 수 있음
  bool get canRenewDue => vtxosToRenew.isNotEmpty && renewAmount >= ArkVtxo.minRenewSats;

  /// 인보이스를 보여 주는 동안은 받은 결제를 빨리 수령하도록 짧게
  Duration get syncInterval => _awaitedInvoice == null ? _normalSync : _invoiceSync;

  /// 지갑이 열려 잔액을 읽은 상태
  bool get isBalanceKnown => _state == ArkWalletState.open;

  Future<void> _tail = Future.value();

  /// 만들기·열기·지우기를 하나씩 차례로
  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> createNew() => _serial(() async {
    _setStep(ArkCreateStep.keys);
    final mnemonic = await _generateMnemonic();
    await _create(mnemonic, ArkSeedSource.created);
  });

  Future<void> restore(Uint8List mnemonic) => _serial(() => _create(mnemonic, ArkSeedSource.restored));

  Future<void> _create(Uint8List mnemonic, ArkSeedSource source) async {
    final restore = source == ArkSeedSource.restored;
    try {
      if (restore) _setStep(ArkCreateStep.restoring);
      final fingerprint = await _backend.fingerprintOf(mnemonic);
      if (!restore) _setStep(ArkCreateStep.connecting);
      await _backend.create(fingerprint, mnemonic, restore: restore);
      if (restore) _setStep(ArkCreateStep.findingFunds);
      _balance = await _backend.balance(fingerprint);
      _isRecoveryPending = await _backend.isRecoveryPending(fingerprint);
      _info = await _store.save(mnemonic: mnemonic, fingerprint: fingerprint, source: source);
      _state = ArkWalletState.open;
      _setStep(ArkCreateStep.ready);
      await _loadActivity(fingerprint);
      _startSync();
      unawaited(syncNow());
    } catch (_) {
      await _backend.wipeAll();
      await _store.clear();
      _info = null;
      _state = ArkWalletState.none;
      _setStep(null);
      rethrow;
    } finally {
      mnemonic.fillRange(0, mnemonic.length, 0);
    }
  }

  Future<void> openAfterAppEntrance() => _serial(_openAfterAppEntrance);

  Future<void> _openAfterAppEntrance() async {
    final info = _info = _store.read();
    if (info == null) {
      if ((await _backend.listFingerprints()).isNotEmpty) await _backend.wipeAll();
      await _store.clear();
      _state = ArkWalletState.none;
      notifyListeners();
      return;
    }
    if (_backend.isOpen(info.fingerprint)) {
      try {
        await refreshBalance();
      } catch (error) {
        Logger.error('ArkWalletProvider: failed to refresh the Ark balance: $error');
      }
      return;
    }
    _state = ArkWalletState.opening;
    notifyListeners();
    try {
      final mnemonic = await _store.readMnemonic(info);
      try {
        await _backend.open(info.fingerprint, mnemonic);
      } finally {
        mnemonic.fillRange(0, mnemonic.length, 0);
      }
      _state = ArkWalletState.open;
      await refreshBalance();
      await _loadActivity(info.fingerprint);
      _startSync();
      unawaited(syncNow());
    } catch (error) {
      Logger.error('ArkWalletProvider: failed to open the Ark wallet: $error');
      _state = ArkWalletState.failed;
      notifyListeners();
    }
  }

  Future<void> refreshBalance() async {
    final info = _info;
    if (info == null || !_backend.isOpen(info.fingerprint)) return;
    _balance = await _backend.balance(info.fingerprint);
    _isRecoveryPending = await _backend.isRecoveryPending(info.fingerprint);
    notifyListeners();
  }

  /// 우편함·라운드·라이트닝 수령을 맞춘 뒤 잔액과 내역을 다시 읽음
  Future<void> syncNow() => _serial(() async {
    final info = _info;
    if (info == null || !_backend.isOpen(info.fingerprint)) return;
    try {
      await _backend.sync(info.fingerprint);
    } catch (error) {
      Logger.error('ArkWalletProvider: sync failed: $error');
    }
    try {
      _balance = await _backend.balance(info.fingerprint);
      _isRecoveryPending = await _backend.isRecoveryPending(info.fingerprint);
      await _loadActivity(info.fingerprint, afterSync: true);
    } catch (error) {
      Logger.error('ArkWalletProvider: reading after sync failed: $error');
    }
    await _loadVtxos(info.fingerprint);
    await _advanceExit(info.fingerprint);
  });

  Future<void> _loadVtxos(String fingerprint) async {
    try {
      _vtxos = [...await _backend.vtxos(fingerprint)]..sort((a, b) => a.expiryHeight.compareTo(b.expiryHeight));
      _tipHeight = await _backend.tipHeight();
      _expiringIds = await _backend.expiringVtxoIds(fingerprint, renewWindowBlocks);
      _renewingIds = await _backend.renewingVtxoIds(fingerprint);
      _vtxoLifetime ??= await _backend.vtxoLifetime(fingerprint);
    } catch (error) {
      Logger.error('ArkWalletProvider: failed to read VTXOs: $error');
    }
    notifyListeners();
    await _updateReminder();
  }

  /// 갱신 구간에 들어설 때(블록 하나 10분으로 셈) 알림. 이미 구간 안이면 홈 안내가 대신함
  Future<void> _updateReminder() async {
    final tip = _tipHeight;
    if (tip == null) return;
    final waiting = [
      for (final vtxo in _vtxos)
        if (!isRenewing(vtxo.id) && vtxo.expiryHeight - tip > renewWindowBlocks) vtxo.expiryHeight,
    ];
    final inWindow = _vtxos.any((vtxo) => !isRenewing(vtxo.id) && vtxo.expiryHeight - tip <= renewWindowBlocks);
    final earliest = waiting.isEmpty || inWindow ? 0 : waiting.reduce((a, b) => a < b ? a : b);
    if (earliest == _remindedExpiry) return;
    _remindedExpiry = earliest;
    await _reminder?.remindAt(
      earliest == 0 ? null : DateTime.now().add(const Duration(minutes: 10) * (earliest - tip - renewWindowBlocks)),
    );
  }

  Future<int> estimateRenewFee(List<String> vtxoIds) =>
      _serial(() => _backend.estimateRenewFee(_info!.fingerprint, vtxoIds));

  Future<void> renew(List<String> vtxoIds) => _serial(() async {
    final fingerprint = _info!.fingerprint;
    await _backend.renew(fingerprint, vtxoIds);
    await _loadVtxos(fingerprint);
  });

  /// 주소는 서버와 동기화한 뒤에만 받음. 서버 없이 만든 직후의 주소는 다른 지갑이 해석하지 못함
  Future<void> _loadActivity(String fingerprint, {bool afterSync = false}) async {
    final history = await _backend.history(fingerprint);
    _movements = mergeArkExits(
      history.where((movement) => movement.isVisibleInHistory).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
    );
    _announceReceived();
    if (afterSync) _arkAddress ??= await _backend.newArkAddress(fingerprint);
    notifyListeners();
  }

  void _announceReceived() {
    final settled = [
      for (final movement in _movements)
        if (!movement.isSend && !movement.isPending && !movement.isFailed && movement.effectiveBalanceSats > 0)
          movement,
    ];
    final known = _settledIncomingIds;
    _settledIncomingIds = {for (final movement in settled) movement.id};
    if (known == null) return;
    for (final movement in settled.reversed) {
      if (!known.contains(movement.id)) _received.add(movement);
    }
  }

  void _startSync() {
    if (!_autoSync) return;
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(syncInterval, (_) => syncNow());
    _lifecycle ??= AppLifecycleListener(
      onPause: () {
        _syncTimer?.cancel();
        _syncTimer = null;
      },
      onResume: () {
        if (_state != ArkWalletState.open) return;
        _startSync();
        syncNow();
      },
    );
  }

  void _stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<ArkLightningInvoice> createInvoice(int amountSats) => _serial(() async {
    final invoice = await _backend.createLightningInvoice(_info!.fingerprint, amountSats);
    _awaitedInvoice = invoice;
    if (_syncTimer != null) _startSync();
    notifyListeners();
    return invoice;
  });

  void stopAwaitingInvoice() {
    if (_awaitedInvoice == null) return;
    _awaitedInvoice = null;
    if (_syncTimer != null) _startSync();
  }

  bool isInvoicePaid(String paymentHash) => _movements.any(
    (movement) =>
        movement.paymentHash == paymentHash &&
        movement.kind == ArkMovementKind.lightningReceive &&
        movement.status == ArkMovementStatus.successful,
  );

  Future<int> estimateFee(ArkPaymentRail rail, int amountSats) =>
      _serial(() => _backend.estimateSendFee(_info!.fingerprint, rail, amountSats));

  Future<ArkSendResult> send(
    ArkPaymentRail rail,
    String destination,
    int amountSats, {
    bool invoiceHasAmount = false,
    String? memo,
  }) => _serial(() async {
    final fingerprint = _info!.fingerprint;
    int? movementId;
    try {
      movementId = await _backend.send(fingerprint, rail, destination, amountSats, invoiceHasAmount: invoiceHasAmount);
      if (movementId != null && memo != null) await _setMemo(movementId, memo);
    } on ArkPaymentException catch (error) {
      Logger.error('ArkWalletProvider: send failed: ${error.cause}');
      await _refreshAfterSend(fingerprint);
      return ArkSendResult(ArkSendOutcome.failed, movementId: error.movementId, error: error.cause);
    }
    await _refreshAfterSend(fingerprint);
    final movement = _movements.where((movement) => movement.id == movementId).firstOrNull;
    final outcome =
        movement == null || movement.isPending
            ? (movement == null ? ArkSendOutcome.sent : ArkSendOutcome.pending)
            : movement.isFailed
            ? ArkSendOutcome.failed
            : ArkSendOutcome.sent;
    return ArkSendResult(outcome, movementId: movementId);
  });

  Future<void> _refreshAfterSend(String fingerprint) async {
    try {
      _balance = await _backend.balance(fingerprint);
      await _loadActivity(fingerprint);
    } catch (error) {
      Logger.error('ArkWalletProvider: refresh after send failed: $error');
    }
  }

  String? memoOf(int movementId) => (_memos ??= _store.readMemos())[movementId];

  Future<void> setMemo(int movementId, String memo) async {
    await _setMemo(movementId, memo);
    notifyListeners();
  }

  Future<void> _setMemo(int movementId, String memo) async {
    await _store.setMemo(movementId, memo);
    _memos = _store.readMemos();
  }

  /// 서버 보딩 한도, 한 번 읽어 둠
  Future<ArkBoardTerms> boardTerms() async => _boardTerms ??= await _backend.boardTerms(_info!.fingerprint);

  /// 보딩 주소. 보딩을 등록할 때까지 같은 주소(새로 받을 때마다 아크 키를 하나 씀)
  Future<ArkBoardFunding> boardFunding() =>
      _serial(() async => _boardFunding ??= await _backend.boardFunding(_info!.fingerprint));

  Future<int> estimateBoardFee(int amountSats) =>
      _serial(() => _backend.estimateBoardFee(_info!.fingerprint, amountSats));

  Future<void> board({required String unsignedPsbtBase64, required ArkBoardFunding funding}) => _serial(() async {
    await _backend.board(_info!.fingerprint, unsignedPsbtBase64: unsignedPsbtBase64, funding: funding);
    _boardFunding = null;
  });

  Future<String> broadcastTx(String txHex) => _serial(() => _backend.broadcastTx(_info!.fingerprint, txHex));

  Future<int> estimateExportFee(String address, {int? amountSats}) =>
      _serial(() => _backend.estimateExportFee(_info!.fingerprint, address, amountSats: amountSats));

  /// 아크 잔액을 내 지갑 주소로. [amountSats]가 없으면 전부
  Future<String> export(String address, {int? amountSats}) => _serial(() async {
    final fingerprint = _info!.fingerprint;
    try {
      return await _backend.export(fingerprint, address, amountSats: amountSats);
    } finally {
      await _refreshAfterSend(fingerprint);
    }
  });

  Future<ArkExitQuote> estimateExit() => _serial(() => _backend.estimateExit(_info!.fingerprint));

  Future<String> exitFeeAddress() => _serial(() => _backend.exitFeeAddress(_info!.fingerprint));

  /// 수수료 준비 거래를 보낸 뒤 부름. 그 거래가 확정되면 동기화 때 출금을 시작함
  Future<void> beginExit(ArkExitSession session) async {
    _exit = session;
    await _store.saveExit(session);
    notifyListeners();
  }

  /// 끝나고 정리까지 마친 출금 기록을 지움
  Future<void> dismissExit() async {
    if (!(_exit?.isSettled ?? false)) return;
    _exitHistory = [_exit!, ..._exitHistory];
    _exit = null;
    await _store.saveExitHistory(_exitHistory);
    await _store.saveExit(null);
    notifyListeners();
  }

  Future<void> _advanceExit(String fingerprint) async {
    final session = _exit;
    if (session == null || session.isSettled || _advancingExit) return;
    _advancingExit = true;
    try {
      final next = await nextArkExitState(_backend.exitSteps(fingerprint), session, tipHeight: _tipHeight);
      if (identical(next, session) || !identical(_exit, session)) return;
      _exit = next;
      await _store.saveExit(next);
      notifyListeners();
    } catch (error) {
      Logger.error('ArkWalletProvider: exit did not advance: $error');
    } finally {
      _advancingExit = false;
    }
  }

  Future<Uint8List> readMnemonicForBackup() => _store.readMnemonic(_info!);

  Future<void> markBackupVerified() async {
    await _store.markBackupVerified();
    _info = _store.read();
    notifyListeners();
  }

  Future<void> wipe() => _serial(_wipe);

  Future<void> _wipe() async {
    _stopSync();
    _awaitedInvoice = null;
    _movements = const [];
    _arkAddress = null;
    _vtxos = const [];
    _tipHeight = null;
    _vtxoLifetime = null;
    _expiringIds = const [];
    _renewingIds = const {};
    _memos = null;
    _boardTerms = null;
    _boardFunding = null;
    _exit = null;
    _exitHistory = const [];
    _settledIncomingIds = null;
    _remindedExpiry = null;
    await _reminder?.remindAt(null);
    await _backend.wipeAll();
    await _store.clear();
    _info = null;
    _state = ArkWalletState.none;
    _step = null;
    _balance = ArkBalance.zero;
    _isRecoveryPending = false;
    notifyListeners();
  }

  void _setStep(ArkCreateStep? step) {
    _step = step;
    notifyListeners();
  }

  @override
  void dispose() {
    _received.close();
    _stopSync();
    _lifecycle?.dispose();
    super.dispose();
  }
}
