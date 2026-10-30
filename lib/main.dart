import 'dart:async';

import 'package:coconut_wallet/app/bootstrap/pin_storage_recovery_app.dart';
import 'package:coconut_wallet/services/security/pin_auth_service.dart';

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
      await _startApplication();
    },
    (error, stackTrace) {
      Logger.error(">>>>> runZoneGuarded error: $error");
      Logger.log('>>>>> runZoneGuarded StackTrace: $stackTrace');
    },
  );
}

/// 인증 저장소가 확인되기 전에는 앱과 AuthProvider를 생성하지 않는다.
Future<void> _startApplication() async {
  try {
    await AppBootstrap.initialize();
    runApp(const CoconutWalletApp());
  } on PinAuthException {
    runApp(const PinStorageRecoveryApp(onRetry: _startApplication));
  }
}
