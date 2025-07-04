import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class WalletItemSettingBottomSheet extends StatefulWidget {
  const WalletItemSettingBottomSheet({super.key});

  @override
  State<WalletItemSettingBottomSheet> createState() => _WalletItemSettingBottomSheetState();
}

class _WalletItemSettingBottomSheetState extends State<WalletItemSettingBottomSheet> {
  late final WalletProvider _walletProvider;
  late final PreferenceProvider _preferenceProvider;
  late bool _isPrimaryWallet;
  late bool _isExcludedFromTotalAmount;

  @override
  void initState() {
    super.initState();
    _preferenceProvider = context.read<PreferenceProvider>();
    _walletProvider = Provider.of<WalletProvider>(context, listen: false);
    _isPrimaryWallet = false;
    _isExcludedFromTotalAmount = false;
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
            t.wallet_list.settings.primary_wallet_description,
            _isPrimaryWallet,
            (bool value) {
              setState(() {
                _isPrimaryWallet = value;
              });
            },
          ),
          CoconutLayout.spacing_400h,
          const Divider(color: CoconutColors.gray700, height: 1),
          CoconutLayout.spacing_400h,
          _buildToggleWidget(
              t.wallet_list.settings.exclude_from_total_amount,
              t.wallet_list.settings.exclude_from_total_amount_description,
              _isExcludedFromTotalAmount, (bool value) {
            setState(() {
              _isExcludedFromTotalAmount = value;
            });
          })
        ],
      ),
    );
  }

  Widget _buildToggleWidget(
      String title, String description, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: CoconutTypography.body3_12),
            Text(
              description,
              style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
            ),
          ],
        ),
        CupertinoSwitch(
          activeColor: CoconutColors.gray100,
          trackColor: CoconutColors.gray600,
          thumbColor: value ? CoconutColors.black : CoconutColors.gray500,
          value: value,
          onChanged: (bool newValue) {
            setState(() {
              onChanged(newValue);
            });
          },
        ),
      ],
    );
  }
}
