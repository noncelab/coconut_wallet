import 'dart:async';

import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/view_model/onboarding/start_view_model.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StartScreen extends StatefulWidget {
  final void Function(AppEntryFlow nextScreen) onComplete;

  const StartScreen({super.key, required this.onComplete});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late StartViewModel _viewModel;

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

  @override
  void initState() {
    super.initState();
    _viewModel = StartViewModel(
      Provider.of<VisibilityProvider>(context, listen: false),
      Provider.of<AuthProvider>(context, listen: false),
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

    AppEntryFlow nextScreen = await _viewModel.determineStartScreen();
    widget.onComplete(nextScreen);
  }

  /// 업데이트 다이얼로그 표시
  Future<bool> _showUpdateDialog() async {
    return (await CustomDialogs.showFutureCustomAlertDialog(
          context,
          title: t.alert.update.title,
          message: t.alert.update.description,
          onConfirm: () async {
            await _viewModel.launchUpdate();
            return true;
          },
          onCancel: () {
            return false;
          },
          confirmButtonText: t.alert.update.btn_update,
          confirmButtonColor: MyColors.primary,
          cancelButtonText: t.alert.update.btn_do_later,
        )) ??
        false;
  }
}
