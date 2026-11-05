import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
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
  late bool _isExcludedFromTotalAmount;

  @override
  void initState() {
    super.initState();
    _preferenceProvider = context.read<PreferenceProvider>();
    _isExcludedFromTotalAmount = _preferenceProvider.excludedFromTotalBalanceWalletIds.contains(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 80, left: 20, right: 20),
      child: Column(
        children: [
          _buildToggleWidget(
            t.wallet_list.settings.exclude_from_total_amount,
            t.wallet_list.settings.exclude_from_total_amount_description,
            _isExcludedFromTotalAmount,
            (bool value) {
              setState(() {
                _isExcludedFromTotalAmount = value;
              });
              List<int> prevExcludedIds = _preferenceProvider.excludedFromTotalBalanceWalletIds;
              if (value && !prevExcludedIds.contains(widget.id)) {
                _preferenceProvider.setExcludedFromTotalBalanceWalletIds([...prevExcludedIds, widget.id]);
              } else if (!value && prevExcludedIds.contains(widget.id)) {
                _preferenceProvider.removeExcludedFromTotalBalanceWalletId(widget.id);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleWidget(String title, String description, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText)),
              Text(
                description,
                style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                maxLines: 2,
                softWrap: true,
              ),
            ],
          ),
        ),
        CoconutLayout.spacing_200w,
        CoconutSwitch(
          isOn: value,
          activeTrackColor: context.coconutColors.switchActiveTrack,
          activeThumbColor: context.coconutColors.switchActiveThumb,
          inactiveTrackColor: context.coconutColors.switchInactiveTrack,
          inactiveThumbColor: context.coconutColors.switchInactiveThumb,
          scale: 0.8,
          onChanged: (bool newValue) {
            vibrateExtraLight();
            setState(() {
              onChanged(newValue);
            });
          },
        ),
      ],
    );
  }
}
