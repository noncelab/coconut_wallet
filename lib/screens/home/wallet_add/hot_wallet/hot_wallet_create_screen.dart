import 'dart:async';
import 'dart:convert';

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutTextField;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/wallet_name_conflict_exception.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/utils/custom_wallet_icons.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/wallet_name_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:coconut_wallet/widgets/common/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

({Uint8List mnemonic, String descriptor}) _generateHotWalletMaterial(
  ({int mnemonicWordCount, Uint8List passphrase}) input,
) {
  final mnemonicWordCount = input.mnemonicWordCount;
  final passphrase = input.passphrase;
  final seed = Seed.random(mnemonicLength: mnemonicWordCount, passphrase: passphrase);
  try {
    final vault = SingleSignatureVault.fromSeed(seed);
    return (mnemonic: Uint8List.fromList(seed.mnemonic), descriptor: vault.descriptor);
  } finally {
    seed.wipe();
    passphrase.fillRange(0, passphrase.length, 0);
  }
}

class HotWalletCreateScreen extends StatefulWidget {
  const HotWalletCreateScreen({super.key});

  @override
  State<HotWalletCreateScreen> createState() => _HotWalletCreateScreenState();
}

class _HotWalletCreateScreenState extends State<HotWalletCreateScreen> {
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
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _suggestedWalletName = _generateDefaultWalletName();
    _nameController = TextEditingController();
    _nameFocusNode.addListener(_handleNameFocusChanged);
    _passphraseFocusNode.addListener(_handlePassphraseFocusChanged);
    _passphraseConfirmFocusNode.addListener(_handlePassphraseConfirmFocusChanged);
  }

  @override
  void dispose() {
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
    return Stack(
      children: [
        Scaffold(
          backgroundColor: context.coconutColors.background,
          appBar: CoconutAppBar.build(
            title: t.wallet_home_screen.hot_wallet_create.title,
            context: context,
            onBackPressed: () => Navigator.pop(context),
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
                  text: t.wallet_home_screen.hot_wallet_create.create_wallet,
                  isActive:
                      !_isCreating &&
                      (!_usePassphrase ||
                          (_passphraseController.text.isNotEmpty &&
                              _passphraseConfirmController.text.isNotEmpty &&
                              _passphraseController.text == _passphraseConfirmController.text)),
                  surroundingsColor: context.coconutColors.background,
                  onButtonClicked: _onCreateWalletPressed,
                ),
              ],
            ),
          ),
        ),
        if (_isCreating) const CoconutLoadingOverlay(applyFullScreen: true),
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

  Widget _buildColorPalette({required int selectedColorIndex, required ValueChanged<int> onSelected}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 24,
      ),
      itemCount: CoconutColors.colorPalette.length,
      itemBuilder: (context, index) {
        final isSelected = index == selectedColorIndex;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelected(index),
          child: Center(
            child: Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? context.coconutColors.primaryText : Colors.transparent,
                  width: 2,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: CoconutColors.colorPalette[index]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconItem({required int iconIndex, required int selectedIconIndex, required VoidCallback onSelected}) {
    final isSelected = iconIndex == selectedIconIndex;
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelected,
        child: Center(
          child: Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? context.coconutColors.primaryText : Colors.transparent, width: 2),
            ),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(shape: BoxShape.circle, color: context.coconutColors.iconBackgroundSubtle),
              child: SvgPicture.asset(
                CustomWalletIcons.getPathByIndex(iconIndex),
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
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

  Widget _buildAppearancePreview({required int colorIndex, required int iconIndex}) {
    final walletName = _nameController.text.trim().isEmpty ? _suggestedWalletName : _nameController.text.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.coconutColors.surface,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Row(
        children: [
          WalletIcon(
            walletImportSource: WalletImportSource.coconutVault,
            colorIndex: colorIndex,
            iconIndex: iconIndex,
            badgeSvgAssetPath: FeatureWalletIconPath.hotWalletFire,
            badgeSize: 18,
          ),
          CoconutLayout.spacing_300w,
          Expanded(
            child: Text(
              walletName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAppearanceSettings() async {
    _nameFocusNode.unfocus();
    FocusScope.of(context).requestFocus(_screenFocusNode);
    var temporaryColorIndex = _selectedColorIndex;
    var temporaryIconIndex = _selectedIconIndex;

    await CommonBottomSheets.showBottomSheet<void>(
      context: context,
      title: t.wallet_home_screen.hot_wallet_create.appearance_settings,
      showDragHandle: true,
      showCloseButton: true,
      adjustForKeyboardInset: false,
      child: SafeArea(
        top: false,
        child: StatefulBuilder(
          builder:
              (bottomSheetContext, setBottomSheetState) => SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.65,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildAppearancePreview(colorIndex: temporaryColorIndex, iconIndex: temporaryIconIndex),
                            CoconutLayout.spacing_500h,
                            _buildSectionTitle(t.wallet_home_screen.hot_wallet_create.color),
                            CoconutLayout.spacing_200h,
                            _buildColorPalette(
                              selectedColorIndex: temporaryColorIndex,
                              onSelected: (index) => setBottomSheetState(() => temporaryColorIndex = index),
                            ),
                            CoconutLayout.spacing_500h,
                            _buildSectionTitle(t.wallet_home_screen.hot_wallet_create.icon),
                            CoconutLayout.spacing_200h,
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 24,
                              ),
                              itemCount: CustomWalletIcons.totalCount,
                              itemBuilder:
                                  (context, index) => _buildIconItem(
                                    iconIndex: index,
                                    selectedIconIndex: temporaryIconIndex,
                                    onSelected: () => setBottomSheetState(() => temporaryIconIndex = index),
                                  ),
                            ),
                            CoconutLayout.spacing_300h,
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ShrinkAnimationButton(
                          onPressed: () {
                            setState(() {
                              _selectedColorIndex = temporaryColorIndex;
                              _selectedIconIndex = temporaryIconIndex;
                            });
                            Navigator.pop(bottomSheetContext);
                          },
                          defaultColor: context.coconutColors.buttonPrimaryBackground,
                          pressedColor: context.coconutColors.buttonPrimaryPressOverlay,
                          borderRadius: CoconutStyles.radius_200,
                          child: SizedBox(
                            height: 52,
                            child: Center(
                              child: Text(
                                t.done,
                                style: CoconutTypography.body1_16_Bold.setColor(
                                  context.coconutColors.buttonPrimaryForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );

    if (mounted) {
      FocusScope.of(context).requestFocus(_screenFocusNode);
    }
  }

  Future<void> _onCreateWalletPressed() async {
    if (_isCreating) return;
    FocusScope.of(context).unfocus();
    final walletProvider = context.read<WalletProvider>();
    final walletName = _nameController.text.trim().isEmpty ? _suggestedWalletName : _nameController.text.trim();

    if (walletProvider.walletItemList.any((wallet) => wallet.name == walletName)) {
      await showInfoDialog(
        context,
        context.read<PreferenceProvider>().language,
        t.wallet_home_screen.hot_wallet_create.duplicate_name_title,
        t.wallet_home_screen.hot_wallet_create.duplicate_name_description,
      );
      return;
    }

    setState(() => _isCreating = true);
    await WidgetsBinding.instance.endOfFrame;

    final passphrase = Uint8List.fromList(utf8.encode(_usePassphrase ? _passphraseController.text : ''));
    Uint8List? mnemonic;
    final secretRepository = HotWalletSecretRepository();
    final storageKey = secretRepository.newSecretStorageKey();
    var sensitiveBytesCleared = false;

    void clearSensitiveBytes() {
      if (sensitiveBytesCleared) return;
      mnemonic?.fillRange(0, mnemonic.length, 0);
      passphrase.fillRange(0, passphrase.length, 0);
      sensitiveBytesCleared = true;
    }

    try {
      final mnemonicWordCount = _mnemonicWordCount;
      final material = await compute(_generateHotWalletMaterial, (
        mnemonicWordCount: mnemonicWordCount,
        passphrase: Uint8List.fromList(passphrase),
      ));
      final generatedMnemonic = material.mnemonic;
      mnemonic = generatedMnemonic;
      final wallet = WatchOnlyWallet(
        walletName,
        _selectedColorIndex,
        _selectedIconIndex,
        material.descriptor,
        null,
        null,
        WalletImportSource.coconutVault.name,
      );

      final passphraseToStore = _enterPassphraseWhenSigning ? Uint8List(0) : Uint8List.fromList(passphrase);
      try {
        await AppGuard.runWithoutPrivacyScreen(
          () => secretRepository.create(
            storageKey: storageKey,
            mnemonic: generatedMnemonic,
            passphrase: passphraseToStore,
          ),
        );
      } finally {
        passphraseToStore.fillRange(0, passphraseToStore.length, 0);
      }
      final addedWallet = await walletProvider.addHotWallet(
        wallet,
        secureStorageKey: storageKey,
        backupVerified: false,
        enterPassphraseWhenSigning: _enterPassphraseWhenSigning,
        createdAt: DateTime.now(),
      );

      if (!mounted) return;
      final mnemonicForBackup = Uint8List.fromList(generatedMnemonic);
      final passphraseForBackup = Uint8List.fromList(passphrase);
      _passphraseController.clear();
      _passphraseConfirmController.clear();
      clearSensitiveBytes();
      await Navigator.pushReplacementNamed(
        context,
        '/hot-wallet-mnemonic-backup-guide',
        arguments: {
          'walletName': walletName,
          'walletId': addedWallet.id,
          'mnemonic': mnemonicForBackup,
          'passphrase': passphraseForBackup,
          'enterPassphraseWhenSigning': _enterPassphraseWhenSigning,
        },
      );
    } catch (error, stackTrace) {
      Logger.error('Hot wallet creation failed: $error\n$stackTrace');
      try {
        await secretRepository.delete(storageKey);
      } catch (_) {
        // 저장이 시작되기 전 실패했거나 이미 정리된 경우
      }
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
    } finally {
      clearSensitiveBytes();
      if (mounted) setState(() => _isCreating = false);
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
