import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/settings/settings_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/button/button_container.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreen();
}

class _SettingsScreen extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider3<AuthProvider, PreferenceProvider, WalletProvider,
            SettingsViewModel>(
        create: (_) => SettingsViewModel(
            Provider.of<AuthProvider>(_, listen: false),
            Provider.of<PreferenceProvider>(_, listen: false),
            Provider.of<WalletProvider>(_, listen: false)),
        update: (_, authProvider, preferenceProvider, walletProvider, settingsViewModel) {
          return SettingsViewModel(authProvider, preferenceProvider, walletProvider);
        },
        child: Consumer<SettingsViewModel>(builder: (context, viewModel, child) {
          return Scaffold(
              backgroundColor: CoconutColors.black,
              appBar: CoconutAppBar.build(
                title: t.settings,
                context: context,
                isBottom: true,
              ),
              body: SafeArea(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _category(t.security),
                  // ButtonGroup(buttons: [
                  //   SingleButton(
                  //       title: t.settings_screen.set_password,
                  //       rightElement: CupertinoSwitch(
                  //           value: viewModel.isSetPin,
                  //           activeColor: CoconutColors.primary,
                  //           onChanged: (isOn) {
                  //             if (isOn) {
                  //               CommonBottomSheets.showBottomSheet_90<bool>(
                  //                 context: context,
                  //                 child: const CustomLoadingOverlay(
                  //                   child: PinSettingScreen(
                  //                       useBiometrics: true),
                  //                 ),
                  //               );
                  //             } else {
                  //               viewModel.deletePin();
                  //             }
                  //           })),
                  //   if (viewModel.canCheckBiometrics && viewModel.isSetPin)
                  //     SingleButton(
                  //       title: t.settings_screen.use_biometric,
                  //       rightElement: CupertinoSwitch(
                  //           value: viewModel.isSetBiometrics,
                  //           activeColor: CoconutColors.primary,
                  //           onChanged: (isOn) async {
                  //             if (isOn) {
                  //               viewModel.authenticateWithBiometrics(
                  //                   isSave: true);
                  //             } else {
                  //               viewModel.saveIsSetBiometrics(false);
                  //             }
                  //           }),
                  //     ),
                  //   if (viewModel.isSetPin)
                  //     SingleButton(
                  //         title: t.settings_screen.change_password,
                  //         onPressed: () async {
                  //           final bool? result =
                  //               await CommonBottomSheets.showBottomSheet_90(
                  //                   context: context,
                  //                   child: const CustomLoadingOverlay(
                  //                       child: PinCheckScreen()));
                  //           if (result == true) {
                  //             await CommonBottomSheets.showBottomSheet_90(
                  //                 context: context,
                  //                 child: const CustomLoadingOverlay(
                  //                     child: PinSettingScreen()));
                  //           }
                  //         }),
                  // ]),
                  // const SizedBox(height: 16),
                  ButtonContainer(
                      child: SingleButton(
                    title: t.settings_screen.hide_balance,
                    rightElement: CupertinoSwitch(
                        value: viewModel.isBalanceHidden,
                        activeColor: CoconutColors.primary,
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
      child: Text(label, style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white)));
}
