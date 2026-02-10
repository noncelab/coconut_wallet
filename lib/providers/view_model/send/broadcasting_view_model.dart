import 'dart:collection';
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
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
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/material.dart';

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
  bool _isSendingDonation = false;
  final List<String> _recipientAddresses = [];
  int? _sendingAmount;
  int? _fee;
  int? _totalAmount;
  int? _sendingAmountWhenAddressIsMyChange; // 내 지갑의 change address로 보내는 경우 잔액
  final List<int> _outputIndexesToMyAddress = [];
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
  bool get isSendingDonation => _isSendingDonation;
  int? get sendingAmountWhenAddressIsMyChange => _sendingAmountWhenAddressIsMyChange;
  int? get totalAmount => _totalAmount;
  AddressType? get walletAddressType => _walletBase?.addressType;
  int? get walletId => _walletId;
  SendEntryPoint? get sendEntryPoint => _sendInfoProvider.sendEntryPoint;
  FeeBumpingType? get feeBumpingType => _sendInfoProvider.feeBumpingType;

  int? get unsignedDraftId => _sendInfoProvider.unsignedDraftId;
  Transaction? get signedTx => _signedTx;
  bool get isAlreadySaved => _signedDraftId != null || _savedDraftId != null;

  Future<Result<String>> broadcast() async {
    Logger.log('BroadcastingViewModel: signedTx = ${_signedTx!.serialize()}');
    final isConnected = await isElectrumServerConnected();
    if (!isConnected) {
      await _nodeProvider.reconnect();
    }
    return _nodeProvider.broadcast(_signedTx!);
  }

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
    if (_signedDraftId != null) {
      await _setSendProviderFromSignedDraft(_signedDraftId);
    }

    _walletBase = _walletProvider.getWalletById(_sendInfoProvider.walletId!).walletBase;
    _walletId = _sendInfoProvider.walletId!;

    _isSendingDonation = _sendInfoProvider.isDonation ?? false;

    Psbt signedPsbt;
    if (isPsbt(_sendInfoProvider.signedResult!)) {
      signedPsbt = Psbt.parse(_sendInfoProvider.signedResult!);
      _signedTx = signedPsbt.getSignedTransaction(walletAddressType!);
    } else {
      try {
        signedPsbt = Psbt.parse(_sendInfoProvider.txWaitingForSign!);

        // raw transaction 데이터 처리 (hex 또는 base64)
        String hexTransaction = decodeTransactionToHex(_sendInfoProvider.signedResult!);
        final signedTx = Transaction.parse(hexTransaction);
        final unSingedTx = signedPsbt.unsignedTransaction;

        // 콜드카드의 경우 SignedTransaction을 넘겨주기 때문에, UnsignedTransaction과 같은 데이터인지 검사 필요
        bool isContentEqual = isTxContentEqual(signedTx, unSingedTx);

        if (!isContentEqual) {
          throw InvalidTransactionException();
        }

        _signedTx = Transaction.parse(hexTransaction);
      } catch (e) {
        Logger.log('--> BroadcastingViewModel.setTxInfo: raw transaction processing error: $e');
        rethrow;
      }
    }
    // input UTXO 유효성 검증
    final inputUtxoIds = _signedTx!.inputs.map((input) => getUtxoId(input.transactionHash, input.index)).toList();
    final (_, excludedUtxoStatus) = _utxoRepository.getValidatedSelectedUtxoList(_walletId!, inputUtxoIds);

    debugPrint('------- sendInfoProvider ------');
    debugPrint('transactionDraftId: ${_sendInfoProvider.unsignedDraftId}');
    debugPrint('signedPsbt: ${_sendInfoProvider.signedResult}');
    debugPrint('txWaitingForSign: ${_sendInfoProvider.txWaitingForSign}');
    debugPrint('walletId: ${_sendInfoProvider.walletId}');
    debugPrint('walletBase: $_walletBase');
    debugPrint('walletAddressType: ${_walletBase!.addressType}');
    debugPrint('walletId: $_walletId');
    debugPrint('-------------------------------');

    Psbt psbt;
    if (_hasAllInputsBip32Derivation(signedPsbt)) {
      psbt = signedPsbt;
    } else {
      psbt = Psbt.parse(_sendInfoProvider.txWaitingForSign!);
    }

    List<PsbtOutput> outputs = psbt.outputs;

    // case1. 다른 사람에게 보내고(B1) 잔액이 있는 경우(A2)
    // case2. 다른 사람에게 보내고(B1) 잔액이 없는 경우
    // case3. 내 지갑의 다른 주소로 보내고(A2) 잔액이 있는 경우(A3)
    // case4. 내 지갑의 다른 주소로 보내고(A2) 잔액이 없는 경우
    // 만약 실수로 내 지갑의 change address로 보내는 경우에는 sendingAmount가 0
    List<PsbtOutput> outputToMyReceivingAddress = [];
    List<PsbtOutput> outputToMyChangeAddress = [];
    List<PsbtOutput> outputsToOther = [];
    for (int i = 0; i < outputs.length; i++) {
      if (outputs[i].bip32Derivation == null) {
        outputsToOther.add(outputs[i]);
      } else if (outputs[i].isChange) {
        outputToMyChangeAddress.add(outputs[i]);
        _outputIndexesToMyAddress.add(i);
      } else {
        outputToMyReceivingAddress.add(outputs[i]);
        _outputIndexesToMyAddress.add(i);
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
      _sendingAmount = psbt.sendingAmount;
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

      _sendingAmount = psbt.sendingAmount;
      if (output != null) {
        _recipientAddresses.add(output.outAddress);
      }
    }
    _fee = psbt.fee;
    _totalAmount = psbt.sendingAmount + psbt.fee;

    _setSignedTransaction(psbt);

    if (excludedUtxoStatus == null) {
      _isInitDone = true;
    }
    notifyListeners();
    return excludedUtxoStatus;
  }

  bool isTxContentEqual(Transaction signedTx, Transaction? unSignedTx) {
    if (unSignedTx == null) return false;

    debugPrint('unsignedPsbt:: $unSignedTx');

    // inputs, outputs 길이가 같은지 비교
    if (signedTx.inputs.length != unSignedTx.inputs.length) return false;
    if (signedTx.outputs.length != unSignedTx.outputs.length) return false;

    // outputs에서 각 output의 amount가 같은지 비교
    for (int i = 0; i < signedTx.outputs.length; i++) {
      if (signedTx.outputs[i].amount != unSignedTx.outputs[i].amount) return false;
    }

    // totalInputAmount 비교
    if (signedTx.totalInputAmount != unSignedTx.totalInputAmount) return false;

    // 트랜잭션 버전 비교
    if (signedTx.version != unSignedTx.version) return false;

    // lockTime 비교 - 추후 필요시 구현, 현재는 다르기 때문에 사용안함
    // if (tx.lockTime != unSignedTx.lockTime) return false;

    return true;
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

  void _setSignedTransaction(Psbt psbt) {}

  // pending상태였던 Tx가 confirmed 되었는지 조회
  bool hasTransactionConfirmed() {
    return _txProvider.hasTransactionConfirmed(walletId!, _txProvider.transaction!.transactionHash);
  }

  Future<void> updateTagsOfUsedUtxos() async {
    try {
      await _tagProvider.applyTagsToNewUtxos(_walletId!, _signedTx!.transactionHash, _outputIndexesToMyAddress);
    } catch (e) {
      Logger.error(e.toString());
      // ignore
    }
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
    _sendInfoProvider.setWalletId(draft.walletId);
    _sendInfoProvider.setFeeRate(draft.feeRate!);
    _sendInfoProvider.setIsMaxMode(draft.isMaxMode!);
    _sendInfoProvider.setTxWaitingForSign(draft.txWaitingForSign!);
    _sendInfoProvider.setSignedResult(draft.signedPsbtBase64Encoded!);
  }

  Future<Result<TransactionDraft>> saveTransactionDraft() async {
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
  Future<void> deleteDraftsIfNeeded() async {
    // 서명 전 트랜잭션 삭제
    if (_sendInfoProvider.unsignedDraftId != null) {
      try {
        await _txDraftRepository.deleteOne(_sendInfoProvider.unsignedDraftId!);
      } catch (e) {
        Logger.error('Failed to delete unsigned draft: $e');
      }
    }

    // 서명 완료 트랜잭션 삭제 (_signedDraftId와 _savedDraftId는 상호 배타적)
    final signedDraftIdToDelete = _signedDraftId ?? _savedDraftId;
    if (signedDraftIdToDelete != null) {
      try {
        await _txDraftRepository.deleteOne(signedDraftIdToDelete);
      } catch (e) {
        Logger.error('Failed to delete signed draft: $e');
      }
    }
  }

  // 삭제 실패 시 안내..??
  Future<void> deleteSignedDraft() async {
    final signedDraftIdToDelete = _signedDraftId ?? _savedDraftId;
    assert(signedDraftIdToDelete != null);
    await _txDraftRepository.deleteOne(signedDraftIdToDelete!);
  }
}
