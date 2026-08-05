import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/core/bip/329/label_jsonl_manager.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class LabelExportWalletPickerScreen extends StatefulWidget {
  const LabelExportWalletPickerScreen({super.key});

  @override
  State<LabelExportWalletPickerScreen> createState() => _LabelExportWalletPickerScreenState();
}

class _LabelExportWalletPickerScreenState extends State<LabelExportWalletPickerScreen> {
  int? _selectedWalletId;
  bool _isExporting = false;
  bool _isWalletSelected = true;

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final wallets = walletProvider.walletItemList;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: context.coconutColors.background,
          appBar: CoconutAppBar.build(title: t.label_management_screen.export_title, context: context),
          body: _buildBody(context, wallets),
        ),
        if (_isExporting)
          Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
      ],
    );
  }

  Widget _buildBody(BuildContext context, List<WalletItemBase> wallets) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: <Widget>[
              _buildInfoTooltip(context),
              CoconutLayout.spacing_400h,
              _buildSegmentedControl(),
              if (_isWalletSelected) Expanded(child: _buildWalletListView(context, wallets)),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: FixedBottomButton(
            text: t.label_management_screen.export_title,
            isActive: _selectedWalletId != null,
            onButtonClicked: _onExportButtonPressed,
          ),
        ),
      ],
    );
  }

  Widget _buildWalletListView(BuildContext context, List<WalletItemBase> wallets) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 20, bottom: 90),
      itemCount: wallets.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _WalletListItemCard(
            title: t.all,
            subtitle: t.label_export_wallet_picker_screen.all_wallets,
            isSelected: _selectedWalletId == -1,
            onTap: () {
              setState(() {
                _selectedWalletId = _selectedWalletId == -1 ? null : -1;
              });
            },
          );
        }

        final wallet = wallets[index - 1];
        return _WalletListItemCard(
          title: wallet.name,
          subtitle: wallet.descriptor.split('#')[0],
          isSelected: _selectedWalletId == wallet.id,
          onTap: () {
            setState(() {
              _selectedWalletId = _selectedWalletId == wallet.id ? null : wallet.id;
            });
          },
        );
      },
    );
  }

  Widget _buildSegmentedControl() {
    return CoconutSegmentedControl(
      isSelected: [_isWalletSelected, !_isWalletSelected],
      onPressed: (index) {
        setState(() {
          _isWalletSelected = index == 0;
          _selectedWalletId = null;
        });
      },
      selectedColor: context.coconutColors.segmentedControlSelected,
      segmentedControlContainerColor: context.coconutColors.segmentedControlBackground,
      selectedTextColor: context.coconutColors.segmentedControlSelectedText,
      unselectedTextColor: context.coconutColors.segmentedControlUnselectedText,
      children: [
        Text(t.label_export_wallet_picker_screen.create_file),
        Text(t.label_export_wallet_picker_screen.view_list),
      ],
    );
  }

  Widget _buildInfoTooltip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: CoconutToolTip(
        backgroundColor: context.coconutColors.surface,
        borderColor: context.coconutColors.surface,
        icon: SvgPicture.asset(
          'assets/svg/circle-info.svg',
          width: 20,
          colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
        ),
        tooltipType: CoconutTooltipType.fixed,
        richText: RichText(
          text: TextSpan(
            style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
            children: [TextSpan(text: t.label_export_wallet_picker_screen.info_tooltip)],
          ),
        ),
      ),
    );
  }

  Future<void> _onExportButtonPressed() async {
    if (_selectedWalletId == null || _isExporting) return;

    setState(() => _isExporting = true);

    final walletProvider = context.read<WalletProvider>();
    final labelManager = LabelJsonLManager();

    try {
      final xFile =
          _selectedWalletId == -1
              ? await labelManager.createLabelsJsonLFileForAllWallets(walletProvider)
              : await labelManager.createLabelsJsonLFile(_selectedWalletId!, walletProvider);

      if (xFile != null) {
        await labelManager.shareFile(xFile);
      } else {
        if (mounted) {
          CoconutToast.showToast(context: context, text: 'a', level: CoconutToastLevel.info);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}

class _WalletListItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _WalletListItemCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: context.coconutColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? context.coconutColors.primaryText : Colors.transparent, width: 1),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              isSelected ? 'assets/svg/square_check.svg' : 'assets/svg/square.svg',
              width: 24,
              colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CoconutTypography.body1_16, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
