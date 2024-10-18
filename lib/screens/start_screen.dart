import 'dart:async';
import 'dart:io';

import 'package:coconut_wallet/constants/app_info.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:coconut_wallet/model/response/app_version_response.dart';
import 'package:coconut_wallet/repositories/app_version_repository.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class StartScreen extends StatefulWidget {
  final void Function(int status) onComplete;

  const StartScreen({super.key, required this.onComplete});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late AppSubStateModel _subModel;
  final AppVersionRepository _repository = AppVersionRepository();
  bool canUpdate = false;
  late PackageInfo _packageInfo;
  final SharedPrefs _sharedPrefs = SharedPrefs();

  @override
  void initState() {
    super.initState();
    _subModel = Provider.of<AppSubStateModel>(context, listen: false);
    _initialize();
  }

  void _initialize() async {
    await _initPackageInfo();
    setStartScreen();
  }

  Future<void> _initPackageInfo() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// 앱 시작 후 어떤 화면을 최초로 보여줄 지 결정합니다.
  void setStartScreen() async {
    await _checkLatestVersion();
    await Future.delayed(const Duration(seconds: 1));
    if (canUpdate) {
      bool finishDialogValue = await _showUpdateDialog();
      if (!finishDialogValue) {
        await _setNextUpdateDialogDate();
      }
    }
    _loadScreenStatus();
  }

  void _loadScreenStatus() async {
    // Splash 보여주기 위한 딜레이
    await Future.delayed(const Duration(seconds: 2));
    await _subModel.setInitData();
    if (!_subModel.hasLaunchedBefore) {
      await _subModel.setHasLaunchedBefore();
    }

    if (!_subModel.isNotEmptyWalletList || !_subModel.isSetPin) {
      widget.onComplete(1);
    } else {
      widget.onComplete(2);
    }
  }

  /// 앱 최신버전 조회
  Future<void> _checkLatestVersion() async {
    try {
      final response = await _repository.getLatestAppVersion();
      if (response is AppVersionResponse) {
        String currentVersion = _packageInfo.version;
        String newVersion = response.latestVersion;
        Logger.log(
            'currentVersion : $currentVersion\nnewVersion : $newVersion');
        if (currentVersion.isNotEmpty && newVersion.isNotEmpty) {
          // 메이저 버전이 다를 경우만 판별
          if (int.tryParse(currentVersion.split('.')[0])! <
              int.tryParse(newVersion.split('.')[0])!) {
            canUpdate = await _shouldShowUpdateDialog();
          }
        }
      }
    } catch (e) {
      Logger.log('[앱 버전 체크 ERROR] ${e.toString()}');
    }
  }

  /// 업데이트 다이얼로그 표시
  Future<bool> _showUpdateDialog() async {
    return (await CustomDialogs.showFutureCustomAlertDialog(
          context,
          title: '업데이트 알림',
          message: '안정적인 서비스 이용을 위해\n최신 버전으로 업데이트 해주세요.',
          onConfirm: () async {
            Uri storeUrl = Platform.isAndroid
                ? Uri.parse(
                    'https://play.google.com/store/apps/details?id=${_packageInfo.packageName}')
                : Uri.parse('https://apps.apple.com/kr/app/$APPSTORE_ID');

            if (await canLaunchUrl(storeUrl)) {
              await launchUrl(storeUrl);
            }

            return true; // 업데이트 버튼을 눌렀을 때 true 반환
          },
          onCancel: () {
            return false; // 다음에 하기 버튼을 눌렀을 때 false 반환
          },
          confirmButtonText: '업데이트하기',
          confirmButtonColor: MyColors.primary,
          cancelButtonText: '다음에 하기',
        )) ??
        false;
  }

  /// 다이얼로그를 마지막으로 띄운 시간을 저장
  Future<void> _setNextUpdateDialogDate() async {
    final nextShowDate = DateTime.now().add(const Duration(days: 7));
    _sharedPrefs.setString(SharedPrefs.kNextVersionUpdateDialogDate,
        nextShowDate.toIso8601String());
  }

  /// 다이얼로그를 띄울지 여부 결졍
  Future<bool> _shouldShowUpdateDialog() async {
    final nextShowDateString =
        SharedPrefs().getString(SharedPrefs.kNextVersionUpdateDialogDate);

    if (nextShowDateString.isEmpty) {
      return true;
    }
    final nextShowDate = DateTime.parse(nextShowDateString);
    if (DateTime.now().isAfter(nextShowDate)) {
      return true;
    }

    Logger.log(
        'User already Canceled Update Dialog. The Next Show Dialog Date is : $nextShowDate');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: MyColors.black,
        body: Center(
          child: Image.asset(
            'assets/images/splash_logo.png',
          ),
        ));
  }
}
