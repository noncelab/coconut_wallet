import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';

enum SendEntryPoint { home, walletDetail }

class SendInfoProvider {
  int? _walletId;
  int? _estimatedFee;
  bool? _isMaxMode;
  bool? _isMultisig;
  SendEntryPoint? _sendEntryPoint;
  Transaction? _transaction;
  String? _txWaitingForSign;
  String? _signedResult; // Base64 OR RawHexString
  // null인 경우 RBF 또는 CPFP가 아닙니다.
  FeeBumpingType? _feeBumpingType;
  WalletImportSource? _walletImportSource;
  int? _unsignedDraftId;
  double? _feeRate;

  int? get walletId => _walletId;
  int? get estimatedFee => _estimatedFee;
  bool? get isMaxMode => _isMaxMode;
  bool? get isMultisig => _isMultisig;
  SendEntryPoint? get sendEntryPoint => _sendEntryPoint;
  Transaction? get transaction => _transaction;
  String? get txWaitingForSign => _txWaitingForSign;
  String? get signedResult => _signedResult; // Base64 OR RawHexString
  FeeBumpingType? get feeBumpingType => _feeBumpingType;
  WalletImportSource? get walletImportSource => _walletImportSource;
  int? get unsignedDraftId => _unsignedDraftId;
  double? get feeRate => _feeRate;

  void setFeeRate(double feeRate) {
    _feeRate = feeRate;
  }

  void setUnsignedDraftId(int? id) {
    _unsignedDraftId = id;
  }

  void setWalletId(int id) {
    _walletId = id;
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

  void setSignedResult(String signedPsbtBase64Encoded) {
    _signedResult = signedPsbtBase64Encoded;
  }

  void setFeeBumpfingType(FeeBumpingType? feeBumpingType) {
    _feeBumpingType = feeBumpingType;
  }

  void setWalletImportSource(WalletImportSource walletImportSource) {
    _walletImportSource = walletImportSource;
  }

  void setSendEntryPoint(SendEntryPoint sendEntryPoint) {
    _sendEntryPoint = sendEntryPoint;
  }

  void clear() {
    _walletId =
        _estimatedFee =
            _isMaxMode =
                _isMultisig =
                    _transaction =
                        _txWaitingForSign =
                            _signedResult =
                                _sendEntryPoint = _feeBumpingType = _walletImportSource = _unsignedDraftId = null;
  }

  Map<String, int>? getRecipientMap() {
    if (_transaction == null) {
      return null;
    }

    final Map<String, int> recipientMap = {};

    for (final output in _transaction!.outputs) {
      if (output.isChangeOutput == true) continue;

      final address = output.getAddress();
      recipientMap.update(address, (amount) => amount + output.amount, ifAbsent: () => output.amount);
    }

    return recipientMap;
  }
}
