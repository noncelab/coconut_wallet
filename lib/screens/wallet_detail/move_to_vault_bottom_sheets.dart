import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutPopup;
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_dialog.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/text/icon_title_description.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/send/select_wallet_bottom_sheet.dart';
import 'package:flutter/material.dart';

import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';

enum MoveToVaultDestination { noBalance, noWatchOnlyWallet, selectWatchOnlyWallet }

MoveToVaultDestination resolveMoveToVaultDestination(int balance, int watchOnlyWalletCount) {
  if (balance <= 0) return MoveToVaultDestination.noBalance;
  if (watchOnlyWalletCount == 0) return MoveToVaultDestination.noWatchOnlyWallet;
  return MoveToVaultDestination.selectWatchOnlyWallet;
}

/// 동기화 전의 빈 거래 목록을 미사용 지갑으로 판단하지 않는다.
bool isVaultSelectionSyncComplete(WalletUpdateInfo? info, NodeSyncState nodeState) =>
    nodeState != NodeSyncState.failed &&
    info != null &&
    info.subscription == WalletSyncState.completed &&
    info.balance == WalletSyncState.completed &&
    info.transaction == WalletSyncState.completed &&
    info.utxo == WalletSyncState.completed;

class ShowVaultNoBalanceBottomSheet extends StatelessWidget {
  final int walletId;
  const ShowVaultNoBalanceBottomSheet({super.key, required this.walletId});

  @override
  Widget build(BuildContext context) {
    return _VaultGuide(
      nextStep: IconTitleDescription(
        svgIconPath: CommonStateIconPath.circleWarning,
        iconColor: context.coconutColors.iconSecondary,
        title: t.wallet_detail_screen.vault_no_balance_title,
        description: t.wallet_detail_screen.vault_no_balance_description,
      ),
      action: InlineActionButton(
        onPressed: () async {
          final navigator = Navigator.of(context);
          final sheetRoute = ModalRoute.of(context);
          navigator.pop();
          await sheetRoute?.completed;
          if (!navigator.mounted) return;
          navigator.pushNamed(AppRouteNames.receiveAddress, arguments: ReceiveAddressRouteArgs(id: walletId));
        },
        text: t.receive,
      ),
    );
  }
}

class ShowVaultNoWatchOnlyWalletBottomSheet extends StatelessWidget {
  final int walletId;
  const ShowVaultNoWatchOnlyWalletBottomSheet({super.key, required this.walletId});

  @override
  Widget build(BuildContext context) {
    return _VaultGuide(
      nextStep: IconTitleDescription(
        svgIconPath: FeatureWalletIconPath.walletEyes,
        iconColor: context.coconutColors.iconSecondary,
        title: t.wallet_detail_screen.vault_watch_only_title,
        description: t.wallet_detail_screen.vault_watch_only_description,
      ),
      action: InlineActionButton(
        onPressed: () async {
          final navigator = Navigator.of(context);
          final sheetRoute = ModalRoute.of(context);
          navigator.pop();
          await sheetRoute?.completed;
          if (!navigator.mounted) return;
          WalletAddDialog.showBottomSheet(
            navigator.context,
            WalletAddDialogMode.watchOnlySource,
            replaceCurrentRouteOnWalletSelected: true,
          );
        },
        text: t.wallet_detail_screen.vault_connect_watch_only_wallet,
      ),
    );
  }
}

class _VaultGuide extends StatelessWidget {
  const _VaultGuide({required this.nextStep, required this.action});

  final IconTitleDescription nextStep;
  final InlineActionButton action;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                IconTitleDescription(
                  svgIconPath: CommonStateIconPath.bulb,
                  title: t.wallet_detail_screen.vault_intro,
                  description: t.wallet_detail_screen.vault_description,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Divider(height: 1, color: context.coconutColors.divider),
                ),
                nextStep,
              ],
            ),
          ),
        ),
        CoconutLayout.spacing_800h,
        action,
      ],
    );
  }
}

class ShowVaultSelectWalletBottomSheet extends StatefulWidget {
  final int walletId;
  final List<WalletItemBase> watchOnlyWallets;
  const ShowVaultSelectWalletBottomSheet({super.key, required this.walletId, required this.watchOnlyWallets});

  @override
  State<ShowVaultSelectWalletBottomSheet> createState() => _ShowVaultSelectWalletBottomSheetState();
}

class _ShowVaultSelectWalletBottomSheetState extends State<ShowVaultSelectWalletBottomSheet> {
  bool _isSelecting = false;

  bool _isSynced(int id) {
    final state = context.read<NodeProvider>().state;
    return isVaultSelectionSyncComplete(state.registeredWallets[id], state.nodeSyncState);
  }

  Future<void> _showSyncRequired() => showDialog<void>(
    context: context,
    builder:
        (dialogContext) => CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.wallet_detail_screen.vault_sync_required_title,
          description: t.wallet_detail_screen.vault_sync_required_description,
          rightButtonText: t.OK,
          onTapRight: () => Navigator.pop(dialogContext),
        ),
  );

  Future<void> _selectWallet(int id) async {
    if (_isSelecting) return;
    setState(() => _isSelecting = true);
    try {
      if (!_isSynced(id)) {
        await _showSyncRequired();
        return;
      }
      final hasHistory = context.read<TransactionRepository>().hasTransactionHistory(id);
      if (!hasHistory) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => CoconutPopup(
                languageCode: context.read<PreferenceProvider>().language,
                title: t.wallet_detail_screen.vault_unused_title,
                description: t.wallet_detail_screen.vault_unused_description,
                leftButtonText: t.cancel,
                rightButtonText: t.wallet_detail_screen.vault_unused_continue,
                onTapLeft: () => Navigator.pop(dialogContext, false),
                onTapRight: () => Navigator.pop(dialogContext, true),
              ),
        );
        if (!mounted || confirmed != true) return;
      }
      if (!mounted) return;
      // 팝업 표시 중 재동기화·지갑 삭제·핫월렛 전환이 발생한 경우 진행하지 않는다.
      final wallets = context.read<WalletProvider>().walletItemList;
      if (!wallets.any((wallet) => wallet.id == id && !wallet.hasLocalKey)) return;
      if (!_isSynced(id)) {
        await _showSyncRequired();
        return;
      }
      Navigator.of(context).pop(id);
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletIds = context.read<WalletProvider>().walletItemList.map((wallet) => wallet.id).toSet();
    return SelectWalletBottomSheet(
      walletId: -1,
      title: t.wallet_detail_screen.vault_select_receiving_wallet,
      currentUnit: context.read<PreferenceProvider>().currentUnit,
      showOnlyMfpWallets: false,
      candidateWalletIds: [
        for (final wallet in widget.watchOnlyWallets)
          if (!wallet.hasLocalKey && walletIds.contains(wallet.id)) wallet.id,
      ],
      onWalletChanged: _selectWallet,
    );
  }
}
