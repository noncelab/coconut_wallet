import 'package:coconut_wallet/utils/logger.dart';
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
  ValueChanged<int>? onConfirmed,
  ValueChanged<Object>? onFailed,
  bool showsToast = true,
}) async {
  final arkProvider = context.read<ArkProvider>();
  ids = arkProvider.withoutRefreshing(ids);
  if (ids.isEmpty) {
    CoconutToast.showToast(context: context, text: t.ark.vtxo.already_refreshing);
    return false;
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  void toast(String text) {
    final overlay = navigator.overlay;
    if (!navigator.mounted || overlay == null) return;
    CoconutToast.showToast(context: navigator.context, overlay: overlay, text: text);
  }

  try {
    final fee = await arkProvider.estimateRefreshFee(walletId, ids);
    if (!context.mounted) return false;
    final confirmed = await confirmArkAction(
      context,
      title: ids.length == 1 ? t.ark.vtxo.refresh_one : t.ark.vtxo.refresh_title(count: ids.length),
      description: t.ark.vtxo.refresh_description(fee: formatSats(unit, fee)),
    );
    if (!confirmed || !context.mounted) return false;
    onConfirmed?.call(fee);
    onRefreshStarted?.call();
    try {
      await arkProvider.refreshDelegated(walletId, ids);
    } finally {
      onRefreshFinished?.call();
    }
    if (showsToast) toast(t.ark.vtxo.refresh_scheduled);
    return true;
  } catch (error) {
    Logger.error('VTXO refresh failed: $error');
    onFailed?.call(error);
    if (showsToast) toast(t.ark.vtxo.refresh_failed);
    return false;
  }
}
