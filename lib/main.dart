import 'dart:async';

import 'package:coconut_wallet/app/bootstrap/app_bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/utils/logger.dart';

import 'app.dart';

void main() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // 예외를 완전히 무시하는 설정
  FlutterError.onError = (FlutterErrorDetails details) {
    Logger.error("Flutter Error (무시됨): ${details.exception}");
    Logger.log("Stack trace: ${details.stack}");
  };

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppBootstrap.initialize();
      runApp(const CoconutWalletApp());
    },
    (error, stackTrace) {
      Logger.error(">>>>> runZoneGuarded error: $error");
      Logger.log('>>>>> runZoneGuarded StackTrace: $stackTrace');
    },
  );
}
