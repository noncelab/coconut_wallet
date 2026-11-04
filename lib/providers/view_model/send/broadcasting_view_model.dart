import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/network_constants.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
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
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/network_util.dart';
import 'package:coconut_wallet/utils/progressive_connection_wait.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/services/transaction/broadcast_transaction_service.dart';
import 'package:flutter/foundation.dart';

class InvalidTransactionException implements Exception {
  final String message;
  InvalidTransactionException([this.message = 'Invalid transaction']);

  @override
  String toString() => 'InvalidSignedTransactionException: $message';
}

class BroadcastingViewModel extends ChangeNotifier {
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
  bool _isSendCancelled = false;
  Completer<void>? _connectionPreparationStop;
  bool _connectionWaitDeclined = false;
  bool _isConnectionRecovering = false;

  /// 노드 요청 전 연결 준비가 연결 확인 제한 시간을 넘겨 이어지는 중인지. 화면은 이때 지연 안내를 띄우고 이탈을 허용한다.
  bool get isConnectionRecovering => _isConnectionRecovering;
  bool get connectionWaitDeclined => _connectionWaitDeclined;
  bool _isBroadcastRequested = false;
  bool _isConfirmingBroadcast = false;

  /// 노드 요청의 응답이 실패해 거래 ID로 전송 여부를 확인하는 중인지. 결과를 모르므로 화면을 떠날 수 없다.
  bool get isConfirmingBroadcast => _isConfirmingBroadcast;
  bool _isInBackground = false;
  Completer<void>? _foreground;
  bool _stoppedInBackground = false;

  /// 노드 요청 전에 앱이 백그라운드로 가서 이번 보내기를 멈췄는지.
  bool get stoppedInBackground => _stoppedInBackground;
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

  /// 화면을 떠날 때 부른다. 아직 노드에 전송을 요청하지 않았으면 이후 전송을 막고 true를 돌려준다.
  /// 이미 요청했으면 취소할 수 없으므로 false를 돌려주며, 화면은 결과를 기다려야 한다.
  bool cancelPendingSend() {
    if (_isBroadcastRequested) return false;
    _isSendCancelled = true;
    _stopConnectionPreparation();
    return true;
  }

  /// 앱이 백그라운드로 가면 부른다. 노드 요청 전이면 이번 보내기를 멈춘다. 같은 거래는 다시 보내도 안전하다.
  /// 요청 후라면 결과 확인을 앱이 돌아올 때까지 미룬다.
  void onAppPaused() {
    if (_isInBackground) return;
    _isInBackground = true;
    _foreground = Completer<void>();
    final stop = _connectionPreparationStop;
    if (!_isBroadcastRequested && stop != null && !stop.isCompleted) {
      Logger.log('[Send] 앱이 백그라운드로 전환되어 요청 전 보내기 중단');
      _stoppedInBackground = true;
      stop.complete();
    }
  }

  void onAppResumed() {
    if (!_isInBackground) return;
    _isInBackground = false;
    _foreground?.complete();
    _foreground = null;
  }

  @override
  void dispose() {
    // 화면이 다른 경로로 사라져도 대기 중이던 보내기가 나중에 전송되지 않도록 한다.
    _isSendCancelled = true;
    _stopConnectionPreparation();
    super.dispose();
  }

  void _stopConnectionPreparation() {
    final stop = _connectionPreparationStop;
    if (stop != null && !stop.isCompleted) stop.complete();
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
  Future<Result<String>> broadcast({
    required List<String> inheritedTagIds,
    ConnectionWaitExtension? onConnectionWaitExtension,
    Future<void> Function()? beforeRequest,
  }) async {
    final candidates = prepareTagInheritance().map((tag) => tag.id).toSet();
    final selectedIds = inheritedTagIds.toSet();
    if (selectedIds.length > 5 || !candidates.containsAll(selectedIds)) {
      throw ArgumentError('Invalid inherited tag selection');
    }
    _tagInheritanceFailed = false;
    _connectionWaitDeclined = false;
    _stoppedInBackground = false;
    Logger.log('BroadcastingViewModel: signedTx = ${_signedTx!.serialize()}');
    final endpoint = _nodeProvider.connectionEndpointIdentity;
    final stop = Completer<void>();
    _connectionPreparationStop = stop;
    final isOnion = isOnionHost(_nodeProvider.host);
    final limits = isOnion ? kSendConnectionWaitLimitsForOnion : kSendConnectionWaitLimits;
    // 연결 확인 시간 안에 준비되면 지연으로 보지 않는다. 확인이 바로 실패해도 이 시간이 지나야 지연 안내를 띄운다.
    final delayNotice = Timer(isOnion ? kSendConnectionCheckTimeoutForOnion : kSendConnectionCheckTimeout, () {
      if (!stop.isCompleted) _setConnectionRecovering(true);
    });
    try {
      final prepared = await waitForConnection(
        Future.any<Result<bool>>([
          _prepareConnectionForSend(stop, endpoint),
          stop.future.then((_) => Result.failure(ErrorCodes.nodeConnectionError)),
        ]),
        limits: limits,
        onExtend:
            onConnectionWaitExtension == null
                ? null
                : (limit, finished) async {
                  if (_isSendCancelled) return false;
                  final extend = await onConnectionWaitExtension(limit, finished);
                  _connectionWaitDeclined = !extend;
                  return extend;
                },
      );
      if (_stoppedInBackground) return Result.failure(ErrorCodes.nodeConnectionError);
      if (prepared.isFailure) return Result.failure(prepared.error);
      if (!prepared.value) return Result.failure(ErrorCodes.nodeConnectionError);
    } on TimeoutException {
      Logger.log('[Send] 연결 준비 대기 종료');
      return Result.failure(ErrorCodes.nodeConnectionError);
    } finally {
      delayNotice.cancel();
      if (!stop.isCompleted) stop.complete();
      if (identical(_connectionPreparationStop, stop)) _connectionPreparationStop = null;
      _setConnectionRecovering(false);
    }

    if (!identical(endpoint, _nodeProvider.connectionEndpointIdentity) || _nodeProvider.isServerChanging) {
      return Result.failure(ErrorCodes.nodeConnectionError);
    }
    if (_isSendCancelled) return _cancelledSend();
    // 화면이 요청 직전에 끝내야 할 일(예: 진행 중인 뒤로 가기 제스처)을 기다린다.
    if (beforeRequest != null) await beforeRequest();
    // 사용자가 떠난 보내기는 연결이 늦게 준비돼도 전송하지 않는다.
    // 이 검사와 요청 표시 사이에 await를 두지 않아야 취소와 전송이 엇갈리지 않는다.
    if (_isSendCancelled) return _cancelledSend();
    if (_isInBackground) {
      Logger.log('[Send] 앱이 백그라운드로 전환되어 요청 전 보내기 중단');
      _stoppedInBackground = true;
      return Result.failure(ErrorCodes.nodeConnectionError);
    }
    _isBroadcastRequested = true;
    Logger.log('[Send] 브로드캐스팅 시작');
    var result = await _nodeProvider.broadcast(_signedTx!);
    if (result.isFailure && !_isExplicitRejection(result.error)) {
      // 응답을 받지 못했으면 노드가 거래를 받았을 수 있다. 실패로 알리기 전에 거래 ID로 확인한다.
      result = await _confirmAfterFailedRequest(result.error);
    }
    if (result.isFailure) {
      _isBroadcastRequested = false;
      return result;
    }

    try {
      final tagApplication = _utxoRepository.applyInheritedTags(
        _walletId!,
        sourceUtxoIds: _tagSourceUtxoIds,
        targetUtxoIds: _outputIndexesToMyAddress.map((index) => getUtxoId(_signedTx!.transactionHash, index)).toList(),
        tagIds: selectedIds.toList(),
      );
      // Observe completion on the original future so late success refreshes tags too.
      final observed = tagApplication.then((applied) {
        if (applied.isFailure) throw applied.error;
        _tagProvider.notifyTagsChanged();
      });
      await observed.timeout(kSendLocalProcessingTimeout);
    } catch (e) {
      // The node already accepted this transaction; a local tag error must not invite a resend.
      _tagInheritanceFailed = true;
      Logger.error('Transaction sent, but tag inheritance failed: $e');
    }
    return result;
  }

  /// 노드가 거래를 받아 명시적으로 거절한 응답인지. 이때만 결과 확인 없이 실패로 확정한다.
  /// 이미 받은 거래라는 거절은 사실상 전송된 것이므로 거래 ID 확인으로 넘긴다.
  bool _isExplicitRejection(AppError error) {
    if (error.code != ErrorCodes.broadcastError.code) return false;
    final message = error.message.toLowerCase();
    const alreadyKnown = [
      'already in mempool',
      'already-in-mempool',
      'txn-already-known',
      'already known',
      'already in block chain',
      'already in blockchain',
      'outputs already in utxo set',
    ];
    return !alreadyKnown.any(message.contains);
  }

  /// 요청의 응답을 받지 못했거나 이미 받은 거래라는 응답이면, 노드에 거래가 있는지 거래 ID로 확인한다.
  /// - 거래가 있으면 성공으로 본다.
  /// - 끝까지 찾지 못하면 [ErrorCodes.broadcastUnconfirmed]를 돌려준다. 조회 실패와 '거래 없음'은 구분하지 않는다.
  ///   노드가 거절했다는 응답 없이 실패를 확정하면, 이미 전송된 거래를 실패로 알려 새 거래를 만들게 할 수 있기 때문이다.
  ///   같은 거래를 다시 보내는 것은 안전하므로 확인 불가 안내는 다시 보내기를 권한다.
  /// 앱이 백그라운드에 있으면 돌아올 때까지 확인을 미룬다.
  Future<Result<String>> _confirmAfterFailedRequest(AppError requestError) async {
    final txHash = _signedTx!.transactionHash;
    final isOnion = isOnionHost(_nodeProvider.host);
    final delays = isOnion ? kSendBroadcastConfirmRetryDelaysForOnion : kSendBroadcastConfirmRetryDelays;
    // 연결 복구가 끝나지 않아도 확인이 멈추지 않게 한 번의 복구 대기에 상한을 둔다.
    final recoveryLimit = isOnion ? kSendConnectionWaitLimitsForOnion.first : kSendConnectionWaitLimits.first;
    Logger.log('[Send] 전송 응답 실패(${requestError.code}), 거래 ID로 전송 여부 확인: $txHash');
    _setConfirmingBroadcast(true);
    try {
      for (var attempt = 0; ; attempt++) {
        await _foreground?.future;
        if (await _isTransactionOnNode(txHash)) {
          Logger.log('[Send] 노드에서 거래 확인, 전송 성공으로 처리: $txHash');
          return Result.success(txHash);
        }
        // 연결 상태는 복구가 필요한지 판단하는 데만 쓴다. 전송 여부의 근거로 쓰지 않는다.
        if (!await _isNodeReachable()) {
          try {
            await _nodeProvider.ensureConnectedForBroadcast().timeout(recoveryLimit);
          } catch (e) {
            Logger.error('[Send] 전송 결과 확인 중 연결 복구 실패: $e');
          }
        }
        if (attempt >= delays.length) break;
        await Future<void>.delayed(delays[attempt]);
      }
      Logger.error('[Send] 전송 결과를 확인하지 못함: $txHash');
      return Result.failure(ErrorCodes.broadcastUnconfirmed);
    } finally {
      _setConfirmingBroadcast(false);
    }
  }

  Future<bool> _isTransactionOnNode(String txHash) async {
    try {
      return (await _nodeProvider.getTransaction(txHash)).isSuccess;
    } catch (e) {
      Logger.error('[Send] 거래 조회 실패: $e');
      return false;
    }
  }

  Future<bool> _isNodeReachable() async {
    try {
      return (await _nodeProvider.getLatestBlock()).isSuccess;
    } catch (_) {
      return false;
    }
  }

  void _setConfirmingBroadcast(bool value) {
    if (_isConfirmingBroadcast == value) return;
    _isConfirmingBroadcast = value;
    if (!_isSendCancelled) notifyListeners();
  }

  void _setConnectionRecovering(bool value) {
    if (_isConnectionRecovering == value) return;
    _isConnectionRecovering = value;
    if (!_isSendCancelled) notifyListeners();
  }

  Future<Result<bool>> _prepareConnectionForSend(Completer<void> stop, Object endpoint) async {
    bool active() =>
        !stop.isCompleted &&
        !_isSendCancelled &&
        !_nodeProvider.isServerChanging &&
        identical(endpoint, _nodeProvider.connectionEndpointIdentity);
    Logger.log('[Send] 연결 확인 시작');
    final connected = await isElectrumServerConnected();
    if (!active()) return Result.failure(ErrorCodes.nodeConnectionError);
    if (connected) return Result.success(true);
    final delays = isOnionHost(_nodeProvider.host) ? kSendRecoveryRetryDelaysForOnion : kSendRecoveryRetryDelays;
    var failures = 0;
    while (active()) {
      Logger.log('[Send] 전송용 연결 복구 시도 ${failures + 1}');
      Result<bool> result;
      try {
        // Await a pending recovery without restarting it. Only a returned failure
        // triggers a retry; the caller's absolute deadline stops this loop.
        result = await _nodeProvider.ensureConnectedForBroadcast();
      } on TimeoutException {
        result = Result.failure(ErrorCodes.nodeIsolateError);
      } on AppError catch (error) {
        result = Result.failure(error);
      }
      if (!active()) return Result.failure(ErrorCodes.nodeConnectionError);
      if (result.isSuccess) return result;
      final retryable = {
        ErrorCodes.networkError.code,
        ErrorCodes.nodeConnectionError.code,
        ErrorCodes.nodeIsolateError.code,
      }.contains(result.error.code);
      if (!retryable) return result;
      final delay = delays[failures < delays.length ? failures : delays.length - 1];
      failures++;
      Logger.log('[Send] 연결 복구 실패, ${delay.inSeconds}초 후 재시도: ${result.error.code}');
      final elapsed = Completer<void>();
      final timer = Timer(delay, () => elapsed.complete());
      try {
        await Future.any<void>([elapsed.future, stop.future]);
      } finally {
        timer.cancel();
      }
    }
    return Result.failure(ErrorCodes.nodeConnectionError);
  }

  /// 화면을 떠나 취소된 보내기의 결과. 화면이 없으므로 사용자에게 표시되지 않는다.
  Result<String> _cancelledSend() {
    Logger.log('[Send] 화면을 떠나 전송 취소');
    return Result.failure(ErrorCodes.nodeConnectionError);
  }

  Future<bool> isElectrumServerConnected() async {
    final isOnion = isOnionHost(_nodeProvider.host);

    final timeout = isOnion ? kSendConnectionCheckTimeoutForOnion : kSendConnectionCheckTimeout;

    try {
      final result = await _nodeProvider.getLatestBlock().timeout(timeout);

      return result.isSuccess;
    } on TimeoutException {
      Logger.log('[Send] 연결 확인 시간 초과: ${timeout.inSeconds}s');
      return false;
    } catch (e) {
      Logger.log('[Send] 연결 확인 실패: $e');
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

    final signedPayload = _sendInfoProvider.signedResult!;
    final signedIsPsbt = isPsbt(signedPayload);
    final prepared = await prepareBroadcastTransaction(
      originalPsbt: _sendInfoProvider.txWaitingForSign!,
      signedPayload: signedIsPsbt ? signedPayload : decodeTransactionToHex(signedPayload),
      signedIsPsbt: signedIsPsbt,
      wallet: _wallet,
    );
    if (_isSendCancelled) return null;
    _signedTx = prepared.transaction;
    _outputIndexesToMyAddress.clear();
    for (var i = 0; i < _signedTx!.outputs.length; i++) {
      if (prepared.originalOutputOwned[i] ||
          _walletProvider.containsAddress(_walletId!, _signedTx!.outputs[i].getAddress())) {
        _outputIndexesToMyAddress.add(i);
      }
    }
    // input UTXO 유효성 검증 (단, feeBumping일 때는 제외)
    final inputUtxoIds = _signedTx!.inputs.map((input) => getUtxoId(input.transactionHash, input.index)).toList();
    final (_, excludedUtxoStatus) =
        isFromSignedDraft
            ? _utxoRepository.getValidatedSelectedUtxoList(_walletId!, inputUtxoIds)
            : (inputUtxoIds, null);

    final psbt = prepared.psbt;

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
          isChange: prepared.outputChange[outputIndex],
        ),
      );
      if (prepared.outputChange[outputIndex]) {
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
      if (!prepared.outputOwned[i]) {
        outputsToOther.add(outputs[i]);
      } else if (prepared.outputChange[i]) {
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
      _sendingAmount = prepared.sendingAmount;
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

      _sendingAmount = prepared.sendingAmount;
      if (output != null) {
        _recipientAddresses.add(output.outAddress);
      }
    }
    _fee = prepared.fee;
    _totalAmount = prepared.sendingAmount + prepared.fee;

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
    }

    return result;
  }

  /// 브로드캐스트 성공 후 관련 draft 삭제
  /// - _sendInfoProvider.unsignedDraftId: 보내기 화면에서 불러온 서명 전 트랜잭션 삭제
  /// - _signedDraftId: 화면 매개변수로 받은 서명 완료 트랜잭션 삭제 (불러오기)
  /// - _savedDraftId: 이 화면에서 임시 저장한 서명 완료 트랜잭션 삭제
  /// (_signedDraftId와 _savedDraftId는 동시에 존재하지 않음)
  /// 이미 전송된 트랜잭션의 후처리이므로 지연·실패가 완료 흐름을 막지 않도록
  /// [kSendLocalProcessingTimeout]까지만 기다리고, 오류는 기록만 한다. (삭제 작업은 시간 초과 후에도 계속된다)
  Future<void> deleteDraftsIfNeeded() async {
    try {
      await _deleteDrafts().timeout(kSendLocalProcessingTimeout);
    } catch (e) {
      Logger.error('Transaction sent, but draft cleanup did not finish: $e');
    }
  }

  Future<void> _deleteDrafts() async {
    // 서명 전 트랜잭션 삭제
    if (_sendInfoProvider.unsignedDraftId != null) {
      try {
        await _txDraftRepository.deleteOne(_sendInfoProvider.unsignedDraftId!);
      } catch (e) {
        Logger.error('Failed to delete unsigned draft: $e');
      }
    }

    final signedDraftIdToDelete = _signedDraftId ?? _savedDraftId;
    if (signedDraftIdToDelete != null) {
      try {
        await _txDraftRepository.deleteOne(signedDraftIdToDelete);
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
