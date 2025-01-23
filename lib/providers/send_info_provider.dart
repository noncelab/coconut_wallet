import 'package:coconut_lib/coconut_lib.dart';

class SendInfoProvider {
  int? _walletId;
  String? _receipientAddress;
  double? _amount;
  int? _feeRate;
  int? _estimatedFee;
  bool? _isMaxMode;
  bool? _isMultisig;
  Transaction? _transaction;
  String? _txWaitingForSign;
  String? _signedPsbtBase64Encoded;

  int? get walletId => _walletId;
  String? get receipientAddress => _receipientAddress;
  double? get amount => _amount;
  int? get feeRate => _feeRate;
  int? get estimatedFee => _estimatedFee;
  bool? get isMaxMode => _isMaxMode;
  bool? get isMultisig => _isMultisig;
  Transaction? get transaction => _transaction;
  String? get txWaitingForSign => _txWaitingForSign;
  String? get signedPsbt => _signedPsbtBase64Encoded;

  setWalletId(int id) {
    _walletId = id;
  }

  setReceipientAddress(String address) {
    _receipientAddress = address;
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

  clear() {
    _walletId = _receipientAddress = _amount = _feeRate = _estimatedFee =
        _isMaxMode = _isMultisig =
            _transaction = _txWaitingForSign = _signedPsbtBase64Encoded = null;
  }
}
