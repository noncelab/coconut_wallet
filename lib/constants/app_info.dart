// ignore_for_file: constant_identifier_names

import 'package:coconut_lib/coconut_lib.dart';

/// TODO: release date 기록
const RELEASE_DATE = '2026.11.10';
const COPYRIGHT_TEXT = '© 2025 Nonce Lab. Inc. in S.Korea.\nLicensed under the MIT License.';

/// AppStore App ID (iOS)
const APPSTORE_ID_REGTEST = '6654902298';
const APPSTORE_ID_MAINNET = '6745778545';

/// 현재 네트워크(mainnet/regtest)에 맞는 AppStore App ID
String get appStoreId => NetworkType.currentNetworkType.isTestnet ? APPSTORE_ID_REGTEST : APPSTORE_ID_MAINNET;
