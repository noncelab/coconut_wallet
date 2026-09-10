import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutTextField;
import 'package:coconut_wallet/core/exceptions/wallet_name_conflict_exception.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/hot_wallet_create_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/hot_wallet/widgets/wallet_appearance_sheet.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/wallet_name_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:coconut_wallet/widgets/common/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class HotWalletCreateScreen extends StatefulWidget {
  const HotWalletCreateScreen({super.key, this.viewModel});

  final HotWalletCreateViewModel? viewModel;

  @override
  State<HotWalletCreateScreen> createState() => _HotWalletCreateScreenState();
}

class _HotWalletCreateScreenState extends State<HotWalletCreateScreen> {
  late final HotWalletCreateViewModel _viewModel;
  late final bool _shouldDisposeViewModel;
  late final TextEditingController _nameController;
  late final String _suggestedWalletName;
  final TextEditingController _passphraseController = TextEditingController();
  final TextEditingController _passphraseConfirmController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _passphraseFocusNode = FocusNode();
  final FocusNode _passphraseConfirmFocusNode = FocusNode();
  final FocusNode _screenFocusNode = FocusNode();
  final GlobalKey _passphraseFieldKey = GlobalKey();
  final GlobalKey _passphraseConfirmFieldKey = GlobalKey();
  Timer? _passphraseScrollTimer;
  int _selectedColorIndex = 0;
  int _selectedIconIndex = 0;
  int _mnemonicWordCount = 12;
  bool _usePassphrase = false;
  bool _isPassphraseVisible = false;
  bool _enterPassphraseWhenSigning = false;
  bool _isPassphraseOptionPressed = false;
  bool _hasNameFieldEverFocused = false;
  bool _isAdvancedSettingsExpanded = false;

  @override
  void initState() {
    super.initState();
    _shouldDisposeViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ?? HotWalletCreateViewModel(context.read<WalletProvider>());
    _viewModel.addListener(_handleViewModelChanged);
    _suggestedWalletName = _generateDefaultWalletName();
    _nameController = TextEditingController();
    _nameFocusNode.addListener(_handleNameFocusChanged);
    _passphraseFocusNode.addListener(_handlePassphraseFocusChanged);
    _passphraseConfirmFocusNode.addListener(_handlePassphraseConfirmFocusChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelChanged);
    if (_shouldDisposeViewModel) _viewModel.dispose();
    _nameFocusNode.removeListener(_handleNameFocusChanged);
    _passphraseFocusNode.removeListener(_handlePassphraseFocusChanged);
    _passphraseConfirmFocusNode.removeListener(_handlePassphraseConfirmFocusChanged);
    _passphraseScrollTimer?.cancel();
    _nameController.dispose();
    _passphraseController.dispose();
    _passphraseConfirmController.dispose();
    _scrollController.dispose();
    _nameFocusNode.dispose();
    _passphraseFocusNode.dispose();
    _passphraseConfirmFocusNode.dispose();
    _screenFocusNode.dispose();
    super.dispose();
  }

  void _handleViewModelChanged() {
    if (mounted) setState(() {});
  }

  void _handleNameFocusChanged() {
    if (!mounted || !_nameFocusNode.hasFocus || _hasNameFieldEverFocused) {
      return;
    }
    setState(() => _hasNameFieldEverFocused = true);
  }

  void _handlePassphraseFocusChanged() {
    if (_passphraseFocusNode.hasFocus) {
      _scrollToPassphraseField(_passphraseFieldKey);
    }
  }

  void _handlePassphraseConfirmFocusChanged() {
    if (_passphraseConfirmFocusNode.hasFocus) {
      _scrollToPassphraseField(_passphraseConfirmFieldKey);
    }
  }

  void _scrollToPassphraseField(GlobalKey fieldKey) {
    _passphraseScrollTimer?.cancel();
    _ensurePassphraseFieldVisible(fieldKey);
    _passphraseScrollTimer = Timer(const Duration(milliseconds: 600), () => _ensurePassphraseFieldVisible(fieldKey));
  }

  void _ensurePassphraseFieldVisible(GlobalKey fieldKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final renderObject = fieldKey.currentContext?.findRenderObject();
      if (renderObject == null || !renderObject.attached) return;
      final alignment = identical(fieldKey, _passphraseConfirmFieldKey) ? 0.08 : 0.25;
      _scrollController.position.ensureVisible(
        renderObject,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: alignment,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_viewModel.isCreating,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: context.coconutColors.background,
            appBar: CoconutAppBar.build(
              title: t.wallet_home_screen.hot_wallet_create.title,
              context: context,
              onBackPressed: () {
                if (_viewModel.isCreating) return;
                Navigator.pop(context);
              },
              backgroundColor: context.coconutColors.background,
            ),
            body: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Stack(
                children: [
                  CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildNameField(),
                              CoconutLayout.spacing_600h,
                              _buildAdvancedSettings(),
                              CoconutLayout.spacing_600h,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  FixedBottomButton(
                    key: const ValueKey('hot-wallet-create-button'),
                    buttonKey: const ValueKey('hot-wallet-create-button-target'),
                    text: t.wallet_home_screen.hot_wallet_create.create_wallet,
                    isActive:
                        !_viewModel.isCreating &&
                        (!_usePassphrase ||
                            (_passphraseController.text.isNotEmpty &&
                                _passphraseConfirmController.text.isNotEmpty &&
                                _passphraseController.text == _passphraseConfirmController.text)),
                    surroundingsColor: context.coconutColors.background,
                    onButtonClicked: _onCreateWalletPressed,
                    subWidget: _buildMnemonicBackupGuide(),
                  ),
                ],
              ),
            ),
          ),
          if (_viewModel.isCreating) const CoconutLoadingOverlay(applyFullScreen: true),
        ],
      ),
    );
  }

  Widget _buildMnemonicBackupGuide() {
    const iconSize = 16.0;
    final guideText = t.wallet_home_screen.hot_wallet_create.mnemonic_backup_guide;
    final textStyle = CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText);
    final textPainter = TextPainter(
      text: TextSpan(text: '가', style: textStyle),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final iconTopPadding = math.max(0.0, (textPainter.height - iconSize) / 2);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: iconTopPadding),
          child: SvgPicture.asset(
            CommonStateIconPath.circleInfo,
            width: iconSize,
            height: iconSize,
            colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
          ),
        ),
        CoconutLayout.spacing_100w,
        Flexible(
          child: Text(
            LocaleSettings.currentLocale == AppLocale.ko ? TextUtils.preventLineBreakInsideWords(guideText) : guideText,
            style: textStyle,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          height: 52,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showAppearanceSettings,
            child: Center(
              child: WalletIcon(
                walletImportSource: WalletImportSource.coconutVault,
                colorIndex: _selectedColorIndex,
                iconIndex: _selectedIconIndex,
                badgeSvgAssetPath: CommonActionIconPath.editOutlined,
                badgeColor: context.coconutColors.iconSecondary,
              ),
            ),
          ),
        ),
        CoconutLayout.spacing_300w,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoconutTextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                maxLength: 20,
                maxLines: 1,
                isLengthVisible: true,
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                placeholderText: _suggestedWalletName,
                backgroundColor: context.coconutColors.inputSurface,
                activeColor: context.coconutColors.primaryText,
                cursorColor: context.coconutColors.primaryText,
                placeholderColor: context.coconutColors.inputPlaceholder,
                onChanged: (_) => setState(() {}),
                suffix:
                    _nameController.text.isEmpty
                        ? null
                        : IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 14,
                          onPressed: () {
                            _nameController.clear();
                            setState(() {});
                          },
                          icon: SvgPicture.asset(
                            CommonFormIconPath.textFieldClear,
                            colorFilter: ColorFilter.mode(context.coconutColors.secondaryText, BlendMode.srcIn),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(text, style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText));
  }

  Widget _buildAdvancedSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.coconutColors.surface,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            key: const ValueKey('hot-wallet-advanced-settings'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _isAdvancedSettingsExpanded = !_isAdvancedSettingsExpanded),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.wallet_home_screen.hot_wallet_create.advanced_settings,
                        style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
                      ),
                      CoconutLayout.spacing_100h,
                      Text(
                        t.wallet_home_screen.hot_wallet_create.advanced_summary(
                          wordCount: _mnemonicWordCount,
                          passphrase:
                              _usePassphrase
                                  ? t.wallet_home_screen.hot_wallet_create.passphrase_used
                                  : t.wallet_home_screen.hot_wallet_create.passphrase_unused,
                        ),
                        style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _isAdvancedSettingsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: context.coconutColors.iconSecondary),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child:
                _isAdvancedSettingsExpanded
                    ? Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionTitle(t.wallet_home_screen.hot_wallet_create.mnemonic_length),
                          CoconutLayout.spacing_200h,
                          Row(
                            children: [
                              for (final wordCount in [12, 24]) ...[
                                Expanded(
                                  child: Semantics(
                                    key: ValueKey('hot-wallet-word-count-$wordCount'),
                                    button: true,
                                    selected: _mnemonicWordCount == wordCount,
                                    child: ShrinkAnimationButton(
                                      onPressed: () => setState(() => _mnemonicWordCount = wordCount),
                                      defaultColor: Colors.transparent,
                                      pressedColor: context.coconutColors.surfacePressOverlay,
                                      borderRadius: 16,
                                      animationEndValue: 0.94,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        curve: Curves.easeOut,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: context.coconutColors.surface,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color:
                                                _mnemonicWordCount == wordCount
                                                    ? context.coconutColors.primaryText
                                                    : context.coconutColors.divider,
                                            width: 2,
                                          ),
                                        ),
                                        child: Text(
                                          t.wallet_home_screen.hot_wallet_create.word_count(count: wordCount),
                                          style:
                                              _mnemonicWordCount == wordCount
                                                  ? CoconutTypography.body1_16_Bold.setColor(
                                                    context.coconutColors.primaryText,
                                                  )
                                                  : CoconutTypography.body2_14.setColor(
                                                    context.coconutColors.primaryText,
                                                  ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (wordCount == 12) CoconutLayout.spacing_100w,
                              ],
                            ],
                          ),
                          CoconutLayout.spacing_500h,
                          SingleButton(
                            key: const ValueKey('hot-wallet-use-passphrase'),
                            title: t.wallet_home_screen.hot_wallet_create.use_passphrase,
                            subtitle: t.wallet_home_screen.hot_wallet_create.passphrase_description,
                            isVerticalSubtitle: true,
                            subtitleStyle: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                            customPadding: EdgeInsets.zero,
                            backgroundColor: context.coconutColors.surface,
                            onPressed: () => _setUsePassphrase(!_usePassphrase),
                            rightElement: CoconutSwitch(
                              isOn: _usePassphrase,
                              scale: 0.75,
                              activeTrackColor: context.coconutColors.switchActiveTrack,
                              activeThumbColor: context.coconutColors.switchActiveThumb,
                              inactiveTrackColor: context.coconutColors.switchInactiveTrack,
                              inactiveThumbColor: context.coconutColors.switchInactiveThumb,
                              onChanged: _setUsePassphrase,
                            ),
                          ),
                          Visibility(
                            visible: _usePassphrase,
                            maintainState: true,
                            maintainAnimation: true,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(
                                children: [
                                  Align(alignment: Alignment.centerRight, child: _buildPassphraseVisibilityButton()),
                                  CoconutLayout.spacing_100h,
                                  KeyedSubtree(
                                    key: _passphraseFieldKey,
                                    child: CoconutTextField(
                                      key: const ValueKey('hot-wallet-passphrase'),
                                      controller: _passphraseController,
                                      focusNode: _passphraseFocusNode,
                                      maxLength: 100,
                                      maxLines: 1,
                                      textInputFormatter: [LengthLimitingTextInputFormatter(100)],
                                      height: 52,
                                      obscureText: !_isPassphraseVisible,
                                      isLengthVisible: true,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      placeholderText: t.wallet_home_screen.hot_wallet_create.passphrase_placeholder,
                                      backgroundColor: context.coconutColors.inputSurface,
                                      activeColor: context.coconutColors.primaryText,
                                      cursorColor: context.coconutColors.primaryText,
                                      placeholderColor: context.coconutColors.inputPlaceholder,
                                      suffix:
                                          _passphraseController.text.isNotEmpty
                                              ? IconButton(
                                                iconSize: 14,
                                                padding: EdgeInsets.zero,
                                                onPressed: () {
                                                  _passphraseController.clear();
                                                  setState(() {});
                                                },
                                                icon: SvgPicture.asset(
                                                  CommonFormIconPath.textFieldClear,
                                                  colorFilter: ColorFilter.mode(
                                                    context.coconutColors.secondaryText,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                              )
                                              : null,
                                      onChanged: (_) {
                                        setState(() {});
                                        _scrollToPassphraseField(_passphraseFieldKey);
                                      },
                                    ),
                                  ),
                                  CoconutLayout.spacing_200h,
                                  KeyedSubtree(
                                    key: _passphraseConfirmFieldKey,
                                    child: CoconutTextField(
                                      key: const ValueKey('hot-wallet-passphrase-confirm'),
                                      controller: _passphraseConfirmController,
                                      focusNode: _passphraseConfirmFocusNode,
                                      maxLength: 100,
                                      maxLines: 1,
                                      textInputFormatter: [LengthLimitingTextInputFormatter(100)],
                                      height: 52,
                                      obscureText: !_isPassphraseVisible,
                                      isLengthVisible: true,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      placeholderText:
                                          t.wallet_home_screen.hot_wallet_create.passphrase_confirm_placeholder,
                                      backgroundColor: context.coconutColors.inputSurface,
                                      activeColor: context.coconutColors.primaryText,
                                      cursorColor: context.coconutColors.primaryText,
                                      placeholderColor: context.coconutColors.inputPlaceholder,
                                      suffix:
                                          _passphraseConfirmController.text.isNotEmpty
                                              ? IconButton(
                                                iconSize: 14,
                                                padding: EdgeInsets.zero,
                                                onPressed: () {
                                                  _passphraseConfirmController.clear();
                                                  setState(() {});
                                                },
                                                icon: SvgPicture.asset(
                                                  CommonFormIconPath.textFieldClear,
                                                  colorFilter: ColorFilter.mode(
                                                    context.coconutColors.secondaryText,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                              )
                                              : null,
                                      isError:
                                          _passphraseConfirmController.text.isNotEmpty &&
                                          _passphraseController.text != _passphraseConfirmController.text,
                                      errorText:
                                          _passphraseConfirmController.text.isNotEmpty &&
                                                  _passphraseController.text != _passphraseConfirmController.text
                                              ? t.wallet_home_screen.hot_wallet_create.passphrase_mismatch
                                              : null,
                                      onChanged: (_) {
                                        setState(() {});
                                        _scrollToPassphraseField(_passphraseConfirmFieldKey);
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Listener(
                                      key: const ValueKey('hot-wallet-enter-passphrase-when-signing'),
                                      onPointerDown: (_) => setState(() => _isPassphraseOptionPressed = true),
                                      onPointerUp: (_) => setState(() => _isPassphraseOptionPressed = false),
                                      onPointerCancel: (_) => setState(() => _isPassphraseOptionPressed = false),
                                      child: Row(
                                        children: [
                                          CoconutCheckbox(
                                            isSelected: _enterPassphraseWhenSigning,
                                            onChanged: _setEnterPassphraseWhenSigning,
                                            disabledColor: context.coconutColors.chipSelectedBackground,
                                            color: context.coconutColors.chipSelectedBackground,
                                          ),
                                          CoconutLayout.spacing_200w,
                                          Expanded(
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => _setEnterPassphraseWhenSigning(!_enterPassphraseWhenSigning),
                                              child: Text(
                                                t.wallet_home_screen.hot_wallet_create.enter_passphrase_when_signing,
                                                style: CoconutTypography.body3_12.setColor(
                                                  _isPassphraseOptionPressed
                                                      ? context.coconutColors.tertiaryText
                                                      : context.coconutColors.secondaryText,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPassphraseVisibilityButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _isPassphraseVisible = !_isPassphraseVisible),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: context.coconutColors.surface,
          borderRadius: BorderRadius.circular(CoconutStyles.radius_100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isPassphraseVisible
                  ? t.wallet_home_screen.hot_wallet_create.hide_passphrase
                  : t.wallet_home_screen.hot_wallet_create.show_passphrase,
              style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
            ),
            CoconutLayout.spacing_100w,
            SvgPicture.asset(
              _isPassphraseVisible ? CommonVisibilityIconPath.eye : CommonVisibilityIconPath.eyeCrossed,
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  void _setUsePassphrase(bool value) {
    if (!value) {
      _passphraseFocusNode.unfocus();
      _passphraseConfirmFocusNode.unfocus();
      _isPassphraseVisible = false;
      _enterPassphraseWhenSigning = false;
    }
    setState(() => _usePassphrase = value);
  }

  Future<void> _showAppearanceSettings() async {
    _nameFocusNode.unfocus();
    FocusScope.of(context).requestFocus(_screenFocusNode);
    await CommonBottomSheets.showBottomSheet<void>(
      context: context,
      title: t.wallet_home_screen.hot_wallet_create.appearance_settings,
      showDragHandle: true,
      showCloseButton: true,
      adjustForKeyboardInset: false,
      child: WalletAppearanceSheet(
        walletName: _nameController.text.trim().isEmpty ? _suggestedWalletName : _nameController.text.trim(),
        initialColorIndex: _selectedColorIndex,
        initialIconIndex: _selectedIconIndex,
        onDone: (selection) {
          setState(() {
            _selectedColorIndex = selection.colorIndex;
            _selectedIconIndex = selection.iconIndex;
          });
          Navigator.pop(context);
        },
      ),
    );

    if (mounted) {
      FocusScope.of(context).requestFocus(_screenFocusNode);
    }
  }

  Future<void> _onCreateWalletPressed() async {
    if (_viewModel.isCreating) return;
    FocusScope.of(context).unfocus();
    final walletName = _nameController.text.trim().isEmpty ? _suggestedWalletName : _nameController.text.trim();
    await WidgetsBinding.instance.endOfFrame;

    try {
      final result = await _viewModel.createWallet(
        walletName: walletName,
        colorIndex: _selectedColorIndex,
        iconIndex: _selectedIconIndex,
        mnemonicWordCount: _mnemonicWordCount,
        passphrase: _usePassphrase ? _passphraseController.text : '',
        enterPassphraseWhenSigning: _enterPassphraseWhenSigning,
      );

      if (!mounted) {
        result.clearSensitiveBytes();
        return;
      }
      _passphraseController.clear();
      _passphraseConfirmController.clear();
      await Navigator.pushReplacementNamed(
        context,
        '/hot-wallet-mnemonic-backup-guide',
        arguments: {
          'walletId': result.walletId,
          'descriptor': result.descriptor,
          'mnemonic': result.mnemonic,
          'passphrase': result.passphrase,
          'enterPassphraseWhenSigning': result.enterPassphraseWhenSigning,
        },
      );
    } catch (error, stackTrace) {
      Logger.error('Hot wallet creation failed: $error\n$stackTrace');
      if (mounted) {
        final isNameConflict = error is WalletNameConflictException;
        await showInfoDialog(
          context,
          context.read<PreferenceProvider>().language,
          isNameConflict ? t.wallet_home_screen.hot_wallet_create.duplicate_name_title : t.alert.error_occurs,
          isNameConflict
              ? t.wallet_home_screen.hot_wallet_create.duplicate_name_description
              : t.wallet_home_screen.hot_wallet_create.creation_failed,
        );
      }
    }
  }

  Future<void> _setEnterPassphraseWhenSigning(bool value) async {
    if (!value) {
      if (mounted) setState(() => _enterPassphraseWhenSigning = false);
      return;
    }

    _keepKeyboardDismissed();
    var confirmed = false;
    await showConfirmDialog(
      context,
      context.read<PreferenceProvider>().language,
      t.wallet_home_screen.hot_wallet_create.passphrase_not_stored_title,
      t.wallet_home_screen.hot_wallet_create.passphrase_not_stored_description,
      leftButtonText: t.cancel,
      rightButtonText: t.wallet_home_screen.hot_wallet_create.passphrase_not_stored_confirm,
      onTapRight: () {
        confirmed = true;
        Navigator.pop(context);
      },
    );
    if (!mounted) return;
    _keepKeyboardDismissed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keepKeyboardDismissed();
    });
    if (confirmed) setState(() => _enterPassphraseWhenSigning = true);
  }

  void _keepKeyboardDismissed() {
    _passphraseScrollTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    _nameFocusNode.unfocus();
    _passphraseFocusNode.unfocus();
    _passphraseConfirmFocusNode.unfocus();
    FocusScope.of(context).requestFocus(_screenFocusNode);
  }

  String _generateDefaultWalletName() {
    return WalletNameUtil.findAvailableDefaultName(
      existingNames: context.read<WalletProvider>().walletItemList.map((wallet) => wallet.name),
      firstName: t.wallet_home_screen.hot_wallet_create.default_name,
      numberedName: (number) => t.wallet_home_screen.hot_wallet_create.default_name_with_number(number: number),
    );
  }
}
