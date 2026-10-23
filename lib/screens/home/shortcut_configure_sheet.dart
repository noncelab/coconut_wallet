import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/widgets/features/home/configure/home_configure_parts.dart';
import 'package:flutter/cupertino.dart';

class ShortcutConfigureSheet extends StatefulWidget {
  final FeatureItem feature;
  final List<WalletItemBase> wallets;
  final ShortcutWalletContext current;
  final bool isNew;

  const ShortcutConfigureSheet({
    super.key,
    required this.feature,
    required this.wallets,
    required this.current,
    this.isNew = true,
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

  @override
  Widget build(BuildContext context) {
    final options = [
      (t.home_edit.ask_every_time, const ShortcutWalletContext.askEveryTime(), const Key('shortcut-configure-ask')),
      for (final wallet in _supported)
        (wallet.name, ShortcutWalletContext.wallet(wallet.id), ValueKey('shortcut-configure-wallet-${wallet.id}')),
    ];
    return HomeConfigureSheetLayout(
      title: t.home_edit.configure_shortcut,
      heading: widget.feature.label(),
      description: t.home_edit.configure_shortcut_description,
      buttonText: widget.isNew ? t.home_edit.add_to_home : t.home_edit.save_changes,
      buttonKey: const Key('shortcut-configure-add'),
      onSubmit: () => Navigator.pop(context, _selected),
      children: [
        HomeConfigureSectionTitle(t.home_edit.wallets),
        for (final (index, (label, value, key)) in options.indexed)
          HomeConfigureCheckRow(
            key: key,
            label: label,
            checked: value == _selected,
            showDivider: index < options.length - 1,
            onTap: () => setState(() => _selected = value),
          ),
      ],
    );
  }
}
