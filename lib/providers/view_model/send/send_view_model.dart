import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/extensions/double_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/ark/ark_payment.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/node_provider/wallet_sync_watcher.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fee_rate_mixin.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/payment_request_parser.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/utils/wallet_util.dart';
import 'package:coconut_wallet/widgets/features/ark/ark_texts.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

typedef WalletInfoUpdateCallback =
    void Function(WalletItemBase walletItem, List<UtxoState> selectedUtxoList, bool isUtxoSelectionAuto);

enum AddressError {
  none,
  invalid,
  invalidNetworkAddress,
  duplicated,
  unsupportedRequest,
  arkWalletOnly,
  onchainOnly,
  ownWallet;

  bool get isError => this != AddressError.none;
  bool get isNotError => this == AddressError.none;

  String getMessage() {
    switch (this) {
      case AddressError.invalid:
        return t.errors.address_error.invalid;
      case AddressError.duplicated:
        return t.errors.address_error.duplicated;
      case AddressError.invalidNetworkAddress:
        {
          if (NetworkType.currentNetworkType == NetworkType.testnet) {
            return t.errors.address_error.not_for_testnet;
          } else if (NetworkType.currentNetworkType == NetworkType.mainnet) {
            return t.errors.address_error.not_for_mainnet;
          } else if (NetworkType.currentNetworkType == NetworkType.regtest) {
            return t.errors.address_error.not_for_regtest;
          } else {
            throw "Unknown network type";
          }
        }
      case AddressError.unsupportedRequest:
        return t.errors.address_error.invalid;
      case AddressError.arkWalletOnly:
        return t.ark.send.ark_wallet_only;
      case AddressError.onchainOnly:
        return t.ark.send.onchain_only;
      case AddressError.ownWallet:
        return t.ark.send.own_wallet;
      case AddressError.none:
        return "";
    }
  }
}

enum AmountError {
  none,
  insufficientBalance,
  minimumAmount;

  bool get isError => this != AmountError.none;
  bool get isNotError => this == AmountError.none;

  String getMessage(BitcoinUnit currentUnit, {required int dustThreshold}) {
    switch (this) {
      case AmountError.insufficientBalance:
        return t.errors.insufficient_balance;
      case AmountError.minimumAmount:
        return t.alert.error_send.minimum_amount(
          amount: currentUnit.displayBitcoinAmount(dustThreshold + 1, withUnit: true),
        );
      case AmountError.none:
        return "";
    }
  }
}

/// 비트코인 주소에 두 잔액 모두 보낼 수 있을 때 사용자가 고르는 잔액
enum SendSource { onchain, ark }

/// 아크 잔액에서 보내는 경로
class ArkSendRoute {
  const ArkSendRoute(this.rail, this.destination, {this.invoiceHasAmount = false});

  final ArkPaymentRail rail;
  final String destination;
  final bool invoiceHasAmount;

  bool get isLightning => rail == ArkPaymentRail.lightningInvoice || rail == ArkPaymentRail.lightningAddress;

  @override
  bool operator ==(Object other) =>
      other is ArkSendRoute &&
      other.rail == rail &&
      other.destination == destination &&
      other.invoiceHasAmount == invoiceHasAmount;

  @override
  int get hashCode => Object.hash(rail, destination, invoiceHasAmount);
}

class SendViewModel extends ChangeNotifier with FeeRateMixin {
  final WalletProvider _walletProvider;
  final ArkProvider? _arkProvider;
  final SendInfoProvider _sendInfoProvider;
  final PreferenceProvider _preferenceProvider;
  final TransactionDraftRepository _transactionDraftRepository;
  final UtxoRepository _utxoRepository;
  final NodeProvider _nodeProvider;

  late final WalletSyncWatcher _walletSyncWatcher;
  bool _isDisposed = false;

  /// 선택한 지갑이 업데이트 중이면 UTXO 선택과 거래 생성을 기다림 (다른 지갑의 업데이트와는 무관)
  bool get isWalletSyncing => _walletSyncWatcher.isSyncing;

  int _excludedUtxoNonce = 0;
  SelectedUtxoExcludedStatus? _lastExcludedUtxoStatus;

  /// 업데이트 후 직접 고른 UTXO가 빠질 때마다 증가
  int get excludedUtxoNonce => _excludedUtxoNonce;
  SelectedUtxoExcludedStatus? get lastExcludedUtxoStatus => _lastExcludedUtxoStatus;

  // send_screen: _amountController, _feeRateController, _recipientPageController
  final Function(String) _onAmountTextUpdate;
  final Function(String) _onFeeRateTextUpdate;
  final Function(int) _onRecipientPageDeleted;

  late List<UtxoState> _allUtxos; // unspent, outgoing, incoming, locked 다 포함

  bool _isMaxMode = false;
  bool get isMaxMode => _isMaxMode;
  bool get isBatchMode => recipientList.length >= 2;

  // 수신자 정보
  List<RecipientInfo> _recipientList = [];
  List<RecipientInfo> get recipientList => _recipientList;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  int get lastIndex => _recipientList.length - 1;
  int get addRecipientCardIndex => _recipientList.length;

  bool _showAddressBoard = false;
  bool get showAddressBoard => _showAddressBoard;

  int _amountSum = 0;
  String get amountSumText => _currentUnit.displayBitcoinAmount(_amountSum, withUnit: true);

  WalletItemBase? _selectedWalletItem;
  late bool _isUtxoSelectionAuto;

  /// 이번 송금에 대한 spend 경로 override. null = wallet 의 defaultSpendType 사용.
  /// 둘 다 가능한 지갑에 한해 send_screen 토글(미구현)에서 setter 호출.
  TaprootSpendType? _taprootSpendType;
  TaprootSpendType? get taprootSpendType => _taprootSpendType;
  bool get canChooseTaprootSpendType {
    final w = _selectedWalletItem;
    return w is TaprootWalletItem && w.canSpendBothPaths;
  }

  void setTaprootSpendType(TaprootSpendType type) {
    if (_taprootSpendType == type) return;
    _taprootSpendType = type;
    _buildTransaction();
    notifyListeners();
  }

  bool _isFeeSubtractedFromSendAmount = false;
  bool _previousIsFeeSubtractedFromSendAmount = false;
  bool get isFeeSubtractedFromSendAmount => _isFeeSubtractedFromSendAmount;

  List<UtxoState> _selectedUtxoList = [];
  List<UtxoState> get selectedUtxoList => _selectedUtxoList;
  int get selectedUtxoListLength => _selectedUtxoList.length;
  int get selectedUtxoAmountSum => _selectedUtxoList.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);

  /// 사용자가 설정한 순서대로 정렬한 지갑 목록
  late List<WalletItemBase> _orderedRegisteredWallets;
  List<WalletItemBase> get orderedRegisteredWallets => _orderedRegisteredWallets;

  List<bool> _walletAddressNeedsUpdate = [];
  Map<int, WalletAddressInfo> _registeredWalletAddressMap = {};
  Map<int, WalletAddressInfo> get registeredWalletAddressMap => _registeredWalletAddressMap;

  WalletItemBase? get selectedWalletItem => _selectedWalletItem;

  int get selectedWalletId => _selectedWalletItem != null ? _selectedWalletItem!.id : -1;
  bool get isUtxoSelectionAuto => _isUtxoSelectionAuto;

  TransactionBuilder? _txBuilder;
  String _feeRateText = "";
  String _changeAddressDerivationPath = "";

  int? _estimatedFee;
  int? get estimatedFeeInSats => _estimatedFee;
  double get _estimatedFeeByUnit {
    int estimatedFeeInInt = _estimatedFee ?? 0;
    return _currentUnit.fromSatoshi(estimatedFeeInInt);
  }

  bool _isFeeRateLowerThanMin = false;
  bool get isFeeRateLowerThanMin => _isFeeRateLowerThanMin;

  late bool? _isNetworkOn;
  late BitcoinUnit _currentUnit;
  int _confirmedBalance = 0;
  int _incomingBalance = 0;

  int get balance {
    return _isUtxoSelectionAuto ? _confirmedBalance : selectedUtxoAmountSum;
  }

  int get incomingBalance => _incomingBalance;

  AmountError _isAmountSumExceedsBalance = AmountError.none;
  AmountError _isLastAmountInsufficient = AmountError.none;

  String _finalErrorMessage = "";
  String get finalErrorMessage => _finalErrorMessage;

  bool get isTotalSendAmountExceedsBalance => _isAmountSumExceedsBalance.isError;
  bool get isLastAmountInsufficient => _isLastAmountInsufficient.isError;

  bool _showFeeBoard = false;
  bool get showFeeBoard => _showFeeBoard;

  bool get isBtcUnit => _currentUnit.isBtcUnit;
  BitcoinUnit get currentUnit => _currentUnit;
  bool get isSatsUnit => _currentUnit.isSatsUnit;

  bool get isNetworkOn => _isNetworkOn == true;
  num get _dustLimitDenominator => (_currentUnit.isBasedOnSatoshi ? 1 : 1e8);
  int get _dustThreshold =>
      _selectedWalletItem != null ? _selectedWalletItem!.walletType.addressType.dustThreshold : DustThresholds.p2wsh;
  bool get isAmountDisabled => (_isMaxMode || _isArkMaxMode) && _currentIndex == lastIndex;
  bool get isEstimatedFeeGreaterThanBalance => balance < (_estimatedFee ?? 0);
  bool get hasValidRecipient => validRecipientList.isNotEmpty;

  int? _unintendedDustFee;
  int? get unintendedDustFee => _unintendedDustFee;

  TransactionBuildResult? _txBuildResult;
  int? _transactionDraftId;

  List<RecipientInfo> get validRecipientList {
    return _recipientList
        .where(
          (e) =>
              e.address.isNotEmpty &&
              e.amount.isNotEmpty &&
              e.addressError.isNotError &&
              e.minimumAmountError.isNotError,
        )
        .toList();
  }

  Map<String, int> get recipientMap {
    final Map<String, int> recipientMap = {};
    for (final recipient in validRecipientList) {
      recipientMap[_onchainAddressOf(recipient.address)] = _currentUnit.toSatoshi(double.parse(recipient.amount));
    }
    return recipientMap;
  }

  double get _amountSumExceptLast {
    double sumExceptLast = 0;
    for (int i = 0; i < lastIndex; ++i) {
      if (_recipientList[i].amount.isNotEmpty) {
        sumExceptLast += double.parse(_recipientList[i].amount);
      }
    }
    return sumExceptLast.roundTo8Digits();
  }

  bool _hasUnvalidatedInput = false;

  SendSource? _chosenSource;
  bool _isArkMaxMode = false;
  bool get isArkMaxMode => _isArkMaxMode;

  /// 라이트닝 주소로 보낼 때 함께 보내는 메모
  String lightningComment = '';

  /// 받는 사람 문자열별 "이 지갑 자신의 아크 주소·인보이스인지" 확인 결과
  final Map<String, bool> _ownRequestChecks = {};

  void _checkOwnRequest(String address, PaymentRequest request) {
    if (_ownRequestChecks.containsKey(address) || !isArkWallet) return;
    if (request.arkAddress == null && request.lightningInvoice == null) return;
    _ownRequestChecks[address] = false;
    final walletId = _selectedWalletItem!.id;
    _arkProvider!.isOwnPaymentRequest(walletId, request).then((isOwn) {
      if (_isDisposed || !isOwn || walletId != selectedWalletId) return;
      _ownRequestChecks[address] = true;
      _validateRecipientInputs();
      notifyListeners();
    });
  }

  int? _arkFee;
  bool _isEstimatingArkFee = false;
  bool _arkFeeFailed = false;
  bool _arkServerDown = false;
  ArkSendRoute? _estimatedRoute;
  int? _estimatedAmount;
  Timer? _arkFeeTimer;

  bool get isArkWallet {
    final wallet = _selectedWalletItem;
    return wallet != null && _arkProvider != null && _arkProvider.supportsArk(wallet);
  }

  bool get isArkLocked => isArkWallet && !_arkProvider!.isOpen(_selectedWalletItem!.id);
  int get arkSendableSats => isArkWallet ? _arkProvider!.sendableSats(_selectedWalletItem!.id) : 0;
  int get arkOffboardableSats => isArkWallet ? _arkProvider!.offboardableSats(_selectedWalletItem!.id) : 0;

  /// 아크·라이트닝으로 보낼 아크 잔액은 모자라지만 온체인 잔액이면 충분할 때(아크로 옮겨야 함)
  bool get _onchainCouldCover {
    final route = arkRoute;
    if (route == null || route.rail == ArkPaymentRail.onchain) return false;
    final amount = _amountSatsAt(0) ?? 0;
    return amount > 0 && amount < balance;
  }

  /// 아크 잔액이 모자라지만 만료된 잔액을 갱신하면 보낼 수 있을 때
  bool get arkShortfallNeedsRefresh {
    if (arkRoute == null || _isArkMaxMode || _isAmountSumExceedsBalance.isNotError) return false;
    final amount = _amountSatsAt(0) ?? 0;
    return amount + (_arkFee ?? 0) <= arkOffboardableSats;
  }

  int? get arkFee => _arkFee;
  bool get isEstimatingArkFee => _isEstimatingArkFee;
  int? get arkPaymentAmountSats => _amountSatsAt(0);

  /// 고르지 않았으면 온체인, 아크·라이트닝이 담긴 결제 요청은 아크
  SendSource get selectedSource =>
      _chosenSource ?? (_hasOffchainOption(_requestAt(0)) ? SendSource.ark : SendSource.onchain);

  bool _hasOffchainOption(PaymentRequest? request) =>
      request != null && request.arkOptions.any((option) => option.rail != ArkPaymentRail.onchain);

  PaymentRequest? _requestAt(int index) {
    final address = _recipientList[index].address.trim();
    return address.isEmpty ? null : PaymentRequest.parse(address, NetworkType.currentNetworkType);
  }

  int? _amountSatsAt(int index) {
    final amount = double.tryParse(_recipientList[index].amount);
    return amount == null || amount <= 0 ? null : _currentUnit.toSatoshi(amount);
  }

  /// BIP321로 받은 주소면 그 안의 비트코인 주소
  String _onchainAddressOf(String address) {
    if (!address.toLowerCase().startsWith('bitcoin:')) return address;
    return PaymentRequest.parse(address, NetworkType.currentNetworkType).bitcoinAddress ?? address;
  }

  /// 아크·라이트닝 경로가 없는 비트코인 주소에 두 잔액 모두 보낼 수 있을 때
  bool get canChooseSource {
    if (!isArkWallet || _recipientList.length != 1 || _isMaxMode || _isArkMaxMode || !_isUtxoSelectionAuto) {
      return false;
    }
    final request = _requestAt(0);
    final amount = _amountSatsAt(0);
    if (request == null || request.bitcoinAddress == null || amount == null) return false;
    return amount < balance && amount <= arkSendableSats;
  }

  /// 아크 잔액에서 보낼 때의 경로, 온체인으로 보내면 null
  ArkSendRoute? get arkRoute {
    if (!isArkWallet || _recipientList.length != 1 || _isMaxMode) return null;
    final request = _requestAt(0);
    if (request == null || !request.isPayable) return null;
    if (_isArkMaxMode) {
      if (request.arkAddress != null) return ArkSendRoute(ArkPaymentRail.ark, request.arkAddress!);
      if (request.bitcoinAddress != null) return ArkSendRoute(ArkPaymentRail.onchain, request.bitcoinAddress!);
      return null;
    }
    final amount = _amountSatsAt(0);
    final arkFits = amount == null || amount <= arkSendableSats;
    final offchain = request.arkOptions.where((option) => option.rail != ArkPaymentRail.onchain).firstOrNull;
    final address = request.bitcoinAddress;
    if (offchain != null && canChooseSource && selectedSource == SendSource.onchain) return null;
    if (offchain != null && (arkFits || address == null)) {
      return ArkSendRoute(
        offchain.rail,
        offchain.destination,
        invoiceHasAmount: offchain.rail == ArkPaymentRail.lightningInvoice && request.invoiceAmountSats != null,
      );
    }
    if (address == null || amount == null || !arkFits || !_isUtxoSelectionAuto) return null;
    if (canChooseSource) return selectedSource == SendSource.ark ? ArkSendRoute(ArkPaymentRail.onchain, address) : null;
    return amount >= balance ? ArkSendRoute(ArkPaymentRail.onchain, address) : null;
  }

  /// 주소란 아래에 보여 줄 받는 사람 종류, 비트코인 주소는 null
  String? requestKindLabel(int index) {
    if (!isArkWallet || index < 0 || index >= _recipientList.length) return null;
    final request = _requestAt(index);
    return switch (request?.kind) {
      PaymentRequestKind.arkAddress => t.ark.request.ark_address,
      PaymentRequestKind.lightningInvoice => [
        t.ark.receive.lightning_invoice,
        if (request!.invoiceDescription case final memo?) memo,
      ].join(' · '),
      PaymentRequestKind.lightningAddress => t.ark.request.lightning_address,
      // 결제 요청은 실제로 보낼 경로
      PaymentRequestKind.bip321 => switch (index == 0 ? arkRoute?.rail : null) {
        ArkPaymentRail.ark => t.ark.request.ark_address,
        ArkPaymentRail.lightningInvoice => t.ark.receive.lightning_invoice,
        ArkPaymentRail.lightningAddress => t.ark.request.lightning_address,
        _ => t.ark.request.bitcoin_address,
      },
      PaymentRequestKind.bitcoinAddress => t.ark.request.bitcoin_address,
      _ => null,
    };
  }

  /// 금액이 담긴 라이트닝 인보이스는 금액을 고칠 수 없음
  bool isAmountLocked(int index) {
    if (!isArkWallet || index < 0 || index >= _recipientList.length) return false;
    final request = _requestAt(index);
    return request?.kind == PaymentRequestKind.lightningInvoice && request?.invoiceAmountSats != null;
  }

  /// 모두 보내기로 쓸 수 있는 잔액, 잔액이 있는 쪽만
  List<SendSource> maxSources(int index) {
    if (!isArkWallet || index < 0 || index >= _recipientList.length) return const [SendSource.onchain];
    final request = _requestAt(index);
    final single = _recipientList.length == 1;
    final hasOnchain = balance > 0;
    final hasArk = single && arkSendableSats > 0;
    final hasOffboardable = single && arkOffboardableSats > 0;
    if (request == null) {
      if (hasOnchain || !hasOffboardable) return const [SendSource.onchain];
      return const [SendSource.ark];
    }
    if (request.amountSats != null) return const [];
    return [
      if (request.bitcoinAddress != null && (hasOnchain || !hasOffboardable)) SendSource.onchain,
      if ((request.bitcoinAddress != null && hasOffboardable) || (request.arkAddress != null && hasArk)) SendSource.ark,
    ];
  }

  void setArkMaxMode(bool isEnabled) {
    if (_isArkMaxMode == isEnabled) return;
    if (isEnabled && _isMaxMode) setMaxMode(false);
    _isArkMaxMode = isEnabled;
    _recipientList[lastIndex].amount = '';
    if (_currentIndex == lastIndex) _onAmountTextUpdate('');
    _arkFee = null;
    _estimatedRoute = null;
    _estimatedAmount = null;
    _validateRecipientInputs();
    vibrateLight();
    notifyListeners();
  }

  /// 받는 사람이 바뀌어 지금 모두 보내기 잔액으로 보낼 수 없으면 다른 잔액의 모두 보내기로 옮김
  void _reconcileMaxMode() {
    if (!isArkWallet || _recipientList.isEmpty) return;
    if (_requestAt(lastIndex)?.isPayable == false) return;
    final sources = maxSources(lastIndex);
    if (_isMaxMode && !sources.contains(SendSource.onchain)) {
      _isMaxMode = false;
      _isFeeSubtractedFromSendAmount = _previousIsFeeSubtractedFromSendAmount;
      _isArkMaxMode = sources.contains(SendSource.ark);
      _arkFee = null;
      _estimatedRoute = null;
      _estimatedAmount = null;
      _recipientList[lastIndex].amount = '';
      if (_currentIndex == lastIndex) _onAmountTextUpdate('');
    } else if (_isArkMaxMode && !sources.contains(SendSource.ark)) {
      _isArkMaxMode = false;
      _recipientList[lastIndex].amount = '';
      if (_currentIndex == lastIndex) _onAmountTextUpdate('');
      if (sources.contains(SendSource.onchain)) {
        _isMaxMode = true;
        _previousIsFeeSubtractedFromSendAmount = _isFeeSubtractedFromSendAmount;
        _isFeeSubtractedFromSendAmount = true;
      }
    }
  }

  /// 아크 모두 보내기: 수수료를 뺀 금액을 받는 사람 금액으로
  void _applyArkMaxAmount() {
    final fee = _arkFee;
    final base = arkRoute?.rail == ArkPaymentRail.onchain ? arkOffboardableSats : arkSendableSats;
    final sats = fee == null ? 0 : base - fee;
    final text =
        fee == null || sats <= 0
            ? ''
            : (_currentUnit.isBasedOnSatoshi ? sats.toString() : UnitUtil.convertSatoshiToBitcoinString(sats));
    _recipientList[lastIndex].amount = text;
    if (_currentIndex == lastIndex) _onAmountTextUpdate(text);
  }

  void setSource(SendSource source) {
    if (selectedSource == source) return;
    _chosenSource = source;
    vibrateLight();
    _validateRecipientInputs();
    notifyListeners();
  }

  void _scheduleArkFeeEstimate() {
    final route = arkRoute;
    final maxBase = route?.rail == ArkPaymentRail.onchain ? arkOffboardableSats : arkSendableSats;
    final amount = _isArkMaxMode ? (maxBase > 0 ? maxBase : null) : _amountSatsAt(0);
    if (route == null || amount == null || isArkLocked) {
      _arkFeeTimer?.cancel();
      _arkFee = null;
      _isEstimatingArkFee = false;
      _arkFeeFailed = false;
      _arkServerDown = false;
      return;
    }
    if (route == _estimatedRoute && amount == _estimatedAmount && (_arkFee != null || _isEstimatingArkFee)) return;
    _arkFeeTimer?.cancel();
    _arkFee = null;
    _arkFeeFailed = false;
    _arkServerDown = false;
    _isEstimatingArkFee = true;
    _estimatedRoute = route;
    _estimatedAmount = amount;
    final walletId = _selectedWalletItem!.id;
    _arkFeeTimer = Timer(const Duration(milliseconds: 300), () async {
      int? fee;
      var serverDown = false;
      try {
        serverDown = !await _arkProvider!.isServerReachable(walletId);
        if (!serverDown) {
          fee = await (_isArkMaxMode && route.rail == ArkPaymentRail.onchain
                  ? _arkProvider.estimateMoveOnchainFee(walletId, route.destination)
                  : _arkProvider.estimatePaymentFee(
                    walletId,
                    route.rail,
                    destination: route.destination,
                    amountSats: amount,
                  ))
              .timeout(const Duration(seconds: 20));
        }
        Logger.log('SendViewModel: Ark fee ${route.rail.name} $amount sats = $fee');
      } catch (error) {
        Logger.error('SendViewModel: Ark fee estimate failed: $error');
      }
      if (_isDisposed || _estimatedRoute != route || _estimatedAmount != amount) return;
      _arkFee = fee;
      _arkFeeFailed = fee == null;
      _arkServerDown = serverDown;
      _isEstimatingArkFee = false;
      if (_isArkMaxMode) _applyArkMaxAmount();
      _updateAmountValidationState();
    });
  }

  bool get isReadyToSend {
    if (arkRoute case final route?) {
      return !_hasUnvalidatedInput &&
          !isArkLocked &&
          _recipientList.single.isInputValid &&
          _isAmountSumExceedsBalance.isNotError &&
          _arkFee != null &&
          _estimatedRoute == route &&
          (_isArkMaxMode || _estimatedAmount == _amountSatsAt(0));
    }
    if (isWalletSyncing) return false;
    if (_hasUnvalidatedInput) return false;
    if (_isAmountSumExceedsBalance.isError || _isLastAmountInsufficient.isError) {
      return false;
    }

    for (final recipient in _recipientList) {
      if (!recipient.isInputValid) {
        return false;
      }
    }

    if (_estimatedFee == null) {
      return false;
    }

    if ((double.tryParse(_feeRateText) ?? 0) < 0.1) {
      return false;
    }

    return true;
  }

  bool get isSelectedWalletNull => _selectedWalletItem == null;

  bool get canGoNext => !isWalletWithoutMfp(_selectedWalletItem) && isReadyToSend && _finalErrorMessage.isEmpty;

  /// 초기화를 비동기로 진행하므로 null이면 아직 초기화 완료 안된 것으로 판단.
  List<TransactionDraft>? _drafts;
  List<TransactionDraft>? get drafts => _drafts;
  bool? get hasDrafts => _drafts?.isNotEmpty;
  bool get isSaved => _transactionDraftId != null;
  bool get canUseTransactionDrafts => selectedWalletItem != null && !selectedWalletItem!.hasLocalKey;

  bool isMaxModeLastIndex(int index) {
    return _isMaxMode && index == lastIndex;
  }

  bool isAmountInsufficient(int index) {
    if (index != lastIndex) return false;
    return _isMaxMode && _recipientList[index].amount == '0';
  }

  bool isOwnAddress(String address) {
    for (WalletItemBase walletItem in _walletProvider.walletItemList) {
      if (_walletProvider.containsAddress(walletItem.id, address)) return true;
    }
    return false;
  }

  SendViewModel(
    this._walletProvider,
    this._sendInfoProvider,
    this._preferenceProvider,
    this._transactionDraftRepository,
    this._utxoRepository,
    this._nodeProvider,
    this._isNetworkOn,
    this._onAmountTextUpdate,
    this._onFeeRateTextUpdate,
    this._onRecipientPageDeleted,
    int? walletId,
    SendEntryPoint sendEntryPoint,
    this._transactionDraftId,
    List<UtxoState>? selectedUtxoList, {
    ArkProvider? arkProvider,
  }) : _arkProvider = arkProvider {
    _sendInfoProvider.clear();
    _sendInfoProvider.setSendEntryPoint(sendEntryPoint);
    _currentUnit = _preferenceProvider.currentUnit;
    _walletSyncWatcher = WalletSyncWatcher(_nodeProvider, _onWalletSyncChanged);

    if (walletId != null) {
      final walletIndex = _walletProvider.walletItemList.indexWhere((e) => e.id == walletId);
      if (walletIndex != -1) {
        _initializeWithSelectedWallet(walletIndex);
      }
    } else {
      _isUtxoSelectionAuto = true;
    }

    _recipientList = [RecipientInfo()];

    if (walletId != null && selectedUtxoList != null) {
      final hasSelectedUtxos = selectedUtxoList.isNotEmpty;

      _isUtxoSelectionAuto = !hasSelectedUtxos;
      if (hasSelectedUtxos) {
        _selectedUtxoList = List<UtxoState>.from(selectedUtxoList);
        _buildTransaction();
      }
    }

    _setRecommendedFees();

    _loadDrafts();
  }

  List<WalletItemBase> _getOrderedRegisteredWallets() {
    final walletList = _walletProvider.walletItemList;
    final order = _preferenceProvider.walletOrder;

    if (order.isEmpty) {
      return walletList;
    }

    final validOrder = order.where((id) => walletList.any((e) => e.id == id)).toList();
    final ordered = validOrder.map((id) => walletList.firstWhere((e) => e.id == id)).toList();
    final remaining = walletList.where((e) => !validOrder.contains(e.id)).toList();
    return [...ordered, ...remaining];
  }

  void _initRegisteredWalletsAddress() {
    if (_selectedWalletItem == null) {
      return;
    }

    final selectedWallet = _selectedWalletItem!;
    final walletAddressMap = _walletProvider.getReceiveAddressMap();
    // The bulk lookup omits wallets whose first receive address is not generated yet.
    // Use the individual lookup to initialize those addresses, and ignore stale order IDs.
    final wallets = [selectedWallet, ..._orderedRegisteredWallets.where((wallet) => wallet.id != selectedWallet.id)];
    _registeredWalletAddressMap = {
      for (final wallet in wallets)
        wallet.id: WalletAddressInfo(
          walletAddress: walletAddressMap[wallet.id] ?? _walletProvider.getReceiveAddress(wallet.id),
          name: wallet.name,
        ),
    };

    _walletAddressNeedsUpdate = List.filled(_registeredWalletAddressMap.length, false);
  }

  void _initializeWithSelectedWallet(int index) {
    if (index == -1) return;
    if (_selectedWalletItem != null && _selectedWalletItem!.id == _walletProvider.walletItemList[index].id) return;

    _orderedRegisteredWallets = _getOrderedRegisteredWallets();
    _selectedWalletItem = _walletProvider.walletItemList[index];
    if (_selectedWalletItem!.hasLocalKey) {
      _transactionDraftId = null;
      _sendInfoProvider.setUnsignedDraftId(null);
      _drafts = [];
    }
    _initRegisteredWalletsAddress();
    _sendInfoProvider.setWalletId(_selectedWalletItem!.id);
    _changeAddressDerivationPath = _walletProvider.getChangeAddress(_selectedWalletItem!.id).derivationPath;

    _allUtxos = _walletProvider.getUtxoList(_selectedWalletItem!.id);
    _walletSyncWatcher.watch(_selectedWalletItem!.id);

    _isUtxoSelectionAuto = !_preferenceProvider.isManualUtxoSelectionMode;
    _initBalances(_allUtxos);

    // per-send override 리셋. Builder 가 wallet 의 defaultSpendType 으로 자동 해석함.
    if (_selectedWalletItem is TaprootWalletItem) {
      _taprootSpendType = (_selectedWalletItem! as TaprootWalletItem).defaultSpendType;
    }
  }

  void _onWalletSyncChanged(bool isSyncing) {
    if (_isDisposed) return;
    if (!isSyncing) _reloadUtxos();
    notifyListeners();
  }

  /// 업데이트가 끝난 UTXO 상태로 잔액과 선택을 다시 맞추고 거래를 다시 만듦
  void _reloadUtxos() {
    final wallet = _selectedWalletItem;
    if (wallet == null) return;
    _allUtxos = _walletProvider.getUtxoList(wallet.id);
    _initBalances(_allUtxos);
    if (!_isUtxoSelectionAuto && _selectedUtxoList.isNotEmpty) {
      final (validatedUtxoList, excludedStatus) = _utxoRepository.getValidatedSelectedUtxoList(
        wallet.id,
        _selectedUtxoList.map((utxo) => utxo.utxoId).toList(),
      );
      _selectedUtxoList = validatedUtxoList;
      if (excludedStatus != null) {
        _lastExcludedUtxoStatus = excludedStatus;
        _excludedUtxoNonce++;
      }
    }
    _buildTransaction();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _arkFeeTimer?.cancel();
    _walletSyncWatcher.dispose();
    super.dispose();
  }

  void setIsUtxoSelectionAuto(bool value) {
    _isUtxoSelectionAuto = value;
    _buildTransaction();
  }

  void setSelectedUtxoList(List<UtxoState> list) {
    _isUtxoSelectionAuto = false;
    _selectedUtxoList = list;
    _buildTransaction();
  }

  TransactionDraft _getDraft(int draftId) {
    final draft = _transactionDraftRepository.getUnsignedTransactionDraft(draftId);
    if (draft == null) {
      throw StateError('Transaction draft not found: $draftId');
    }
    return draft;
  }

  /// TransactionDraft를 로드하여 SendViewModel 상태에 반영
  /// 사용불가 UTXO가 제외된 경우 해당 상태를 반환 (토스트 표시용)
  SelectedUtxoExcludedStatus? loadTransactionDraft(int draftId) {
    final draft = _getDraft(draftId);

    // 1. 지갑 선택 및 초기화
    final walletIndex = _walletProvider.walletItemList.indexWhere((e) => e.id == draft.walletId);
    if (walletIndex == -1) return null;
    if (_walletProvider.walletItemList[walletIndex].hasLocalKey) {
      throw StateError('Transaction drafts are not supported for hot wallets');
    }
    _initializeWithSelectedWallet(walletIndex);

    final (validatedUtxoList, excludedUtxoStatus) = _utxoRepository.getValidatedSelectedUtxoList(
      _selectedWalletItem!.id,
      draft.selectedUtxoIds.toList(),
    );

    // 2. Draft ID 설정
    _sendInfoProvider.setUnsignedDraftId(draft.id);

    // 3. 비트코인 단위 설정 (수신자 금액 변환 전에 먼저 설정)
    if (draft.bitcoinUnit != null && draft.bitcoinUnit != _currentUnit) {
      _currentUnit = draft.bitcoinUnit!;
    }

    // 4. 수신자 목록 설정 (sats → 현재 단위 문자열로 변환)
    _recipientList =
        draft.recipients.map((r) {
          final amountStr =
              _currentUnit.isBasedOnSatoshi
                  ? r.amount.toString()
                  : UnitUtil.convertSatoshiToBitcoin(r.amount).toString();
          return RecipientInfo(address: r.address, amount: amountStr);
        }).toList();

    // 5. 수수료율 설정 (setFeeRateText 대신 직접 설정하여 _buildTransaction 중복 호출 방지)
    _feeRateText = draft.feeRate.toString();
    try {
      final feeRateValue = double.parse(_feeRateText);
      _isFeeRateLowerThanMin = minimumFeeRate != null && feeRateValue < minimumFeeRate!;
    } catch (e) {
      Logger.error(e);
      _isFeeRateLowerThanMin = false;
    }

    // 6. UTXO 선택 모드 및 목록 설정 (_getDraft에서 검증된 목록 활용)
    if (validatedUtxoList.isNotEmpty) {
      _isUtxoSelectionAuto = false;
      _selectedUtxoList = validatedUtxoList;
    } else if (excludedUtxoStatus != null) {
      _isUtxoSelectionAuto = false;
      _selectedUtxoList.clear();
    } else {
      _isUtxoSelectionAuto = true;
    }

    // 7. 수수료 차감 설정
    _isFeeSubtractedFromSendAmount = draft.isFeeSubtractedFromSendAmount == true;

    // 8. 모두 보내기 모드 설정 (setMaxMode 대신 직접 설정하여 _buildTransaction 중복 호출 방지)
    _isMaxMode = draft.isMaxMode == true;
    if (_isMaxMode) {
      _previousIsFeeSubtractedFromSendAmount = _isFeeSubtractedFromSendAmount;
      _isFeeSubtractedFromSendAmount = true;
    }

    // 9. 모두 보내기 모드면 마지막 수신자 금액 재계산
    if (_isMaxMode) {
      _adjustLastReceiverAmount(recipientIndex: lastIndex);
    }
    // 불러온 초안은 이전 수동 입력의 검증 대기 상태를 대체한다.
    _hasUnvalidatedInput = false;
    // 10. 트랜잭션 빌드 (딱 1번만 호출)
    _buildTransaction();
    _transactionDraftId = draftId;

    // 11. 유효성 검증 상태 업데이트
    _updateAmountValidationState();

    // 12. UI 상태 업데이트
    _showAddressBoard = false;
    _showFeeBoard = recipientList.length > 1 || recipientList.any((r) => r.amount.isNotEmpty && r.address.isNotEmpty);

    // 13. 페이지 초기화 및 컨트롤러 동기화
    _currentIndex = 0;
    _onRecipientPageDeleted(0);
    _onAmountTextUpdate(_recipientList[_currentIndex].amount);
    _onFeeRateTextUpdate(_feeRateText);

    notifyListeners();

    return excludedUtxoStatus;
  }

  void _setEstimatedFee(int? estimatedFee) {
    _estimatedFee = estimatedFee;

    if (_isMaxMode) {
      _adjustLastReceiverAmount();
    } else {
      _updateAmountValidationState();
    }
  }

  void _buildTransaction() {
    if (_hasUnvalidatedInput) return;
    if (_selectedWalletItem == null ||
        !hasValidRecipient ||
        _feeRateText.isEmpty ||
        _feeRateText == "0" ||
        _changeAddressDerivationPath.isEmpty) {
      _setEstimatedFee(null);
      notifyListeners();
      return;
    }

    final feeRate = double.parse(_feeRateText);
    _txBuilder = TransactionBuilder(
      availableUtxos:
          _isUtxoSelectionAuto
              ? _allUtxos.where((utxo) => utxo.status == UtxoStatus.unspent).toList()
              : _selectedUtxoList,
      recipients: _getRecipientMapForTx(recipientMap),
      feeRate: feeRate,
      changeDerivationPath: _changeAddressDerivationPath,
      walletItemBase: _selectedWalletItem!,
      isFeeSubtractedFromAmount: _isFeeSubtractedFromSendAmount,
      isUtxoFixed: !_isUtxoSelectionAuto,
      scriptPathPolicy:
          (_taprootSpendType == TaprootSpendType.scriptPath)
              ? (_selectedWalletItem! as TaprootWalletItem).defaultPolicy!
              : null,
    );

    _txBuildResult = _txBuilder!.build();
    _setEstimatedFee(_txBuildResult!.estimatedFee - (_txBuildResult!.unintendedDustFee ?? 0));
    _setUnintendedDustFee((_txBuildResult!.unintendedDustFee ?? 0) == 0 ? null : _txBuildResult!.unintendedDustFee);
    _updateFinalErrorMessage();
    Logger.log(_txBuilder.toString());
  }

  void _setUnintendedDustFee(int? unintendedDustFee) {
    if (_unintendedDustFee == unintendedDustFee) return;
    _unintendedDustFee = unintendedDustFee;
    notifyListeners();
  }

  void _updateWalletAddressList() {
    for (int i = 0; i < _walletAddressNeedsUpdate.length; ++i) {
      if (!_walletAddressNeedsUpdate[i]) continue;
      final walletId = _registeredWalletAddressMap.keys.toList()[i];
      final nextAddressIndex = _registeredWalletAddressMap.entries.toList()[i].value.walletAddress.index + 1;
      final walletListItem = _walletProvider.getWalletById(walletId);
      final walletAddress = _walletProvider.generateAddress(walletListItem.walletBase, nextAddressIndex, false);
      _registeredWalletAddressMap[walletListItem.id] = WalletAddressInfo(
        walletAddress: walletAddress,
        name: _registeredWalletAddressMap[walletListItem.id]!.name,
      );

      _walletAddressNeedsUpdate[i] = false;
    }

    notifyListeners();
  }

  void markWalletAddressForUpdate(int index) {
    _walletAddressNeedsUpdate[index] = true;
  }

  Future<void> refreshRecommendedFees() async {
    if (recommendedFeeFetchStatus == RecommendedFeeFetchStatus.fetching) return;
    await _setRecommendedFees();
  }

  Future<bool> _setRecommendedFees() async {
    return fetchRecommendedFees(
      currentFeeRateText: _feeRateText,
      onDefaultFeeRateSet: (text) {
        if (_transactionDraftId == null) {
          _feeRateText = text;
          _onFeeRateTextUpdate(text);
        }
      },
    );
  }

  void setCurrentPage(int index) {
    _currentIndex = index;

    // 수신자 추가가 표시되어 있으면 주소 보드를 닫는다.
    if (index == recipientList.length) {
      setShowAddressBoard(false);
    } else {
      _onAmountTextUpdate(recipientList[_currentIndex].amount);
    }
    notifyListeners();
  }

  void setShowAddressBoard(bool isEnabled) {
    if (_showAddressBoard == isEnabled) return;
    _showAddressBoard = isEnabled;
    if (_showAddressBoard) _updateWalletAddressList();
    notifyListeners();
  }

  void _adjustLastReceiverAmount({int? recipientIndex}) {
    assert(_isMaxMode);
    double amountSumExceptLast = _amountSumExceptLast;
    int estimatedFeeInSats = _estimatedFee ?? 0;
    int maxBalanceInSats = balance - _currentUnit.toSatoshi(amountSumExceptLast) - estimatedFeeInSats;
    _recipientList[lastIndex].amount =
        maxBalanceInSats > _dustThreshold
            ? (_currentUnit.isBasedOnSatoshi
                    ? maxBalanceInSats
                    : UnitUtil.convertSatoshiToBitcoinString(maxBalanceInSats))
                .toString()
            : "0";

    if (_currentIndex == lastIndex) {
      _onAmountTextUpdate(recipientList[lastIndex].amount);
    }

    _updateAmountValidationState(recipientIndex: recipientIndex);
  }

  void setMaxMode(bool isEnabled, {bool skipAmountReset = false}) {
    if (_isMaxMode == isEnabled) return;

    _isMaxMode = isEnabled;
    if (_isMaxMode) _isArkMaxMode = false;
    if (_isMaxMode) {
      _adjustLastReceiverAmount(recipientIndex: lastIndex);
      _previousIsFeeSubtractedFromSendAmount = _isFeeSubtractedFromSendAmount;
      _isFeeSubtractedFromSendAmount = true;
    } else {
      /// maxMode 꺼지면 마지막 수신자 금액 초기화 (skipAmountReset이 true면 스킵)
      if (!skipAmountReset) {
        if (_recipientList.isNotEmpty && lastIndex >= 0) {
          _recipientList[lastIndex].amount = "";
          if (_currentIndex == lastIndex) {
            _onAmountTextUpdate(_recipientList[lastIndex].amount);
          }
        }
      }
      _isFeeSubtractedFromSendAmount = _previousIsFeeSubtractedFromSendAmount;
    }

    _validateRecipientInputs();
    vibrateLight();
    notifyListeners();
  }

  void addRecipient() {
    _isArkMaxMode = false;
    final newList = [..._recipientList, RecipientInfo(address: '', amount: '')];
    _recipientList = newList;
    _updateFinalErrorMessage();
    vibrateLight();
    notifyListeners();
  }

  void deleteRecipient() {
    _recipientList.removeAt(_currentIndex);
    _recipientList = [..._recipientList];
    if (lastIndex >= 0) _currentIndex = lastIndex;
    setCurrentPage(_currentIndex);
    _onRecipientPageDeleted(_currentIndex);

    _validateRecipientInputs();
    vibrateLight();
    notifyListeners();
  }

  void updateFeeBoardVisibility() {
    if (_showFeeBoard) return;

    _showFeeBoard = hasValidRecipient;
    if (_showFeeBoard) _buildTransaction();
    notifyListeners();
  }

  void _updateFinalErrorMessage() {
    String message = "";
    if (arkRoute != null) {
      final addressErrorIndex = _recipientList.indexWhere((r) => r.addressError.isError);
      if (addressErrorIndex != -1) {
        final recipient = _recipientList[addressErrorIndex];
        message = recipient.requestProblemText ?? recipient.addressError.getMessage();
      } else if (isArkLocked) {
        message = t.ark.send.locked;
      } else if (_isAmountSumExceedsBalance.isError) {
        message =
            arkShortfallNeedsRefresh
                ? t.ark.send.needs_refresh
                : _onchainCouldCover
                ? t.ark.send.not_enough_ark_move
                : t.ark.send.not_enough_ark;
      } else if (_arkServerDown) {
        message = t.ark.send.server_down;
      } else if (_arkFeeFailed) {
        message = t.ark.send.estimate_failed;
      }
      _finalErrorMessage = message;
      notifyListeners();
      return;
    }
    // [전체] 충분하지 않은 Balance 입력 > [수신자] dust 보다 적은 금액을 입력 > [마지막 수신자] 전송 금액 - 예상 수수료가 dustLimit보다 크지 않음 > [수신자] 주소에 에러가 있는 경우 > 최소값보다 낮은 수수료 입력
    if (_isAmountSumExceedsBalance.isError) {
      message = _isAmountSumExceedsBalance.getMessage(currentUnit, dustThreshold: _dustThreshold);
    } else if (_recipientList.any((r) => r.minimumAmountError.isError)) {
      message = AmountError.minimumAmount.getMessage(currentUnit, dustThreshold: _dustThreshold);
    } else if (_isLastAmountInsufficient.isError) {
      message = _isLastAmountInsufficient.getMessage(currentUnit, dustThreshold: _dustThreshold);
    } else if (_recipientList.any((r) => r.addressError.isError)) {
      int addressErrorIndex = _recipientList.indexWhere((r) => r.addressError.isError);
      if (addressErrorIndex != -1) {
        final recipient = _recipientList[addressErrorIndex];
        message = recipient.requestProblemText ?? recipient.addressError.getMessage();
      }
    } else if (_txBuildResult?.exception != null && _recipientList.every((r) => r.isInputValid)) {
      // 모든 수신자 카드 amount, address가 유효한 경우에만 메시지 보여주기
      message = _txBuildResult!.exception.toString();
    }

    _finalErrorMessage = message;
    notifyListeners();
  }

  void checkAndSetDuplicationError() {
    // 주소별 갯수 집계
    final Map<String, int> addressCount = {};
    for (final recipient in _recipientList) {
      if (recipient.address.isEmpty) continue;
      addressCount[recipient.address] = (addressCount[recipient.address] ?? 0) + 1;
    }

    for (int i = 0; i < _recipientList.length; i++) {
      final recipient = _recipientList[i];
      if (recipient.address.isEmpty) continue;
      if (recipient.addressError != AddressError.none && recipient.addressError != AddressError.duplicated) {
        // 중복 오류가 아닌 다른 오류는 건드리지 않음
        continue;
      }

      if (addressCount[recipient.address]! >= 2) {
        // 중복인 경우 duplicated 오류 설정
        _setAddressError(AddressError.duplicated, i);
      } else {
        // 더 이상 중복이 아니면 오류 해제
        _setAddressError(AddressError.none, i);
      }
    }
  }

  /// recipientIndex 유효성 검사
  bool _isValidRecipientIndex(int recipientIndex, String methodName) {
    if (recipientIndex < 0 || recipientIndex >= _recipientList.length) {
      debugPrint(
        '$methodName: Invalid recipientIndex $recipientIndex, _recipientList.length: ${_recipientList.length}',
      );
      return false;
    }
    return true;
  }

  void setAddressText(String text, int recipientIndex) {
    if (!_isValidRecipientIndex(recipientIndex, 'setAddressText')) return;
    if (_recipientList[recipientIndex].address == text) return;
    _recipientList[recipientIndex].address = text;
    if (text.isEmpty) {
      _txBuildResult = null;
    }
    if (recipientIndex == lastIndex) _reconcileMaxMode();
    if (isAmountLocked(recipientIndex)) {
      final sats = _requestAt(recipientIndex)!.invoiceAmountSats!;
      _recipientList[recipientIndex].amount =
          _currentUnit.isBasedOnSatoshi ? sats.toString() : UnitUtil.convertSatoshiToBitcoinString(sats);
      if (_currentIndex == recipientIndex) _onAmountTextUpdate(_recipientList[recipientIndex].amount);
    }
    _invalidateRecipientCalculation();
  }

  /// bip21 url에서 amount값 파싱 성공했을 때 사용
  void setAmountText(int satoshi, int recipientIndex, {bool validate = true}) {
    if (!_isValidRecipientIndex(recipientIndex, 'setAmountText')) return;
    if (_currentUnit.isBasedOnSatoshi) {
      _recipientList[recipientIndex].amount = satoshi.toString();
    } else {
      _recipientList[recipientIndex].amount = UnitUtil.convertSatoshiToBitcoin(satoshi).toString();
    }
    _invalidateRecipientCalculation();
    if (validate) _validateRecipientInputs();
  }

  void setFeeRateText(String feeRate) {
    _feeRateText = feeRate;

    try {
      var feeRateValue = double.parse(feeRate);
      _isFeeRateLowerThanMin = minimumFeeRate != null && feeRateValue < minimumFeeRate!;
    } catch (e) {
      Logger.error(e);
      _isFeeRateLowerThanMin = false;
    }

    _buildTransaction();
    notifyListeners();
  }

  void toggleUnit() {
    try {
      final prevUnit = _currentUnit;
      _currentUnit = _currentUnit.next;
      for (RecipientInfo recipient in recipientList) {
        if (recipient.amount.isNotEmpty && recipient.amount != '0') {
          final satoshi = prevUnit.toSatoshi(double.parse(recipient.amount));
          final converted = _currentUnit.fromSatoshi(satoshi);
          recipient.amount = _currentUnit.isBasedOnSatoshi ? converted.toInt().toString() : converted.toString();

          if (recipient.amount.contains('e')) {
            recipient.amount = double.parse(recipient.amount).toStringAsFixed(8);
          }
        }
      }

      if (currentIndex != recipientList.length) {
        _onAmountTextUpdate(recipientList[_currentIndex].amount);
      }

      vibrateLight();
      notifyListeners();
    } catch (e) {
      Logger.error(e);
    }
  }

  void setIsFeeSubtractedFromSendAmount(bool isEnabled) {
    if (_isFeeSubtractedFromSendAmount == isEnabled) return;
    _isFeeSubtractedFromSendAmount = isEnabled;
    _buildTransaction();
    _updateAmountValidationState();
    notifyListeners();
  }

  void onKeyTap(String newInput) {
    if (_currentIndex == _recipientList.length) return;
    if (isAmountLocked(_currentIndex)) return;
    if (newInput == ',') newInput = '.';
    if (_currentUnit.isBasedOnSatoshi && newInput == '.') return;

    final recipient = _recipientList[_currentIndex];
    if (newInput == '<') {
      if (recipient.amount.isNotEmpty) {
        recipient.amount = recipient.amount.substring(0, recipient.amount.length - 1);
      }
    } else if (newInput == '.') {
      if (recipient.amount.isEmpty) {
        recipient.amount = '0.';
      } else {
        if (!recipient.amount.contains('.')) {
          recipient.amount += newInput;
        }
      }
    } else {
      if (recipient.amount.isEmpty) {
        /// 첫 입력이 0인 경우는 바로 추가
        if (newInput == '0') {
          recipient.amount += newInput;
        } else if (newInput != '0' || recipient.amount.contains('.')) {
          recipient.amount += newInput;
        }
      } else if (recipient.amount == '0' && newInput != '.') {
        /// 첫 입력이 0이고, 그 후 0이 아닌 숫자가 올 경우에는 기존 0을 대체
        recipient.amount = newInput;
      } else if (recipient.amount.contains('.')) {
        /// 소수점 이후 숫자가 8자리 이하인 경우 추가
        int decimalIndex = recipient.amount.indexOf('.');
        if (recipient.amount.length - decimalIndex <= 8) {
          recipient.amount += newInput;
        }
      } else {
        /// 자연수인 경우 BTC 8자리 제한, sats 16자리 제한
        if (recipient.amount.length < (_currentUnit.isBasedOnSatoshi ? 16 : 8)) {
          recipient.amount += newInput;
        }
      }
    }
    _invalidateRecipientCalculation();
  }

  void _invalidateRecipientCalculation() {
    _hasUnvalidatedInput = true;
    _txBuildResult = null;
    _estimatedFee = null;
    _unintendedDustFee = null;
    _finalErrorMessage = '';
    notifyListeners();
  }

  void validateAllFieldsOnFocusLost() => _validateRecipientInputs();

  // 입력 방식과 포커스 이동 여부에 관계없이 검증 및 수수료 상태를 갱신한다.
  void _validateRecipientInputs() {
    _hasUnvalidatedInput = false;
    _reconcileMaxMode();
    if (_isMaxMode) _adjustLastReceiverAmount();
    for (int i = 0; i < _recipientList.length; ++i) {
      _updateAmountValidationState(recipientIndex: i);
      validateAddress(_recipientList[i].address, i);
    }
    checkAndSetDuplicationError();
    _showFeeBoard = _showFeeBoard || hasValidRecipient;
    _scheduleArkFeeEstimate();
    if (arkRoute != null) {
      _txBuildResult = null;
      _updateAmountValidationState();
      return;
    }
    _buildTransaction();
  }

  void clearAmountText() {
    if (_currentIndex == _recipientList.length) return;
    _recipientList[_currentIndex].amount = "";
    _updateAmountValidationState(recipientIndex: _currentIndex);
    _txBuildResult = null;
    _updateFinalErrorMessage();
    notifyListeners();
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    if (isNetworkOn == true && recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed) {
      refreshRecommendedFees();
    }
    notifyListeners();
  }

  void _initBalances(List<UtxoState> allUtxos) {
    if (_selectedWalletItem == null) {
      return;
    }

    int unspentBalance = 0, incomingBalance = 0;
    for (UtxoState utxo in allUtxos) {
      if (utxo.status == UtxoStatus.unspent) {
        unspentBalance += utxo.amount;
      } else if (utxo.status == UtxoStatus.incoming) {
        incomingBalance += utxo.amount;
      }
    }

    _confirmedBalance = unspentBalance;
    _incomingBalance = incomingBalance;
  }

  void _updateAmountSum() {
    double amountSum = recipientList
        .where((r) => r.amount.isNotEmpty)
        .fold(0, (sum, r) => sum + double.parse(r.amount));
    amountSum = amountSum.roundTo8Digits();
    _amountSum = _currentUnit.toSatoshi(amountSum);

    _updateIsAmountSumExceedsBalance(amountSum);
    notifyListeners();
  }

  void _updateIsAmountSumExceedsBalance(double amountSum) {
    if (arkRoute != null) {
      final amount = _isArkMaxMode ? 0 : (_amountSatsAt(0) ?? 0);
      _isAmountSumExceedsBalance =
          amount > 0 && amount + (_arkFee ?? 0) > arkSendableSats ? AmountError.insufficientBalance : AmountError.none;
      return;
    }
    double total = _isFeeSubtractedFromSendAmount ? amountSum : amountSum + _estimatedFeeByUnit;
    double balanceInUnit = balance / _dustLimitDenominator;
    _isAmountSumExceedsBalance =
        total > 0 && total > balanceInUnit ? AmountError.insufficientBalance : AmountError.none;
  }

  void _validateOneAmount(int recipientIndex) {
    assert(recipientIndex != -1);
    final recipient = recipientList[recipientIndex];
    if (arkRoute != null) {
      recipient.minimumAmountError = AmountError.none;
      return;
    }
    if (recipient.amount.isNotEmpty && double.parse(recipient.amount) > 0) {
      if (double.parse(recipient.amount) <= _dustThreshold / _dustLimitDenominator) {
        recipient.minimumAmountError = AmountError.minimumAmount;
      } else {
        recipient.minimumAmountError = AmountError.none;
      }
    } else {
      recipient.minimumAmountError = AmountError.none;
    }
  }

  // 마지막 수신자의 전송 금액을 확인한다. (전송 금액 - 예상 수수료 <= dust)
  // _isFeeSubtractedFromSendAmount가 true일 때만 체크되어야 함
  void _updateLastAmountErrorIfInsufficient() {
    // 모두 보내기는 금액 계산 단계에서 수수료와 dust 검사를 완료한다.
    if (_isMaxMode || !_isFeeSubtractedFromSendAmount) {
      _isLastAmountInsufficient = AmountError.none;
      return;
    }

    if (_recipientList[lastIndex].amount.isNotEmpty) {
      double amount = double.parse(_recipientList[lastIndex].amount);
      int estimatedFeeInSats = _estimatedFee ?? 0;
      bool isAmountInsufficientForFee = _currentUnit.toSatoshi(amount) - estimatedFeeInSats <= _dustThreshold;

      _isLastAmountInsufficient = isAmountInsufficientForFee ? AmountError.insufficientBalance : AmountError.none;
      Logger.log("_insufficientBalanceErrorOfLastRecipient: $_isLastAmountInsufficient");
    }
  }

  void _updateAmountValidationState({int? recipientIndex}) {
    _updateAmountSum();
    if (recipientIndex != null) {
      _validateOneAmount(recipientIndex);
    }
    _updateLastAmountErrorIfInsufficient();

    _updateFinalErrorMessage();
    notifyListeners();
  }

  void _setAddressError(AddressError error, int index) {
    debugPrint('setAddressError: $error, $index');
    if (!_isValidRecipientIndex(index, '_setAddressError')) return;
    if (_recipientList[index].addressError != error) {
      _recipientList[index].addressError = error;
      _updateFinalErrorMessage();
      notifyListeners();
    }
  }

  AddressValidationError? validateScannedAddress(String address) {
    return AddressValidator.validateAddress(address, NetworkType.currentNetworkType);
  }

  bool validateAddress(String address, int recipientIndex) {
    if (!_isValidRecipientIndex(recipientIndex, 'validateAddress')) return false;

    _recipientList[recipientIndex].requestProblemText = null;
    final request = address.trim().isEmpty ? null : PaymentRequest.parse(address, NetworkType.currentNetworkType);
    switch (request?.kind) {
      case PaymentRequestKind.arkAddress ||
          PaymentRequestKind.lightningInvoice ||
          PaymentRequestKind.lightningAddress ||
          PaymentRequestKind.bip321:
        final AddressError error;
        if (!isArkWallet && (request!.kind != PaymentRequestKind.bip321 || request.bitcoinAddress == null)) {
          error = AddressError.arkWalletOnly;
        } else if (_ownRequestChecks[address] == true && request!.bitcoinAddress == null) {
          error = AddressError.ownWallet;
        } else if (_recipientList.length > 1 && request!.bitcoinAddress == null) {
          error = AddressError.onchainOnly;
        } else {
          error = AddressError.none;
          _checkOwnRequest(address, request!);
        }
        _setAddressError(error, recipientIndex);
        return error.isNotError;
      case PaymentRequestKind.unsupported:
        _recipientList[recipientIndex].requestProblemText = paymentRequestProblemText(request!);
        _setAddressError(AddressError.unsupportedRequest, recipientIndex);
        _updateFinalErrorMessage();
        return false;
      default:
        break;
    }

    AddressValidationError? error = AddressValidator.validateAddress(address, NetworkType.currentNetworkType);

    switch (error) {
      case AddressValidationError.notTestnetAddress:
      case AddressValidationError.notMainnetAddress:
      case AddressValidationError.notRegtestnetAddress:
        _setAddressError(AddressError.invalidNetworkAddress, recipientIndex);
        return false;
      case AddressValidationError.minimumLength:
      case AddressValidationError.unknown:
        _setAddressError(AddressError.invalid, recipientIndex);
        return false;
      case AddressValidationError.empty:
      default:
        break;
    }

    _setAddressError(AddressError.none, recipientIndex);
    return true;
  }

  Map<String, int> _getRecipientMapForTx(Map<String, int> map) {
    final Map<String, int> normalizedMap = {for (var entry in map.entries) normalizeAddress(entry.key): entry.value};

    if (!_isMaxMode) return normalizedMap;

    final double amountSumExceptLast = _amountSumExceptLast;
    final int maxBalanceInSats = balance - _currentUnit.toSatoshi(amountSumExceptLast);
    final String lastRecipientAddress = normalizeAddress(_onchainAddressOf(_recipientList[lastIndex].address));

    normalizedMap[lastRecipientAddress] = maxBalanceInSats;
    return normalizedMap;
  }

  void saveSendInfo() {
    assert(_txBuildResult!.isSuccess);

    final recipientMapInBtc = recipientMap.map((key, value) => MapEntry(key, UnitUtil.convertSatoshiToBitcoin(value)));

    // 모두 보내기 모드가 아니고 수수료 수신자 부담 옵션을 활성화한 경우, 마지막 수신자의 amount에서 수수료를 뺀다. (보기용)
    if (!_isMaxMode && _isFeeSubtractedFromSendAmount) {
      String lastRecipientAddress = _onchainAddressOf(_recipientList[lastIndex].address);
      recipientMapInBtc[lastRecipientAddress] =
          (recipientMapInBtc[lastRecipientAddress]! - UnitUtil.convertSatoshiToBitcoin(estimatedFeeInSats!))
              .roundTo8Digits();
    }

    _sendInfoProvider.setTransaction(_txBuildResult!.transaction!);
    _sendInfoProvider.setIsMultisig(_selectedWalletItem!.walletType == WalletType.multiSignature);
    _sendInfoProvider.setWalletImportSource(_selectedWalletItem!.walletImportSource);
    _sendInfoProvider.setFeeRate(double.parse(_feeRateText));
    _sendInfoProvider.setIsMaxMode(_isMaxMode);
    _sendInfoProvider.setUnsignedDraftId(canUseTransactionDrafts ? _transactionDraftId : null);
  }

  void clearSendInfo() {
    _sendInfoProvider.clear();
  }

  /// --------------- 임시 저장 / 불러오기 --------------- ///
  Future<TransactionDraft> saveNewDraft() async {
    if (!canUseTransactionDrafts) {
      throw StateError('Transaction drafts are not supported for this wallet');
    }
    assert(_selectedWalletItem != null);

    final result = await _transactionDraftRepository.saveUnsignedDraft(
      walletId: selectedWalletItem!.id,
      feeRate: double.parse(_feeRateText),
      isMaxMode: _isMaxMode,
      isFeeSubtractedFromSendAmount: _isFeeSubtractedFromSendAmount,
      recipients:
          _recipientList.map((r) => RecipientDraft.fromRecipientInfo(r.address, r.amount, _currentUnit)).toList(),
      bitcoinUnit: _currentUnit,
      selectedUtxoIds: _isUtxoSelectionAuto ? null : _selectedUtxoList.map((utxo) => utxo.utxoId).toList(),
    );

    if (result.isSuccess) {
      _transactionDraftId = result.value.id;
      _loadDrafts();
      return result.value;
    } else {
      throw Exception(result.error.message);
    }
  }

  Future<TransactionDraft> updateDraft() async {
    if (!canUseTransactionDrafts) {
      throw StateError('Transaction drafts are not supported for this wallet');
    }
    assert(_selectedWalletItem != null);
    assert(_transactionDraftId != null);

    final result = await _transactionDraftRepository.updateUnsignedDraft(
      draftId: _transactionDraftId!,
      feeRate: double.parse(_feeRateText),
      isMaxMode: _isMaxMode,
      isFeeSubtractedFromSendAmount: _isFeeSubtractedFromSendAmount,
      recipients:
          _recipientList.map((r) => RecipientDraft.fromRecipientInfo(r.address, r.amount, _currentUnit)).toList(),
      bitcoinUnit: _currentUnit,
      selectedUtxoIds: _isUtxoSelectionAuto ? null : _selectedUtxoList.map((utxo) => utxo.utxoId).toList(),
    );

    if (result.isSuccess) {
      _loadDrafts();
      return result.value;
    } else {
      throw Exception(result.error.message);
    }
  }

  Future<void> _loadDrafts() async {
    if (_selectedWalletItem == null) return;
    if (!canUseTransactionDrafts) {
      _drafts = [];
      notifyListeners();
      return;
    }
    try {
      _drafts = _transactionDraftRepository.getUnsignedTransactionDraftsByWalletId(_selectedWalletItem!.id);
    } catch (e) {
      // ignore
    }
  }

  Future<void> deleteDraft(int draftId) async {
    final result = await _transactionDraftRepository.deleteUnsignedTransactionDraft(draftId);
    if (result.isSuccess) {
      await _loadDrafts();
    }
  }
}

class RecipientInfo {
  String address;
  String amount;
  AddressError addressError;
  AmountError minimumAmountError; // 전송량이 적은 경우
  String? requestProblemText;

  RecipientInfo({
    this.address = '',
    this.amount = '',
    this.addressError = AddressError.none,
    this.minimumAmountError = AmountError.none,
  });

  bool get isInputValid {
    final amountDecimal = Decimal.tryParse(amount);
    return address.trim().isNotEmpty &&
        amount.trim().isNotEmpty &&
        amountDecimal != null &&
        amountDecimal != Decimal.zero &&
        addressError.isNotError &&
        minimumAmountError.isNotError;
  }
}

class WalletAddressInfo {
  WalletAddress walletAddress;
  String name;

  WalletAddressInfo({required this.walletAddress, required this.name});
}
