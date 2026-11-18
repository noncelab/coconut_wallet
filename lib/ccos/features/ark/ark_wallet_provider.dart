import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_backend.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_store.dart';
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
    bool autoSync = true,
  }) : _store = store,
       _autoSync = autoSync,
       _backend = backend,
       _generateMnemonic = generateMnemonic ?? _generateMnemonicInIsolate,
       _info = store.read();

  final ArkWalletStore _store;
  final ArkWalletBackend _backend;
  final Future<Uint8List> Function() _generateMnemonic;
  final bool _autoSync;

  ArkWalletInfo? _info;
  ArkWalletState _state = ArkWalletState.none;
  ArkCreateStep? _step;
  ArkBalance _balance = ArkBalance.zero;
  bool _isRecoveryPending = false;
  List<ArkMovement> _movements = const [];
  String? _arkAddress;
  ArkLightningInvoice? _awaitedInvoice;
  Timer? _syncTimer;
  AppLifecycleListener? _lifecycle;

  static const _normalSync = Duration(seconds: 30);
  static const _invoiceSync = Duration(seconds: 3);

  ArkWalletInfo? get info => _info;
  bool get hasWallet => _info != null;
  ArkWalletState get state => _state;
  ArkCreateStep? get step => _step;
  ArkBalance get balance => _balance;
  bool get needsBackup => _info != null && !_info!.backupVerified;
  bool get isRecoveryPending => _isRecoveryPending;

  /// 보여 줄 거래, 최신순
  List<ArkMovement> get movements => _movements;
  String? get arkAddress => _arkAddress;
  bool get isSyncing => _syncTimer != null;

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
      _balance = await _backend.balance(info.fingerprint);
      _isRecoveryPending = await _backend.isRecoveryPending(info.fingerprint);
      await _loadActivity(info.fingerprint, afterSync: true);
    } catch (error) {
      Logger.error('ArkWalletProvider: sync failed: $error');
    }
  });

  /// 주소는 서버와 동기화한 뒤에만 받음. 서버 없이 만든 직후의 주소는 다른 지갑이 해석하지 못함
  Future<void> _loadActivity(String fingerprint, {bool afterSync = false}) async {
    final history = await _backend.history(fingerprint);
    _movements =
        history.where((movement) => movement.isVisibleInHistory).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (afterSync) _arkAddress ??= await _backend.newArkAddress(fingerprint);
    notifyListeners();
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
  }) => _serial(() async {
    final fingerprint = _info!.fingerprint;
    int? movementId;
    try {
      movementId = await _backend.send(fingerprint, rail, destination, amountSats, invoiceHasAmount: invoiceHasAmount);
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
    _stopSync();
    _lifecycle?.dispose();
    super.dispose();
  }
}
