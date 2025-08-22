import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/settings/settings_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/settings/pin_setting_screen.dart';
import 'package:coconut_wallet/screens/settings/realm_debug_screen.dart';
import 'package:coconut_wallet/screens/settings/unit_bottom_sheet.dart';
import 'package:coconut_wallet/screens/settings/language_bottom_sheet.dart';
import 'package:coconut_wallet/screens/settings/fiat_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/button/button_group.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:coconut_wallet/screens/settings/fake_balance_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/button/multi_button.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    return ChangeNotifierProxyProvider2<AuthProvider, PreferenceProvider, SettingsViewModel>(
        create: (_) => SettingsViewModel(Provider.of<AuthProvider>(_, listen: false),
            Provider.of<PreferenceProvider>(_, listen: false)),
        update: (_, authProvider, preferenceProvider, settingsViewModel) {
          return SettingsViewModel(authProvider, preferenceProvider);
        },
        child: Consumer<SettingsViewModel>(builder: (context, viewModel, child) {
          return Scaffold(
              backgroundColor: CoconutColors.black,
              appBar: CoconutAppBar.build(
                title: t.settings,
                context: context,
                isBottom: true,
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // 보안
                  _category(t.security),
                  ButtonGroup(buttons: [
                    SingleButton(
                      title: t.settings_screen.set_password,
                      rightElement: _buildSwitch(
                          isOn: viewModel.isSetPin,
                          onChanged: (isOn) async {
                            if (isOn) {
                              _showPinSettingScreen(useBiometrics: true);
                              return;
                            }

                            final authProvider = viewModel.authProvider;
                            if (await authProvider.isBiometricsAuthValid()) {
                              viewModel.deletePin();
                              return;
                            }

                            if (await _isPinCheckValid()) {
                              viewModel.deletePin();
                            }
                          }),
                    ),
                    if (viewModel.canCheckBiometrics && viewModel.isSetPin)
                      SingleButton(
                        title: t.settings_screen.use_biometric,
                        rightElement: _buildSwitch(
                            isOn: viewModel.isSetBiometrics,
                            onChanged: (isOn) async {
                              if (isOn) {
                                viewModel.authenticateWithBiometrics(isSave: true);
                              } else {
                                viewModel.saveIsSetBiometrics(false);
                              }
                            }),
                      ),
                    if (viewModel.isSetPin)
                      SingleButton(
                          title: t.settings_screen.change_password,
                          onPressed: () async {
                            final authProvider = viewModel.authProvider;
                            if (await authProvider.isBiometricsAuthValid()) {
                              _showPinSettingScreen(useBiometrics: false);
                              return;
                            }

                            if (await _isPinCheckValid()) {
                              _showPinSettingScreen(useBiometrics: false);
                            }
                          }),
                  ]),

                  // 홈 잔액 숨기기 + 가짜 잔액 설정
                  if (context.read<WalletProvider>().walletItemList.isNotEmpty) ...[
                    CoconutLayout.spacing_200h,
                    ButtonGroup(buttons: [
                      SingleButton(
                          title: t.settings_screen.hide_balance,
                          rightElement: _buildSwitch(
                              isOn: viewModel.isBalanceHidden,
                              onChanged: (value) {
                                viewModel.changeIsBalanceHidden(value);
                              })),
                      SingleButton(
                        enableShrinkAnim: true,
                        title: t.settings_screen.fake_balance.fake_balance_setting,
                        onPressed: () async {
                          CommonBottomSheets.showBottomSheet_50(
                              context: context, child: const FakeBalanceBottomSheet());
                        },
                      ),
                    ]),
                  ],
                  CoconutLayout.spacing_400h,

                  // 단위
                  _category(t.unit),
                  ButtonGroup(buttons: [
                    Selector<PreferenceProvider, bool>(
                        selector: (_, viewModel) => viewModel.isBtcUnit,
                        builder: (context, isBtcUnit, child) {
                          return SingleButton(
                            enableShrinkAnim: true,
                            animationEndValue: 0.97,
                            title: t.bitcoin_kr,
                            subtitle: isBtcUnit ? t.btc : t.sats,
                            onPressed: () async {
                              CommonBottomSheets.showBottomSheet_50(
                                  context: context, child: const UnitBottomSheet());
                            },
                          );
                        }),
                    Selector<PreferenceProvider, String>(
                        selector: (_, provider) => provider.selectedFiat.code,
                        builder: (context, fiatCode, child) {
                          String fiatDisplayName;
                          switch (fiatCode) {
                            case 'KRW':
                              fiatDisplayName = FiatCode.KRW.code;
                              break;
                            case 'JPY':
                              fiatDisplayName = FiatCode.JPY.code;
                              break;
                            case 'USD':
                            default:
                              fiatDisplayName = FiatCode.USD.code;
                              break;
                          }

                          return SingleButton(
                            enableShrinkAnim: true,
                            animationEndValue: 0.97,
                            title: t.fiat.fiat,
                            subtitle: fiatDisplayName,
                            onPressed: () async {
                              CommonBottomSheets.showBottomSheet_50(
                                  context: context, child: const FiatBottomSheet());
                            },
                          );
                        }),
                  ]),
                  CoconutLayout.spacing_400h,

                  // 일반
                  _category(t.general),
                  Selector<PreferenceProvider, String>(
                    selector: (_, provider) => provider.language,
                    builder: (context, language, child) {
                      return SingleButton(
                        enableShrinkAnim: true,
                        animationEndValue: 0.97,
                        title: t.settings_screen.language,
                        subtitle: _getCurrentLanguageDisplayName(language),
                        subtitleStyle: CoconutTypography.body3_12.setColor(CoconutColors.white),
                        onPressed: () async {
                          CommonBottomSheets.showBottomSheet_50(
                            context: context,
                            child: const LanguageBottomSheet(),
                          );
                        },
                      );
                    },
                  ),
                  CoconutLayout.spacing_400h,

                  // 네트워크
                  _category(t.network),
                  ButtonGroup(
                    buttons: [
                      SingleButton(
                        enableShrinkAnim: true,
                        animationEndValue: 0.97,
                        title: t.electrum_server,
                        onPressed: () async {
                          Navigator.pushNamed(context, '/electrum-server');
                        },
                      ),
                    ],
                  ),
                  CoconutLayout.spacing_400h,

                  // 도구
                  _category(t.tool),
                  ButtonGroup(buttons: [
                    SingleButton(
                      title: t.settings_screen.log_viewer_screen.title,
                      onPressed: () {
                        Navigator.pushNamed(context, '/log-viewer');
                      },
                    ),
                  ]),

                  // 개발자 모드에서만 표시되는 디버그 섹션
                  if (kDebugMode) ...[
                    CoconutLayout.spacing_400h,
                    _category('개발자 도구'),
                    SingleButton(
                      enableShrinkAnim: true,
                      animationEndValue: 0.97,
                      title: 'Realm 디버그용 뷰어',
                      onPressed: () {
                        final realmManager = Provider.of<RealmManager>(context, listen: false);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => RealmDebugScreen(
                              realmManager: realmManager,
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: Sizes.size32)
                ]),
              ));
        }));
  }

  Widget _buildSwitch({required bool isOn, required Function(bool) onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: CoconutSwitch(
          isOn: isOn,
          activeColor: CoconutColors.gray100,
          trackColor: CoconutColors.gray600,
          thumbColor: CoconutColors.gray800,
          onChanged: onChanged),
    );
  }

  Widget _category(String label) => Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 0, 12),
      child: Text(label, style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white)));

  void _showPinSettingScreen({required bool useBiometrics}) {
    CommonBottomSheets.showBottomSheet_90(
      context: context,
      child: CustomLoadingOverlay(
        child: PinSettingScreen(useBiometrics: useBiometrics),
      ),
    );
  }

  Future<bool> _isPinCheckValid() async {
    return (await CommonBottomSheets.showBottomSheet_90(
            context: context, child: const CustomLoadingOverlay(child: PinCheckScreen())) ==
        true);
  }

  String _getCurrentLanguageDisplayName(String language) {
    switch (language) {
      case 'kr':
        return t.settings_screen.korean;
      case 'en':
        return t.settings_screen.english;
      default:
        return t.settings_screen.korean;
    }
  }
}
