import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
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
  final UpbitConnectModel _upbitConnectModel;
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

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

  late bool _isWalletSyncing;
  bool get isWalletSyncing => _isWalletSyncing;

  late int _balance;
  int get balance => _balance;

  WalletDetailViewModel(this._walletId, this._walletProvider, this._txProvider,
      this._connectProvider, this._upbitConnectModel) {
    // 지갑 상세 초기화
    final walletBaseItem = _walletProvider.getWalletById(_walletId);
    _walletListBaseItem = walletBaseItem;
    _walletType = walletBaseItem.walletType;

    _txProvider.initTxList(_walletId);
    // _tagProvider.initTagList(_walletId);

    // 지갑 업데이트
    _prevWalletUpdateInfo = _walletProvider.getWalletUpdateInfo(_walletId);
    _addChangeListener();
    _isWalletSyncing = !_allElementUpdateCompleted(_prevWalletUpdateInfo);
    _balance = _getBalance();

    // Faucet
    _setReceiveAddress();
    _walletName = walletBaseItem.name.length > 10
        ? '${walletBaseItem.name.substring(0, 7)}...'
        : walletBaseItem.name;
    _faucetRecord = _sharedPrefs.getFaucetHistoryWithId(_walletId);
    _checkFaucetRecord();
    //_getFaucetStatus();

    showFaucetTooltip();
  }

  bool get faucetTooltipVisible => _faucetTooltipVisible;

  bool get isRequesting => _isRequesting;

  String get derivationPath => _receiveAddress.derivationPath;
  String get receiveAddressIndex =>
      _receiveAddress.derivationPath.split('/').last;
  String get receiveAddress => _receiveAddress.address;

  List<TransactionRecord> get txList => _txProvider.txList;

  int get walletId => _walletId;
  WalletListItemBase? get walletListBaseItem => _walletListBaseItem;
  String get walletName => _walletName;
  WalletProvider? get walletProvider => _walletProvider;
  WalletType get walletType => _walletType;
  bool? get isNetworkOn => _connectProvider.isNetworkOn;
  int? get bitcoinPriceKrw => _upbitConnectModel.bitcoinPriceKrw;

  void removeFaucetTooltip() {
    _faucetTooltipVisible = false;
    notifyListeners();
  }

  void _setReceiveAddress() {
    _receiveAddress = _walletProvider.getReceiveAddress(_walletId);
    Logger.log('--> 리시브주소: ${_receiveAddress.address}');
  }

  Future<void> requestTestBitcoin(String address, double requestAmount,
      Function(bool, String) onResult) async {
    _isRequesting = true;
    notifyListeners();

    try {
      final response = await _faucetService
          .getTestCoin(FaucetRequest(address: address, amount: requestAmount));
      if (response is FaucetResponse) {
        onResult(true, '테스트 비트코인을 요청했어요. 잠시만 기다려 주세요.');
        _updateFaucetRecord();
      } else if (response is DefaultErrorResponse &&
          response.error == 'TOO_MANY_REQUEST_FAUCET') {
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
      notifyListeners();
    }
  }

  /// Faucet methods
  void showFaucetTooltip() async {
    final faucetHistory = _sharedPrefs.getFaucetHistoryWithId(_walletId);
    if (faucetHistory.count < 3) {
      _faucetTooltipVisible = true;
    }
    notifyListeners();
  }

  // TODO: 필요없을지도 모름.
  void updateProvider() async {
    _setReceiveAddress();
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
    _faucetRecord = FaucetRecord(
        id: _walletId,
        dateTime: DateTime.now().millisecondsSinceEpoch,
        count: 0);
  }

  void _saveFaucetRecordToSharedPrefs() {
    Logger.log('_checkFaucetHistory(): $_faucetRecord');
    _sharedPrefs.saveFaucetHistory(_faucetRecord);
  }

  void _updateFaucetRecord() {
    _checkFaucetRecord();

    int count = _faucetRecord.count;
    int dateTime = DateTime.now().millisecondsSinceEpoch;
    _faucetRecord =
        _faucetRecord.copyWith(dateTime: dateTime, count: count + 1);
    _saveFaucetRecordToSharedPrefs();
  }

  // todo: 상태를 반환해주도록 수정되면 좋겠음.
  Future<void> refreshWallet() async {
    _balance = _getBalance();
    _txProvider.initTxList(_walletId);
    notifyListeners();
  }

  void _addChangeListener() {
    _walletProvider.addWalletUpdateListener(
        _walletId, _onWalletUpdateInfoChanged);
  }

  int _getBalance() {
    return _walletProvider.getWalletBalance(_walletId).total;
  }

  // balance, transaction만 고려
  void _onWalletUpdateInfoChanged(WalletUpdateInfo updateInfo) {
    Logger.log('--> 지갑$_walletId 업데이트 체크');
    // balance
    if (_prevWalletUpdateInfo.balance != UpdateStatus.completed &&
        updateInfo.balance == UpdateStatus.completed) {
      _balance = _getBalance();
      notifyListeners();
      Logger.log('--> 지갑$_walletId의 balance를 업데이트했습니다.');
    }
    // transaction
    if (_prevWalletUpdateInfo.transaction != UpdateStatus.completed &&
        updateInfo.transaction == UpdateStatus.completed) {
      _txProvider.initTxList(_walletId);
      notifyListeners();
      Logger.log('--> 지갑$_walletId의 TX를 업데이트했습니다.');
    }

    bool isSyncing = !_allElementUpdateCompleted(updateInfo);
    if (_isWalletSyncing != isSyncing) {
      _isWalletSyncing = isSyncing;
      Logger.log('--> 지갑$_walletId loading ui: $_isWalletSyncing으로 변경');
      notifyListeners();
    }

    _prevWalletUpdateInfo = updateInfo;
  }

  bool _allElementUpdateCompleted(WalletUpdateInfo updateInfo) {
    return updateInfo.balance == UpdateStatus.completed &&
        updateInfo.transaction == UpdateStatus.completed;
  }

  @override
  void dispose() {
    _walletProvider.removeWalletUpdateListener(
        _walletId, _onWalletUpdateInfoChanged);
    super.dispose();
  }
}
