import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class HomeAddWalletOptionBottomSheet extends StatefulWidget {
  const HomeAddWalletOptionBottomSheet({super.key, required this.initialOption});

  final HomeAddWalletOption initialOption;

  @override
  State<HomeAddWalletOptionBottomSheet> createState() => _HomeAddWalletOptionBottomSheetState();
}

class _HomeAddWalletOptionBottomSheetState extends State<HomeAddWalletOptionBottomSheet> {
  static const int _previewSatoshiAmount = 1234567890;

  late HomeAddWalletOption _selectedOption;
  late final String _previewFiatAmount;

  @override
  void initState() {
    super.initState();
    _selectedOption = widget.initialOption;
    _previewFiatAmount = context.read<PriceProvider>().getFiatPrice(_previewSatoshiAmount);
  }

  @override
  Widget build(BuildContext context) {
    return CoconutBottomSheet(
      useIntrinsicHeight: true,
      backgroundColor: context.coconutColors.surfaceBottomSheet,
      bottomMargin: Sizes.size20,
      appBar: CoconutAppBar.build(
        isBottom: true,
        context: context,
        onBackPressed: () => Navigator.pop(context),
        title: t.wallet_home_screen.edit.home_add_wallet_button.sheet_title,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sizes.size16, 0, Sizes.size16, Sizes.size16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HomeScreenPreview(option: _selectedOption, fiatAmount: _previewFiatAmount),
              CoconutLayout.spacing_600h,
              Row(
                children: [
                  for (final option in const [
                    HomeAddWalletOption.all,
                    HomeAddWalletOption.watchOnly,
                    HomeAddWalletOption.hotWallet,
                    HomeAddWalletOption.hidden,
                  ]) ...[
                    Expanded(
                      child: _HomeAddWalletOptionButton(
                        option: option,
                        isSelected: option == _selectedOption,
                        label: _getTitle(option),
                        onPressed: () => setState(() => _selectedOption = option),
                      ),
                    ),
                    if (option != HomeAddWalletOption.hidden) CoconutLayout.spacing_200w,
                  ],
                ],
              ),
              CoconutLayout.spacing_800h,
              InlineActionButton(
                onPressed: () => Navigator.pop(context, _selectedOption),
                text: t.done,
                isActive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTitle(HomeAddWalletOption option) {
    switch (option) {
      case HomeAddWalletOption.all:
        return t.wallet_home_screen.edit.home_add_wallet_button.all.title;
      case HomeAddWalletOption.watchOnly:
        return t.wallet_home_screen.edit.home_add_wallet_button.watch_only.title;
      case HomeAddWalletOption.hotWallet:
        return t.wallet_home_screen.edit.home_add_wallet_button.hot_wallet.title;
      case HomeAddWalletOption.hidden:
        return t.wallet_home_screen.edit.home_add_wallet_button.hidden.title;
    }
  }
}

class _HomeScreenPreview extends StatelessWidget {
  const _HomeScreenPreview({required this.option, required this.fiatAmount});

  final HomeAddWalletOption option;
  final String fiatAmount;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(Sizes.size20),
      decoration: BoxDecoration(color: context.coconutColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.wallet_home_screen.edit.home_add_wallet_button.preview,
                  style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: RichText(text: _buildPreviewTitleSpan(context)),
              ),
            ],
          ),
          CoconutLayout.spacing_200h,
          Container(
            height: 96,
            padding: const EdgeInsets.fromLTRB(Sizes.size16, Sizes.size18, Sizes.size12, Sizes.size12),
            decoration: BoxDecoration(
              color: context.coconutColors.homeBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.coconutColors.divider),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  child: Row(
                    children: [
                      if (_iconPath != null) ...[
                        SvgPicture.asset(
                          _iconPath!,
                          width: 18,
                          height: 18,
                          fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                        ),
                        CoconutLayout.spacing_300w,
                      ],
                      CoconutLayout.spacing_300w,
                      SvgPicture.asset(
                        CommonMenuIconPath.kebab,
                        width: 16,
                        height: 16,
                        colorFilter: ColorFilter.mode(context.coconutColors.tertiaryText, BlendMode.srcIn),
                      ),
                      CoconutLayout.spacing_500w,
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  right: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fiatAmount,
                        style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.tertiaryText),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '12.3456 7890 BTC',
                              style: CoconutTypography.body1_16_NumberBold.setColor(context.coconutColors.tertiaryText),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.coconutColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              t.hide,
                              style: CoconutTypography.caption_10.setColor(context.coconutColors.tertiaryText),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _previewTitle {
    switch (option) {
      case HomeAddWalletOption.all:
        return t.wallet_home_screen.edit.home_add_wallet_button.preview_all;
      case HomeAddWalletOption.watchOnly:
        return t.wallet_home_screen.edit.home_add_wallet_button.preview_watch_only;
      case HomeAddWalletOption.hotWallet:
        return t.wallet_home_screen.edit.home_add_wallet_button.preview_hot_wallet;
      case HomeAddWalletOption.hidden:
        return t.wallet_home_screen.edit.home_add_wallet_button.preview_hidden;
    }
  }

  TextSpan _buildPreviewTitleSpan(BuildContext context) {
    final normalStyle = CoconutTypography.body3_12.setColor(context.coconutColors.primaryText);
    final emphasizedText = switch (option) {
      HomeAddWalletOption.all => t.wallet_home_screen.edit.home_add_wallet_button.preview_all_emphasis,
      HomeAddWalletOption.watchOnly => t.wallet_home_screen.edit.home_add_wallet_button.watch_only.title,
      HomeAddWalletOption.hotWallet => t.wallet_home_screen.edit.home_add_wallet_button.hot_wallet.title,
      HomeAddWalletOption.hidden => t.wallet_home_screen.edit.home_add_wallet_button.preview_hidden_emphasis,
    };
    final emphasizedStart = _previewTitle.toLowerCase().indexOf(emphasizedText.toLowerCase());
    if (emphasizedStart == -1) {
      return TextSpan(text: _previewTitle, style: normalStyle);
    }
    final emphasizedEnd = emphasizedStart + emphasizedText.length;

    return TextSpan(
      style: normalStyle,
      children: [
        if (emphasizedStart > 0) TextSpan(text: _previewTitle.substring(0, emphasizedStart)),
        TextSpan(
          text: _previewTitle.substring(emphasizedStart, emphasizedEnd),
          style: CoconutTypography.body3_12_Bold.setColor(context.coconutColors.primaryText),
        ),
        if (emphasizedEnd < _previewTitle.length) TextSpan(text: _previewTitle.substring(emphasizedEnd)),
      ],
    );
  }

  String? get _iconPath {
    switch (option) {
      case HomeAddWalletOption.all:
        return FeatureWalletIconPath.walletAddDefault;
      case HomeAddWalletOption.watchOnly:
        return FeatureWalletIconPath.walletEyes;
      case HomeAddWalletOption.hotWallet:
        return FeatureWalletIconPath.walletAddHot;
      case HomeAddWalletOption.hidden:
        return null;
    }
  }
}

class _HomeAddWalletOptionButton extends StatelessWidget {
  const _HomeAddWalletOptionButton({
    required this.option,
    required this.isSelected,
    required this.label,
    required this.onPressed,
  });

  final HomeAddWalletOption option;
  final bool isSelected;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isHiddenOption = option == HomeAddWalletOption.hidden;
    final iconWidth = isHiddenOption ? (isSelected ? 32.0 : 20.0) : (isSelected ? 34.0 : 22.0);
    final iconHeight = isHiddenOption ? (isSelected ? 32.0 : 20.0) : (isSelected ? 27.0 : 19.0);

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: AspectRatio(
        aspectRatio: 1,
        child: ShrinkAnimationButton(
          onPressed: onPressed,
          defaultColor: Colors.transparent,
          pressedColor: context.coconutColors.surfacePressOverlay,
          borderRadius: 16,
          animationEndValue: 0.94,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.coconutColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? context.coconutColors.primaryText : context.coconutColors.divider,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: iconWidth,
              height: iconHeight,
              child: SvgPicture.asset(
                _iconPath,
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(
                  isSelected ? context.coconutColors.iconPrimary : context.coconutColors.iconSecondary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _iconPath {
    switch (option) {
      case HomeAddWalletOption.all:
        return FeatureWalletIconPath.walletAddDefault;
      case HomeAddWalletOption.watchOnly:
        return FeatureWalletIconPath.walletEyes;
      case HomeAddWalletOption.hotWallet:
        return FeatureWalletIconPath.walletAddHot;
      case HomeAddWalletOption.hidden:
        return CommonVisibilityIconPath.eyeCrossed;
    }
  }
}
