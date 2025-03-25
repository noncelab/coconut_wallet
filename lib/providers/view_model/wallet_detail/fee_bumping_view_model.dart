import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/services/dio_client.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/material.dart';

enum PaymentType {
  forSweep,
  forSinglePayment,
  forBatchPayment,
}

class FeeBumpingViewModel extends ChangeNotifier {
  final FeeBumpingType _type;
  final TransactionRecord _parentTx;
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final SendInfoProvider _sendInfoProvider;
  final TransactionProvider _txProvider;
  final AddressRepository _addressRepository;
  final UtxoRepository _utxoRepository;
  final int _walletId;
  late Transaction? _bumpingTransaction;
  late WalletListItemBase _walletListItemBase;

  final List<FeeInfoWithLevel> _feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];
  bool? _isFeeFetchSuccess;
  bool? _isInitializedSuccess;
  double? _recommendedFeeRate;
  String? _recommendedFeeRateDescription;

  FeeBumpingViewModel(
    this._type,
    this._parentTx,
    this._walletId,
    this._sendInfoProvider,
    this._txProvider,
    this._walletProvider,
    this._nodeProvider,
    this._addressRepository,
    this._utxoRepository,
  ) {
    _walletListItemBase = _walletProvider.getWalletById(_walletId);
  }

  double? get recommendFeeRate => _recommendedFeeRate;
  String? get recommendFeeRateDescription => _recommendedFeeRateDescription;

  // Utxo? get currentUtxo => _currentUtxo;
  List<FeeInfoWithLevel> get feeInfos => _feeInfos;
  bool? get didFetchRecommendedFeesSuccessfully => _isFeeFetchSuccess;
  bool? get isInitializedSuccess => _isInitializedSuccess;

  TransactionRecord get transaction => _parentTx;
  int get walletId => _walletId;

  WalletListItemBase get walletListItemBase => _walletListItemBase;

  bool _insufficientUtxos = false;
  bool get insufficientUtxos => _insufficientUtxos;

  Future<void> initialize() async {
    await _fetchRecommendedFees(); // _isFeeFetchSuccess로 성공 여부 기록함
    if (_isFeeFetchSuccess == true) {
      await _initializeBumpingTransaction(_feeInfos[2].satsPerVb!.toDouble());
      _recommendedFeeRate = _getRecommendedFeeRate(_bumpingTransaction!);
      _recommendedFeeRateDescription = _type == FeeBumpingType.cpfp
          ? _getRecommendedFeeRateDescriptionForCpfp()
          : t.transaction_fee_bumping_screen.recommend_fee_info_rbf;
      _isInitializedSuccess = true;
    } else {
      _isInitializedSuccess = false;
    }
    notifyListeners();
  }

  bool isFeeRateTooLow(double feeRate) {
    assert(_isInitializedSuccess == true);
    assert(_recommendedFeeRate != null);

    return feeRate < _recommendedFeeRate! || feeRate < _parentTx.feeRate;
  }

  // pending상태였던 Tx가 confirmed 되었는지 조회
  bool hasTransactionConfirmed() {
    TransactionRecord? tx = _txProvider.getTransactionRecord(
        _walletId, transaction.transactionHash);
    if (tx == null || tx.blockHeight! <= 0) return false;
    return true;
  }

  bool prepareToSend(double newTxFeeRate) {
    assert(_bumpingTransaction != null);
    try {
      _initializeBumpingTransaction(newTxFeeRate);
      _updateSendInfoProvider(newTxFeeRate, _type);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 수수료 입력 시 예상 총 수수료 계산
  int getTotalEstimatedFee(double newFeeRate) {
    assert(_bumpingTransaction != null);

    if (newFeeRate == 0) {
      return 0;
    }

    return _bumpingTransaction != null
        ? (_estimateVirtualByte(_bumpingTransaction!) * newFeeRate)
            .ceil()
            .toInt()
        : 0;
  }

  void _updateSendInfoProvider(
      double newTxFeeRate, FeeBumpingType feeBumpingType) {
    bool isMultisig =
        walletListItemBase.walletType == WalletType.multiSignature;
    _sendInfoProvider.setWalletId(_walletId);
    _sendInfoProvider.setIsMultisig(isMultisig);
    _sendInfoProvider.setFeeRate(newTxFeeRate.toInt()); // fixme
    _sendInfoProvider.setTxWaitingForSign(Psbt.fromTransaction(
            _bumpingTransaction!, walletListItemBase.walletBase)
        .serialize());
    _sendInfoProvider.setFeeBumpfingType(feeBumpingType);
  }

  List<TransactionAddress> _getExternalOutputs() => _parentTx.outputAddressList
      .where((output) => !_walletProvider
          .containsAddress(_walletId, output.address, isChange: true))
      .toList();

  List<TransactionAddress> _getMyOutputs() => _parentTx.outputAddressList
      .where((output) =>
          _walletProvider.containsAddress(_walletId, output.address))
      .toList();

  PaymentType? _getPaymentType() {
    int inputCount = _parentTx.inputAddressList.length;
    int outputCount = _parentTx.outputAddressList.length;

    if (inputCount == 0 || outputCount == 0) {
      return null; // wrong tx
    }

    final externalOutputs = _getExternalOutputs();
    switch (outputCount) {
      case 1:
        return PaymentType.forSweep;
      case 2:
        if (externalOutputs.length == 1) {
          return PaymentType.forSinglePayment;
        }
      default:
        return PaymentType.forBatchPayment;
    }

    return null;
  }

  // 새 수수료로 트랜잭션 생성
  Future<void> _initializeBumpingTransaction(double newFeeRate) async {
    if (_type == FeeBumpingType.cpfp) {
      _initializeCpfpTransaction(newFeeRate);
    } else if (_type == FeeBumpingType.rbf) {
      await _initializeRbfTransaction(newFeeRate);
    }
  }

  void _initializeCpfpTransaction(double newFeeRate) {
    final myAddressList = _getMyOutputs();
    int amount = myAddressList.fold(0, (sum, output) => sum + output.amount);
    final List<UtxoState> utxoList = [];
    // 내 주소와 일치하는 utxo 찾기
    for (var myAddress in myAddressList) {
      final utxoStateList =
          _utxoRepository.getUtxosByStatus(_walletId, UtxoStatus.incoming);
      for (var utxoState in utxoStateList) {
        if (myAddress.address == utxoState.to &&
            myAddress.amount == utxoState.amount &&
            _parentTx.transactionHash == utxoState.transactionHash &&
            _parentTx.outputAddressList[utxoState.index].address ==
                utxoState.to) {
          utxoList.add(utxoState);
        }
      }
    }

    assert(utxoList.isNotEmpty);

    // Transaction 생성
    final recipient = _walletProvider.getReceiveAddress(_walletId).address;
    double estimatedVSize;
    try {
      _bumpingTransaction = Transaction.forSweep(
          utxoList, recipient, newFeeRate, walletListItemBase.walletBase);
      estimatedVSize = _estimateVirtualByte(_bumpingTransaction!);
    } catch (e) {
      // insufficient utxo for sweep
      double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
      estimatedVSize = _parentTx.vSize.toDouble();
      double outputSum = amount + estimatedVSize * newFeeRate;

      debugPrint(
          '😇 CPFP utxo (${utxoList.length})개 input: $inputSum / output: $outputSum / 👉🏻 입력한 fee rate: $newFeeRate');
      if (!_ensureSufficientUtxos(
          utxoList, outputSum, estimatedVSize.ceil(), newFeeRate, amount)) {
        debugPrint('❌ 사용할 수 있는 추가 UTXO가 없음!');
        return;
      }
    }

    debugPrint('😇 CPFP utxo (${utxoList.length})개');
    _bumpingTransaction = Transaction.forSweep(
        utxoList, recipient, newFeeRate, walletListItemBase.walletBase);

    _sendInfoProvider.setRecipientAddress(recipient);
    _sendInfoProvider.setIsMaxMode(true);
    _sendInfoProvider
        .setAmount(_bumpingTransaction!.outputs[0].amount.toDouble());
  }

  Future<void> _initializeRbfTransaction(double newFeeRate) async {
    final type = _getPaymentType();
    if (type == null) return;

    final externalOutputs = _getExternalOutputs();
    var amount = externalOutputs.fold(0, (sum, output) => sum + output.amount);
    var changeAddress =
        _parentTx.outputAddressList.map((e) => e.address).firstWhere(
              (address) => _walletProvider.containsAddress(_walletId, address,
                  isChange: true),
              orElse: () => '',
            );

    //input 정보 추출
    List<Utxo> utxoList = await _getUtxoListForRbf();
    double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    int estimatedVSize = _parentTx.vSize;
    double outputSum = amount + estimatedVSize * newFeeRate;

    if (inputSum <= outputSum) {
      // output에 내 주소가 있는 경우 amount 조정
      if (externalOutputs.any((output) =>
          _walletProvider.containsAddress(_walletId, output.address))) {
        amount = (inputSum - _parentTx.vSize * newFeeRate).toInt();
        if (amount < 0) {
          debugPrint('❌ input 합계가 output 합계보다 작음!');
          if (!_ensureSufficientUtxos(
              utxoList, outputSum, estimatedVSize, newFeeRate, amount)) {
            return;
          }
        }
        debugPrint('amount 조정됨 $amount');
      } else {
        // repicient가 남의 주소인 경우 utxo 추가
        if (!_ensureSufficientUtxos(
            utxoList, outputSum, estimatedVSize, newFeeRate, amount)) {
          return;
        }
        changeAddress = _walletProvider.getChangeAddress(_walletId).address;
      }
    }

    if (type == PaymentType.forSweep && changeAddress.isEmpty) {
      _bumpingTransaction = Transaction.forSweep(
          utxoList,
          externalOutputs[0].address,
          newFeeRate,
          walletListItemBase.walletBase);
      _sendInfoProvider.setRecipientAddress(externalOutputs[0].address);
      _sendInfoProvider.setIsMaxMode(true);
      return;
    }

    if (changeAddress.isEmpty) {
      changeAddress = _walletProvider.getChangeAddress(_walletId).address;
    }

    switch (type) {
      case PaymentType.forSweep:
      case PaymentType.forSinglePayment:
        _bumpingTransaction = Transaction.forSinglePayment(
            utxoList,
            externalOutputs[0].address,
            _addressRepository.getDerivationPath(_walletId, changeAddress),
            amount,
            newFeeRate,
            walletListItemBase.walletBase);
        _sendInfoProvider.setAmount(UnitUtil.satoshiToBitcoin(amount));
        _sendInfoProvider.setIsMaxMode(false);
        break;
      case PaymentType.forBatchPayment:
        Map<String, int> paymentMap =
            _createPaymentMapForRbfBatchTx(transaction.outputAddressList);

        _bumpingTransaction = Transaction.forBatchPayment(utxoList, paymentMap,
            changeAddress, newFeeRate, walletListItemBase.walletBase);

        _sendInfoProvider.setRecipientsForBatch(
            paymentMap.map((key, value) => MapEntry(key, value.toDouble())));
        _sendInfoProvider.setIsMaxMode(false);
        break;
      default:
        break;
    }
  }

  bool _ensureSufficientUtxos(List<Utxo> utxoList, double outputSum,
      int estimatedVSize, double newFeeRate, int amount) {
    double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    while (inputSum <= outputSum) {
      final additionalUtxos = _getAdditionalUtxos(outputSum - inputSum);
      if (additionalUtxos.isEmpty) {
        debugPrint('❌ 사용할 수 있는 추가 UTXO가 없음!');
        _insufficientUtxos = true;
        notifyListeners();
        return false;
      }
      utxoList.addAll(additionalUtxos);
      estimatedVSize += _getVSizeIncreasement() * additionalUtxos.length;

      inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
      outputSum = amount + estimatedVSize * newFeeRate;
    }
    return true;
  }

  int _getVSizeIncreasement() {
    switch (walletListItemBase.walletType) {
      case WalletType.singleSignature:
        return 68;
      case WalletType.multiSignature:
        final wallet = walletListItemBase.walletBase as MultisignatureWallet;
        final m = wallet.requiredSignature;
        final n = wallet.totalSigner;
        return 1 + (m * 73) + (n * 34) + 2;
      default:
        return 68;
    }
  }

  // todo: utxo lock 기능 추가 시 utxo 제외 로직 필요
  List<Utxo> _getAdditionalUtxos(double requiredAmount) {
    List<Utxo> additionalUtxos = [];
    final utxoStateList =
        _utxoRepository.getUtxosByStatus(_walletId, UtxoStatus.unspent);
    if (utxoStateList.isNotEmpty) {
      utxoStateList.sort((a, b) => a.amount.compareTo(b.amount));
      double sum = 0;
      for (var utxo in utxoStateList) {
        sum += utxo.amount;
        additionalUtxos.add(Utxo(
          utxo.transactionHash,
          utxo.index,
          utxo.amount,
          _addressRepository.getDerivationPath(_walletId, utxo.to),
        ));
        if (sum >= requiredAmount) {
          break;
        }
      }
    }
    return additionalUtxos;
  }

  Map<String, int> _createPaymentMapForRbfBatchTx(
      List<TransactionAddress> outputAddressList) {
    Map<String, int> paymentMap = {};

    for (TransactionAddress addressInfo in outputAddressList) {
      paymentMap[addressInfo.address] = addressInfo.amount;
    }

    return paymentMap;
  }

  Future<List<Utxo>> _getUtxoListForRbf() async {
    final txResult =
        await _nodeProvider.getTransaction(_parentTx.transactionHash);
    if (txResult.isFailure) {
      debugPrint('❌ 트랜잭션 조회 실패');
      return [];
    }

    final tx = txResult.value;
    final inputList = Transaction.parse(tx).inputs;

    List<Utxo> utxoList = [];
    for (var input in inputList) {
      var utxo = _utxoRepository.getUtxoState(
          _walletId, '${input.transactionHash}${input.index}');
      if (utxo != null && utxo.status == UtxoStatus.outgoing) {
        utxoList.add(Utxo(utxo.transactionHash, utxo.index, utxo.amount,
            utxo.derivationPath));
      }
    }

    return utxoList;
  }

  // 노드 프로바이더에서 추천 수수료 조회
  Future<void> _fetchRecommendedFees() async {
    // TODO: 테스트 후 원래 코드로 원복해야 함
    // ※ 주의 Node Provider 관련 import 문, 변수 등 지우지 말 것!
    final recommendedFeesResult = await _nodeProvider.getRecommendedFees();
    if (recommendedFeesResult.isFailure) {
      _isFeeFetchSuccess = false;
      notifyListeners();
      return;
    }

    final recommendedFees = recommendedFeesResult.value;

    // TODO: 추천수수료 mock 테스트 코드!
    // final recommendedFees = await DioClient().getRecommendedFee();

    _feeInfos[0].satsPerVb = recommendedFees.fastestFee;
    _feeInfos[1].satsPerVb = recommendedFees.halfHourFee;
    _feeInfos[2].satsPerVb = recommendedFees.hourFee;
    _isFeeFetchSuccess = true;
  }

  // 추천 수수료
  double _getRecommendedFeeRate(Transaction transaction) {
    if (_type == FeeBumpingType.cpfp) {
      return _getRecommendedFeeRateForCpfp(transaction);
    }
    return _getRecommendedFeeRateForRbf(transaction);
  }

  double _getRecommendedFeeRateForCpfp(Transaction transaction) {
    final recommendedFeeRate = _feeInfos[2].satsPerVb; // 느린 수수료

    if (recommendedFeeRate == null) {
      return 0;
    }
    if (recommendedFeeRate < _parentTx.feeRate) {
      return _parentTx.feeRate;
    }

    double cpfpTxSize = _estimateVirtualByte(transaction);
    double totalFee = (_parentTx.vSize + cpfpTxSize) * recommendedFeeRate;
    double cpfpTxFee = totalFee - _parentTx.fee!.toDouble();
    double cpfpTxFeeRate = cpfpTxFee / cpfpTxSize;

    if (cpfpTxFeeRate < recommendedFeeRate || cpfpTxFeeRate < 0) {
      return (recommendedFeeRate * 100).ceilToDouble() / 100;
    }

    return (cpfpTxFeeRate * 100).ceilToDouble() / 100;
  }

  /// 새로운 트랜잭션이 기존 트랜잭션보다 추가 지불하는 수수료양이 "새로운 트랜잭션 크기"이상이어야 합니다.
  /// 그렇지 않으면 브로드캐스팅 실패합니다.
  double _getRecommendedFeeRateForRbf(Transaction transaction) {
    final recommendedFeeRate = _feeInfos[2].satsPerVb; // 느린 수수료

    if (recommendedFeeRate == null) {
      return 0;
    }

    double estimatedVirtualByte = _estimateVirtualByte(transaction);
    double minimumRequiredFee =
        _parentTx.fee!.toDouble() + estimatedVirtualByte;
    double mempoolRecommendedFee = estimatedVirtualByte * recommendedFeeRate;

    if (mempoolRecommendedFee < minimumRequiredFee) {
      double feePerVByte = minimumRequiredFee / estimatedVirtualByte;
      double roundedFee = (feePerVByte * 100).ceilToDouble() / 100;

      // 계산된 추천 수수료가 현재 멤풀 수수료보다 작은 경우, 기존 수수료보다 1s/vb 높은 수수료로 설정
      // FYI, 이 조건에서 트랜잭션이 이미 처리되었을 것이므로 메인넷에서는 거의 발생 확률이 낮음
      if (feePerVByte < _parentTx.feeRate) {
        roundedFee = ((_parentTx.feeRate + 1) * 100).ceilToDouble() / 100;
      }
      return double.parse((roundedFee).toStringAsFixed(2));
    }

    return recommendedFeeRate.toDouble();
  }

  double _estimateVirtualByte(Transaction transaction) {
    double estimatedVirtualByte;
    switch (_walletListItemBase.walletType) {
      case WalletType.singleSignature:
        estimatedVirtualByte =
            transaction.estimateVirtualByte(AddressType.p2wpkh);
        break;
      case WalletType.multiSignature:
        final multisigWallet =
            _walletListItemBase.walletBase as MultisignatureWallet;
        estimatedVirtualByte = transaction.estimateVirtualByte(
            AddressType.p2wsh,
            requiredSignature: multisigWallet.requiredSignature,
            totalSigner: multisigWallet.totalSigner);
        break;
      default:
        throw Exception('Unknown wallet type');
    }
    return estimatedVirtualByte;
  }

  String _getRecommendedFeeRateDescriptionForCpfp() {
    assert(_recommendedFeeRate != null);
    assert(_bumpingTransaction != null);

    final recommendedFeeRate = _recommendedFeeRate!;
    // 추천 수수료가 현재 수수료보다 작은 경우
    // FYI, 이 조건에서 트랜잭션이 이미 처리되었을 것이므로 메인넷에서는 발생하지 않는 상황
    // 하지만, regtest에서 임의로 마이닝을 중지하는 경우 발생하여 예외 처리
    // 예) (pending tx fee rate) = 4 s/vb, (recommended fee rate) = 1 s/vb
    if (recommendedFeeRate < _parentTx.feeRate) {
      return t.transaction_fee_bumping_screen
          .recommended_fee_less_than_pending_tx_fee;
    }

    final cpfpTxSize = _estimateVirtualByte(_bumpingTransaction!);
    final cpfpTxFee = cpfpTxSize * recommendedFeeRate;
    final cpfpTxFeeRate = cpfpTxFee / cpfpTxSize;
    final totalRequiredFee =
        _parentTx.vSize * _parentTx.feeRate + cpfpTxSize * recommendedFeeRate;

    if (cpfpTxFeeRate < recommendedFeeRate || cpfpTxFeeRate < 0) {
      return t
          .transaction_fee_bumping_screen.recommended_fee_less_than_network_fee;
    }

    String inequalitySign = cpfpTxFeeRate % 1 == 0 ? "=" : "≈";
    return t.transaction_fee_bumping_screen.recommend_fee_info_cpfp(
      newTxSize: _formatNumber(cpfpTxSize),
      recommendedFeeRate: _formatNumber(recommendedFeeRate),
      originalTxSize: _formatNumber(_parentTx.vSize.toDouble()),
      originalFee: _formatNumber((_parentTx.fee ?? 0).toDouble()),
      totalRequiredFee: _formatNumber(totalRequiredFee.toDouble()),
      newTxFee: _formatNumber(cpfpTxFee),
      newTxFeeRate: _formatNumber(cpfpTxFeeRate),
      inequalitySign: inequalitySign,
    );
  }

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  }
}
