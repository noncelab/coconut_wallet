import 'dart:collection';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/services/model/error/default_error_response.dart';
import 'package:coconut_wallet/services/model/request/faucet_request.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/faucet_response.dart';
import 'package:coconut_wallet/model/faucet/faucet_history.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/faucet_service.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/services/model/stream/stream_state.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/cupertino.dart';

class WalletDetailViewModel extends ChangeNotifier {
  static const int kMaxFaucetRequestCount = 3;
  final int _walletId;
  final WalletProvider _walletProvider;
  final TransactionProvider _txProvider;
  final UtxoTagProvider _tagProvider;
  final ConnectivityProvider _connectProvider;
  final UpbitConnectModel _upbitConnectModel;
  final NodeProvider _nodeProvider;
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

  List<UtxoState> _utxoList = [];

  WalletListItemBase? _walletListBaseItem;
  // TODO: walletFeature
  // late WalletFeature _walletFeature;
  WalletType _walletType = WalletType.singleSignature;

  WalletInitState _prevWalletInitState = WalletInitState.never;
  bool _prevIsLatestTxBlockHeightZero = false;

  bool _isUtxoListLoadComplete = false;
  int? _prevTxCount;

  UtxoOrderEnum _selectedUtxoOrder = UtxoOrderEnum.byTimestampDesc;
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

  WalletDetailViewModel(
      this._walletId,
      this._walletProvider,
      this._txProvider,
      this._tagProvider,
      this._connectProvider,
      this._upbitConnectModel,
      this._nodeProvider) {
    // 지갑 상세 초기화
    _prevWalletInitState = _walletProvider.walletInitState;
    final walletBaseItem = _walletProvider.getWalletById(_walletId);
    _walletListBaseItem = walletBaseItem;
    // TODO: walletFeature
    // _walletFeature = walletBaseItem.walletFeature;

    _prevTxCount = walletBaseItem.txCount;
    _prevIsLatestTxBlockHeightZero = walletBaseItem.isLatestTxBlockHeightZero;
    _walletType = walletBaseItem.walletType;

    if (_walletProvider.walletInitState == WalletInitState.finished) {
      getUtxoListWithHoldingAddress();
    }

    _txProvider.initTxList(_walletId);
    _tagProvider.initTagList(_walletId);

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

  bool get isUpdatedTagList => _tagProvider.isUpdatedTagList;
  bool get isUtxoListLoadComplete => _isUtxoListLoadComplete;

  String get receiveAddressIndex => _receiveAddressIndex;

  List<UtxoTag> get selectedTagList => _tagProvider.selectedTagList;
  UtxoOrderEnum get selectedUtxoOrder => _selectedUtxoOrder;

  List<TransactionRecord> get txList => _txProvider.txList;
  List<UtxoState> get utxoList => _utxoList;

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

  void getUtxoListWithHoldingAddress() {
    List<UtxoState> utxos = [];

    // TODO: walletFeature
    // if (_walletFeature.walletStatus?.utxoList.isNotEmpty == true) {
    //   for (var utxo in _walletFeature.walletStatus!.utxoList) {
    //     String ownedAddress = _walletListBaseItem!.walletBase.getAddress(
    //         DerivationPathUtil.getAccountIndex(
    //             _walletType, utxo.derivationPath),
    //         isChange: DerivationPathUtil.getChangeElement(
    //                 _walletType, utxo.derivationPath) ==
    //             1);

    //     final tags =
    //         _tagProvider.loadSelectedUtxoTagList(_walletId, utxo.utxoId);

    //     utxos.add(model.UTXO(
    //       utxo.timestamp.toString(),
    //       utxo.blockHeight.toString(),
    //       utxo.amount,
    //       ownedAddress,
    //       utxo.derivationPath,
    //       utxo.transactionHash,
    //       utxo.index,
    //       tags: tags,
    //     ));
    //   }
    // }

    _isUtxoListLoadComplete = true;
    _utxoList = utxos;
    UtxoState.sortUtxo(_utxoList, _selectedUtxoOrder);
  }

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
      getUtxoListWithHoldingAddress();
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

  void updateUtxoFilter(UtxoOrderEnum selectedUtxoFilter) async {
    _selectedUtxoOrder = selectedUtxoFilter;
    UtxoState.sortUtxo(_utxoList, selectedUtxoFilter);
    notifyListeners();
  }

  void updateUtxoTagList(String utxoId, List<UtxoTag> utxoTagList) {
    final findUtxo = utxoList.firstWhere((item) => item.utxoId == utxoId);
    findUtxo.tags?.clear();
    findUtxo.tags?.addAll(utxoTagList);
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

  // TODO: TransactionProvider에서 처리하는 것이 적절해보임
  /// 트랜잭션의 정보를 모두 제공하기 위해서 3단계를 거쳐야 합니다.
  /// 1. 이미 DB에 저장되어 알고있는 트랸잭션을 제외한 새로운 트랜잭션 조회
  /// 2. 조회된 트랜잭션의 블록 타임스탬프 조회
  /// 3. 조회된 트랜잭션의 정확한 금액, 수수료 계산을 위해 입력(이전) 트랜잭션 조회
  Future<void> fetchTransactions() async {
    // 1. 새로운 트랜잭션 조회
    final fetchedTxs = await _fetchNewTransactions();
    // 2. 미확인 트랜잭션 상태 업데이트
    await _updateUnconfirmedTransactions(fetchedTxs);

    if (fetchedTxs.isEmpty) {
      return;
    }

    // 3. 트랜잭션의 블록 타임스탬프 조회
    final txBlockHeightMap = _createTxBlockHeightMap(fetchedTxs);
    final blockTimestampMap = await _fetchBlockTimestamps(fetchedTxs);

    // 4. 트랜잭션 상세 조회 및 처리
    final fetchedTransactions = await _fetchTransactionDetails(fetchedTxs);

    // 5. 트랜잭션 레코드 생성 및 저장
    final newTransactionRecords = await _createTransactionRecords(
      fetchedTransactions,
      txBlockHeightMap,
      blockTimestampMap,
    );

    // DB에 저장
    _txProvider.addAllTransactions(walletId, newTransactionRecords);
    notifyListeners();
  }

  /// 미확인 트랜잭션의 상태를 업데이트합니다.
  Future<void> _updateUnconfirmedTransactions(
      List<FetchTransactionResponse> fetchedTxs) async {
    // 1. DB에서 미확인 트랜잭션 조회
    final unconfirmedTxs = _txProvider.getUnconfirmedTransactions(walletId);
    if (unconfirmedTxs.isEmpty) {
      return;
    }

    // 2. 새로 조회한 트랜잭션과 비교
    final fetchedTxMap = {for (var tx in fetchedTxs) tx.transactionHash: tx};

    final List<String> txsToUpdate = [];
    final List<String> txsToDelete = [];

    for (final unconfirmedTx in unconfirmedTxs) {
      final fetchedTx = fetchedTxMap[unconfirmedTx.transactionHash];

      if (fetchedTx == null) {
        // INFO: RBF(Replace-By-Fee)에 의해서 처리되지 않은 트랜잭션이 삭제된 경우를 대비
        // INFO: 추후에는 삭제가 아니라 '무효화됨'으로 표기될 수 있음
        txsToDelete.add(unconfirmedTx.transactionHash);
      } else if (fetchedTx.height > 0) {
        // 블록에 포함된 경우 (confirmed)
        txsToUpdate.add(unconfirmedTx.transactionHash);
      }
    }

    if (txsToUpdate.isEmpty && txsToDelete.isEmpty) {
      return;
    }

    // 3. 블록 타임스탬프 조회 (업데이트할 트랜잭션이 있는 경우)
    Map<int, BlockTimestamp> blockTimestampMap = txsToUpdate.isEmpty
        ? {}
        : await _fetchBlockTimestamps(fetchedTxs
            .where((tx) => txsToUpdate.contains(tx.transactionHash))
            .toList());

    // 4. 트랜잭션 상태 업데이트
    await _txProvider.updateTransactionStates(
      walletId,
      txsToUpdate,
      txsToDelete,
      fetchedTxMap,
      blockTimestampMap,
    );
  }

  /// 새로운 트랜잭션을 조회합니다.
  Future<List<FetchTransactionResponse>> _fetchNewTransactions() async {
    Set<String> knownTransactionHashes = _txProvider.txList
        .where((tx) {
          if (tx.blockHeight == null) {
            return false;
          }
          return tx.blockHeight! > 0;
        })
        .map((tx) => tx.transactionHash)
        .toSet();

    final List<FetchTransactionResponse> transactions = [];

    await for (final state in _nodeProvider.fetchTransactions(
        _walletListBaseItem!,
        knownTransactionHashes: knownTransactionHashes)) {
      if (state is SuccessState<FetchTransactionResponse>) {
        transactions.add(state.data);
      }
    }

    return transactions;
  }

  /// 트랜잭션 해시와 블록 높이를 매핑하는 맵을 생성합니다.
  Map<String, int> _createTxBlockHeightMap(
      List<FetchTransactionResponse> fetchedTxs) {
    return HashMap.fromEntries(
        fetchedTxs.map((tx) => MapEntry(tx.transactionHash, tx.height)));
  }

  /// 블록 타임스탬프를 조회합니다.
  Future<Map<int, BlockTimestamp>> _fetchBlockTimestamps(
      List<FetchTransactionResponse> fetchedTxs) async {
    final toFetchBlockHeights = fetchedTxs
        .map((tx) => tx.height)
        .where((blockHeight) => blockHeight > 0)
        .toSet();

    return await _nodeProvider
        .fetchBlocksByHeight(toFetchBlockHeights)
        .where((state) => state is SuccessState<BlockTimestamp>)
        .cast<SuccessState<BlockTimestamp>>()
        .map((state) => state.data)
        .fold<Map<int, BlockTimestamp>>({}, (map, blockTimestamp) {
      map[blockTimestamp.height] = blockTimestamp;
      return map;
    });
  }

  /// 트랜잭션 상세 정보를 조회합니다.
  Future<List<Transaction>> _fetchTransactionDetails(
      List<FetchTransactionResponse> fetchedTxs) async {
    final fetchedTxHashes = fetchedTxs.map((tx) => tx.transactionHash).toSet();

    return await _nodeProvider
        .fetchTransactionDetails(fetchedTxHashes)
        .where((state) => state is SuccessState<Transaction>)
        .cast<SuccessState<Transaction>>()
        .map((state) => state.data)
        .toList();
  }

  /// 트랜잭션 레코드를 생성합니다.
  Future<List<TransactionRecord>> _createTransactionRecords(
    List<Transaction> fetchedTransactions,
    Map<String, int> txBlockHeightMap,
    Map<int, BlockTimestamp> blockTimestampMap,
  ) async {
    return Future.wait(fetchedTransactions.map((tx) async {
      final previousTxsResult =
          await _nodeProvider.getPreviousTransactions(tx, []);

      if (previousTxsResult.isFailure) {
        throw ErrorCodes.fetchTransactionsError;
      }

      final txDetails =
          await _processTransactionDetails(tx, previousTxsResult.value);

      return TransactionRecord.fromTransactions(
        transactionHash: tx.transactionHash,
        timestamp:
            blockTimestampMap[txBlockHeightMap[tx.transactionHash]!]!.timestamp,
        blockHeight: txBlockHeightMap[tx.transactionHash]!,
        inputAddressList: txDetails.inputAddressList,
        outputAddressList: txDetails.outputAddressList,
        transactionType: txDetails.txType.name,
        amount: txDetails.amount,
        fee: txDetails.fee,
      );
    }));
  }

  /// 트랜잭션의 입출력 상세 정보를 처리합니다.
  Future<_TransactionDetails> _processTransactionDetails(
    Transaction tx,
    List<Transaction> previousTxs,
  ) async {
    List<TransactionAddress> inputAddressList = [];
    int selfInputCount = 0;
    int selfOutputCount = 0;
    int fee = 0;
    int amount = 0;

    // 입력 처리
    for (int i = 0; i < tx.inputs.length; i++) {
      final input = tx.inputs[i];
      final previousOutput = previousTxs[i].outputs[input.index];
      final inputAddress = TransactionAddress(
          previousOutput.scriptPubKey.getAddress(), previousOutput.amount);
      inputAddressList.add(inputAddress);

      fee += inputAddress.amount;

      if (_walletProvider.containsAddress(
          _walletListBaseItem!, inputAddress.address)) {
        selfInputCount++;
        amount -= inputAddress.amount;
      }
    }

    // 출력 처리
    List<TransactionAddress> outputAddressList = [];
    for (int i = 0; i < tx.outputs.length; i++) {
      final output = tx.outputs[i];
      final outputAddress =
          TransactionAddress(output.scriptPubKey.getAddress(), output.amount);
      outputAddressList.add(outputAddress);

      fee -= outputAddress.amount;

      if (_walletProvider.containsAddress(
          _walletListBaseItem!, outputAddress.address)) {
        selfOutputCount++;
        amount += outputAddress.amount;
      }
    }

    // 트랜잭션 유형 결정
    TransactionTypeEnum txType;
    if (selfInputCount > 0 &&
        selfOutputCount == tx.outputs.length &&
        selfInputCount == tx.inputs.length) {
      txType = TransactionTypeEnum.self;
    } else if (selfInputCount > 0 && selfOutputCount < tx.outputs.length) {
      txType = TransactionTypeEnum.sent;
    } else {
      txType = TransactionTypeEnum.received;
    }

    return _TransactionDetails(
      inputAddressList: inputAddressList,
      outputAddressList: outputAddressList,
      txType: txType,
      amount: amount,
      fee: fee,
    );
  }
}

/// 트랜잭션 상세 정보를 담는 클래스
class _TransactionDetails {
  final List<TransactionAddress> inputAddressList;
  final List<TransactionAddress> outputAddressList;
  final TransactionTypeEnum txType;
  final int amount;
  final int fee;

  _TransactionDetails({
    required this.inputAddressList,
    required this.outputAddressList,
    required this.txType,
    required this.amount,
    required this.fee,
  });
}
