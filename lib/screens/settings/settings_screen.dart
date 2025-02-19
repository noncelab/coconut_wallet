import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/settings/settings_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/button/button_container.dart';
import 'package:coconut_wallet/widgets/button/button_group.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:provider/provider.dart';

import 'pin_setting_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreen();
}

class _SettingsScreen extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider3<AuthProvider, PreferenceProvider,
            WalletProvider, SettingsViewModel>(
        create: (_) => SettingsViewModel(
            Provider.of<AuthProvider>(_, listen: false),
            Provider.of<PreferenceProvider>(_, listen: false),
            Provider.of<WalletProvider>(_, listen: false)),
        update: (_, authProvider, preferenceProvider, walletProvider,
            settingsViewModel) {
          return SettingsViewModel(
              authProvider, preferenceProvider, walletProvider);
        },
        child:
            Consumer<SettingsViewModel>(builder: (context, viewModel, child) {
          return Scaffold(
              backgroundColor: MyColors.black,
              appBar: CustomAppBar.build(
                title: t.settings,
                context: context,
                hasRightIcon: false,
                isBottom: true,
                showTestnetLabel: false,
              ),
              body: SafeArea(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _category(t.security),
                      ButtonGroup(buttons: [
                        SingleButton(
                            title: t.settings_screen.set_password,
                            rightElement: CoconutSwitch(
                                isOn: viewModel.isSetPin,
                                activeColor: CoconutColors.primary,
                                thumbColor: CoconutColors.white,
                                onChanged: (isOn) {
                                  if (isOn) {
                                    CommonBottomSheets.showCustomBottomSheet<
                                        bool>(
                                      context: context,
                                      child: const CustomLoadingOverlay(
                                        child: PinSettingScreen(
                                            useBiometrics: true),
                                      ),
                                    );
                                  } else {
                                    viewModel.deletePin();
                                  }
                                })),
                        if (viewModel.canCheckBiometrics && viewModel.isSetPin)
                          SingleButton(
                            title: t.settings_screen.use_biometric,
                            rightElement: CoconutSwitch(
                                isOn: viewModel.isSetBiometrics,
                                activeColor: CoconutColors.primary,
                                thumbColor: CoconutColors.white,
                                onChanged: (isOn) async {
                                  if (isOn) {
                                    viewModel.authenticateWithBiometrics(
                                        isSave: true);
                                  } else {
                                    viewModel.saveIsSetBiometrics(false);
                                  }
                                }),
                          ),
                        if (viewModel.isSetPin)
                          SingleButton(
                              title: t.settings_screen.change_password,
                              onPressed: () async {
                                final bool? result = await CommonBottomSheets
                                    .showCustomBottomSheet(
                                        context: context,
                                        child: const CustomLoadingOverlay(
                                            child: PinCheckScreen()));
                                if (result == true) {
                                  await CommonBottomSheets
                                      .showCustomBottomSheet(
                                          context: context,
                                          child: const CustomLoadingOverlay(
                                              child: PinSettingScreen()));
                                }
                              }),
                      ]),
                      const SizedBox(height: 16),
                      ButtonContainer(
                          child: SingleButton(
                        title: t.settings_screen.hide_balance,
                        rightElement: CoconutSwitch(
                            isOn: viewModel.isBalanceHidden,
                            activeColor: CoconutColors.primary,
                            thumbColor: CoconutColors.white,
                            onChanged: (value) {
                              viewModel.changeIsBalanceHidden(value);
                            }),
                      )),
                    ]),
              )));
        }));
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
