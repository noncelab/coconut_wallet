import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/ark/ark_exit.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/notification/local_notification_service.dart';
import 'package:coconut_wallet/services/security/hot_wallet_signing_service.dart';
import 'package:coconut_wallet/services/transaction/unsigned_psbt_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_intent_validator.dart';
import 'package:flutter/foundation.dart';

enum ArkExitStep { loading, confirm, preparing, exiting, waiting, claiming, done, failed }

/// 직접 출금 화면: 확인 → 수수료 준비 → 출금 거래 올리기 → 대기 → 받기
class ArkExitViewModel extends ChangeNotifier {
  ArkExitViewModel(
    this._arkProvider,
    this._walletProvider,
    this._nodeProvider,
    this._utxoRepository,
    this.walletId, {
    bool isManualUtxoSelection = false,
    HotWalletSigningService? signingService,
    LocalNotificationService? notifications,
  }) : _signingService = signingService ?? HotWalletSigningService(),
       _notifications = notifications,
       _isManualUtxoSelection = isManualUtxoSelection {
    _arkProvider.addListener(_onArkChanged);
    load();
  }

  /// 만료까지 이만큼은 남아야 출금 거래를 다 올릴 수 있다고 봄(메인넷 약 하루)
  static const minBlocksBeforeExpiry = 144;

  final ArkProvider _arkProvider;
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final UtxoRepository _utxoRepository;
  final HotWalletSigningService _signingService;
  final LocalNotificationService? _notifications;
  final int walletId;

  ArkExitStep _step = ArkExitStep.loading;

  ArkExitSession? get session => _arkProvider.exitSession(walletId);

  ArkExitStep get step {
    final session = this.session;
    if (session == null) return _step;
    return switch (session.phase) {
      ArkExitPhase.funding => ArkExitStep.preparing,
      ArkExitPhase.exiting => ArkExitStep.exiting,
      ArkExitPhase.waiting => ArkExitStep.waiting,
      ArkExitPhase.claiming => ArkExitStep.claiming,
      ArkExitPhase.done => ArkExitStep.done,
      ArkExitPhase.failed => ArkExitStep.failed,
    };
  }

  ArkExitEstimate? _estimate;
  ArkExitEstimate? get estimate => _estimate;

  String? _error;
  String? get error => _error;

  bool _isStarting = false;
  bool get isStarting => _isStarting;

  bool? _notificationsAllowed;
  bool? get notificationsAllowed => _notificationsAllowed;

  bool _disposed = false;

  /// 화면을 열 때 서버에 직접 닿아 본 결과, 확인 전에는 null
  bool? _serverReachable;
  bool? get serverReachable => _serverReachable;

  Future<void> _checkServer() async {
    _serverReachable = await _arkProvider.isServerReachable(walletId);
    if (!_disposed) notifyListeners();
  }

  /// 앱 설정이 UTXO 직접 선택이면 고르기 전에는 시작할 수 없음
  final bool _isManualUtxoSelection;

  /// 수수료 준비 거래에 쓸 UTXO, 비어 있으면 자동 선택
  List<UtxoState> _selectedUtxos = const [];
  List<UtxoState> get selectedUtxos => _selectedUtxos;
  int get selectedUtxoSats => _selectedUtxos.fold<int>(0, (sum, utxo) => sum + utxo.amount);

  void setSelectedUtxos(List<UtxoState> utxos) {
    _selectedUtxos = List.unmodifiable(utxos);
    notifyListeners();
  }

  /// 고른 UTXO로 수수료 준비 거래를 만들 때 필요한 최소 금액(입력당 약 68vB, 출력·기본 약 100vB)
  int get requiredSelectedSats {
    final estimate = _estimate;
    if (estimate == null) return 0;
    return estimate.fundingSats + estimate.feeRateSatPerVb * (68 * _selectedUtxos.length + 100);
  }

  int get onchainBalanceSats => _walletProvider.getWalletBalance(walletId).confirmed;

  /// 출금한 비트코인을 받을 이 지갑의 받기 주소
  WalletAddress get receiveAddress => _walletProvider.getReceiveAddress(walletId);

  /// 받은 거래가 지갑 내역에 들어와 상세 화면을 열 수 있는지
  bool get hasClaimTransaction {
    final txid = session?.claimTxid;
    return txid != null && _walletProvider.getTransactionRecordList(walletId).any((tx) => tx.transactionHash == txid);
  }

  String get walletName => _walletProvider.getWalletById(walletId).name;

  int? get blocksLeft => _arkProvider.exitBlocksLeft(walletId);
  DateTime? get claimableAt => _arkProvider.exitClaimableAt(walletId);
  ({int done, int total, Duration remaining})? get txProgress => _arkProvider.exitTxProgress(walletId);

  bool get needsPassphrase =>
      _walletProvider.getWalletById(walletId).hotWalletMetadata?.enterPassphraseWhenSigning ?? false;

  ArkExitBlocker? get blocker {
    final estimate = _estimate;
    if (estimate == null) return null;
    if (estimate.vtxoIds.isEmpty) return ArkExitBlocker.nothingToExit;
    final blocksLeft = estimate.blocksUntilFirstExpiry;
    if (blocksLeft != null && blocksLeft < minBlocksBeforeExpiry) return ArkExitBlocker.tooCloseToExpiry;
    if (onchainBalanceSats < estimate.fundingSats) return ArkExitBlocker.notEnoughOnchain;
    if (_selectedUtxos.isEmpty && _isManualUtxoSelection) return ArkExitBlocker.selectUtxo;
    if (_selectedUtxos.isNotEmpty && selectedUtxoSats < requiredSelectedSats) return ArkExitBlocker.notEnoughSelected;
    return null;
  }

  bool get canStart => step == ArkExitStep.confirm && !_isStarting && _estimate != null && blocker == null;

  Future<void> load() async {
    if (session != null) {
      if (step == ArkExitStep.waiting) unawaited(_requestNotificationPermission());
      notifyListeners();
      return;
    }
    _step = ArkExitStep.loading;
    _error = null;
    notifyListeners();
    unawaited(_checkServer());
    try {
      _estimate = await _arkProvider.estimateDirectExit(walletId);
      _step = ArkExitStep.confirm;
    } catch (error) {
      Logger.error('ArkExitViewModel: estimate failed: $error');
      _error = '$error';
      _step = ArkExitStep.failed;
    }
    if (!_disposed) notifyListeners();
  }

  Future<bool> validatePassphrase(Uint8List passphrase) {
    final wallet = _walletProvider.getWalletById(walletId);
    final metadata = wallet.hotWalletMetadata;
    final walletBase = wallet.walletBase;
    if (metadata == null || walletBase is! SingleSignatureWallet) return Future.value(false);
    return _signingService.validatePassphrase(
      storageKey: metadata.secureStorageKey,
      passphrase: passphrase,
      addressTypeName: walletBase.addressType.name,
      accountIndex: metadata.accountIndex,
      expectedExtendedPublicKey: walletBase.keyStore.extendedPublicKey.serialize(),
    );
  }

  /// 수수료를 내장 지갑으로 옮기는 거래를 서명·전송하고 출금을 시작함. 화면이 인증을 마친 뒤 호출
  Future<void> start({Uint8List? passphrase}) async {
    final estimate = _estimate;
    if (estimate == null || !canStart) return;
    _isStarting = true;
    notifyListeners();
    try {
      final wallet = _walletProvider.getWalletById(walletId);
      final metadata = wallet.hotWalletMetadata;
      final walletBase = wallet.walletBase;
      if (metadata == null || walletBase is! SingleSignatureWallet) throw StateError('Local signer is not available');

      final feeAddress = await _arkProvider.directExitFeeAddress(walletId);
      final built =
          TransactionBuilder(
            availableUtxos:
                _selectedUtxos.isNotEmpty
                    ? _selectedUtxos
                    : [
                      for (final utxo in _walletProvider.getUtxoList(walletId))
                        if (utxo.status == UtxoStatus.unspent) utxo,
                    ],
            recipients: {feeAddress: estimate.fundingSats},
            feeRate: estimate.feeRateSatPerVb.toDouble(),
            changeDerivationPath: _walletProvider.getChangeAddress(walletId).derivationPath,
            walletItemBase: wallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: _selectedUtxos.isNotEmpty,
          ).build();
      if (built.isFailure) throw built.exception ?? StateError('Funding transaction was not built');

      final prepared = await prepareUnsignedPsbt(transaction: built.transaction!, wallet: walletBase);
      final signed = await _signingService.sign((
        storageKey: metadata.secureStorageKey,
        passphrase: passphrase,
        addressTypeName: walletBase.addressType.name,
        accountIndex: metadata.accountIndex,
        expectedExtendedPublicKey: walletBase.keyStore.extendedPublicKey.serialize(),
        unsignedPsbt: prepared.serialized,
      ));
      final signedTx = Psbt.parse(signed).getSignedTransaction(walletBase.addressType);
      TransactionIntentValidator.ensureMatches(prepared.psbt.unsignedTransaction, signedTx);

      final broadcast = await _nodeProvider.broadcast(signedTx);
      if (broadcast.isFailure) throw broadcast.error;
      try {
        await _utxoRepository.markUnspentInputsAsOutgoing(walletId, signedTx);
      } catch (error) {
        Logger.error('ArkExitViewModel: funding sent, but marking inputs failed: $error');
      }

      final destination = receiveAddress;
      await _arkProvider.beginDirectExit(
        ArkExitSession(
          walletId: walletId,
          vtxoIds: estimate.vtxoIds,
          amountSats: estimate.amountSats,
          destination: destination.address,
          destinationPath: destination.derivationPath,
          fundingTxid: broadcast.value,
          fundingSats: estimate.fundingSats,
          feeRateSatPerVb: estimate.feeRateSatPerVb,
          firstExpiryHeight: estimate.firstExpiryHeight,
          startedAt: DateTime.now(),
        ),
      );
      unawaited(_requestNotificationPermission());
    } finally {
      _isStarting = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// 완료·실패를 확인하고 기록을 지움
  Future<void> dismiss() => _arkProvider.dismissDirectExit(walletId);

  Future<void> _requestNotificationPermission() async {
    final notifications = _notifications;
    if (notifications == null) return;
    try {
      _notificationsAllowed = await notifications.requestPermission();
    } catch (_) {
      _notificationsAllowed = false;
    }
    if (!_disposed) notifyListeners();
  }

  ArkExitStep? _lastStep;

  void _onArkChanged() {
    if (_disposed) return;
    final current = step;
    if (current == ArkExitStep.waiting && _lastStep != ArkExitStep.waiting && _notificationsAllowed == null) {
      unawaited(_requestNotificationPermission());
    }
    _lastStep = current;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (session case final finished? when !finished.isActive) unawaited(_arkProvider.dismissDirectExit(walletId));
    _arkProvider.removeListener(_onArkChanged);
    super.dispose();
  }
}
