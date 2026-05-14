import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SelectedUtxoAmountHeader extends StatelessWidget {
  final GlobalKey orderDropdownButtonKey;
  final String orderText;
  final int selectedUtxoCount;
  final int selectedUtxoAmountSum;
  final BitcoinUnit currentUnit;
  final VoidCallback onSelectAll;
  final VoidCallback onUnselectAll;
  final VoidCallback onToggleOrderDropdown;

  const SelectedUtxoAmountHeader({
    super.key,
    required this.orderDropdownButtonKey,
    required this.orderText,
    required this.selectedUtxoCount,
    required this.selectedUtxoAmountSum,
    required this.currentUnit,
    required this.onSelectAll,
    required this.onUnselectAll,
    required this.onToggleOrderDropdown,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    String utxoSumText = currentUnit.displayBitcoinAmount(
      selectedUtxoAmountSum,
      defaultWhenZero: '0',
      shouldCheckZero: true,
    );
    String unitText = currentUnit.symbol;

    return Container(
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _buildTotalRow(context, utxoSumText, unitText),
          const SizedBox(height: 25),
          _buildActionRow(context),
        ],
      ),
    );
  }

  Widget _buildTotalRow(BuildContext context, String utxoSumText, String unitText) {
    final colors = context.coconutColors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: colors.surfaceCard, borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Text(t.utxo_total, style: CoconutTypography.body2_14.setColor(colors.primaryText)),
                  CoconutLayout.spacing_100w,
                  Visibility(
                    visible: selectedUtxoCount != 0,
                    child: Text(
                      t.utxo_count(count: selectedUtxoCount),
                      style: CoconutTypography.caption_10_Number.setColor(colors.secondaryText),
                    ),
                  ),
                ],
              ),
            ),
          ),
          CoconutLayout.spacing_200w,
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      currentUnit.isPrefixSymbol ? CrossAxisAlignment.center : CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (currentUnit.isPrefixSymbol)
                      Text(unitText, style: CoconutTypography.body1_16_Number.setColor(colors.primaryText)),
                    Text(utxoSumText, style: CoconutTypography.body1_16_NumberBold.setColor(colors.primaryText)),
                    if (!currentUnit.isPrefixSymbol) ...[
                      CoconutLayout.spacing_50w,
                      Text(unitText, style: CoconutTypography.body1_16_Number.setColor(colors.primaryText)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    final colors = context.coconutColors;
    return Row(
      children: [
        CupertinoButton(
          key: orderDropdownButtonKey,
          onPressed: onToggleOrderDropdown,
          minSize: 0,
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(orderText, style: CoconutTypography.caption_10.setColor(colors.primaryText)),
              const SizedBox(width: 4),
              SvgPicture.asset(
                'assets/svg/arrow-down.svg',
                colorFilter: ColorFilter.mode(colors.iconDefault, BlendMode.srcIn),
              ),
            ],
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 16),
                  CustomUnderlinedButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    text: t.unselect_all,
                    isEnable: true,
                    onTap: onUnselectAll,
                  ),
                  SvgPicture.asset(
                    'assets/svg/row-divider.svg',
                    colorFilter: ColorFilter.mode(colors.iconDefault, BlendMode.srcIn),
                  ),
                  CustomUnderlinedButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    text: t.select_all,
                    isEnable: true,
                    onTap: onSelectAll,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
