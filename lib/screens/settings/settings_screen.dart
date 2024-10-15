import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/screens/pin_check_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/bottom_sheet.dart';
import 'package:coconut_wallet/widgets/button/button_container.dart';
import 'package:coconut_wallet/widgets/button/button_group.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:provider/provider.dart';

import '../pin_setting_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreen();
}

class _SettingsScreen extends State<SettingsScreen> {
  late AppSubStateModel _subModel;

  @override
  void initState() {
    super.initState();
    _subModel = Provider.of<AppSubStateModel>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateModel>(
        builder: (BuildContext context, AppStateModel model, Widget? child) {
      return Scaffold(
          backgroundColor: MyColors.black,
          appBar: CustomAppBar.build(
            title: '설정',
            context: context,
            hasRightIcon: false,
            isBottom: false,
            showTestnetLabel: false,
          ),
          body: SafeArea(
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _category('보안'),
              ButtonGroup(buttons: [
                SingleButton(
                    title: '비밀번호 설정하기',
                    rightElement: CupertinoSwitch(
                        value: _subModel.isSetPin,
                        activeColor: MyColors.primary,
                        onChanged: (isOn) {
                          if (isOn) {
                            MyBottomSheet.showBottomSheet_90<bool>(
                              context: context,
                              child: const CustomLoadingOverlay(
                                child: PinSettingScreen(),
                              ),
                            );
                          } else {
                            _subModel.deletePin();
                          }
                        })),
                if (_subModel.canCheckBiometrics && _subModel.isSetPin)
                  SingleButton(
                    title: '생체 인증 사용하기',
                    rightElement: CupertinoSwitch(
                        value: _subModel.isSetBiometrics,
                        activeColor: MyColors.primary,
                        onChanged: (isOn) async {
                          if (isOn) {
                            _subModel.authenticateWithBiometrics(isSave: true);
                          } else {
                            _subModel.saveIsSetBiometrics(false);
                          }
                        }),
                  ),
                if (_subModel.isSetPin)
                  SingleButton(
                      title: '비밀번호 바꾸기',
                      onPressed: () async {
                        _subModel.shuffleNumbers();
                        final bool? result =
                            await MyBottomSheet.showBottomSheet_90(
                                context: context,
                                child: const CustomLoadingOverlay(
                                    child: PinCheckScreen()));
                        if (result == true) {
                          _subModel.shuffleNumbers(isSettings: true);
                          await MyBottomSheet.showBottomSheet_90(
                              context: context,
                              child: const CustomLoadingOverlay(
                                  child: PinSettingScreen()));
                        }
                      }),
              ]),
              const SizedBox(height: 16),
              ButtonContainer(
                  child: SingleButton(
                title: '홈 화면 잔액 숨기기',
                rightElement: CupertinoSwitch(
                    value: _subModel.isBalanceHidden,
                    activeColor: MyColors.primary,
                    onChanged: (value) {
                      _subModel.changeIsBalanceHidden(value);
                    }),
              )),
              /*_category('정보'),
              ButtonGroup(buttons: [
                SingleButton(
                    title: '셀프 보안 점검',
                    onPressed: () {
                      MyBottomSheet.showBottomSheet_95(
                          context: context,
                          child: const SecuritySelfCheckScreen());
                    }),
                SingleButton(
                    title: '니모닉 문구 단어집',
                    onPressed: () {
                      MyBottomSheet.showBottomSheet_95(
                          context: context, child: const Bip39ListScreen());
                    }),
                SingleButton(
                    title: '용어집',
                    onPressed: () {
                      MyBottomSheet.showBottomSheet_95(
                          context: context, child: const TermsScreen());
                    }),
              ]),
              const SizedBox(height: 32),
              ButtonContainer(
                  child: SingleButton(
                title: '앱 정보 보기',
                onPressed: () {
                  Navigator.pushNamed(context, '/app-info');
                },
              )),
              const SizedBox(height: 40),*/
            ]),
          )));
    });
  }

  Widget _category(String label) => Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 0, 12),
      child: Text(label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            color: Colors.white,
            fontSize: 16,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.bold,
          )));
}
