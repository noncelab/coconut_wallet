import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_actions.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_screen.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 지갑 추가 방법의 제목, 설명, 선택지 묶음. 지갑 추가 화면과 지갑이 없을 때의 내 지갑 화면이 함께 쓴다.
class WalletAddOptions extends StatelessWidget {
  final bool showsWatchOnly;
  final bool showsHot;

  const WalletAddOptions({super.key, this.showsWatchOnly = true, this.showsHot = true});

  void _openSources(BuildContext context, String title, List<WalletAddSourceSection> sections) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        settings: const RouteSettings(name: WalletAddScreen.sourcesRouteName),
        builder: (_) => WalletAddSourcesScreen(title: title, sections: sections),
      ),
    );
  }

  static Widget _icon(BuildContext context, String asset) => SvgPicture.asset(
    asset,
    width: 22,
    height: 22,
    colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
  );

  Future<void> _openHotWallet(BuildContext context, {required bool restore}) async {
    if (!await WalletAddActions.prepareHotWallet(context, restore: restore) || !context.mounted) return;
    Navigator.of(context).pushNamed(WalletAddActions.hotWalletRoute(restore: restore));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final copy = t.wallet_add_screen;
    final watchOnlyTitle = t.feature_registry.wallet_add_watch_only;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          TextUtils.preventLineBreakInsideWords(copy.title),
          style: CoconutTypography.heading3_21_Bold.copyWith(color: colors.primaryText),
        ),
        const SizedBox(height: 4),
        Text(
          TextUtils.preventLineBreakInsideWords(copy.subtitle),
          style: CoconutTypography.body2_14.copyWith(color: colors.secondaryText),
        ),
        CoconutLayout.spacing_600h,
        if (showsWatchOnly)
          _OptionGroup(
            iconPath: FeatureWalletIconPath.walletAddWatchOnly,
            title: watchOnlyTitle,
            description: copy.watch_only_description,
            onHeaderPressed:
                () => _openSources(context, watchOnlyTitle, [
                  (title: copy.air_gapped, sources: WalletAddActions.airGappedSources),
                  (title: copy.connected, sources: WalletAddActions.connectedSources),
                ]),
            options: [
              _Option(
                key: const Key('wallet-add-air-gapped'),
                icon: _icon(context, FeatureWalletIconPath.walletAddAirGapped),
                title: copy.air_gapped,
                onPressed:
                    () => _openSources(context, copy.air_gapped, [
                      (title: null, sources: WalletAddActions.airGappedSources),
                    ]),
              ),
              _Option(
                key: const Key('wallet-add-connected'),
                icon: _icon(context, FeatureWalletIconPath.walletAddConnected),
                title: copy.connected,
                onPressed:
                    () => _openSources(context, copy.connected, [
                      (title: null, sources: WalletAddActions.connectedSources),
                    ]),
              ),
            ],
          ),
        if (showsWatchOnly && showsHot) CoconutLayout.spacing_400h,
        if (showsHot)
          _OptionGroup(
            iconPath: FeatureWalletIconPath.walletAddHot,
            title: t.feature_registry.wallet_add_hot,
            description: copy.hot_description,
            options: [
              _Option(
                key: const Key('wallet-add-hot-create'),
                icon: _icon(context, FeatureWalletIconPath.walletAddCreate),
                title: t.wallet_home_screen.hot_wallet_add.create.title,
                showChevron: true,
                onPressed: () => _openHotWallet(context, restore: false),
              ),
              _Option(
                key: const Key('wallet-add-hot-restore'),
                icon: _icon(context, FeatureWalletIconPath.walletAddImport),
                title: t.wallet_home_screen.hot_wallet_add.restore.title,
                showChevron: true,
                onPressed: () => _openHotWallet(context, restore: true),
              ),
            ],
          ),
      ],
    );
  }
}

class _OptionGroup extends StatelessWidget {
  final String iconPath;
  final String title;
  final String description;
  final VoidCallback? onHeaderPressed;
  final List<Widget> options;

  const _OptionGroup({
    required this.iconPath,
    required this.title,
    required this.description,
    required this.options,
    this.onHeaderPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            iconPath,
            width: 26,
            height: 26,
            colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
          ),
          CoconutLayout.spacing_300w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText)),
                const SizedBox(height: 2),
                Text(
                  TextUtils.preventLineBreakInsideWords(description),
                  style: CoconutTypography.body3_12.copyWith(color: colors.primaryText),
                ),
              ],
            ),
          ),
          if (onHeaderPressed != null) Icon(CupertinoIcons.chevron_right, size: 18, color: colors.primaryText),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onHeaderPressed == null)
            header
          else
            GestureDetector(behavior: HitTestBehavior.opaque, onTap: onHeaderPressed, child: header),
          for (final (index, option) in options.indexed) ...[if (index > 0) CoconutLayout.spacing_300h, option],
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final Widget icon;
  final String title;
  final bool showChevron;
  final VoidCallback onPressed;

  const _Option({
    super.key,
    required this.icon,
    required this.title,
    required this.onPressed,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      defaultColor: colors.homeBackground,
      pressedOverlayColor: colors.homeSurfacePressOverlay,
      pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
      borderRadius: 14,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SizedBox.square(dimension: 24, child: Center(child: icon)),
            CoconutLayout.spacing_400w,
            Expanded(child: Text(title, style: CoconutTypography.body1_16.copyWith(color: colors.primaryText))),
            if (showChevron) Icon(CupertinoIcons.chevron_right, size: 16, color: colors.primaryText),
          ],
        ),
      ),
    );
  }
}
