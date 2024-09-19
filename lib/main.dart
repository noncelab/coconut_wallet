import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/database_path_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:provider/provider.dart';

import 'app.dart';

late final String dbDirectoryPath;

void main() {
  runZonedGuarded(() async {
    // This app is designed only to work vertically, so we limit
    // orientations to portrait up and down.
    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [
        SystemUiOverlay.top,
        SystemUiOverlay.bottom,
      ],
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: MyColors.black, //상단바 색상
        statusBarIconBrightness: Brightness.light, //상단바 아이콘 색상
        systemNavigationBarDividerColor: MyColors.black, //하단바 디바이더 색상
        systemNavigationBarColor: MyColors.black, //하단바 색상
        systemNavigationBarIconBrightness: Brightness.light, //하단바 아이콘 색상
      ),
    );
    Provider.debugCheckInvalidValueType = null;

    await SharedPrefs().init();

    final dbDirectory = await getAppDocumentDirectory(paths: ['objectbox']);
    dbDirectoryPath = dbDirectory.path;
    Repository.initialize(dbDirectoryPath);
    BitcoinNetwork.setNetwork(BitcoinNetwork.regtest);

    String envFile = '$appFlavor.env';
    await dotenv.load(fileName: envFile);
    PowWalletApp.kElectrumHost = dotenv.env['ELECTRUM_HOST'] ?? '';
    String? portString = dotenv.env['ELECTRUM_PORT'];
    PowWalletApp.kElectrumPort =
        portString != null ? int.tryParse(portString) ?? 0 : 0;
    PowWalletApp.kElectrumIsSSL =
        dotenv.env['ELECTRUM_IS_SSL']?.toLowerCase() == 'true';
    PowWalletApp.kMempoolHost = dotenv.env['MEMPOOL_HOST'] ?? '';
    PowWalletApp.kFaucetHost = dotenv.env['API_HOST'] ?? '';
    runApp(const PowWalletApp());
  }, (error, stackTrace) {
    Logger.log(">>>>> runZoneGuarded error: $error");
    Logger.log('Stack trace: $stackTrace');
  });
}
