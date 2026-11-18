import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutToast, CoconutToastLevel;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_vtxo.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_row.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 갱신 확인. 금액과 수수료를 보여 주고 확인해야 갱신(한 번 누르기로 바로 갱신하지 않음)
Future<void> showArkRenewSheet(BuildContext context, List<ArkVtxo> vtxos) {
  final wallet = context.read<ArkWalletProvider>();
  return CommonBottomSheets.showBottomSheet<void>(
    context: context,
    title: t.ark_wallet.renew_sheet_title,
    screenName: AnalyticsScreenNames.ccosArkWalletRenew,
    showDragHandle: true,
    child: ChangeNotifierProvider.value(value: wallet, child: _ArkRenewSheet(vtxos: vtxos)),
  );
}

class _ArkRenewSheet extends StatefulWidget {
  const _ArkRenewSheet({required this.vtxos});

  final List<ArkVtxo> vtxos;

  @override
  State<_ArkRenewSheet> createState() => _ArkRenewSheetState();
}

class _ArkRenewSheetState extends State<_ArkRenewSheet> {
  late final List<String> _ids = [for (final vtxo in widget.vtxos) vtxo.id];
  int? _fee;
  bool _feeFailed = false;
  bool _renewing = false;

  @override
  void initState() {
    super.initState();
    context
        .read<ArkWalletProvider>()
        .estimateRenewFee(_ids)
        .then((fee) {
          if (mounted) setState(() => _fee = fee);
        })
        .catchError((Object error) {
          Logger.error('ArkRenewSheet: fee estimate failed: $error');
          if (mounted) setState(() => _feeFailed = true);
        });
  }

  Future<void> _renew() async {
    setState(() => _renewing = true);
    try {
      await context.read<ArkWalletProvider>().renew(_ids);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      Logger.error('ArkRenewSheet: renew failed: $error');
      if (!mounted) return;
      setState(() => _renewing = false);
      CoconutToast.showToast(
        context: context,
        isVisibleIcon: true,
        iconPath: CommonStateIconPath.triangleWarning,
        text: t.ark_wallet.renew_failed,
        level: CoconutToastLevel.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final unit = context.select<PreferenceProvider, BitcoinUnit>((preferences) => preferences.currentUnit);
    final amount = widget.vtxos.fold(0, (sum, vtxo) => sum + vtxo.amountSats);
    final fee = _fee;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.ark_wallet.renew_sheet_line, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
          CoconutLayout.spacing_300h,
          ArkInfoRow(
            label: t.ark_wallet.renew_amount,
            value: unit.displayBitcoinAmount(amount, withUnit: true),
            isNumber: true,
          ),
          ArkInfoRow(
            label: t.fee,
            value:
                _feeFailed
                    ? t.ark_wallet.problem_fee
                    : fee == null
                    ? '…'
                    : fee == 0
                    ? t.ark_wallet.fee_free
                    : unit.displayBitcoinAmount(fee, withUnit: true),
            isNumber: fee != null && fee != 0,
            valueColor: _feeFailed ? colors.danger : null,
          ),
          CoconutLayout.spacing_500h,
          CoconutButton(
            key: const Key('ark-renew-confirm'),
            text: t.ark_wallet.renew_button,
            isActive: fee != null && !_renewing,
            onPressed: _renew,
            backgroundColor: colors.primaryText,
            foregroundColor: colors.background,
          ),
        ],
      ),
    );
  }
}
