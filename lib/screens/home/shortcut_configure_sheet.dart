import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/cupertino.dart';

class ShortcutConfigureSheet extends StatefulWidget {
  final FeatureItem feature;
  final List<WalletItemBase> wallets;
  final ShortcutWalletContext current;
  final bool hasOtherWalletShortcuts;

  const ShortcutConfigureSheet({
    super.key,
    required this.feature,
    required this.wallets,
    required this.current,
    this.hasOtherWalletShortcuts = false,
  });

  @override
  State<ShortcutConfigureSheet> createState() => _ShortcutConfigureSheetState();
}

class _ShortcutConfigureSheetState extends State<ShortcutConfigureSheet> {
  late List<WalletItemBase> _supported = widget.wallets.where(widget.feature.supportsWallet).toList();
  late ShortcutWalletContext _selected =
      widget.current.mode == ShortcutWalletMode.wallet &&
              _supported.any((wallet) => wallet.id == widget.current.walletId)
          ? widget.current
          : const ShortcutWalletContext.askEveryTime();

  @override
  void didUpdateWidget(covariant ShortcutConfigureSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _supported = widget.wallets.where(widget.feature.supportsWallet).toList();
  }

  Widget _buildOption(String label, ShortcutWalletContext value, Key key) {
    final colors = context.coconutColors;
    final selected = value == _selected;
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
        child: Row(
          children: [
            Icon(
              selected ? CupertinoIcons.checkmark_square : CupertinoIcons.square,
              color: colors.primaryText,
              size: 24,
            ),
            CoconutLayout.spacing_300w,
            Expanded(child: Text(label, style: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final changesShared = widget.hasOtherWalletShortcuts && _selected != widget.current;
    return CoconutBottomSheet(
      useIntrinsicHeight: true,
      backgroundColor: colors.surfaceBottomSheet,
      bottomMargin: Sizes.size20,
      appBar: CoconutAppBar.build(
        isBottom: true,
        context: context,
        onBackPressed: () => Navigator.pop(context),
        title: t.home_edit.configure_shortcut,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sizes.size16, 0, Sizes.size16, Sizes.size16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.feature.label(),
                style: CoconutTypography.heading4_18_Bold.copyWith(color: colors.primaryText),
              ),
              CoconutLayout.spacing_200h,
              Text(
                t.home_edit.configure_shortcut_description,
                style: CoconutTypography.body2_14.copyWith(color: colors.secondaryText),
              ),
              CoconutLayout.spacing_600h,
              Text(t.home_edit.wallets, style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText)),
              CoconutLayout.spacing_200h,
              _buildOption(
                t.home_edit.ask_every_time,
                const ShortcutWalletContext.askEveryTime(),
                const Key('shortcut-configure-ask'),
              ),
              for (final wallet in _supported)
                _buildOption(
                  wallet.name,
                  ShortcutWalletContext.wallet(wallet.id),
                  ValueKey('shortcut-configure-wallet-${wallet.id}'),
                ),
              if (changesShared) ...[
                CoconutLayout.spacing_400h,
                Text(
                  t.home_edit.shared_wallet_notice,
                  key: const Key('shortcut-configure-shared-notice'),
                  style: CoconutTypography.body3_12.copyWith(color: colors.warning),
                ),
              ],
              CoconutLayout.spacing_800h,
              InlineActionButton(
                key: const Key('shortcut-configure-add'),
                onPressed: () => Navigator.pop(context, _selected),
                text: t.home_edit.add_to_home,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
