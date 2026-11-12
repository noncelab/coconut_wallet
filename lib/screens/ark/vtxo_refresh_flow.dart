import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/widgets/features/ark/ark_texts.dart';
import 'package:coconut_wallet/widgets/features/ark/ark_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Asks to refresh [ids] with the fee bark estimates, then hands them to the Ark server's next
/// round (delegated). Returns whether the refresh was scheduled; failures are shown as a toast.
Future<bool> refreshVtxosWithConfirmation(
  BuildContext context, {
  required int walletId,
  required List<String> ids,
  required BitcoinUnit unit,
  VoidCallback? onRefreshStarted,
  VoidCallback? onRefreshFinished,
}) async {
  if (ids.isEmpty) return false;
  final arkProvider = context.read<ArkProvider>();
  void toast(String text) => CoconutToast.showBottomToast(context: context, text: text);
  try {
    final fee = await arkProvider.estimateRefreshFee(walletId, ids);
    if (!context.mounted) return false;
    final confirmed = await confirmArkAction(
      context,
      title: ids.length == 1 ? t.ark.vtxo.refresh_one : t.ark.vtxo.refresh_title(count: ids.length),
      description: t.ark.vtxo.refresh_description(fee: formatSats(unit, fee)),
    );
    if (!confirmed || !context.mounted) return false;
    onRefreshStarted?.call();
    try {
      await arkProvider.refreshDelegated(walletId, ids);
    } finally {
      onRefreshFinished?.call();
    }
    if (context.mounted) toast(t.ark.vtxo.refresh_scheduled);
    return true;
  } catch (error) {
    if (context.mounted) toast(t.ark.vtxo.refresh_failed(error: '$error'));
    return false;
  }
}
