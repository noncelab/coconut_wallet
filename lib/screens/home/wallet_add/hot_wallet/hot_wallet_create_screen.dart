import 'dart:async';
import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/screens/settings/pin_setting_screen.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/icon/wallet_icon.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

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
  Timer? _pinRecommendationTimer;
  int _selectedColorIndex = 0;
  int _selectedIconIndex = 0;
  int _mnemonicWordCount = 12;
  bool _usePassphrase = false;
  bool _isPassphraseVisible = false;
  bool _hasNameFieldEverFocused = false;
  bool _isAdvancedSettingsExpanded = false;
  bool _isPinRecommendationVisible = false;

  @override
  void initState() {
    super.initState();
    _suggestedWalletName = _generateDefaultWalletName();
    _nameController = TextEditingController();
    _nameFocusNode.addListener(_handleNameFocusChanged);
    _passphraseFocusNode.addListener(_handlePassphraseFocusChanged);
    _passphraseConfirmFocusNode.addListener(_handlePassphraseConfirmFocusChanged);
    _pinRecommendationTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted || context.read<AuthProvider>().isSetPin) return;
      setState(() => _isPinRecommendationVisible = true);
    });
  }

  @override
  void dispose() {
    _nameFocusNode.removeListener(_handleNameFocusChanged);
    _passphraseFocusNode.removeListener(_handlePassphraseFocusChanged);
    _passphraseConfirmFocusNode.removeListener(_handlePassphraseConfirmFocusChanged);
    _passphraseScrollTimer?.cancel();
    _pinRecommendationTimer?.cancel();
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
    if (!mounted || !_nameFocusNode.hasFocus || _hasNameFieldEverFocused) return;
    setState(() => _hasNameFieldEverFocused = true);
  }

  void _handlePassphraseFocusChanged() {
    if (_passphraseFocusNode.hasFocus) _scrollToPassphraseField(_passphraseFieldKey);
  }

  void _handlePassphraseConfirmFocusChanged() {
    if (_passphraseConfirmFocusNode.hasFocus) _scrollToPassphraseField(_passphraseConfirmFieldKey);
  }

  void _scrollToPassphraseField(GlobalKey fieldKey) {
    _passphraseScrollTimer?.cancel();
    _ensurePassphraseFieldVisible(fieldKey);
    _passphraseScrollTimer = Timer(const Duration(milliseconds: 300), () => _ensurePassphraseFieldVisible(fieldKey));
  }

  void _ensurePassphraseFieldVisible(GlobalKey fieldKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final renderObject = fieldKey.currentContext?.findRenderObject();
      if (renderObject == null || !renderObject.attached) return;
      _scrollController.position.ensureVisible(
        renderObject,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.4,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        if (!context.watch<AuthProvider>().isSetPin) _buildPinRecommendationEntrance(),
                        _buildAdvancedSettings(),
                        CoconutLayout.spacing_600h,
                        _buildSecurityInformation(),
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
                  !_usePassphrase ||
                  (_passphraseController.text.isNotEmpty &&
                      _passphraseConfirmController.text.isNotEmpty &&
                      _passphraseController.text == _passphraseConfirmController.text),
              surroundingsColor: context.coconutColors.background,
              onButtonClicked: _onCreateWalletPressed,
            ),
          ],
        ),
      ),
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
                badgeSvgAssetPath: 'assets/svg/edit-outlined.svg',
                badgeColor: context.coconutColors.iconDefault,
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
                borderColor: context.coconutColors.inputBorder,
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
                            'assets/svg/text-field-clear.svg',
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
                CustomIcons.getPathByIndex(iconIndex),
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
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
        color: context.coconutColors.surfaceCard,
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
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: context.coconutColors.iconSubDefault),
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
                                      pressedColor: context.coconutColors.surfacePressed,
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
                                if (wordCount == 12) CoconutLayout.spacing_300w,
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
                            backgroundColor: context.coconutColors.surfaceCard,
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
                                      maxLines: 1,
                                      height: 52,
                                      obscureText: !_isPassphraseVisible,
                                      isLengthVisible: false,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      placeholderText: t.wallet_home_screen.hot_wallet_create.passphrase_placeholder,
                                      backgroundColor: context.coconutColors.inputSurface,
                                      borderColor: context.coconutColors.inputBorder,
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
                                                  'assets/svg/text-field-clear.svg',
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
                                      maxLines: 1,
                                      height: 52,
                                      obscureText: !_isPassphraseVisible,
                                      isLengthVisible: false,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      placeholderText:
                                          t.wallet_home_screen.hot_wallet_create.passphrase_confirm_placeholder,
                                      backgroundColor: context.coconutColors.inputSurface,
                                      borderColor: context.coconutColors.inputBorder,
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
                                                  'assets/svg/text-field-clear.svg',
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
                                  CoconutLayout.spacing_300h,
                                  _buildPassphraseRecoveryWarning(),
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
          color: context.coconutColors.surfaceCard,
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
              _isPassphraseVisible ? 'assets/svg/eye.svg' : 'assets/svg/eye-crossed.svg',
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(context.coconutColors.iconSubDefault, BlendMode.srcIn),
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
    }
    setState(() => _usePassphrase = value);
  }

  Widget _buildSecurityInformation() {
    final strings = t.wallet_home_screen.hot_wallet_create;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.security_checklist_title,
          style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
        ),
        CoconutLayout.spacing_300h,
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.coconutColors.surfaceCard,
            borderRadius: BorderRadius.circular(CoconutStyles.radius_300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSecurityRule(title: strings.recovery_guide_title, description: strings.recovery_guide_description),
              CoconutLayout.spacing_400h,
              _buildSecurityRule(title: strings.privacy_guide_title, description: strings.privacy_guide_description),
              CoconutLayout.spacing_400h,
              _buildSecurityRule(
                title: strings.hot_wallet_usage_title,
                description: strings.hot_wallet_usage_description,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityRule({required String title, required String description}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText)),
        CoconutLayout.spacing_100h,
        Text(description, style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
      ],
    );
  }

  Widget _buildPassphraseRecoveryWarning() {
    final warningColor = context.coconutColors.warning;
    final strings = t.wallet_home_screen.hot_wallet_create;

    return CoconutToolTip(
      tooltipType: CoconutTooltipType.fixed,
      tooltipState: CoconutTooltipState.warning,
      padding: const EdgeInsets.all(16),
      borderRadius: CoconutStyles.radius_300,
      backgroundColor: warningColor.withValues(alpha: 0.12),
      borderColor: Colors.transparent,
      icon: SvgPicture.asset(
        'assets/svg/triangle-warning.svg',
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(warningColor, BlendMode.srcIn),
      ),
      richText: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${strings.passphrase_warning_title}\n',
              style: CoconutTypography.body2_14_Bold.setColor(warningColor),
            ),
            TextSpan(
              text: strings.passphrase_warning_description,
              style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinRecommendationEntrance() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final scaleAnimation = Tween<double>(
          begin: 0.88,
          end: 1,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));

        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: ScaleTransition(
            scale: scaleAnimation,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child:
          _isPinRecommendationVisible
              ? Column(
                key: const ValueKey('pin-recommendation'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_buildPinRecommendation(), CoconutLayout.spacing_600h],
              )
              : const SizedBox(key: ValueKey('pin-recommendation-hidden')),
    );
  }

  Widget _buildPinRecommendation() {
    final warningColor = context.coconutColors.warning;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.coconutColors.surfaceCard,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: warningColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: SvgPicture.asset(
                      'assets/svg/lock_simple.svg',
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(warningColor, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
              CoconutLayout.spacing_300w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: warningColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        t.wallet_home_screen.hot_wallet_create.recommended_badge,
                        style: CoconutTypography.body3_12_Bold.setColor(warningColor),
                      ),
                    ),
                    CoconutLayout.spacing_100h,
                    Text(
                      t.wallet_home_screen.hot_wallet_create.pin_recommendation_title,
                      style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          CoconutLayout.spacing_300h,
          Text(
            t.wallet_home_screen.hot_wallet_create.pin_recommendation_description,
            style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
          ),
          CoconutLayout.spacing_500h,
          ShrinkAnimationButton(
            onPressed: _showPinSettingScreen,
            defaultColor: context.coconutColors.actionButtonBackground,
            pressedColor: context.coconutColors.actionButtonPressed,
            borderRadius: 12,
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: Center(
                child: Text(
                  t.go_to_settings,
                  style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.actionButtonText),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearancePreview({required int colorIndex, required int iconIndex}) {
    final walletName = _nameController.text.trim().isEmpty ? _suggestedWalletName : _nameController.text.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.coconutColors.surfaceCard,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Row(
        children: [
          WalletIcon(
            walletImportSource: WalletImportSource.coconutVault,
            colorIndex: colorIndex,
            iconIndex: iconIndex,
            badgeSvgAssetPath: 'assets/svg/hot-wallet-fire.svg',
            badgeSize: 22,
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
                              itemCount: CustomIcons.totalCount,
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
                          defaultColor: context.coconutColors.actionButtonBackground,
                          pressedColor: context.coconutColors.actionButtonPressed,
                          borderRadius: CoconutStyles.radius_200,
                          child: SizedBox(
                            height: 52,
                            child: Center(
                              child: Text(
                                t.done,
                                style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.actionButtonText),
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

  Future<void> _showPinSettingScreen() async {
    _nameFocusNode.unfocus();
    FocusScope.of(context).requestFocus(_screenFocusNode);

    await CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      heightRatio: 0.9,
      child: const CustomLoadingOverlay(child: PinSettingScreen(useBiometrics: true, popParentOnComplete: false)),
    );

    if (mounted) {
      FocusScope.of(context).requestFocus(_screenFocusNode);
    }
  }

  void _onCreateWalletPressed() {
    // TODO: 입력한 이름이 없으면 _suggestedWalletName을 사용해 니모닉 생성 및 핫월렛 저장 플로우 연결
  }

  String _generateDefaultWalletName() {
    final random = Random.secure();
    final adjectives = t.wallet_home_screen.hot_wallet_create.default_names.adjectives;
    final nouns = t.wallet_home_screen.hot_wallet_create.default_names.nouns;
    return t.wallet_home_screen.hot_wallet_create.default_name(
      adjective: adjectives[random.nextInt(adjectives.length)],
      noun: nouns[random.nextInt(nouns.length)],
    );
  }
}
