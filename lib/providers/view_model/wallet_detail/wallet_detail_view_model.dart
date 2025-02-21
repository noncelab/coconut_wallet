import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
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
import 'package:coconut_wallet/utils/derivation_path_util.dart';
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

  WalletListItemBase? _walletListBaseItem;
  // TODO: walletFeature
  // late WalletFeature _walletFeature;
  WalletType _walletType = WalletType.singleSignature;

  WalletInitState _prevWalletInitState = WalletInitState.never;
  bool _prevIsLatestTxBlockHeightZero = false;

  int? _prevTxCount;

  bool _faucetTooltipVisible = false;

  /// Faucet
  final Faucet _faucetService = Faucet();
  // TODO: addressBook
  // late AddressBook _walletAddressBook;
  late FaucetRecord _faucetRecord;

  String _walletAddress = '';
  String _derivationPath = '';

  String _walletName = '';
  String _receiveAddressIndex = '';

  bool _isRequesting = false;

  // fixme
  int get balance =>
      _walletProvider.getWalletBalance(_walletListBaseItem!.id).total;

  WalletDetailViewModel(this._walletId, this._walletProvider, this._txProvider,
      this._connectProvider, this._upbitConnectModel) {
    // 지갑 상세 초기화
    _prevWalletInitState = _walletProvider.walletInitState;
    final walletBaseItem = _walletProvider.getWalletById(_walletId);
    _walletListBaseItem = walletBaseItem;

    // TODO: walletFeature
    // _walletFeature = walletBaseItem.walletFeature;

    _prevTxCount = walletBaseItem.txCount;
    _prevIsLatestTxBlockHeightZero = walletBaseItem.isLatestTxBlockHeightZero;
    _walletType = walletBaseItem.walletType;

    _txProvider.initTxList(_walletId);
    // _tagProvider.initTagList(_walletId);

    // Faucet
    // TODO: address
    // Address receiveAddress = walletBaseItem.walletBase.getReceiveAddress();
    var receiveAddress = WalletAddress('', '', 0, false, 0, 0, 0);
    _walletAddress = receiveAddress.address;
    _derivationPath = receiveAddress.derivationPath;
    _walletName = walletBaseItem.name.length > 20
        ? '${walletBaseItem.name.substring(0, 17)}...'
        : walletBaseItem.name; // FIXME 지갑 이름 최대 20자로 제한, 이 코드 필요 없음
    _receiveAddressIndex = receiveAddress.derivationPath.split('/').last;
    // TODO: addressBook
    // _walletAddressBook = walletBaseItem.walletBase.addressBook;
    _faucetRecord = _sharedPrefs.getFaucetHistoryWithId(_walletId);
    _checkFaucetRecord();
    //_getFaucetStatus();

    showFaucetTooltip();
  }

  String get derivationPath => _derivationPath;
  bool get faucetTooltipVisible => _faucetTooltipVisible;

  bool get isRequesting => _isRequesting;

  String get receiveAddressIndex => _receiveAddressIndex;

  List<TransactionRecord> get txList => _txProvider.txList;

  int get walletId => _walletId;
  String get walletAddress => _walletAddress;

  // AddressBook get walletAddressBook => _walletAddressBook;
  WalletInitState get walletInitState => _walletProvider.walletInitState;

  WalletListItemBase? get walletListBaseItem => _walletListBaseItem;
  String get walletName => _walletName;

  WalletProvider? get walletProvider => _walletProvider;
  WalletType get walletType => _walletType;

  // WalletProvider
  // WalletStatus? getInitializedWalletStatus() {
  //   try {
  //     return _walletFeature.walletStatus;
  //   } catch (e) {
  //     return null;
  //   }
  // }
  bool? get isNetworkOn => _connectProvider.isNetworkOn;
  int? get bitcoinPriceKrw => _upbitConnectModel.bitcoinPriceKrw;

  void removeFaucetTooltip() {
    _faucetTooltipVisible = false;
    notifyListeners();
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
    if (_walletListBaseItem!.balance == 0 && faucetHistory.count < 3) {
      _faucetTooltipVisible = true;
    }
    notifyListeners();
  }

  void updateProvider() async {
    if (_prevWalletInitState != WalletInitState.finished &&
        _walletProvider.walletInitState == WalletInitState.finished) {
      _checkTxCount();
      // getUtxoListWithHoldingAddress();
    }
    _prevWalletInitState = _walletProvider.walletInitState;

    try {
      final WalletListItemBase walletListItemBase =
          _walletProvider.getWalletById(_walletId);

      // TODO: address
      // _walletAddress =
      //     walletListItemBase.walletBase.getReceiveAddress().address;
      _walletAddress = '';
    } catch (e) {}

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

  void _checkTxCount() {
    final txCount = _walletListBaseItem!.txCount;
    final isLatestTxBlockHeightZero =
        _walletListBaseItem!.isLatestTxBlockHeightZero;
    Logger.log('--> prevTxCount: $_prevTxCount, wallet.txCount: $txCount');
    Logger.log(
        '--> prevIsZero: $_prevIsLatestTxBlockHeightZero, wallet.isZero: $isLatestTxBlockHeightZero');

    /// _walletListItem의 txCount, isLatestTxBlockHeightZero가 변경되었을 때만 트랜잭션 목록 업데이트
    if (_prevTxCount != txCount ||
        _prevIsLatestTxBlockHeightZero != isLatestTxBlockHeightZero) {
      _txProvider.initTxList(_walletId);
    }
    _prevTxCount = txCount;
    _prevIsLatestTxBlockHeightZero = isLatestTxBlockHeightZero;
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
    _walletProvider.initWallet(targetId: _walletId);
  }
}
