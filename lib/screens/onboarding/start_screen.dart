import 'dart:async';

import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/providers/view_model/onboarding/start_view_model.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:provider/provider.dart';

class StartScreen extends StatefulWidget {
  final void Function(AccessFlow nextScreen) onComplete;

  const StartScreen({super.key, required this.onComplete});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late StartViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = StartViewModel(
      Provider.of<AppSubStateModel>(context, listen: false),
      Provider.of<VisibilityProvider>(context, listen: false),
    );

    _initialize();
  }

  void _initialize() async {
    await Future.delayed(const Duration(seconds: 1));
    if (_viewModel.canUpdate) {
      bool finishDialogValue = await _showUpdateDialog();
      if (!finishDialogValue) {
        await _viewModel.setNextUpdateDialogDate();
      }
    }

    AccessFlow nextScreen = await _viewModel.determineStartScreen();
    widget.onComplete(nextScreen);
  }

  /// 업데이트 다이얼로그 표시
  Future<bool> _showUpdateDialog() async {
    return (await CustomDialogs.showFutureCustomAlertDialog(
          context,
          title: '업데이트 알림',
          message: '안정적인 서비스 이용을 위해\n최신 버전으로 업데이트 해주세요.',
          onConfirm: () async {
            await _viewModel.launchUpdate();
            return true;
          },
          onCancel: () {
            return false;
          },
          confirmButtonText: '업데이트하기',
          confirmButtonColor: MyColors.primary,
          cancelButtonText: '다음에 하기',
        )) ??
        false;
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
