import 'dart:async';

import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/model/feature/feature_navigation_target.dart';
import 'package:coconut_wallet/screens/common/feature_search_focus.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart' show CoconutPopup;
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutPopup;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/screens/settings/theme_bottom_sheet.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/constants/app_language.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/settings/settings_view_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/premium/premium_subscription_screen.dart';
import 'package:coconut_wallet/screens/settings/pin_setting_screen.dart';
import 'package:coconut_wallet/screens/settings/realm_debug_screen.dart';
import 'package:coconut_wallet/screens/settings/unit_bottom_sheet.dart';
import 'package:coconut_wallet/screens/settings/language_bottom_sheet.dart';
import 'package:coconut_wallet/screens/settings/number_format_bottom_sheet.dart';
import 'package:coconut_wallet/screens/settings/fiat_bottom_sheet.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/button_group.dart';
import 'package:coconut_wallet/widgets/common/overlays/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart' show PremiumMark;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:provider/provider.dart';

class AppSettingsScreen extends StatefulWidget {
  final AppSettingsTarget? initialTarget;

  const AppSettingsScreen({super.key, this.initialTarget});

  static final _pendingSelectionSheets = <BuildContext>{};

  static Future<void> open(
    BuildContext context,
    AppSettingsTarget target, {
    CoconutThemeVariant? highlightTheme,
  }) async {
    final selectionSheet = switch (target) {
      AppSettingsTarget.unit ||
      AppSettingsTarget.fiat ||
      AppSettingsTarget.language ||
      AppSettingsTarget.theme ||
      AppSettingsTarget.numberFormat => true,
      _ => false,
    };
    if (!selectionSheet) return _openTarget(context, target, highlightTheme: highlightTheme);
    if (!_pendingSelectionSheets.add(context)) return;
    bool releasePending() => _pendingSelectionSheets.remove(context);
    final bool ready;
    try {
      ready = await _waitForSourceKeyboard(context);
    } finally {
      releasePending();
    }
    if (ready && context.mounted && ModalRoute.of(context)?.isCurrent != false) {
      await _openTarget(context, target, highlightTheme: highlightTheme);
    }
  }

  static Future<bool> _waitForSourceKeyboard(BuildContext context) {
    final view = View.of(context);
    if (view.viewInsets.bottom == 0 && MediaQuery.viewInsetsOf(context).bottom == 0) {
      return Future.value(context.mounted);
    }
    final completed = Completer<bool>();
    final initialFocus = FocusManager.instance.primaryFocus;
    var focusReleased = initialFocus == null || initialFocus is FocusScopeNode;
    var entryFocusChecked = false;
    void focusChanged() {
      final primary = FocusManager.instance.primaryFocus;
      if (primary != initialFocus) focusReleased = true;
      if (focusReleased && primary != null && primary is! FocusScopeNode && !completed.isCompleted) {
        completed.complete(false);
      }
    }

    FocusManager.instance.addListener(focusChanged);
    final route = ModalRoute.of(context);
    final focusOwner = Focus.maybeOf(context);
    final sourceBox = context.findRenderObject();
    final box = sourceBox is RenderBox && sourceBox.hasSize ? sourceBox : null;
    final origin = box?.localToGlobal(Offset.zero);
    final horizontalEnd = box?.localToGlobal(Offset(box.size.width, 0));
    final lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed && !completed.isCompleted) completed.complete(false);
      },
    );
    // Stale IME metrics cancel this request instead of retaining its source indefinitely.
    final watchdog = Timer(const Duration(seconds: 2), () {
      if (!completed.isCompleted) completed.complete(false);
    });
    void afterFrame(Duration _) {
      if (completed.isCompleted) return;
      final focusExcluded =
          focusOwner != null &&
          (!focusOwner.descendantsAreFocusable || focusOwner.ancestors.any((node) => !node.descendantsAreFocusable));
      // A retained pager face can leave the foreground without changing routes.
      final sourceMoved =
          box != null &&
          (!box.attached ||
              (box.localToGlobal(Offset.zero) - origin!).distance > 0.5 ||
              (box.localToGlobal(Offset(box.size.width, 0)) - horizontalEnd!).distance > 0.5);
      if (!context.mounted || (route != null && !route.isCurrent) || focusExcluded || sourceMoved) {
        completed.complete(false);
      } else {
        if (!entryFocusChecked) {
          entryFocusChecked = true;
          if (initialFocus is! FocusScopeNode && initialFocus?.hasPrimaryFocus == true) initialFocus!.unfocus();
        }
        if (view.viewInsets.bottom == 0) {
          completed.complete(true);
        } else {
          WidgetsBinding.instance.addPostFrameCallback(afterFrame);
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback(afterFrame);
    WidgetsBinding.instance.scheduleFrame();
    return completed.future.whenComplete(() {
      watchdog.cancel();
      lifecycle.dispose();
      FocusManager.instance.removeListener(focusChanged);
    });
  }

  static Future<void> _openTarget(
    BuildContext context,
    AppSettingsTarget target, {
    CoconutThemeVariant? highlightTheme,
  }) async {
    switch (target) {
      case AppSettingsTarget.unit:
        await CommonBottomSheets.showCustomHeightBottomSheet(
          context: context,
          screenName: AnalyticsScreenNames.appSettingsUnitSheet,
          heightRatio: 0.5,
          child: const UnitBottomSheet(),
        );
      case AppSettingsTarget.fiat:
        await FiatBottomSheet.show(context);
      case AppSettingsTarget.language:
        await CommonBottomSheets.showCustomHeightBottomSheet(
          context: context,
          screenName: AnalyticsScreenNames.appSettingsLanguageSheet,
          heightRatio: 0.6,
          child: LanguageBottomSheet(),
        );
      case AppSettingsTarget.theme:
        await CommonBottomSheets.showCustomHeightBottomSheet(
          context: context,
          screenName: AnalyticsScreenNames.appSettingsThemeSheet,
          heightRatio: 0.5,
          child: ThemeBottomSheet(highlightVariant: highlightTheme),
        );
      case AppSettingsTarget.numberFormat:
        await CommonBottomSheets.showCustomHeightBottomSheet(
          context: context,
          screenName: AnalyticsScreenNames.appSettingsNumberFormatSheet,
          heightRatio: 0.5,
          child: NumberFormatBottomSheet(),
        );
      case AppSettingsTarget.electrum:
        await Navigator.pushNamed(context, AppRouteNames.electrumServer);
      case AppSettingsTarget.explorer:
        if (NetworkType.currentNetworkType == NetworkType.mainnet) {
          await Navigator.pushNamed(context, AppRouteNames.blockExplorer);
        }
      case AppSettingsTarget.appInfo:
        await Navigator.pushNamed(context, AppRouteNames.appInfo);
      case AppSettingsTarget.pin:
      case AppSettingsTarget.biometrics:
      case AppSettingsTarget.pinChange:
      case AppSettingsTarget.utxoSelection:
        await Navigator.of(context).push(
          CupertinoPageRoute<void>(
            settings: const RouteSettings(name: '/app-settings'),
            builder: (_) => AppSettingsScreen(initialTarget: target),
          ),
        );
    }
  }

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreen();
}

class _AppSettingsScreen extends State<AppSettingsScreen> {
  bool _isDisablingAppLock = false;

  Widget _focus(AppSettingsTarget target, SingleButton child) =>
      widget.initialTarget == target
          ? FeatureSearchFocus(
            key: ValueKey('app-settings-focus-${target.name}'),
            borderRadius: child.buttonPosition.radius,
            child: child,
          )
          : child;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<AuthProvider, PreferenceProvider, SettingsViewModel>(
      create:
          (_) => SettingsViewModel(
            Provider.of<AuthProvider>(context, listen: false),
            Provider.of<PreferenceProvider>(context, listen: false),
          ),
      update: (_, authProvider, preferenceProvider, settingsViewModel) {
        return SettingsViewModel(authProvider, preferenceProvider);
      },
      child: Consumer<SettingsViewModel>(
        builder: (context, viewModel, child) {
          final colors = context.coconutColors;
          final premium = context.read<EntitlementService?>();
          final premiumDebug = premium != null && premiumDebugOverrideAllowed();
          return Scaffold(
            backgroundColor: colors.background,
            appBar: CoconutAppBar.build(title: t.app_settings, context: context, isBottom: true),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 보안
                  _category(t.security),
                  ButtonGroup(
                    buttons: [
                      _focus(
                        AppSettingsTarget.pin,
                        SingleButton(
                          title: t.settings_screen.set_password,
                          rightElement: _buildSwitch(
                            isOn: viewModel.isSetPin,
                            onChanged: (isOn) async {
                              if (isOn) {
                                _showPinSettingScreen(useBiometrics: true);
                                return;
                              }

                              await _disableAppLock();
                            },
                          ),
                        ),
                      ),
                      if (viewModel.canCheckBiometrics && viewModel.isSetPin)
                        _focus(
                          AppSettingsTarget.biometrics,
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
                              },
                            ),
                          ),
                        ),
                      if (viewModel.isSetPin)
                        _focus(
                          AppSettingsTarget.pinChange,
                          SingleButton(
                            title: t.settings_screen.change_password,
                            onPressed: () async {
                              final authProvider = viewModel.authProvider;
                              if (await authProvider.isBiometricsAuthValid()) {
                                _showPinSettingScreen(useBiometrics: false);
                                return;
                              }

                              if (await _requestPin()) {
                                _showPinSettingScreen(useBiometrics: false);
                              }
                            },
                          ),
                        ),
                    ],
                  ),

                  CoconutLayout.spacing_400h,

                  // 단위
                  _category(t.unit),
                  ButtonGroup(
                    buttons: [
                      Selector<PreferenceProvider, BitcoinUnit>(
                        selector: (_, viewModel) => viewModel.currentUnit,
                        builder: (context, currentUnit, child) {
                          return _buildAnimatedButton(
                            title: t.bitcoin,
                            subtitle: currentUnit.symbol,
                            onPressed: () async {
                              AppSettingsScreen.open(context, AppSettingsTarget.unit);
                            },
                          );
                        },
                      ),
                      Selector<PreferenceProvider, String>(
                        selector: (_, provider) => provider.selectedFiat.code,
                        builder: (context, fiatCode, child) {
                          return _buildAnimatedButton(
                            title: t.settings_screen.fiat,
                            subtitle: fiatCode,
                            onPressed: () async {
                              AppSettingsScreen.open(context, AppSettingsTarget.fiat);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  CoconutLayout.spacing_400h,

                  // 일반
                  _category(t.general),
                  ButtonGroup(
                    buttons: [
                      Selector<PreferenceProvider, String>(
                        selector: (_, provider) => provider.language,
                        builder: (context, language, child) {
                          return _buildAnimatedButton(
                            title: t.settings_screen.language,
                            subtitle: _getCurrentLanguageDisplayName(language),
                            onPressed: () async {
                              AppSettingsScreen.open(context, AppSettingsTarget.language);
                            },
                          );
                        },
                      ),
                      ValueListenableBuilder<CoconutThemeVariant>(
                        valueListenable: CoconutThemeController.variantNotifier,
                        builder: (context, variant, _) {
                          final currentLabel = switch (variant) {
                            CoconutThemeVariant.light => t.theme_light,
                            CoconutThemeVariant.dark => t.theme_dark,
                            CoconutThemeVariant.coconutTheme => t.theme_coconut,
                          };
                          return _buildAnimatedButton(
                            title: t.theme,
                            subtitle: currentLabel,
                            onPressed: () {
                              AppSettingsScreen.open(context, AppSettingsTarget.theme);
                            },
                          );
                        },
                      ),
                      Selector<PreferenceProvider, NumberFormatPreset>(
                        selector: (_, provider) => provider.numberFormatPreset,
                        builder: (context, preset, child) {
                          return _buildAnimatedButton(
                            title: t.settings_screen.number_format,
                            subtitle: preset.displayLabel,
                            onPressed: () {
                              AppSettingsScreen.open(context, AppSettingsTarget.numberFormat);
                            },
                          );
                        },
                      ),
                      if (premium != null)
                        ValueListenableBuilder<PremiumState>(
                          key: const Key('app-settings-premium'),
                          valueListenable: premium.state,
                          builder: (context, state, _) {
                            final label = premiumStatusLabel(state);
                            return LayoutBuilder(
                              builder:
                                  (context, constraints) => SingleButton(
                                    enableShrinkAnim: true,
                                    animationEndValue: 0.97,
                                    title: t.premium.settings_name,
                                    leftElement: PremiumMark(size: 20, muted: !state.isActive),
                                    rightElement: ConstrainedBox(
                                      constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.4),
                                      child: Text(
                                        label,
                                        textAlign: TextAlign.end,
                                        style: (label.containsCJK
                                                ? CoconutTypography.body3_12.copyWith(height: 1.3)
                                                : CoconutTypography.body3_12_Number)
                                            .setColor(
                                              state.isActive
                                                  ? context.coconutColors.premiumText
                                                  : context.coconutColors.tertiaryText,
                                            ),
                                      ),
                                    ),
                                    showRightArrowWithRightElement: true,
                                    onPressed: () => PremiumSubscriptionScreen.open(context),
                                  ),
                            );
                          },
                        ),
                    ],
                  ),
                  CoconutLayout.spacing_400h,

                  // 네트워크
                  _category(t.network),
                  // mainnet인 경우만 블록 익스플로러 표시
                  NetworkType.currentNetworkType == NetworkType.mainnet
                      ? ButtonGroup(
                        buttons: [
                          _buildAnimatedButton(
                            title: t.electrum_server,
                            onPressed: () async {
                              Navigator.pushNamed(context, AppRouteNames.electrumServer);
                            },
                          ),
                          _buildAnimatedButton(
                            title: t.block_explorer,
                            onPressed: () async {
                              Navigator.pushNamed(context, AppRouteNames.blockExplorer);
                            },
                          ),
                        ],
                      )
                      : _buildAnimatedButton(
                        title: t.electrum_server,
                        onPressed: () async {
                          Navigator.pushNamed(context, AppRouteNames.electrumServer);
                        },
                      ),

                  CoconutLayout.spacing_400h,

                  // 도구
                  _category(t.tool),
                  ButtonGroup(
                    buttons: [
                      _focus(
                        AppSettingsTarget.utxoSelection,
                        SingleButton(
                          title: t.settings_screen.utxo_manual_selection,
                          subtitle: t.settings_screen.utxo_manual_selection_description,
                          isVerticalSubtitle: true,
                          rightElement: _buildSwitch(
                            isOn: viewModel.isManualUtxoSelectionMode,
                            onChanged: (isOn) async {
                              viewModel.setManualUtxoSelectionMode(isOn);
                              vibrateExtraLight();
                            },
                          ),
                        ),
                      ),
                      _buildAnimatedButton(
                        title: t.label_management_screen.title,
                        subtitle: t.label_management_screen.subtitle,
                        isVerticalSubtitle: true,
                        onPressed: () => _showLabelsManagementScreen(context),
                      ),
                    ],
                  ),

                  // 개발자 모드에서만 표시되는 디버그 섹션(Premium 강제 켜기는 regtest 빌드에서도. 메인넷 릴리즈엔 없음)
                  if (kDebugMode || premiumDebug) ...[
                    CoconutLayout.spacing_400h,
                    _category('개발자 도구'),
                    ButtonGroup(
                      buttons: [
                        if (kDebugMode)
                          _buildAnimatedButton(
                            title: 'Realm 디버그용 뷰어',
                            onPressed: () {
                              final realmManager = Provider.of<RealmManager>(context, listen: false);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => RealmDebugScreen(realmManager: realmManager)),
                              );
                            },
                          ),
                        if (premiumDebug)
                          SingleButton(
                            key: const Key('app-settings-premium-debug'),
                            title: t.premium.subscription.dev_force_premium,
                            rightElement: _buildSwitch(
                              isOn: premium.debugOverride,
                              onChanged: (isOn) async {
                                await premium.setDebugOverride(isOn);
                                if (mounted) setState(() {});
                              },
                            ),
                          ),
                      ],
                    ),
                  ],

                  CoconutLayout.spacing_400h,

                  // 앱 정보 보기
                  _category(t.app_info),
                  _buildAnimatedButton(
                    title: t.view_app_info,
                    onPressed: () => Navigator.pushNamed(context, AppRouteNames.appInfo),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwitch({required bool isOn, required Function(bool) onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: CoconutSwitch(
        isOn: isOn,
        activeTrackColor: context.coconutColors.switchActiveTrack,
        activeThumbColor: context.coconutColors.switchActiveThumb,
        inactiveTrackColor: context.coconutColors.switchInactiveTrack,
        inactiveThumbColor: context.coconutColors.switchInactiveThumb,
        onChanged: onChanged,
        scale: 0.75,
      ),
    );
  }

  Widget _category(String label) => Container(
    padding: const EdgeInsets.fromLTRB(8, 20, 0, 12),
    child: Text(label, style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText)),
  );

  Widget _buildAnimatedButton({
    required String title,
    required VoidCallback onPressed,
    String? subtitle,
    TextStyle? subtitleStyle,
    bool isVerticalSubtitle = false,
  }) {
    return SingleButton(
      enableShrinkAnim: true,
      isVerticalSubtitle: isVerticalSubtitle,
      animationEndValue: 0.97,
      title: title,
      subtitle: subtitle,
      subtitleStyle: subtitleStyle,
      onPressed: onPressed,
    );
  }

  void _showPinSettingScreen({required bool useBiometrics}) {
    CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      screenName: AnalyticsScreenNames.appSettingsPinSetSheet,
      heightRatio: 0.9,
      child: CustomLoadingOverlay(child: PinSettingScreen(useBiometrics: useBiometrics)),
    );
  }

  Future<void> _disableAppLock() async {
    if (_isDisablingAppLock) return;
    _isDisablingAppLock = true;
    try {
      final authProvider = context.read<AuthProvider>();
      if (context.read<WalletProvider>().hasHotWalletWithBalance) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => CoconutPopup(
                languageCode: context.read<PreferenceProvider>().language,
                title: t.settings_screen.disable_app_lock_title,
                description: t.settings_screen.disable_app_lock_description,
                leftButtonText: t.cancel,
                rightButtonText: t.settings_screen.disable_app_lock_confirm,
                onTapLeft: () => Navigator.of(dialogContext).pop(false),
                onTapRight: () => Navigator.of(dialogContext).pop(true),
              ),
        );
        if (!mounted || confirmed != true) return;
      }

      final biometricVerified = await authProvider.isBiometricsAuthValid();
      if (!mounted) return;
      if (!biometricVerified) {
        final pinVerified = await _requestPin();
        if (!mounted || !pinVerified) return;
      }
      await authProvider.deletePin();
    } finally {
      _isDisablingAppLock = false;
    }
  }

  Future<bool> _requestPin() async {
    return await CommonBottomSheets.showCustomHeightBottomSheet<bool>(
          context: context,
          screenName: AnalyticsScreenNames.appSettingsPinCheckSheet,
          heightRatio: 0.9,
          child: const CustomLoadingOverlay(child: PinCheckScreen(allowBiometrics: false)),
        ) ??
        false;
  }

  String _getCurrentLanguageDisplayName(String language) {
    switch (AppLanguage.fromCode(language)) {
      case AppLanguage.ko:
        return t.settings_screen.locales.korean;
      case AppLanguage.ja:
        return t.settings_screen.locales.japanese;
      case AppLanguage.es:
        return t.settings_screen.locales.spanish;
      case AppLanguage.en:
        return t.settings_screen.locales.english;
      case AppLanguage.de:
        return t.settings_screen.locales.german;
    }
  }

  void _showLabelsManagementScreen(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRouteNames.labelManagement,
      arguments: const LabelManagementRouteArgs(showImportMemosFromOtherWalletsOption: false),
    );
  }
}
