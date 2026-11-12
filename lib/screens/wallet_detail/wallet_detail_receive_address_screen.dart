import 'dart:async';
import 'package:coconut_wallet/model/ark/ark_lightning_invoice.dart';
import 'package:coconut_wallet/model/ark/ark_movement.dart';
import 'package:coconut_wallet/model/ark/ark_snapshot.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/receive_complete_screen.dart';
import 'package:coconut_wallet/screens/ark/ark_unlock_flow.dart';
import 'package:coconut_wallet/widgets/common/buttons/copy_text_container.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutToast;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/widgets/features/qr/input_and_share_overlay.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/icon/coconut_logo_icon.dart';
import 'package:coconut_wallet/screens/common/receive_amount_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coconut_wallet/widgets/features/qr/qrcode_info.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class ReceiveAddressScreen extends StatefulWidget {
  final int id;

  const ReceiveAddressScreen({super.key, required this.id});

  @override
  State<ReceiveAddressScreen> createState() => _ReceiveAddressScreenState();
}

class _ReceiveAddressScreenState extends State<ReceiveAddressScreen> {
  WalletItemBase? _selectedWalletItem;
  WalletAddress? _receiveAddress;
  int? _enteredReceiveAmountSats;
  final GlobalKey _qrCaptureKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();
  late final ArkProvider _arkProvider;

  // The Ark side of a hot wallet's unified (BIP321) receive code.
  ArkLightningInvoice? _invoice;
  bool _isCreatingInvoice = false;
  String? _invoiceError;
  int? _fastSyncWalletId;
  final Set<int> _announcedMovementIds = {};

  // On-chain payments: the selected wallet's transactions seen so far, checked after each sync.
  late final TransactionProvider _transactionProvider;
  StreamSubscription<WalletUpdateInfo>? _walletUpdateSubscription;
  final Set<String> _seenTxHashes = {};
  int _receiveMode = 1;
  final Set<String> _expandedValues = {};
  bool _isShowingReceived = false;

  String get derivationPath {
    if (_receiveAddress == null) return "";
    return _receiveAddress!.derivationPath;
  }

  String get receiveAddressIndex {
    if (_receiveAddress == null) return "";
    return _receiveAddress!.derivationPath.split('/').last;
  }

  String get receiveAddress {
    if (_receiveAddress == null) return "";
    return _receiveAddress!.address;
  }

  bool get _isArkWallet => _selectedWalletItem != null && _arkProvider.supportsArk(_selectedWalletItem!);

  ArkSnapshot? get _arkSnapshot => _isArkWallet ? _arkProvider.snapshot(selectedWalletId) : null;

  String? get _arkAddress => _arkSnapshot?.address;

  bool get _isInvoicePaid {
    final invoice = _invoice;
    if (invoice == null) return false;
    return _arkSnapshot?.movements.any(
          (movement) =>
              movement.kind == ArkMovementKind.lightningReceive &&
              movement.paymentHash == invoice.paymentHash &&
              movement.status == ArkMovementStatus.successful,
        ) ??
        false;
  }

  /// A plain address, a BIP21 URI with an amount, or for hot wallets with Ark a BIP321 URI that
  /// adds the Ark address and, once an amount is set, a Lightning invoice. Wallets that don't
  /// know a payment method ignore its parameter and pay on-chain.
  String get qrData {
    if (_receiveAddress == null) return '';
    final parameters = <String, String>{
      if (_showsUnified && _arkAddress != null) 'ark': _arkAddress!,
      if (_showsUnified && _invoice != null && !_isInvoicePaid) 'lightning': _invoice!.invoice,
    };
    if (_enteredReceiveAmountSats == null && parameters.isEmpty) return _receiveAddress!.address;
    return buildPaymentUriFromWalletAddress(
      _receiveAddress!,
      amount: _enteredReceiveAmountSats,
      parameters: parameters.isEmpty ? null : parameters,
    );
  }

  bool get _showsUnified => _isArkWallet && _receiveMode == 1;

  int get selectedWalletId => _selectedWalletItem != null ? _selectedWalletItem!.id : -1;

  @override
  void initState() {
    super.initState();
    if (widget.id == -1) return;
    AppGuard.disablePrivacyScreen();

    final walletProvider = context.read<WalletProvider>();
    _arkProvider = context.read<ArkProvider>();
    _transactionProvider = context.read<TransactionProvider>();
    _selectedWalletItem = walletProvider.walletItemList.where((e) => e.id == widget.id).first;
    _receiveAddress = walletProvider.getReceiveAddress(_selectedWalletItem!.id);
    _arkProvider.cacheRevision.addListener(_onArkCacheChanged);
    _onWalletSelected();
  }

  @override
  void dispose() {
    _walletUpdateSubscription?.cancel();
    _arkProvider.cacheRevision.removeListener(_onArkCacheChanged);
    _stopFastSync();
    AppGuard.enablePrivacyScreen();
    super.dispose();
  }

  /// While this screen is open, payments to the selected wallet open the Received screen. A hot
  /// wallet with Ark syncs every few seconds so Ark and Lightning payments (which bark claims
  /// during sync) show up promptly; on-chain ones show once Coconut's node sync has them.
  void _onWalletSelected() {
    _stopFastSync();
    _invoice = null;
    _invoiceError = null;
    _announcedMovementIds
      ..clear()
      ..addAll(_arkSnapshot?.movements.map((movement) => movement.id) ?? const []);
    _watchOnchain();
    if (!_isArkWallet) return;
    _fastSyncWalletId = selectedWalletId;
    _arkProvider.setFastSync(selectedWalletId, true);
    unawaited(_arkProvider.syncNow(selectedWalletId, withRounds: false));
  }

  void _stopFastSync() {
    final walletId = _fastSyncWalletId;
    if (walletId == null) return;
    _arkProvider.setFastSync(walletId, false);
    _fastSyncWalletId = null;
  }

  void _onArkCacheChanged() {
    if (!mounted || !_isArkWallet) return;
    for (final movement in _arkSnapshot?.movements ?? const <ArkMovement>[]) {
      if (_announcedMovementIds.contains(movement.id)) continue;
      if (movement.status != ArkMovementStatus.successful || movement.effectiveBalanceSats <= 0) continue;
      _announcedMovementIds.add(movement.id);
      unawaited(_showReceived(movement.effectiveBalanceSats));
    }
    setState(() {});
  }

  /// Notes the selected wallet's transactions so far, then looks for new incoming ones after each of
  /// its syncs.
  void _watchOnchain() {
    _walletUpdateSubscription?.cancel();
    final walletId = selectedWalletId;
    _seenTxHashes
      ..clear()
      ..addAll(_transactionProvider.getTransactionRecordList(walletId).map((tx) => tx.transactionHash));
    _walletUpdateSubscription = context.read<NodeProvider>().getWalletStateStream(walletId).listen((update) {
      if (update.transaction == WalletSyncState.completed) _onOnchainSynced(walletId);
    });
  }

  void _onOnchainSynced(int walletId) {
    if (!mounted || walletId != selectedWalletId) return;
    for (final tx in _transactionProvider.getTransactionRecordList(walletId)) {
      if (!_seenTxHashes.add(tx.transactionHash)) continue;
      if (tx.transactionType != TransactionType.received || tx.amount <= 0) continue;
      unawaited(_showReceived(tx.amount, isUnconfirmed: tx.blockHeight == 0));
    }
  }

  /// The first payment to arrive takes over with the Received screen, whose Confirm closes this
  /// screen too; any others meanwhile are in the history.
  Future<void> _showReceived(int amountSats, {bool isUnconfirmed = false}) async {
    if (_isShowingReceived || !mounted) return;
    _isShowingReceived = true;
    final unit = context.read<PreferenceProvider>().currentUnit;
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (_, __, ___) => ReceiveCompleteScreen(amountSats: amountSats, unit: unit, isUnconfirmed: isUnconfirmed),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  /// Opens the Ark wallet for the session if needed, then makes an invoice for the entered amount.
  Future<void> _createInvoice() async {
    final amount = _enteredReceiveAmountSats;
    final walletId = selectedWalletId;
    setState(() {
      _invoice = null;
      _invoiceError = null;
    });
    if (amount == null || !_isArkWallet) return;
    if (!await openArkWalletForSession(context, walletId, userInitiated: true)) return;
    if (!mounted || walletId != selectedWalletId || amount != _enteredReceiveAmountSats) return;
    setState(() => _isCreatingInvoice = true);
    try {
      final invoice = await _arkProvider.createLightningInvoice(walletId, amount);
      if (!mounted || walletId != selectedWalletId || amount != _enteredReceiveAmountSats) return;
      setState(() => _invoice = invoice);
    } catch (error) {
      if (mounted) setState(() => _invoiceError = t.ark.receive.invoice_failed(error: '$error'));
    } finally {
      if (mounted) setState(() => _isCreatingInvoice = false);
    }
  }

  Future<void> _onEnterAmountTap() async {
    final preferenceProvider = context.read<PreferenceProvider>();
    final result = await ReceiveAmountBottomSheet.show(
      context: context,
      currentUnit: preferenceProvider.currentUnit,
      initialAmountSats: _enteredReceiveAmountSats,
      description: _showsUnified ? t.ark.receive.amount_description : null,
      screenName: AnalyticsScreenNames.receiveAddressSetAmountSheet,
    );
    if (!mounted || result == null || !result.didEdit) return;
    setState(() {
      _enteredReceiveAmountSats = result.amountInSats;
    });
    await _createInvoice();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      resizeToAvoidBottomInset: false,
      appBar: CoconutAppBar.build(
        title: t.receive,
        customTitle: Text(
          _selectedWalletItem?.name ?? '',
          style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
        ),
        context: context,
        isBottom: true,
        actionButtonList: const [SizedBox(width: 48, height: 48)],
        onBackPressed: () {
          Navigator.of(context).pop();
        },
      ),
      body:
          _selectedWalletItem != null
              ? InputAndShareOverlay(
                shareButtonKey: _shareButtonKey,
                onEnterAmountTap: _onEnterAmountTap,
                onShareTap: () async {
                  try {
                    final RenderRepaintBoundary boundary =
                        _qrCaptureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

                    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                    final Uint8List pngBytes = byteData!.buffer.asUint8List();

                    final directory = await getTemporaryDirectory();
                    final file = File('${directory.path}/share_qr_address.png');
                    await file.writeAsBytes(pngBytes);

                    // 버튼 위치 계산
                    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
                    final Rect sharePositionOrigin =
                        box != null ? box.localToGlobal(Offset.zero) & box.size : const Rect.fromLTWH(0, 400, 300, 50);

                    AppGuard.disablePrivacyScreen();
                    await SharePlus.instance.share(
                      ShareParams(files: [XFile(file.path)], text: qrData, sharePositionOrigin: sharePositionOrigin),
                    );
                  } catch (e, stack) {
                    debugPrint('Failed to capture and share: $e');
                    debugPrint('Stack: $stack');
                  } finally {
                    AppGuard.enablePrivacyScreen();
                  }
                },
                child: SafeArea(
                  child: Container(
                    padding: EdgeInsets.fromLTRB(10, _isArkWallet ? 4 : 20, 10, 20),
                    child:
                        _isArkWallet
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildReceiveModeControl(),
                                _showsUnified ? CoconutLayout.spacing_600h : CoconutLayout.spacing_500h,
                                _showsUnified ? _buildUnifiedReceive() : _buildBitcoinReceive(),
                              ],
                            )
                            : _buildBitcoinReceive(),
                  ),
                ),
              )
              : const SizedBox(),
    );
  }

  Widget _buildReceiveModeControl() {
    final colors = context.coconutColors;
    return Center(
      child: CoconutSegmentedControl(
        isSelected: [_receiveMode == 0, _receiveMode == 1],
        onPressed: (index) => setState(() => _receiveMode = index),
        selectedColor: colors.segmentedControlSelected,
        segmentedControlContainerColor: colors.segmentedControlBackground,
        selectedTextColor: colors.segmentedControlSelectedText,
        unselectedTextColor: colors.segmentedControlUnselectedText,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          Text(t.ark.receive.mode_bitcoin, key: const Key('receive-mode-bitcoin')),
          Text(t.ark.receive.mode_unified, key: const Key('receive-mode-unified')),
        ],
      ),
    );
  }

  Widget _buildBitcoinReceive() {
    return Column(
      children: [
        QrCodeInfo(
          qrCaptureKey: _qrCaptureKey,
          qrcodeTopWidget: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.address_list_screen.address_index(index: receiveAddressIndex),
                          style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
                        ),
                        Text(
                          derivationPath,
                          style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildViewAllAddressesButton(),
              ],
            ),
          ),
          qrData: qrData,
          embedWidget: const CoconutLogoIcon(size: 16),
          isAddress: true,
        ),
      ],
    );
  }

  Widget _buildViewAllAddressesButton() {
    return ShrinkAnimationButton(
      onPressed: _onAddressListButtonPressed,
      defaultColor: context.coconutColors.surface,
      pressedOverlayColor: context.coconutColors.surfacePressOverlay,
      borderRadius: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          t.view_all_addresses,
          style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
        ),
      ),
    );
  }

  /// QR with every payment method of a hot wallet with Ark, then one row per method to copy it.
  Widget _buildUnifiedReceive() {
    final arkAddress = _arkAddress;
    final isArkOpen = _arkProvider.isOpen(selectedWalletId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QrCodeInfo(
          qrCaptureKey: _qrCaptureKey,
          qrData: qrData,
          embedWidget: const CoconutLogoIcon(size: 16),
          showCopyText: false,
        ),
        if (_enteredReceiveAmountSats case final amount?) ...[
          CoconutLayout.spacing_300h,
          Text(
            t.ark.receive.requested_amount(
              amount: context.read<PreferenceProvider>().currentUnit.displayBitcoinAmount(amount, withUnit: true),
            ),
            key: const Key('receive-requested-amount'),
            textAlign: TextAlign.center,
            style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
          ),
        ],
        CoconutLayout.spacing_500h,
        _ReceiveMethodRow(
          title: t.ark.request.bitcoin_address,
          subtitle: '${t.address_list_screen.address_index(index: receiveAddressIndex)} · $derivationPath',
          trailing: _buildViewAllAddressesButton(),
          child: CopyTextContainer(text: receiveAddress, isAddress: true, padding: const EdgeInsets.all(20)),
        ),
        _ReceiveMethodRow(
          title: t.ark.request.ark_address,
          child:
              arkAddress != null
                  ? _buildFoldableCopyText(arkAddress, key: 'ark')
                  : isArkOpen
                  ? _ReceiveActionTile(text: t.ark.receive.preparing_ark)
                  : _ReceiveActionTile(
                    text: t.ark.receive.unlock_ark,
                    actionText: t.ark.send.unlock,
                    onTap: _unlockArk,
                  ),
        ),
        _ReceiveMethodRow(
          title: t.ark.receive.lightning_invoice,
          subtitle: _lightningSubtitle(),
          child: _buildLightningMethod(isArkOpen),
        ),
      ],
    );
  }

  Widget _buildLightningMethod(bool isArkOpen) {
    if (_enteredReceiveAmountSats == null) {
      return _ReceiveActionTile(text: t.ark.receive.set_amount_for_invoice);
    }
    if (_isCreatingInvoice) return _ReceiveActionTile(text: t.ark.receive.creating_invoice);
    if (_invoiceError != null) {
      return _ReceiveActionTile(text: _invoiceError!, actionText: t.retry, onTap: _createInvoice);
    }
    final invoice = _invoice;
    if (invoice == null) {
      return _ReceiveActionTile(
        text: isArkOpen ? t.ark.receive.add_invoice : t.ark.receive.unlock_invoice,
        actionText: isArkOpen ? t.ark.receive.add : t.ark.send.unlock,
        onTap: _createInvoice,
      );
    }
    if (_isInvoicePaid) return _ReceiveActionTile(text: t.ark.receive.paid);
    return _buildFoldableCopyText(invoice.invoice, key: 'invoice');
  }

  Widget _buildFoldableCopyText(String value, {required String key}) {
    final isExpanded = _expandedValues.contains(key);
    void toggle() => setState(() => isExpanded ? _expandedValues.remove(key) : _expandedValues.add(key));
    Widget card(String shown, String suffix) => CopyTextContainer(
      key: Key('receive-$key-value-$suffix'),
      text: shown,
      copyText: value,
      isAddress: true,
      padding: const EdgeInsets.all(20),
      onTextTap: toggle,
    );
    if (value.length <= 48) return card(value, 'full');
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 240),
      sizeCurve: Curves.easeOutCubic,
      firstCurve: Curves.easeOut,
      secondCurve: Curves.easeOut,
      crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: card('${value.substring(0, 24)}…${value.substring(value.length - 16)}', 'short'),
      secondChild: card(value, 'full'),
    );
  }

  String? _lightningSubtitle() {
    final invoice = _invoice;
    if (invoice == null) return null;
    final unit = context.read<PreferenceProvider>().currentUnit;
    if (_isInvoicePaid) return t.ark.receive.received_over_lightning;
    if (invoice.feeSats == 0) return null;
    return t.ark.receive.you_receive(
      amount: unit.displayBitcoinAmount(invoice.netAmountSats, withUnit: true),
      fee: unit.displayBitcoinAmount(invoice.feeSats, withUnit: true),
    );
  }

  Future<void> _unlockArk() async {
    final opened = await openArkWalletForSession(context, selectedWalletId, userInitiated: true);
    if (opened && _enteredReceiveAmountSats != null) await _createInvoice();
  }

  void _onAddressListButtonPressed() {
    Navigator.pushNamed(
      context,
      AppRouteNames.addressList,
      arguments: AddressListRouteArgs(id: _selectedWalletItem!.id),
    );
  }
}

/// One payment method of the unified receive code: a title, an optional subtitle and action,
/// and the value to copy.
class _ReceiveMethodRow extends StatelessWidget {
  const _ReceiveMethodRow({required this.title, required this.child, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText)),
                    if (subtitle != null)
                      Text(subtitle!, style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          CoconutLayout.spacing_200h,
          child,
        ],
      ),
    );
  }
}

/// A box in place of a value that isn't available yet, with a small button to get it when there
/// is one (the "view all addresses" button style).
class _ReceiveActionTile extends StatelessWidget {
  const _ReceiveActionTile({required this.text, this.actionText, this.onTap});

  final String text;
  final String? actionText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(CoconutStyles.radius_400)),
      child: Row(
        children: [
          Expanded(child: Text(text, style: CoconutTypography.body2_14.setColor(colors.secondaryText))),
          if (actionText != null && onTap != null) ...[
            CoconutLayout.spacing_300w,
            ShrinkAnimationButton(
              onPressed: onTap!,
              defaultColor: colors.surfaceButton,
              pressedOverlayColor: colors.surfacePressOverlay,
              borderRadius: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(actionText!, style: CoconutTypography.body3_12.setColor(colors.surfaceButtonText)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
