import 'package:coconut_wallet/constants/network_constants.dart';

class TransactionProcessingState {
  final DateTime _startTime;
  bool _isConfirmed;
  bool _isCompleted;

  DateTime get startTime => _startTime;
  bool get isConfirmed => _isConfirmed;
  bool get isCompleted => _isCompleted;

  TransactionProcessingState(this._startTime, this._isConfirmed, this._isCompleted);

  void setCompleted() {
    _isCompleted = true;
  }

  void setConfirmed() {
    _isConfirmed = true;
  }

  bool isProcessable() {
    if (isCompleted) {
      final timeElapsed = DateTime.now().difference(startTime);

      if (timeElapsed >= kTransactionProcessingTimeout) {
        return true;
      }
    }

    return false;
  }
}
