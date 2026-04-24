class BottomSheetOpenGuard {
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  bool tryOpen() {
    if (_isOpen) return false;
    _isOpen = true;
    return true;
  }

  void close() {
    _isOpen = false;
  }

  Future<T?> run<T>(Future<T?> Function() action) async {
    if (_isOpen) return null;
    _isOpen = true;
    try {
      return await action();
    } finally {
      _isOpen = false;
    }
  }
}
