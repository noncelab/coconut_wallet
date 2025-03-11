import 'dart:collection';

import 'package:coconut_lib/coconut_lib.dart';

class SendInfoProvider {
  int? _walletId;
  String? _recipientAddress;
  double? _amount;
  int? _feeRate;
  int? _estimatedFee;
  bool? _isMaxMode;
  bool? _isMultisig;
  Transaction? _transaction;
  String? _txWaitingForSign;
  String? _signedPsbtBase64Encoded;
  // batch tx (주소, 수량)
  Map<String, int>? _recipientsForBatch;

  int? get walletId => _walletId;
  String? get recipientAddress => _recipientAddress;
  double? get amount => _amount;
  int? get feeRate => _feeRate;
  int? get estimatedFee => _estimatedFee;
  bool? get isMaxMode => _isMaxMode;
  bool? get isMultisig => _isMultisig;
  Transaction? get transaction => _transaction;
  String? get txWaitingForSign => _txWaitingForSign;
  String? get signedPsbt => _signedPsbtBase64Encoded;
  Map<String, int>? get recipientsForBatch => _recipientsForBatch == null
      ? null
      : UnmodifiableMapView(_recipientsForBatch!);

  setWalletId(int id) {
    _walletId = id;
  }

  setRecipientAddress(String address) {
    _recipientAddress = address;
  }

  setAmount(double amount) {
    _amount = amount;
  }

  setFeeRate(int feeRate) {
    _feeRate = feeRate;
  }

  setEstimatedFee(int fee) {
    _estimatedFee = fee;
  }

  setIsMaxMode(bool isMaxMode) {
    _isMaxMode = isMaxMode;
  }

  setIsMultisig(bool isMultisig) {
    _isMultisig = isMultisig;
  }

  setTransaction(Transaction transaction) {
    _transaction = transaction;
  }

  setTxWaitingForSign(String transaction) {
    _txWaitingForSign = transaction;
  }

  setSignedPsbtBase64Encoded(String signedPsbtBase64Encoded) {
    _signedPsbtBase64Encoded = signedPsbtBase64Encoded;
  }

  setRecipientsForBatch(Map<String, int> recipients) {
    _recipientsForBatch = recipients;
  }

  clear() {
    _walletId = _recipientAddress = _amount = _feeRate = _estimatedFee =
        _isMaxMode = _isMultisig = _transaction = _txWaitingForSign =
            _signedPsbtBase64Encoded = _recipientsForBatch = null;
  }
}
