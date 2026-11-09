import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/consensus_constants.dart';
import 'package:coconut_wallet/constants/network_constants.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/repository/realm/payjoin_session_repository.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_psbt.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_send_attempt.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_sender.dart' show PayjoinCheckedProposal;
import 'package:coconut_wallet/services/payjoin/payjoin_signer.dart';
import 'package:coconut_wallet/services/security/hot_wallet_signing_service.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/utils/transaction_intent_validator.dart';
import 'package:flutter/material.dart';

class InvalidTransactionException implements Exception {
  final String message;
  InvalidTransactionException([this.message = 'Invalid transaction']);

  @override
  String toString() => 'InvalidSignedTransactionException: $message';
}

class BroadcastingViewModel extends ChangeNotifier {
  /// 전송 실패 사유를 사용자 안내 문구로 변환 (모르는 사유는 원문 그대로)
  static String broadcastFailureMessage(Object error) {
    final reason = error.toString();
    if (reason.contains('min relay fee not met')) return t.alert.error_send.insufficient_fee;
    if (reason.contains('missingorspent') || reason.contains('txn-mempool-conflict')) {
      return t.alert.error_send.used_utxo_included;
    }
    if (reason.contains('premature-spend-of-coinbase')) {
      final depth = RegExp(r'spend coinbase at depth (\d+)').firstMatch(reason)?.group(1);
      final remaining = depth == null ? 0 : kCoinbaseMaturity - int.parse(depth);
      return remaining > 0
          ? t.alert.error_send.immature_coinbase_remaining(count: remaining)
          : t.alert.error_send.immature_coinbase;
    }
    return reason;
  }

  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late final UtxoTagProvider _tagProvider;
  late final NodeProvider _nodeProvider;
  late final TransactionProvider _txProvider;
  late final TransactionDraftRepository _txDraftRepository;
  late final UtxoRepository _utxoRepository;
  late final int? _signedDraftId;
  WalletBase? _walletBase;
  int? _walletId;
  late bool? _isNetworkOn;
  bool _isInitDone = false;
  bool _isSendingToMyAddress = false;
  final List<String> _recipientAddresses = [];
  int? _sendingAmount;
  int? _fee;
  int? _totalAmount;
  int? _sendingAmountWhenAddressIsMyChange; // 내 지갑의 change address로 보내는 경우 잔액
  int _inputCount = 0;
  int? _inputTotalAmount;
  final List<int?> _inputAmounts = [];
  final List<int> _externalOutputAmounts = [];
  final List<int> _changeOutputAmounts = [];
  final List<BroadcastingOutputDetailItem> _outputDetailItems = [];
  final List<int> _outputIndexesToMyAddress = [];
  final List<String> _tagSourceUtxoIds = [];
  List<UtxoTag>? _inheritanceTags;
  bool _tagInheritanceFailed = false;
  bool _isBroadcastDispatched = false;
  bool _isBroadcastResultUnknown = false;
  bool _isTransactionAccepted = false;
  bool _isDisposed = false;
  Completer<void>? _pendingBroadcastCancel;
  ({PayjoinSessionRepository repository, String id})? _payjoinSession;
  Transaction? _signedTx;
  int? _savedDraftId;

  BroadcastingViewModel(
    this._sendInfoProvider,
    this._walletProvider,
    this._tagProvider,
    this._isNetworkOn,
    this._nodeProvider,
    this._txProvider,
    this._txDraftRepository,
    this._utxoRepository,
    this._signedDraftId,
  );

  List<String> get recipientAddresses => UnmodifiableListView(_recipientAddresses);

  int? get amount => _sendingAmountWhenAddressIsMyChange ?? _sendingAmount;
  int? get fee => _fee;
  bool get isInitDone => _isInitDone;
  bool get isNetworkOn => _isNetworkOn == true;
  bool get isSendingToMyAddress => _isSendingToMyAddress;
  int? get sendingAmountWhenAddressIsMyChange => _sendingAmountWhenAddressIsMyChange;
  int? get totalAmount => _totalAmount;
  int get inputCount => _inputCount;
  int? get inputTotalAmount => _inputTotalAmount;
  List<int?> get inputAmounts => UnmodifiableListView(_inputAmounts);
  List<int> get externalOutputAmounts => UnmodifiableListView(_externalOutputAmounts);
  List<int> get changeOutputAmounts => UnmodifiableListView(_changeOutputAmounts);
  List<BroadcastingOutputDetailItem> get outputDetailItems => UnmodifiableListView(_outputDetailItems);
  AddressType? get walletAddressType => _walletBase?.addressType;
  WalletBase get _wallet => _walletBase!;
  int? get walletId => _walletId;
  SendEntryPoint? get sendEntryPoint => _sendInfoProvider.sendEntryPoint;
  FeeBumpingType? get feeBumpingType => _sendInfoProvider.feeBumpingType;

  int? get unsignedDraftId => _sendInfoProvider.unsignedDraftId;
  Transaction? get signedTx => _signedTx;
  bool get isFromSignedDraft => _signedDraftId != null;
  bool get isAlreadySaved => isFromSignedDraft || _savedDraftId != null;
  bool get canUseTransactionDrafts {
    final walletId = _walletId ?? _sendInfoProvider.walletId;
    return walletId != null && !_walletProvider.getWalletById(walletId).hasLocalKey;
  }

  bool get tagInheritanceFailed => _tagInheritanceFailed;

  /// 노드에 거래를 넘긴 뒤 (결과를 기다리는 중이거나 성공)
  bool get isBroadcastDispatched => _isBroadcastDispatched;

  /// 마지막 송금이 노드에 들어갔는지 끝내 확인하지 못함
  bool get isBroadcastResultUnknown => _isBroadcastResultUnknown;

  /// 노드가 받은 것으로 확인된 거래 (결과 확인 필요 안내 뒤 늦게 확인된 경우 포함)
  bool get isTransactionAccepted => _isTransactionAccepted;

  /// 노드에 넘기기 전인 송금 취소 (이미 넘긴 거래는 되돌릴 수 없음)
  void cancelPendingBroadcast() {
    if (_isBroadcastDispatched) return;
    final cancel = _pendingBroadcastCancel ??= Completer<void>();
    if (!cancel.isCompleted) cancel.complete();
  }

  /// The receiver's BIP 21 URI when this send tries a payjoin first.
  String? get payjoinUri => feeBumpingType == null && !isFromSignedDraft ? _sendInfoProvider.payjoinUri : null;

  /// The signed, finalized Original: the transaction a payjoin replaces, and
  /// the one to send if it does not happen. Coconut Vault returns its
  /// signatures unfinalized, so they are finalized here.
  String? get signedOriginalPsbt {
    final signed = _sendInfoProvider.signedResult;
    if (signed == null || !isPsbt(signed)) return signed;
    return finalizeOriginalForPayjoin(signed);
  }

  String get walletName => _walletProvider.getWalletById(_walletId!).name;

  PayjoinSigner? get payjoinSigner => payjoinSignerOf(_walletProvider.getWalletById(_walletId!));

  /// The receiver's proposal as Coconut Vault gets it for the second
  /// signature: the receiver's input final, ours with their key origins.
  String payjoinProposalForVault(PayjoinCheckedProposal proposal) {
    final wallet = _walletProvider.getWalletById(_walletId!).walletBase as SingleSignatureWallet;
    return addOwnDerivations(
      proposal.psbtBase64,
      wallet: wallet,
      derivationPathOf: (address) => _walletProvider.derivationPathOf(_walletId!, address),
    );
  }

  double? get feeRate => _sendInfoProvider.feeRate;

  bool _isPayjoinProposalApplied = false;
  bool get isPayjoinProposalApplied => _isPayjoinProposalApplied;

  /// Signs our inputs of the receiver's payjoin proposal with the hot wallet.
  Future<String> signPayjoinProposal(PayjoinCheckedProposal proposal) {
    final walletItem = _walletProvider.getWalletById(_walletId!);
    final metadata = walletItem.hotWalletMetadata;
    final wallet = walletItem.walletBase;
    if (metadata == null || wallet is! SingleSignatureWallet) {
      throw StateError('Only a hot single-signature wallet signs payjoin proposals');
    }
    final unsignedPsbt = addOwnDerivations(
      proposal.psbtBase64,
      wallet: wallet,
      derivationPathOf: (address) => _walletProvider.derivationPathOf(_walletId!, address),
    );
    return HotWalletSigningService().signAndFinalize(
      (
        storageKey: metadata.secureStorageKey,
        passphrase: null,
        addressTypeName: wallet.addressType.name,
        accountIndex: metadata.accountIndex,
        expectedExtendedPublicKey: wallet.keyStore.extendedPublicKey.serialize(),
        unsignedPsbt: unsignedPsbt,
      ),
      allowFinalizedForeignInputs: true,
      keepDerivations: false,
    );
  }

  /// Makes the signed payjoin proposal the transaction this screen sends.
  ///
  /// The receiver's input changes the totals: we now pay the transfer, our
  /// part of the original fee and the fee contribution payjoin allowed the
  /// receiver to take from our change.
  void applyPayjoinProposal(String signedProposalPsbt, PayjoinCheckedProposal checked) {
    final original = Psbt.parse(_sendInfoProvider.txWaitingForSign!);
    final proposal = Psbt.parse(signedProposalPsbt).getSignedTransaction(walletAddressType!);
    bool isOurs(TransactionOutput output) => _walletProvider.containsAddress(_walletId!, output.getAddress());
    TransactionIntentValidator.ensurePayjoinProposalMatches(
      original.unsignedTransaction,
      proposal,
      checked,
      isOwnOutput: isOurs,
    );

    final ourInputs = original.inputs.fold<int>(0, (sum, input) => sum + input.witnessUtxo!.amount);
    final ourOutputs = proposal.outputs.where(isOurs).fold<int>(0, (sum, output) => sum + output.amount);
    _signedTx = proposal;
    _outputIndexesToMyAddress
      ..clear()
      ..addAll([
        for (var i = 0; i < proposal.outputs.length; i++)
          if (isOurs(proposal.outputs[i])) i,
      ]);
    _totalAmount = ourInputs - ourOutputs;
    _fee = _totalAmount! - (_sendingAmount ?? 0);
    _isPayjoinProposalApplied = true;
    notifyListeners();
  }

  List<UtxoTag> prepareTagInheritance() {
    if (!_isInitDone) throw StateError('Transaction is not ready');
    if (_inheritanceTags != null) return _inheritanceTags!;

    final sourceIds = _signedTx!.inputs.map((input) => getUtxoId(input.transactionHash, input.index)).toSet();
    final replacedHashes = <String>{};
    for (final sourceId in sourceIds) {
      final input = _utxoRepository.getUtxoState(_walletId!, sourceId);
      final spentBy = input?.spentByTransactionHash;
      if (input?.status != UtxoStatus.outgoing || spentBy == null || spentBy == _signedTx!.transactionHash) continue;
      final previous = _txProvider.getTransactionRecord(_walletId!, spentBy);
      if (previous != null && previous.blockHeight < 1) replacedHashes.add(spentBy);
    }

    final result = _utxoRepository.getUtxoTags(_walletId!);
    if (result.isFailure) throw result.error;
    final tags = result.value;
    // A broadcast can have tag links before sync creates the predecessor's output rows.
    for (final tag in tags) {
      for (final id in tag.utxoIdList ?? <String>[]) {
        if (id.length > 64 &&
            replacedHashes.contains(id.substring(0, 64)) &&
            RegExp(r'^\d+$').hasMatch(id.substring(64))) {
          sourceIds.add(id);
        }
      }
    }
    _tagSourceUtxoIds.addAll(sourceIds);
    _inheritanceTags = List.unmodifiable(
      _outputIndexesToMyAddress.isEmpty
          ? <UtxoTag>[]
          : tags.where((tag) => tag.utxoIdList?.any(sourceIds.contains) == true),
    );
    return _inheritanceTags!;
  }

  bool get isTaprootScriptPathWallet {
    final walletId = _sendInfoProvider.walletId;
    if (walletId == null) return false;
    try {
      final wallet = _walletProvider.getWalletById(walletId);
      return wallet is TaprootWalletItem && wallet.defaultSpendType == TaprootSpendType.scriptPath;
    } catch (_) {
      return false;
    }
  }

  /// Electrum 브로드캐스트 실패 시 [Result]의 `error` getter(`AppError`)에 담기는 에러 코드
  /// - `1004` [ErrorCodes.nodeConnectionError]: `IsolateManager`에서 명령 전 소켓 상태 선검사 실패·종료
  /// - `1301` [ErrorCodes.nodeIsolateError]: isolate 미준비·준비 대기 타임아웃·isolate 응답 타임아웃 등
  /// - `1300` [ErrorCodes.nodeUnknown]: 메인 isolate 브리지의 기타 예외, 또는 isolate가 `Result`가 아닌 `Exception`을 보낸 경우(`IsolateController` 최상위 catch 등)
  /// - `1302` [ErrorCodes.broadcastError]: isolate 내부 Electrum broadcast RPC 실패(메시지에 상세 포함 가능)
  ///
  /// `failureStage`는 디버그용 [Logger]에 기록되는 구간 라벨이다.
  ///
  /// 노드에 넘기기 전에 [cancelPendingBroadcast]로 취소되면 `null`
  Future<Result<String>?> broadcast({required List<String> inheritedTagIds}) async {
    final candidates = prepareTagInheritance().map((tag) => tag.id).toSet();
    final selectedIds = inheritedTagIds.toSet();
    if (selectedIds.length > 5 || !candidates.containsAll(selectedIds)) {
      throw ArgumentError('Invalid inherited tag selection');
    }
    final cancel = _pendingBroadcastCancel ??= Completer<void>();
    try {
      return await _broadcast(selectedIds, cancel);
    } finally {
      if (identical(_pendingBroadcastCancel, cancel)) _pendingBroadcastCancel = null;
    }
  }

  Future<Result<String>?> _broadcast(Set<String> selectedIds, Completer<void> cancel) async {
    Future<T?> unlessCancelled<T>(Future<T> work) => Future.any<T?>([work, cancel.future.then<T?>((_) => null)]);

    _tagInheritanceFailed = false;
    _isBroadcastResultUnknown = false;
    final unsignedDraftId = _sendInfoProvider.unsignedDraftId;
    Future<void> finalize() => _finalizeAcceptedTransaction(selectedIds, unsignedDraftId);
    Logger.log('BroadcastingViewModel: signedTx = ${_signedTx!.serialize()}');
    final connectionWaitLimit =
        _nodeProvider.host.contains('.onion')
            ? kBroadcastConnectionWaitTimeoutForOnion
            : kBroadcastConnectionWaitTimeout;
    final isConnected = await unlessCancelled(
      _waitForConnection().timeout(connectionWaitLimit, onTimeout: () => false),
    );
    if (cancel.isCompleted) return null;
    if (isConnected != true) {
      return Result.failure(
        AppError(ErrorCodes.nodeConnectionError.code, t.broadcasting_screen.dialog.not_sent_no_connection),
      );
    }

    _isBroadcastDispatched = true;
    notifyListeners();
    var result = await _nodeProvider.broadcast(_signedTx!);
    if (result.isFailure && _isUnknownOutcome(result.error)) {
      result = await _confirmUnansweredBroadcast(connectionWaitLimit, onLateSuccess: finalize);
      _isBroadcastResultUnknown = result.isFailure && _isUnknownOutcome(result.error);
    }
    if (result.isFailure) {
      _isBroadcastDispatched = false;
      if (!_isDisposed) notifyListeners();
      return result;
    }

    await finalize();
    return result;
  }

  /// 노드가 받은 거래의 후처리: 입력 표시, 태그 상속, 관련 임시저장 삭제
  Future<void> _finalizeAcceptedTransaction(Set<String> selectedIds, int? unsignedDraftId) async {
    _isTransactionAccepted = true;
    _closePayjoinSession();
    await _markInputsAsOutgoing();

    try {
      final applied = await _utxoRepository.applyInheritedTags(
        _walletId!,
        sourceUtxoIds: _tagSourceUtxoIds,
        targetUtxoIds: _outputIndexesToMyAddress.map((index) => getUtxoId(_signedTx!.transactionHash, index)).toList(),
        tagIds: selectedIds.toList(),
      );
      if (applied.isFailure) throw applied.error;
      _tagProvider.notifyTagsChanged();
    } catch (e) {
      // The node already accepted this transaction; a local tag error must not invite a resend.
      _tagInheritanceFailed = true;
      Logger.error('Transaction sent, but tag inheritance failed: $e');
    }

    await _deleteDrafts(unsignedDraftId, _signedDraftId ?? _savedDraftId);
    if (!_isDisposed) notifyListeners();
  }

  /// 노드가 거절한 실패와 달리 응답을 받지 못해 전송 여부를 모르는 실패
  static bool _isUnknownOutcome(AppError error) =>
      error.code == ErrorCodes.nodeIsolateError.code || error.code == ErrorCodes.nodeUnknown.code;

  /// 노드에 들어갔는지 조회하고, 없으면 같은 거래를 한 번 더 보냄 (같은 txid라 중복 전송 없음)
  Future<Result<String>> _confirmUnansweredBroadcast(Duration limit, {required Future<void> Function() onLateSuccess}) {
    final txid = _signedTx!.transactionHash;
    final unknown = Result<String>.failure(
      AppError(ErrorCodes.nodeIsolateError.code, t.broadcasting_screen.dialog.result_unknown),
    );
    var expired = false;
    Future<Result<String>> confirm() async {
      if (!await _waitForConnection() || expired) return unknown;
      if ((await _nodeProvider.getTransaction(txid)).isSuccess) return Result.success(txid);
      if (expired || _isDisposed) return unknown;
      final resent = await _nodeProvider.broadcast(_signedTx!);
      return resent.isFailure && _isUnknownOutcome(resent.error) ? unknown : resent;
    }

    final attempt = confirm();
    // 확인 제한 시간이 지난 뒤에야 성공이 확인된 거래의 후처리
    attempt.then((late) async {
      if (expired && late.isSuccess) await onLateSuccess();
    }).ignore();
    return attempt.timeout(
      limit,
      onTimeout: () {
        expired = true;
        return unknown;
      },
    );
  }

  /// Offers the receiver of [payjoinUri] a payjoin and returns whether its
  /// proposal, signed by [signProposal], replaced the Original as the
  /// transaction to send. On a fallback, an error, or a [signProposal] that
  /// returns null, the Original stays, and the receiver accepts it as well.
  Future<bool> attemptPayjoin(
    PayjoinSessionRepository sessions,
    PayjoinSendAttempt attempt, {
    required Future<String?> Function(PayjoinCheckedProposal proposal) signProposal,
  }) async {
    PayjoinSendOutcome? outcome;
    try {
      outcome = await attempt.run(
        walletId: _walletId!,
        bip21: payjoinUri!,
        signedOriginalPsbt: signedOriginalPsbt!,
        originalTxHex: _signedTx!.serialize(),
        feeRateSatPerVb: feeRate ?? 1,
      );
      switch (outcome) {
        case PayjoinSendProposal(:final proposal):
          final signed = await signProposal(proposal);
          if (signed == null) {
            Logger.log('Payjoin proposal not signed, sending the Original');
            return false;
          }
          applyPayjoinProposal(signed, proposal);
          return true;
        case PayjoinSendFallsBack(:final reason):
          Logger.log('Payjoin not used: $reason');
          return false;
      }
    } catch (e) {
      Logger.error('Payjoin attempt failed, sending the Original: $e');
      return false;
    } finally {
      final sessionId = outcome?.sessionId;
      if (sessionId != null) settlePayjoinSessionOnAccept(sessions, sessionId);
    }
  }

  /// Records which payjoin send session this screen's transaction settles,
  /// whether that transaction is the receiver's proposal or the Original.
  /// The session is closed once the node accepts the transaction, so the
  /// Original is not broadcast again when the app next starts.
  void settlePayjoinSessionOnAccept(PayjoinSessionRepository sessions, String sessionId) {
    _payjoinSession = (repository: sessions, id: sessionId);
  }

  void _closePayjoinSession() {
    final session = _payjoinSession;
    if (session == null) return;
    try {
      session.repository
        ..writeValue(session.id, PayjoinSendValues.broadcastTxid, _signedTx!.transactionHash)
        ..markClosed(session.id);
    } catch (e) {
      Logger.error('Transaction sent, but closing the payjoin session failed: $e');
    }
  }

  Future<void> _markInputsAsOutgoing() async {
    try {
      await _utxoRepository.markUnspentInputsAsOutgoing(_walletId!, _signedTx!);
    } catch (e) {
      Logger.error('Transaction sent, but marking inputs as outgoing failed: $e');
    }
  }

  Future<bool> _waitForConnection() async =>
      await isElectrumServerConnected() || await _nodeProvider.reconnectWithoutWaitingForSync();

  Future<bool> isElectrumServerConnected() async {
    try {
      // getLatestBlock 호출하여 실제 네트워크 연결 상태 확인
      final result = await _nodeProvider.getLatestBlock();

      if (result.isSuccess) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  /// 전달된 문자열이 Base64로 인코딩된 PSBT인지 확인하는 함수
  bool isPsbt(String signedTransaction) {
    try {
      List<int> decoded;
      // 이미 Base64인지 확인
      if (RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(signedTransaction)) {
        decoded = base64Decode(signedTransaction);
      } else {
        // Base64가 아닌 경우 UTF-8 바이트로 변환
        decoded = utf8.encode(signedTransaction);
      }

      bool isPsbtResult =
          decoded.length >= 5 &&
          decoded[0] == 0x70 &&
          decoded[1] == 0x73 &&
          decoded[2] == 0x62 &&
          decoded[3] == 0x74 &&
          decoded[4] == 0xff;

      return isPsbtResult;
    } catch (_) {
      return false;
    }
  }

  Future<SelectedUtxoExcludedStatus?> setTxInfo() async {
    if (isFromSignedDraft) {
      await _setSendProviderFromSignedDraft(_signedDraftId!);
    }

    _walletBase = _walletProvider.getWalletById(_sendInfoProvider.walletId!).walletBase;
    _walletId = _sendInfoProvider.walletId!;

    final originalPsbt = Psbt.parse(_sendInfoProvider.txWaitingForSign!);
    final expectedTransaction = originalPsbt.unsignedTransaction;
    late final Psbt signedPsbt;
    if (isPsbt(_sendInfoProvider.signedResult!)) {
      signedPsbt = Psbt.parse(_sendInfoProvider.signedResult!);
      TransactionIntentValidator.ensureMatches(expectedTransaction, signedPsbt.unsignedTransaction);

      final finalizedTransaction = signedPsbt.getSignedTransaction(walletAddressType!);
      TransactionIntentValidator.ensureMatches(expectedTransaction, finalizedTransaction);
      _signedTx = finalizedTransaction;
    } else {
      try {
        signedPsbt = originalPsbt;

        // raw transaction 데이터 처리 (hex 또는 base64)
        final hexTransaction = decodeTransactionToHex(_sendInfoProvider.signedResult!);
        final signedTx = Transaction.parse(hexTransaction);
        TransactionIntentValidator.ensureMatches(expectedTransaction, signedTx);

        _signedTx = signedTx;
      } catch (e) {
        Logger.log('--> BroadcastingViewModel.setTxInfo: raw transaction processing error: $e');
        rethrow;
      }
    }
    _outputIndexesToMyAddress.clear();
    for (var i = 0; i < _signedTx!.outputs.length; i++) {
      if (originalPsbt.outputs[i].isOwnedBy(_wallet) ||
          _walletProvider.containsAddress(_walletId!, _signedTx!.outputs[i].getAddress())) {
        _outputIndexesToMyAddress.add(i);
      }
    }
    // input UTXO 유효성 검증 (단, feeBumping일 때는 제외)
    final inputUtxoIds = _signedTx!.inputs.map((input) => getUtxoId(input.transactionHash, input.index)).toList();
    final (_, excludedUtxoStatus) =
        isFromSignedDraft || feeBumpingType == null
            ? _utxoRepository.getValidatedSelectedUtxoList(_walletId!, inputUtxoIds)
            : (inputUtxoIds, null);

    //_debugPrintSendInfoProvider();

    Psbt psbt;
    if (_hasAllInputsBip32Derivation(signedPsbt)) {
      psbt = signedPsbt;
    } else {
      psbt = Psbt.parse(_sendInfoProvider.txWaitingForSign!);
    }

    List<PsbtOutput> outputs = psbt.outputs;
    _inputCount = _signedTx?.inputs.length ?? 0;
    _inputTotalAmount = _signedTx?.totalInputAmount;
    _inputAmounts
      ..clear()
      ..addAll(psbt.inputs.map((input) => input.witnessUtxo?.amount));
    _externalOutputAmounts.clear();
    _changeOutputAmounts.clear();
    _outputDetailItems.clear();
    for (final (outputIndex, output) in outputs.indexed) {
      final amount = output.outAmount;
      if (amount == null) {
        continue;
      }
      _outputDetailItems.add(
        BroadcastingOutputDetailItem(
          outputIndex: outputIndex,
          address: output.outAddress,
          amount: amount,
          isChange: output.isChange(_wallet),
        ),
      );
      if (output.isChange(_wallet)) {
        _changeOutputAmounts.add(amount);
      } else {
        _externalOutputAmounts.add(amount);
      }
    }

    // case1. 다른 사람에게 보내고(B1) 잔액이 있는 경우(A2)
    // case2. 다른 사람에게 보내고(B1) 잔액이 없는 경우
    // case3. 내 지갑의 다른 주소로 보내고(A2) 잔액이 있는 경우(A3)
    // case4. 내 지갑의 다른 주소로 보내고(A2) 잔액이 없는 경우
    // 만약 실수로 내 지갑의 change address로 보내는 경우에는 sendingAmount가 0
    List<PsbtOutput> outputToMyReceivingAddress = [];
    List<PsbtOutput> outputToMyChangeAddress = [];
    List<PsbtOutput> outputsToOther = [];
    for (int i = 0; i < outputs.length; i++) {
      if (!outputs[i].isOwnedBy(_wallet)) {
        outputsToOther.add(outputs[i]);
      } else if (outputs[i].isChange(_wallet)) {
        outputToMyChangeAddress.add(outputs[i]);
      } else {
        outputToMyReceivingAddress.add(outputs[i]);
      }
    }

    if (_isBatchTransaction(outputToMyReceivingAddress, outputToMyChangeAddress, outputsToOther)) {
      Map<String, double> recipientAmounts = {};
      if (outputsToOther.isNotEmpty) {
        for (var output in outputsToOther) {
          recipientAmounts[output.outAddress] = UnitUtil.convertSatoshiToBitcoin(output.outAmount!);
        }
      }
      if (outputToMyReceivingAddress.isNotEmpty) {
        for (var output in outputToMyReceivingAddress) {
          recipientAmounts[output.outAddress] = UnitUtil.convertSatoshiToBitcoin(output.outAmount!);
        }
        _isSendingToMyAddress = true;
      }
      if (outputToMyChangeAddress.length > 1) {
        for (int i = outputToMyChangeAddress.length - 1; i > 0; i--) {
          var output = outputToMyChangeAddress[i];
          recipientAmounts[output.outAddress] = UnitUtil.convertSatoshiToBitcoin(output.outAmount!);
        }
      }
      _sendingAmount = psbt.sendingAmount(_wallet);
      _recipientAddresses.addAll(recipientAmounts.entries.map((e) => '${e.key} (${e.value} ${t.btc})'));
    } else {
      PsbtOutput? output;
      if (outputsToOther.isNotEmpty) {
        output = outputsToOther[0];
      } else if (outputToMyReceivingAddress.isNotEmpty) {
        /// DEPRECATED:2025.07.01 받는 주소가 내 지갑의 receive adress여도 outputs[i].bip32Derivation == null로 설정되고 있어 항상 첫번째 if문을 거침
        output = outputToMyReceivingAddress[0];
        _isSendingToMyAddress = true;
      } else if (outputToMyChangeAddress.isNotEmpty) {
        /// DEPRECATED: 2025.07.01 받는 주소가 내 지갑의 change address여도 outputs[i].bip32Derivation == null로 설정되고 있어 항상 첫번째 if문을 거침

        // 받는 주소에 내 지갑의 change address를 입력한 경우
        // 원래 이 경우 output.sendingAmount = 0, 보낼 주소가 표기되지 않았었지만, 버그처럼 보이는 문제 때문에 대응합니다.
        // (주의!!) coconut_lib에서 output 배열에 sendingOutput을 먼저 담으므로 항상 첫번째 것을 사용하면 전액 보내기일 때와 아닐 때 모두 커버 됨
        // 하지만 coconut_lib에 종속적이므로 coconut_lib에 변경 발생 시 대응 필요

        output = outputToMyChangeAddress[0];
        _sendingAmountWhenAddressIsMyChange = output.outAmount;
        _isSendingToMyAddress = true;
      }

      _sendingAmount = psbt.sendingAmount(_wallet);
      if (output != null) {
        _recipientAddresses.add(output.outAddress);
      }
    }
    _fee = psbt.fee;
    _totalAmount = psbt.sendingAmount(_wallet) + psbt.fee;

    if (excludedUtxoStatus == null) {
      _isInitDone = true;
    }
    notifyListeners();
    return excludedUtxoStatus;
  }

  void clearSendInfo() {
    _sendInfoProvider.clear();
  }

  ///예외: 사용자가 배치 트랜잭션에 '남의 주소 또는 내 Receive 주소 1개'와 '본인 change 주소 1개'를 입력하고, 이 트랜잭션의 잔액이 없는 희박한 상황에서는 배치 트랜잭션임을 구분하지 못함
  bool _isBatchTransaction(
    List<PsbtOutput> outputToMyReceivingAddress,
    List<PsbtOutput> outputToMyChangeAddress,
    List<PsbtOutput> outputsToOther,
  ) {
    var countExceptToMyChangeAddress = outputToMyReceivingAddress.length + outputsToOther.length;
    if (countExceptToMyChangeAddress >= 2) {
      return true;
    }
    if (outputToMyChangeAddress.length >= 3) {
      return true;
    }
    if (outputToMyChangeAddress.length == 2 && countExceptToMyChangeAddress >= 1) {
      return true;
    }

    return false;
  }

  // pending상태였던 Tx가 confirmed 되었는지 조회
  bool hasTransactionConfirmed() {
    return _txProvider.hasTransactionConfirmed(walletId!, _txProvider.transaction!.transactionHash);
  }

  bool _hasAllInputsBip32Derivation(Psbt psbt) {
    return psbt.inputs.every((input) => input.bip32Derivation != null);
  }

  /// 트랜잭션 문자열을 hex 형식으로 디코딩하는 헬퍼 메서드
  String decodeTransactionToHex(String signedTransaction) {
    try {
      // 먼저 hex 문자열인지 확인
      if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(signedTransaction)) {
        // 이미 hex 문자열인 경우
        return signedTransaction;
      } else {
        // 콜드카드의 경우 Base64로 넘겨주기 때문에 이를 Hex로 변경
        final bytes = base64.decode(signedTransaction);
        final decodedString = String.fromCharCodes(bytes);

        if (decodedString.startsWith('303230')) {
          // ASCII 문자열이 Hex로 인코딩된 경우, 실제 Hex로 변환
          final hexResult = String.fromCharCodes(
            List.generate(decodedString.length ~/ 2, (i) {
              return int.parse(decodedString.substring(i * 2, i * 2 + 2), radix: 16);
            }),
          );
          return hexResult;
        } else {
          final hexResult = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

          return hexResult;
        }
      }
    } catch (e) {
      throw InvalidTransactionException('Failed to decode transaction: $e');
    }
  }

  Future<void> _setSendProviderFromSignedDraft(int draftId) async {
    final result = await _txDraftRepository.getSignedDraft(draftId);
    if (result.isFailure) {
      throw result.error.message;
    }
    assert(result.value.isSigned);
    final TransactionDraft draft = result.value;
    if (_walletProvider.getWalletById(draft.walletId).hasLocalKey) {
      throw StateError('Transaction drafts are not supported for hot wallets');
    }
    clearSendInfo();
    _sendInfoProvider.setWalletId(draft.walletId);
    _sendInfoProvider.setFeeRate(draft.feeRate);
    _sendInfoProvider.setIsMaxMode(draft.isMaxMode);
    _sendInfoProvider.setTxWaitingForSign(draft.txWaitingForSign!);
    _sendInfoProvider.setSignedResult(draft.signedPsbtBase64Encoded!);
  }

  Future<Result<TransactionDraft>> saveTransactionDraft() async {
    if (!canUseTransactionDrafts) {
      throw StateError('Transaction drafts are not supported for this wallet');
    }
    final result = await _txDraftRepository.saveSignedDraft(
      walletId: walletId!,
      recipients:
          _sendInfoProvider
              .getRecipientMap()!
              .entries
              .map((entry) => RecipientDraft(address: entry.key, amount: entry.value))
              .toList(),
      feeRate: _sendInfoProvider.feeRate!,
      isMaxMode: _sendInfoProvider.isMaxMode!,
      txWaitingForSign: _sendInfoProvider.txWaitingForSign!,
      signedPsbtBase64Encoded: _sendInfoProvider.signedResult!,
    );

    if (result.isSuccess) {
      _savedDraftId = result.value.id;
      // 저장이 끝나기 전에 노드가 받은 것으로 확인된 거래의 임시저장
      if (_isTransactionAccepted) await _deleteDrafts(null, _savedDraftId);
    }

    return result;
  }

  /// 브로드캐스트 성공 후 관련 draft 삭제
  /// - unsignedDraftId: 보내기 화면에서 불러온 서명 전 트랜잭션 (송금 시작 시점의 ID)
  /// - signedDraftId: 화면 매개변수로 받았거나(_signedDraftId) 이 화면에서 임시 저장한(_savedDraftId) 서명 완료 트랜잭션
  Future<void> _deleteDrafts(int? unsignedDraftId, int? signedDraftId) async {
    if (unsignedDraftId != null) {
      try {
        await _txDraftRepository.deleteOne(unsignedDraftId);
      } catch (e) {
        Logger.error('Failed to delete unsigned draft: $e');
      }
    }

    if (signedDraftId != null) {
      try {
        await _txDraftRepository.deleteOne(signedDraftId);
      } catch (e) {
        Logger.error('Failed to delete signed draft: $e');
      }
    }
  }

  Future<void> deleteSignedDraft() async {
    final signedDraftIdToDelete = _signedDraftId ?? _savedDraftId;
    assert(signedDraftIdToDelete != null);
    await _txDraftRepository.deleteOne(signedDraftIdToDelete!);
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    cancelPendingBroadcast();
    _isDisposed = true;
    super.dispose();
  }

  // ignore: unused_element
  void _debugPrintSendInfoProvider() {
    debugPrint('------- sendInfoProvider ------');
    debugPrint('walletId: $_walletId');
    debugPrint('transactionDraftId: ${_sendInfoProvider.unsignedDraftId}');
    debugPrint('signedPsbt: ${_sendInfoProvider.signedResult}');
    debugPrint('txWaitingForSign: ${_sendInfoProvider.txWaitingForSign}');
    debugPrint('walletId: ${_sendInfoProvider.walletId}');
    debugPrint('walletBase: $_walletBase');
    debugPrint('walletAddressType: ${_walletBase!.addressType}');
    debugPrint('-------------------------------');
  }
}

class BroadcastingOutputDetailItem {
  final int outputIndex;
  final String address;
  final int amount;
  final bool isChange;

  const BroadcastingOutputDetailItem({
    required this.outputIndex,
    required this.address,
    required this.amount,
    required this.isChange,
  });
}
