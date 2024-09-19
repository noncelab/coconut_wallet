import 'dart:io';

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

void vibrateLight() {
  if (Platform.isAndroid) {
    Vibration.vibrate(duration: 100);
  } else if (Platform.isIOS) {
    HapticFeedback.lightImpact();
  }
}

void vibrateMedium() {
  if (Platform.isAndroid) {
    Vibration.vibrate(duration: 1000);
  } else if (Platform.isIOS) {
    HapticFeedback.vibrate();
  }
}

void vibrateLightDouble() async {
  if (Platform.isAndroid) {
    Vibration.vibrate(pattern: [0, 100, 100, 100]);
  } else if (Platform.isIOS) {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
  }
}
