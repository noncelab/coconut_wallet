import 'dart:io';

import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/constants/app_info.dart';
import 'package:coconut_wallet/model/api/response/app_version_response.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/services/app_version_service.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class StartViewModel extends ChangeNotifier {
  /// Common variables ---------------------------------------------------------
  late final VisibilityProvider _visibilityProvider;
  late final AuthProvider _authProvider;

  final SharedPrefs _sharedPrefs = SharedPrefs();
  final AppVersion _appVersionRepository = AppVersion();

  late PackageInfo _packageInfo;

  bool _canUpdate = false;
  bool _isLoading = true;

  StartViewModel(this._visibilityProvider, this._authProvider) {
    _initialize();
  }

  bool get canUpdate => _canUpdate;
  bool get isLoading => _isLoading;
  bool get hasLaunchedBefore => _visibilityProvider.hasLaunchedBefore;
  bool get isSetPin => _authProvider.isSetPin;
  int get walletCount => _visibilityProvider.walletCount;

  /// 시작 화면 결정
  Future<AccessFlow> determineStartScreen() async {
    // Splash 보여주기 위한 딜레이
    await Future.delayed(const Duration(seconds: 2));
    if (!hasLaunchedBefore) {
      await _visibilityProvider.setHasLaunchedBefore();
    }
    debugPrint(
        'walletCount --> ${_visibilityProvider.walletCount}\nisSetPin --> ${_authProvider.isSetPin}');
    if (_visibilityProvider.walletCount == 0 || !_authProvider.isSetPin) {
      return AccessFlow.main;
    } else {
      return AccessFlow.pinCheck;
    }
  }

  /// 업데이트 실행
  Future<void> launchUpdate() async {
    Uri storeUrl = Platform.isAndroid
        ? Uri.parse(
            'https://play.google.com/store/apps/details?id=${_packageInfo.packageName}')
        : Uri.parse('https://apps.apple.com/kr/app/$APPSTORE_ID');

    if (await canLaunchUrl(storeUrl)) {
      await launchUrl(storeUrl);
    }
  }

  /// 업데이트 다이얼로그를 마지막으로 띄운 시간 저장
  Future<void> setNextUpdateDialogDate() async {
    final nextShowDate = DateTime.now().add(const Duration(days: 7));
    _sharedPrefs.setString(SharedPrefs.kNextVersionUpdateDialogDate,
        nextShowDate.toIso8601String());
  }

  /// 앱 최신 버전 확인
  Future<void> _checkLatestVersion() async {
    try {
      final response = await _appVersionRepository.getLatestAppVersion();
      if (response is AppVersionResponse) {
        String currentVersion = _packageInfo.version;
        String newVersion = response.latestVersion;
        Logger.log(
            'currentVersion : $currentVersion\nnewVersion : $newVersion');
        if (currentVersion.isNotEmpty && newVersion.isNotEmpty) {
          // 메이저 버전이 다를 경우만 판별
          if (int.tryParse(currentVersion.split('.')[0])! <
              int.tryParse(newVersion.split('.')[0])!) {
            _canUpdate = await _shouldShowUpdateDialog();
          }
        }
      }
    } catch (e) {
      Logger.log('[앱 버전 체크 ERROR] ${e.toString()}');
    }
  }

  /// 초기화
  Future<void> _initialize() async {
    await _initPackageInfo();
    await _checkLatestVersion();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _initPackageInfo() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// 업데이트 다이얼로그 표시 여부 결정
  Future<bool> _shouldShowUpdateDialog() async {
    final nextShowDateString =
        _sharedPrefs.getString(SharedPrefs.kNextVersionUpdateDialogDate);

    if (nextShowDateString.isEmpty) return true;

    final nextShowDate = DateTime.parse(nextShowDateString);
    return DateTime.now().isAfter(nextShowDate);
  }
}
