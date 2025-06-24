import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/services/model/error/default_error_response.dart';
import 'package:coconut_wallet/services/model/request/faucet_request.dart';
import 'package:coconut_wallet/services/model/response/faucet_response.dart';
import 'package:coconut_wallet/model/faucet/faucet_history.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/faucet_service.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/cupertino.dart';

class WalletDetailViewModel extends ChangeNotifier {
  static const int kMaxFaucetRequestCount = 3;
  final int _walletId;
  final WalletProvider _walletProvider;
  final TransactionProvider _txProvider;
  final ConnectivityProvider _connectProvider;
  final PriceProvider _priceProvider;
  final SendInfoProvider _sendInfoProvider;
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();
  final Stream<WalletUpdateInfo> _syncWalletStateStream;
  StreamSubscription<WalletUpdateInfo>? _syncWalletStateSubscription;

  late WalletListItemBase _walletListBaseItem;
  late WalletType _walletType;
  late WalletAddress _receiveAddress;

  bool _faucetTooltipVisible = false;

  /// Faucet
  final Faucet _faucetService = Faucet();
  late FaucetRecord _faucetRecord;

  String _walletName = '';

  bool _isRequesting = false;
  // 상태 변화 확인용
  late WalletUpdateInfo _prevWalletUpdateInfo;

  // balance 애니메이션을 위한 이전 잔액을 담는 변수
  late int _prevBalance;

  int get prevBalance => _prevBalance;
  late bool _isWalletSyncing;
  bool get isWalletSyncing => _isWalletSyncing;

  late int _balance;
  int get balance => _balance;

  int _receivingAmount = 0;
  int _sendingAmount = 0;
  int get receivingAmount => _receivingAmount;
  int get sendingAmount => _sendingAmount;

  WalletDetailViewModel(
      this._walletId,
      this._walletProvider,
      this._txProvider,
      this._connectProvider,
      this._priceProvider,
      this._sendInfoProvider,
      this._syncWalletStateStream) {
    // 지갑 상세 초기화
    final walletBaseItem = _walletProvider.getWalletById(_walletId);
    _walletListBaseItem = walletBaseItem;
    _walletType = walletBaseItem.walletType;
    _txProvider.initTxList(_walletId);

    // 지갑 업데이트
    _prevWalletUpdateInfo = WalletUpdateInfo(_walletId);
    _syncWalletStateSubscription = _syncWalletStateStream.listen(_onWalletUpdateInfoChanged);
    _isWalletSyncing = !_allElementUpdateCompleted(_prevWalletUpdateInfo);
    _balance = _getBalance();

    // UpbitConnectModel 변경 감지 리스너
    _priceProvider.addListener(_updateBitcoinPrice);

    _setPendingAmount();
    _prevBalance = balance;
    debugPrint('prev :: $_prevBalance');

    // Faucet
    _setReceiveAddress();
    _walletName = walletBaseItem.name.length > 10
        ? '${walletBaseItem.name.substring(0, 7)}...'
        : walletBaseItem.name;
    _faucetRecord = _sharedPrefs.getFaucetHistoryWithId(_walletId);
    _checkFaucetRecord();

    showFaucetTooltip();
  }

  void _setReceiveAddress() {
    _receiveAddress = _walletProvider.getReceiveAddress(_walletId);
    Logger.log('--> 리시브주소: ${_receiveAddress.address}');
  }

  bool get faucetTooltipVisible => _faucetTooltipVisible;

  bool get isRequesting => _isRequesting;

  String get derivationPath => _receiveAddress.derivationPath;
  String get receiveAddressIndex => _receiveAddress.derivationPath.split('/').last;
  String get receiveAddress => _receiveAddress.address;

  List<TransactionRecord> get txList => _txProvider.txList;

  int get walletId => _walletId;
  WalletListItemBase get walletListBaseItem => _walletListBaseItem;
  String get walletName => _walletName;
  WalletProvider? get walletProvider => _walletProvider;
  WalletType get walletType => _walletType;
  bool? get isNetworkOn => _connectProvider.isNetworkOn;
  bool get isMultisigWallet => _walletListBaseItem is MultisigWalletListItem;
  String? get masterFingerprint => isMultisigWallet
      ? null
      : (_walletListBaseItem.walletBase as SingleSignatureWallet).keyStore.masterFingerprint;

  int _bitcoinPriceKrw = 0;
  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  String _bitcoinPriceKrwInString = '';

  String get bitcoinPriceKrwInString => _bitcoinPriceKrwInString;

  // todo: 상태를 반환해주도록 수정되면 좋겠음.
  Future<void> refreshWallet() async {
    _balance = _getBalance();
    _setReceiveAddress();
    _txProvider.initTxList(_walletId);
    notifyListeners();
  }

  void _updateBitcoinPrice() {
    _bitcoinPriceKrw = _priceProvider.bitcoinPriceKrw ?? 0;
    _bitcoinPriceKrwInString = _priceProvider.getFiatPrice(_balance, CurrencyCode.KRW);
    notifyListeners();
  }

  void updateWalletName() {
    final updatedName = _walletProvider.getWalletById(_walletId).name;
    _walletName = updatedName;
    notifyListeners();
  }

  int _getBalance() {
    return _walletProvider.getWalletBalance(_walletId).total;
  }

  // balance, transaction만 고려
  void _onWalletUpdateInfoChanged(WalletUpdateInfo newInfo) {
    // balance
    if (_prevWalletUpdateInfo.balance != WalletSyncState.completed &&
        newInfo.balance == WalletSyncState.completed) {
      _balance = _getBalance();
      _setReceiveAddress();
      notifyListeners();
      Logger.log('--> 지갑$_walletId의 balance를 업데이트했습니다.');
    }
    // transaction
    if (_prevWalletUpdateInfo.transaction != WalletSyncState.completed &&
        newInfo.transaction == WalletSyncState.completed) {
      _txProvider.initTxList(_walletId);
      _setReceiveAddress();
      notifyListeners();
      Logger.log('--> 지갑$_walletId의 TX를 업데이트했습니다.');
    }

    bool isSyncing = !_allElementUpdateCompleted(newInfo);
    if (_isWalletSyncing != isSyncing) {
      _isWalletSyncing = isSyncing;
      Logger.log('--> 지갑$_walletId loading ui: $_isWalletSyncing으로 변경');
      notifyListeners();
    }

    _setPendingAmount();
    _prevWalletUpdateInfo = newInfo;
  }

  bool _allElementUpdateCompleted(WalletUpdateInfo updateInfo) {
    return updateInfo.balance == WalletSyncState.completed &&
        updateInfo.transaction == WalletSyncState.completed;
  }

  void _setPendingAmount() {
    int sending = 0;
    int receiving = 0;

    for (var tx in _txProvider.txList) {
      if (tx.blockHeight == 0) {
        switch (tx.transactionType) {
          case TransactionType.sent:
          case TransactionType.self:
            sending += tx.amount.abs();
            break;
          case TransactionType.received:
            receiving += tx.amount;
            break;
          default:
            break;
        }
      }
    }

    _sendingAmount = sending;
    _receivingAmount = receiving;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncWalletStateSubscription?.cancel();
    _priceProvider.removeListener(_updateBitcoinPrice);
    super.dispose();
  }

  // ----------> Faucet 메소드 시작
  void removeFaucetTooltip() {
    _faucetTooltipVisible = false;
    notifyListeners();
  }

  Future<void> requestTestBitcoin(
      String address, double requestAmount, Function(bool, String) onResult) async {
    _isRequesting = true;
    notifyListeners();
    try {
      final response =
          await _faucetService.getTestCoin(FaucetRequest(address: address, amount: requestAmount));
      if (response is FaucetResponse) {
        onResult(true, '테스트 비트코인을 요청했어요. 잠시만 기다려 주세요.');
        _updateFaucetRecord();
      } else if (response is DefaultErrorResponse && response.error == 'TOO_MANY_REQUEST_FAUCET') {
        onResult(false, '해당 주소로 이미 요청했습니다. 입금까지 최대 5분이 걸릴 수 있습니다.');
      } else {
        onResult(false, '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } catch (e) {
      Logger.error(e);
      // Error handling
      onResult(false, '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      _isRequesting = false;
      _setReceiveAddress();
      notifyListeners();
    }
  }

  /// Faucet methods
  void showFaucetTooltip() async {
    final faucetHistory = _sharedPrefs.getFaucetHistoryWithId(_walletId);
    if (faucetHistory.count < 3 && txList.isEmpty) {
      _faucetTooltipVisible = true;
    }
    notifyListeners();
  }

  void _checkFaucetRecord() {
    _faucetRecord = _sharedPrefs.getFaucetHistoryWithId(_walletId);
    if (!_faucetRecord.isToday) {
      // 오늘 처음 요청
      _initFaucetRecord();
      _saveFaucetRecordToSharedPrefs();
      return;
    }
  }

  void _initFaucetRecord() {
    _faucetRecord =
        FaucetRecord(id: _walletId, dateTime: DateTime.now().millisecondsSinceEpoch, count: 0);
  }

  void _saveFaucetRecordToSharedPrefs() {
    Logger.log('_checkFaucetHistory(): $_faucetRecord');
    _sharedPrefs.saveFaucetHistory(_faucetRecord);
  }

  void _updateFaucetRecord() {
    _checkFaucetRecord();

    int count = _faucetRecord.count;
    int dateTime = DateTime.now().millisecondsSinceEpoch;
    _faucetRecord = _faucetRecord.copyWith(dateTime: dateTime, count: count + 1);
    _saveFaucetRecordToSharedPrefs();
  }
  // <------ Faucet 메소드 끝

  void clearSendInfo() {
    _sendInfoProvider.clear();
  }
}
