class TransactionProcessingState {
  bool _isConfirmed;
  bool _isCompleted;

  bool get isConfirmed => _isConfirmed;
  bool get isCompleted => _isCompleted;

  TransactionProcessingState(this._isConfirmed, this._isCompleted);

  void setCompleted() {
    _isCompleted = true;
  }

  void setConfirmed() {
    _isConfirmed = true;
  }
}
