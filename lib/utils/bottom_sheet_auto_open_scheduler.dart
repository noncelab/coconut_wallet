import 'dart:async';

import 'package:flutter/foundation.dart';

class BottomSheetAutoOpenScheduler {
  Timer? _timer;

  bool get isScheduled => _timer?.isActive ?? false;

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void schedule({required Duration delay, required VoidCallback action, bool replaceIfScheduled = true}) {
    if (isScheduled) {
      if (!replaceIfScheduled) return;
      cancel();
    }

    _timer = Timer(delay, () {
      _timer = null;
      action();
    });
  }
}
