import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/app/bootstrap/platform_channels.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/system_chrome_util.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

bool _orientationUpdatesAllowed = true;
bool? _lastPortraitOnly;

Future<void> updatePreferredOrientations(ui.FlutterView view) async {
  if (!_orientationUpdatesAllowed) return;
  final display = view.display;
  // Letterboxing can shrink the view; folding can leave the engine's display metadata stale.
  final portraitOnly =
      display.size.shortestSide / display.devicePixelRatio < 600 &&
      view.physicalSize.shortestSide / view.devicePixelRatio < 600;
  if (_lastPortraitOnly == portraitOnly) return;
  _lastPortraitOnly = portraitOnly;
  try {
    await SystemChrome.setPreferredOrientations(
      portraitOnly ? [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown] : [],
    );
  } on PlatformException catch (e) {
    _lastPortraitOnly = null;
    Logger.log("Failed to update display orientation: '${e.message}'.");
  }
}

Future<void> configureSystemUi() async {
  final rootIsolateToken = RootIsolateToken.instance!;
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

  if (Platform.isAndroid) {
    _orientationUpdatesAllowed = false;
    try {
      const channel = MethodChannel(methodChannelOS);
      final int version = await channel.invokeMethod('getSdkVersion');
      _orientationUpdatesAllowed = version != 26;
    } on PlatformException catch (e) {
      Logger.log("Failed to get platform version: '${e.message}'.");
    }
  }
  await updatePreferredOrientations(WidgetsBinding.instance.platformDispatcher.views.first);

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  updateSystemBarColor(CoconutThemeController.currentVariant);
}
