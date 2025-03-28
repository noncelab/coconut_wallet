import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
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
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:flutter/material.dart';

enum PaymentType {
  sweep,
  singlePayment,
  batchPayment,
}

class FeeBumpingViewModel extends ChangeNotifier {
  final FeeBumpingType _type;
  final TransactionRecord _pendingTx;
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final SendInfoProvider _sendInfoProvider;
  final TransactionProvider _txProvider;
  final AddressRepository _addressRepository;
  final UtxoRepository _utxoRepository;
  final int _walletId;
  Transaction? _bumpingTransaction;
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
    this._pendingTx,
    this._walletId,
    this._sendInfoProvider,
    this._nodeProvider,
    this._txProvider,
    this._walletProvider,
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

  TransactionRecord get transaction => _pendingTx;
  int get walletId => _walletId;

  WalletListItemBase get walletListItemBase => _walletListItemBase;

  bool _insufficientUtxos = false;
  bool get insufficientUtxos => _insufficientUtxos;

  Future<void> initialize() async {
    await _fetchRecommendedFees(); // _isFeeFetchSuccess로 성공 여부 기록함
    if (_isFeeFetchSuccess == true) {
      await initializeBumpingTransaction(_feeInfos[2].satsPerVb!.toDouble());
      if (_bumpingTransaction == null) {
        _isInitializedSuccess = false;
        return;
      }
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

    return feeRate < _recommendedFeeRate! || feeRate < _pendingTx.feeRate;
  }

  // pending상태였던 Tx가 confirmed 되었는지 조회
  bool hasTransactionConfirmed() {
    TransactionRecord? tx = _txProvider.getTransactionRecord(
        _walletId, transaction.transactionHash);
    if (tx == null || tx.blockHeight! <= 0) return false;
    return true;
  }

  Future<bool> prepareToSend(double newTxFeeRate) async {
    assert(_bumpingTransaction != null);
    try {
      await initializeBumpingTransaction(newTxFeeRate);
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
    _sendInfoProvider.setWalletId(_walletId);
    _sendInfoProvider.setIsMultisig(
        _walletListItemBase.walletType == WalletType.multiSignature);
    _sendInfoProvider.setTxWaitingForSign(Psbt.fromTransaction(
            _bumpingTransaction!, _walletListItemBase.walletBase)
        .serialize());
    _sendInfoProvider.setFeeBumpfingType(feeBumpingType);
  }

  List<TransactionAddress> _getExternalOutputs() => _pendingTx.outputAddressList
      .where((output) => !_walletProvider
          .containsAddress(_walletId, output.address, isChange: true))
      .toList();

  List<TransactionAddress> _getMyOutputs() => _pendingTx.outputAddressList
      .where((output) =>
          _walletProvider.containsAddress(_walletId, output.address))
      .toList();

  PaymentType? _getPaymentType() {
    int inputCount = _pendingTx.inputAddressList.length;
    int outputCount = _pendingTx.outputAddressList.length;

    if (inputCount == 0 || outputCount == 0) {
      return null; // wrong tx
    }

    final externalOutputs = _getExternalOutputs();
    switch (outputCount) {
      case 1:
        return PaymentType.sweep;
      case 2:
        if (externalOutputs.length == 1) {
          return PaymentType.singlePayment;
        }
      default:
        return PaymentType.batchPayment;
    }

    return null;
  }

  // 새 수수료로 트랜잭션 생성
  Future<void> initializeBumpingTransaction(double newFeeRate) async {
    if (_type == FeeBumpingType.cpfp) {
      _initializeCpfpTransaction(newFeeRate);
    } else if (_type == FeeBumpingType.rbf) {
      await _initializeRbfTransaction(newFeeRate);
    }
  }

  void _initializeCpfpTransaction(double newFeeRate) {
    final myAddressList = _getMyOutputs();
    int amount = myAddressList.fold(0, (sum, output) => sum + output.amount);
    final List<Utxo> utxoList = [];
    // 내 주소와 일치하는 utxo 찾기
    for (var myAddress in myAddressList) {
      final utxoStateList =
          _utxoRepository.getUtxosByStatus(_walletId, UtxoStatus.incoming);
      for (var utxoState in utxoStateList) {
        if (myAddress.address == utxoState.to &&
            myAddress.amount == utxoState.amount &&
            _pendingTx.transactionHash == utxoState.transactionHash &&
            _pendingTx.outputAddressList[utxoState.index].address ==
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
      estimatedVSize = _pendingTx.vSize.toDouble();
      double outputSum = amount + estimatedVSize * newFeeRate;

      debugPrint(
          '😇 CPFP utxo (${utxoList.length})개 input: $inputSum / output: $outputSum / 👉🏻 입력한 fee rate: $newFeeRate');
      if (!_ensureSufficientUtxos(
          utxoList, outputSum, estimatedVSize, newFeeRate, amount)) {
        debugPrint('❌ 사용할 수 있는 추가 UTXO가 없음!');
        return;
      }

      _bumpingTransaction = Transaction.forSweep(
          utxoList, recipient, newFeeRate, walletListItemBase.walletBase);
    }

    debugPrint('😇 CPFP utxo (${utxoList.length})개');
    _sendInfoProvider.setRecipientAddress(recipient);
    _sendInfoProvider.setIsMaxMode(true);
    _sendInfoProvider
        .setAmount(_bumpingTransaction!.outputs[0].amount.toDouble());
    _setInsufficientUtxo(false);
  }

  Future<void> _initializeRbfTransaction(double newFeeRate) async {
    final type = _getPaymentType();
    if (type == null) return;

    final externalOutputs = _getExternalOutputs();
    var externalSendingAmount =
        externalOutputs.fold(0, (sum, output) => sum + output.amount);

    final int changeOutputIndex =
        _pendingTx.outputAddressList.lastIndexWhere((output) {
      return _walletProvider.containsAddress(_walletId, output.address,
          isChange: true);
    });
    TransactionAddress changeTxAddress = changeOutputIndex == -1
        ? TransactionAddress('', 0)
        : _pendingTx.outputAddressList[changeOutputIndex];
    var changeAddress = changeTxAddress.address;
    var changeAmount = changeTxAddress.amount;
    final bool hasChange = changeAddress.isNotEmpty && changeAmount > 0;

    //input 정보 추출
    List<Utxo> utxoList = await _getUtxoListForRbf();
    double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    double estimatedVSize = _bumpingTransaction == null
        ? _pendingTx.vSize.toDouble()
        : _bumpingTransaction!
            .estimateVirtualByte(_walletListItemBase.walletBase.addressType);
    double newFee = estimatedVSize * newFeeRate;
    double outputSum = externalSendingAmount + newFee;

    // 내 주소가 output에 있는지 확인
    final selfOutputs = externalOutputs
        .where((output) =>
            _walletProvider.containsAddress(_walletId, output.address))
        .toList();
    final containsSelfOutputs = selfOutputs.isNotEmpty;

    List<TransactionAddress> newOutputList =
        List.from(_pendingTx.outputAddressList);
    if (changeOutputIndex != -1) {
      newOutputList.removeAt(changeOutputIndex);
    }

    debugPrint('RBF:: $inputSum $outputSum');
    if (inputSum < outputSum) {
      debugPrint('RBF:: ❌ input 합계가 output 합계보다 작음!');
      // 1. 충분한 잔돈이 있음 - singlePayment or batchPayment
      if (hasChange) {
        if (changeAmount >= newFee) {
          debugPrint('RBF:: 1️⃣ 충분한 Change 있음');
          if (type == PaymentType.batchPayment) {
            debugPrint('RBF:: 1.1.1. 배치 트잭');
            _generateBatchTransation(
                utxoList,
                _createPaymentMapForRbfBatchTx(newOutputList),
                changeAddress,
                newFeeRate);
            return;
          }

          if (changeAmount == newFee) {
            debugPrint('RBF:: 1.1.2. Change = newFee >>> 스윕 트잭');
            _generateSweepPayment(
                utxoList, externalOutputs[0].address, newFeeRate);
            return;
          }

          debugPrint('RBF:: 1.1.3. Change > newFee >>> 싱글 트잭');
          _generateSinglePayment(utxoList, externalOutputs[0].address,
              changeAddress, newFeeRate, externalSendingAmount);
          return;
        } else {
          debugPrint('RBF:: 2️⃣ Change 있지만 부족함');
          if (!_ensureSufficientUtxos(utxoList, outputSum, estimatedVSize,
              newFeeRate, externalSendingAmount)) {
            return;
          }
        }
      }
      // 2. output에 내 주소가 있는 경우 amount 조정
      else if (containsSelfOutputs) {
        debugPrint('RBF:: 3️⃣ 내 아웃풋이 있음!');
        // 1. 배치 트랜잭션인 경우
        if (type == PaymentType.batchPayment) {
          debugPrint('RBF:: 배치 트랜잭션임');
          Map<String, int> paymentMap = {};
          int remainingFee = newFee.toInt();
          for (var output in newOutputList) {
            if (selfOutputs
                .any((selfOutput) => selfOutput.address == output.address)) {
              int deduction = remainingFee > output.amount
                  ? output.amount.toInt()
                  : remainingFee.toInt();

              if (output.amount - deduction > 0) {
                paymentMap[output.address] = output.amount - deduction;
              }
              remainingFee -= deduction;
            } else {
              paymentMap[output.address] = output.amount;
            }
          }

          if (remainingFee > 0) {
            if (!_ensureSufficientUtxos(utxoList, outputSum, estimatedVSize,
                newFeeRate, paymentMap.values.reduce((a, b) => a + b))) {
              return;
            }
          }

          _generateBatchTransation(
              utxoList, paymentMap, changeAddress, newFeeRate);
          return;
        }
        //2. 내 주소로 보내는 싱글 또는 스윕이었던 경우
        final myOutputAmount = selfOutputs[0].amount;
        debugPrint('RBF:: 싱글 또는 스윕 >> amount 조정 $externalSendingAmount');
        int adjustedMyOuputAmount =
            myOutputAmount - (newFee - _pendingTx.fee!).toInt();
        debugPrint('RBF::                        조정 후 $adjustedMyOuputAmount');

        if (adjustedMyOuputAmount == 0) {
          debugPrint('RBF:: 조정해서 내가 받을 금액 0 - 남의 주소에게 보내는 스윕 트잭');
          _generateSweepPayment(utxoList, selfOutputs[0].address, newFeeRate);
          return;
        }

        if (adjustedMyOuputAmount > 0 && adjustedMyOuputAmount > dustLimit) {
          debugPrint('RBF:: 금액 조정 - $adjustedMyOuputAmount');
          changeAddress = _walletProvider.getChangeAddress(_walletId).address;
          _generateSinglePayment(utxoList, selfOutputs[0].address,
              changeAddress, newFeeRate, adjustedMyOuputAmount);
          return;
        }

        debugPrint('RBF:: ❌ amount 조정해도 안됨 > utxo 추가 - amount 조정 없이 utxo 추가');
        if (!_ensureSufficientUtxos(utxoList, outputSum, estimatedVSize,
            newFeeRate, externalSendingAmount)) {
          return;
        }
        debugPrint('RBF:: ✅ utxo 추가 완료 보낼 수량 $externalSendingAmount');
        changeAddress = _walletProvider.getChangeAddress(_walletId).address;
        _generateSinglePayment(utxoList, externalOutputs[0].address,
            changeAddress, newFeeRate, externalSendingAmount);
        return;
      } else {
        debugPrint('RBF:: 4️⃣ change도 없고, 내 아웃풋도 없음 >>> utxo 추가!');
        if (!_ensureSufficientUtxos(utxoList, outputSum, estimatedVSize,
            newFeeRate, externalSendingAmount)) {
          return;
        }
        changeAddress = _walletProvider.getChangeAddress(_walletId).address;
      }
    }

    debugPrint(
        'RBF:: $inputSum 합계 > $outputSum 합계 OR if (inputSum < outputSum) 문 빠져나옴!!');
    if (type == PaymentType.sweep && changeAddress.isEmpty) {
      _generateSweepPayment(utxoList, externalOutputs[0].address, newFeeRate);
      return;
    }

    if (changeAddress.isEmpty) {
      changeAddress = _walletProvider.getChangeAddress(_walletId).address;
    }

    switch (type) {
      case PaymentType.sweep:
      case PaymentType.singlePayment:
        _generateSinglePayment(utxoList, externalOutputs[0].address,
            changeAddress, newFeeRate, externalSendingAmount);
        break;
      case PaymentType.batchPayment:
        Map<String, int> paymentMap =
            _createPaymentMapForRbfBatchTx(newOutputList);

        _generateBatchTransation(
            utxoList, paymentMap, changeAddress, newFeeRate);
        break;
      default:
        break;
    }
  }

  void _generateSinglePayment(List<Utxo> inputs, String recipient,
      String changeAddress, double feeRate, int amount) {
    _bumpingTransaction = Transaction.forSinglePayment(
        inputs,
        recipient,
        _addressRepository.getDerivationPath(_walletId, changeAddress),
        amount,
        feeRate,
        walletListItemBase.walletBase);
    _sendInfoProvider.setAmount(UnitUtil.satoshiToBitcoin(amount));
    _sendInfoProvider.setIsMaxMode(false);
    _setInsufficientUtxo(false);
    debugPrint('RBF::    ▶️ 싱글 트잭 생성(fee rate: $feeRate)');
  }

  void _generateSweepPayment(
      List<Utxo> inputs, String recipient, double feeRate) {
    _bumpingTransaction = Transaction.forSweep(
        inputs, recipient, feeRate, _walletListItemBase.walletBase);
    _sendInfoProvider.setRecipientAddress(recipient);
    _sendInfoProvider.setIsMaxMode(true);
    _setInsufficientUtxo(false);
    debugPrint('RBF::    ▶️ 스윕 트잭 생성(fee rate: $feeRate)');
  }

  void _generateBatchTransation(List<Utxo> inputs, Map<String, int> paymentMap,
      String changeAddress, double feeRate) {
    _bumpingTransaction = Transaction.forBatchPayment(
        inputs,
        paymentMap,
        _addressRepository.getDerivationPath(_walletId, changeAddress),
        feeRate,
        _walletListItemBase.walletBase);
    _sendInfoProvider.setRecipientsForBatch(
        paymentMap.map((key, value) => MapEntry(key, value.toDouble())));
    _sendInfoProvider.setIsMaxMode(false);
    _setInsufficientUtxo(false);
    debugPrint('RBF::    ▶️ 배치 트잭 생성(fee rate: $feeRate)');
  }

  bool _ensureSufficientUtxos(List<Utxo> utxoList, double outputSum,
      double estimatedVSize, double newFeeRate, int amount) {
    double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    List<UtxoState> unspentUtxos =
        _utxoRepository.getUtxosByStatus(_walletId, UtxoStatus.unspent);
    unspentUtxos.sort((a, b) => b.amount.compareTo(a.amount));
    int sublistIndex = 0; // for unspentUtxos
    while (inputSum <= outputSum && sublistIndex < unspentUtxos.length) {
      final additionalUtxos = _getAdditionalUtxos(
          unspentUtxos.sublist(sublistIndex), outputSum - inputSum);
      if (additionalUtxos.isEmpty) {
        debugPrint('❌ 사용할 수 있는 추가 UTXO가 없음!');
        _setInsufficientUtxo(true);
        return false;
      }
      utxoList.addAll(additionalUtxos);
      sublistIndex += additionalUtxos.length;

      int additionalVSize = _getVSizeIncreasement() * additionalUtxos.length;
      outputSum = amount + (estimatedVSize + additionalVSize) * newFeeRate;
      inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    }

    if (inputSum <= outputSum) {
      _setInsufficientUtxo(true);
      return false;
    }

    _setInsufficientUtxo(false);
    return true;
  }

  void _setInsufficientUtxo(bool value) {
    _insufficientUtxos = value;
    notifyListeners();
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
  List<Utxo> _getAdditionalUtxos(
      List<Utxo> unspentUtxo, double requiredAmount) {
    List<Utxo> additionalUtxos = [];
    double sum = 0;
    if (unspentUtxo.isNotEmpty) {
      for (var utxo in unspentUtxo) {
        sum += utxo.amount;
        additionalUtxos.add(utxo);
        if (sum >= requiredAmount) {
          break;
        }
      }
    }

    if (sum < requiredAmount) {
      return [];
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
        await _nodeProvider.getTransaction(_pendingTx.transactionHash);
    if (txResult.isFailure) {
      debugPrint('❌ 트랜잭션 조회 실패');
      return [];
    }

    final tx = txResult.value;
    final inputList = Transaction.parse(tx).inputs;

    List<Utxo> utxoList = [];
    for (var input in inputList) {
      var utxo = _utxoRepository.getUtxoState(
          _walletId, makeUtxoId(input.transactionHash, input.index));
      if (utxo != null) {
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
    if (recommendedFeeRate < _pendingTx.feeRate) {
      return _pendingTx.feeRate;
    }

    double cpfpTxSize = _estimateVirtualByte(transaction);
    double totalFee = (_pendingTx.vSize + cpfpTxSize) * recommendedFeeRate;
    double cpfpTxFee = totalFee - _pendingTx.fee!.toDouble();
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
        _pendingTx.fee!.toDouble() + estimatedVirtualByte;
    // double mempoolRecommendedFee = estimatedVirtualByte * recommendedFeeRate;

    // if (mempoolRecommendedFee < minimumRequiredFee) {
    double feePerVByte = minimumRequiredFee / estimatedVirtualByte;
    double roundedFee = (feePerVByte * 100).ceilToDouble() / 100;

    // 계산된 추천 수수료가 현재 멤풀 수수료보다 작은 경우, 기존 수수료보다 1s/vb 높은 수수료로 설정
    // FYI, 이 조건에서 트랜잭션이 이미 처리되었을 것이므로 메인넷에서는 거의 발생 확률이 낮음
    // if (feePerVByte < _pendingTx.feeRate) {
    // roundedFee = ((_pendingTx.feeRate + 1) * 100).ceilToDouble() / 100;
    // }
    return double.parse((roundedFee).toStringAsFixed(2));
    // }

    // return recommendedFeeRate.toDouble();
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
    if (recommendedFeeRate < _pendingTx.feeRate) {
      return t.transaction_fee_bumping_screen
          .recommended_fee_less_than_pending_tx_fee;
    }

    final cpfpTxSize = _estimateVirtualByte(_bumpingTransaction!);
    final cpfpTxFee = cpfpTxSize * recommendedFeeRate;
    final cpfpTxFeeRate = cpfpTxFee / cpfpTxSize;
    final totalRequiredFee =
        _pendingTx.vSize * _pendingTx.feeRate + cpfpTxSize * recommendedFeeRate;

    if (cpfpTxFeeRate < recommendedFeeRate || cpfpTxFeeRate < 0) {
      return t
          .transaction_fee_bumping_screen.recommended_fee_less_than_network_fee;
    }

    String inequalitySign = cpfpTxFeeRate % 1 == 0 ? "=" : "≈";
    return t.transaction_fee_bumping_screen.recommend_fee_info_cpfp(
      newTxSize: _formatNumber(cpfpTxSize),
      recommendedFeeRate: _formatNumber(recommendedFeeRate),
      originalTxSize: _formatNumber(_pendingTx.vSize.toDouble()),
      originalFee: _formatNumber((_pendingTx.fee ?? 0).toDouble()),
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
