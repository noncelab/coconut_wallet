import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WalletItemSettingBottomSheet extends StatefulWidget {
  final int id;

  const WalletItemSettingBottomSheet({super.key, required this.id});

  @override
  State<WalletItemSettingBottomSheet> createState() => _WalletItemSettingBottomSheetState();
}

class _WalletItemSettingBottomSheetState extends State<WalletItemSettingBottomSheet> {
  late final PreferenceProvider _preferenceProvider;
  late bool _isPrimaryWallet;
  late bool _isExcludedFromTotalAmount;

  final GlobalKey<CoconutShakeAnimationState> _primaryWalletShakeKey =
      GlobalKey<CoconutShakeAnimationState>();

  @override
  void initState() {
    super.initState();
    _preferenceProvider = context.read<PreferenceProvider>();
    _isPrimaryWallet = _preferenceProvider.walletOrder.first == widget.id;
    _isExcludedFromTotalAmount =
        _preferenceProvider.excludedFromTotalBalanceWalletIds.contains(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 80, left: 20, right: 20),
      child: Column(
        children: [
          _buildToggleWidget(
            t.wallet_list.settings.primary_wallet,
            _isPrimaryWallet
                ? t.wallet_list.settings.primary_wallet_abled_description
                : t.wallet_list.settings.primary_wallet_disabled_description,
            _isPrimaryWallet,
            true,
            (bool value) {
              if (!value) {
                _primaryWalletShakeKey.currentState?.shake();
                return;
              }
              setState(() {
                _isPrimaryWallet = value;
              });
              final updatedOrder = [
                widget.id,
                ..._preferenceProvider.walletOrder.where((id) => id != widget.id),
              ];
              _preferenceProvider.setWalletOrder(updatedOrder);
            },
          ),
          CoconutLayout.spacing_400h,
          const Divider(color: CoconutColors.gray700, height: 1),
          CoconutLayout.spacing_400h,
          _buildToggleWidget(
            t.wallet_list.settings.exclude_from_total_amount,
            t.wallet_list.settings.exclude_from_total_amount_description,
            _isExcludedFromTotalAmount,
            false,
            (bool value) {
              setState(() {
                _isExcludedFromTotalAmount = value;
              });
              List<int> prevExcludedIds = _preferenceProvider.excludedFromTotalBalanceWalletIds;
              if (value && !prevExcludedIds.contains(widget.id)) {
                _preferenceProvider
                    .setExcludedFromTotalBalanceWalletIds([...prevExcludedIds, widget.id]);
              } else if (!value && prevExcludedIds.contains(widget.id)) {
                _preferenceProvider.removeExcludedFromTotalBalanceWalletId(widget.id);
              }
            },
          )
        ],
      ),
    );
  }

  Widget _buildToggleWidget(
    String title,
    String description,
    bool value,
    bool shouldHideWhenOn,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: CoconutTypography.body2_14),
              Text(
                description,
                style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                maxLines: 2,
                softWrap: true,
              ),
            ],
          ),
        ),
        CoconutLayout.spacing_200w,
        Visibility(
          visible: shouldHideWhenOn ? !value : true,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: CoconutSwitch(
            isOn: value,
            activeColor: CoconutColors.gray100,
            thumbColor: value ? CoconutColors.black : CoconutColors.gray500,
            trackColor: CoconutColors.gray600,
            scale: 0.8,
            onChanged: (bool newValue) {
              setState(() {
                onChanged(newValue);
              });
            },
          ),
        ),
      ],
    );
  }
}
