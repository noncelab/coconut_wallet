import 'dart:collection';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';

class SendInfoProvider {
  int? _walletId;
  String? _recipientAddress;
  double? _amount;
  int? _estimatedFee;
  bool? _isMaxMode;
  bool? _isMultisig;
  bool? _isDonation;
  Transaction? _transaction;
  String? _txWaitingForSign;
  String? _signedPsbtBase64Encoded;
  // batch tx (주소, 수량)
  Map<String, double>? _recipientsForBatch;
  // null인 경우 RBF 또는 CPFP가 아닙니다.
  FeeBumpingType? _feeBumpingType;
  WalletImportSource? _walletImportSource;

  int? get walletId => _walletId;
  String? get recipientAddress => _recipientAddress;
  double? get amount => _amount;
  int? get estimatedFee => _estimatedFee;
  bool? get isMaxMode => _isMaxMode;
  bool? get isMultisig => _isMultisig;
  bool? get isDonation => _isDonation;
  Transaction? get transaction => _transaction;
  String? get txWaitingForSign => _txWaitingForSign;
  String? get signedPsbt => _signedPsbtBase64Encoded;
  Map<String, double>? get recipientsForBatch =>
      _recipientsForBatch == null ? null : UnmodifiableMapView(_recipientsForBatch!);
  FeeBumpingType? get feeBumpingType => _feeBumpingType;
  WalletImportSource? get walletImportSource => _walletImportSource;

  void setWalletId(int id) {
    _walletId = id;
  }

  void setRecipientAddress(String address) {
    _recipientAddress = address;
  }

  void setAmount(double amount) {
    _amount = amount;
  }

  void setEstimatedFee(int fee) {
    _estimatedFee = fee;
  }

  void setIsMaxMode(bool isMaxMode) {
    _isMaxMode = isMaxMode;
  }

  void setIsMultisig(bool isMultisig) {
    _isMultisig = isMultisig;
  }

  void setTransaction(Transaction transaction) {
    _transaction = transaction;
  }

  void setTxWaitingForSign(String transaction) {
    _txWaitingForSign = transaction;
  }

  void setSignedPsbtBase64Encoded(String signedPsbtBase64Encoded) {
    _signedPsbtBase64Encoded = signedPsbtBase64Encoded;
  }

  void setRecipientsForBatch(Map<String, double> recipients) {
    _recipientsForBatch = recipients;
  }

  void setFeeBumpfingType(FeeBumpingType? feeBumpingType) {
    _feeBumpingType = feeBumpingType;
  }

  void setWalletImportSource(WalletImportSource walletImportSource) {
    _walletImportSource = walletImportSource;
  }

  void setIsDonation(bool isDonation) {
    _isDonation = isDonation;
  }

  void clear() {
    _walletId = _recipientAddress = _amount = _estimatedFee = _isMaxMode = _isMultisig =
        _transaction = _txWaitingForSign = _signedPsbtBase64Encoded =
            _isDonation = _recipientsForBatch = _feeBumpingType = _walletImportSource = null;
  }

  Map<String, int>? getRecipientMap() {
    if (_recipientsForBatch == null && _recipientAddress == null) {
      return null;
    }

    if (_recipientsForBatch != null) {
      return _recipientsForBatch!
          .map((key, value) => MapEntry(key, UnitUtil.convertBitcoinToSatoshi(value)));
    }

    return {_recipientAddress!: UnitUtil.convertBitcoinToSatoshi(_amount!)};
  }
}
