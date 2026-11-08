import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/screens/payjoin/payjoin_vault_sign_screen.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_psbt.dart' show finalizeDeviceSignedPsbt;
import 'package:coconut_wallet/services/payjoin/payjoin_receiver.dart'
    show PayjoinReceiveNeedsSignature, payjoinUriWithAmount;
import 'package:coconut_wallet/services/payjoin/payjoin_signer.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_session_manager.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/widgets/features/payjoin/payjoin_receive_status.dart';
import 'package:coconut_wallet/widgets/features/qr/input_and_share_overlay.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/icon/coconut_logo_icon.dart';
import 'package:coconut_wallet/screens/common/bip21_amount_bottom_sheet.dart';
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
  late int _walletCount;
  final GlobalKey _qrCaptureKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

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

  String get qrData {
    if (_receiveAddress == null) return '';
    final pjUri = _payjoinUri;
    if (pjUri != null) return payjoinUriWithAmount(pjUri, _enteredReceiveAmountSats);
    if (_enteredReceiveAmountSats == null) return _receiveAddress!.address;
    return buildBip21UriFromWalletAddress(_receiveAddress!, amount: _enteredReceiveAmountSats);
  }

  String? _payjoinSessionId;
  String? _payjoinUri;
  bool _payjoinStarting = false;

  PayjoinSigner? get _payjoinSigner => _selectedWalletItem == null ? null : payjoinSignerOf(_selectedWalletItem!);

  /// Takes the proposal to Coconut Vault and back, then lets the session
  /// post it. The sender is polling meanwhile, so this is the step the
  /// payjoin waits on.
  Future<void> _signWithVault(String sessionId, String psbtToSign) async {
    final manager = context.read<PayjoinSessionManager>();
    final signed = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder:
            (_) => PayjoinVaultSignScreen(
              psbtBase64: psbtToSign,
              instruction: t.payjoin.vault_sign_receive(name: _selectedWalletItem!.name),
              accept: (answer) => finalizeDeviceSignedPsbt(answer, shownPsbtBase64: psbtToSign),
            ),
      ),
    );
    if (signed == null) return;
    await manager.submitSignedProposal(sessionId, signed);
  }

  void _resumePayjoinSession() {
    final id = context.read<PayjoinSessionManager>().openReceiveSession(selectedWalletId, receiveAddress);
    _payjoinSessionId = id;
    _payjoinUri = id == null ? null : context.read<PayjoinSessionManager>().pjUri(id);
  }

  Future<void> _setPayjoin(bool on) async {
    final manager = context.read<PayjoinSessionManager>();
    if (!on) {
      final id = _payjoinSessionId;
      setState(() {
        _payjoinSessionId = null;
        _payjoinUri = null;
      });
      if (id != null) await manager.cancelReceive(id);
      return;
    }
    setState(() => _payjoinStarting = true);
    try {
      final id = await manager.startReceive(walletId: selectedWalletId, address: receiveAddress);
      if (!mounted) return;
      setState(() {
        _payjoinSessionId = id;
        _payjoinUri = manager.pjUri(id);
      });
    } catch (e) {
      if (!mounted) return;
      CoconutToast.showToast(context: context, isVisibleIcon: true, text: t.payjoin.receive_unavailable);
    } finally {
      if (mounted) setState(() => _payjoinStarting = false);
    }
  }

  bool _isWaitingForVault(PayjoinSessionManager manager) =>
      _payjoinSigner == PayjoinSigner.coconutVault &&
      _payjoinSessionId != null &&
      manager.receiveProgress(_payjoinSessionId!) is PayjoinReceiveNeedsSignature;

  Widget _buildPayjoinToggle() {
    final colors = context.coconutColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoconutLayout.spacing_400h,
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.payjoin.receive_title, style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText)),
                    // While waiting for the vault the description is hidden, to
                    // make room for the "Sign with vault" button above the
                    // screen's bottom actions.
                    Consumer<PayjoinSessionManager>(
                      builder:
                          (context, manager, _) =>
                              _isWaitingForVault(manager)
                                  ? const SizedBox.shrink()
                                  : Text(
                                    t.payjoin.receive_description,
                                    style: CoconutTypography.body3_12.setColor(colors.secondaryTextStrong),
                                  ),
                    ),
                  ],
                ),
              ),
              CoconutLayout.spacing_200w,
              CoconutSwitch(
                key: const ValueKey('payjoin-receive-switch'),
                scale: 0.7,
                isOn: _payjoinSessionId != null || _payjoinStarting,
                activeTrackColor: colors.switchActiveTrack,
                activeThumbColor: colors.switchActiveThumb,
                inactiveTrackColor: colors.switchInactiveTrack,
                inactiveThumbColor: colors.switchInactiveThumb,
                onChanged: (isOn) => _payjoinStarting ? null : _setPayjoin(isOn),
              ),
            ],
          ),
          if (_payjoinSessionId != null)
            Consumer<PayjoinSessionManager>(
              builder: (context, manager, _) {
                final sessionId = _payjoinSessionId!;
                final progress = manager.receiveProgress(sessionId);
                final signsWithVault = _payjoinSigner == PayjoinSigner.coconutVault;
                final status = payjoinReceiveStatusText(
                  progress,
                  hasError: manager.receiveError(sessionId) != null,
                  signsWithVault: signsWithVault,
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        status,
                        key: const ValueKey('payjoin-receive-status'),
                        style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
                      ),
                      if (signsWithVault && progress is PayjoinReceiveNeedsSignature) ...[
                        CoconutLayout.spacing_200h,
                        CoconutButton(
                          key: const ValueKey('payjoin-sign-with-vault'),
                          text: t.payjoin.sign_with_vault,
                          height: 44,
                          onPressed: () => _signWithVault(sessionId, progress.psbtToSign),
                          backgroundColor: colors.primaryText,
                          foregroundColor: colors.background,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  int get selectedWalletId => _selectedWalletItem != null ? _selectedWalletItem!.id : -1;

  @override
  void initState() {
    super.initState();
    if (widget.id == -1) return;
    AppGuard.disablePrivacyScreen();

    final walletProvider = context.read<WalletProvider>();
    _selectedWalletItem = walletProvider.walletItemList.where((e) => e.id == widget.id).first;
    _receiveAddress = walletProvider.getReceiveAddress(_selectedWalletItem!.id);
    _walletCount = walletProvider.walletItemList.length;
    _resumePayjoinSession();
  }

  @override
  void dispose() {
    AppGuard.enablePrivacyScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      resizeToAvoidBottomInset: false,
      appBar: CoconutAppBar.build(
        title: t.receive,
        customTitle: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _selectedWalletItem?.name ?? t.send_screen.select_wallet,
                  style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
                ),
                if (_walletCount > 1) ...[
                  CoconutLayout.spacing_50w,
                  Icon(Icons.keyboard_arrow_down_sharp, color: context.coconutColors.iconPrimary, size: 16),
                ],
              ],
            ),
          ],
        ),
        onTitlePressed: _onAppBarTitlePressed,
        context: context,
        isBottom: true,
        actionButtonList: [
          _walletCount > 1 ? const SizedBox(width: 24, height: 24) : const SizedBox(width: 48, height: 48),
        ],
        onBackPressed: () {
          Navigator.of(context).pop();
        },
      ),
      body:
          _selectedWalletItem != null
              ? InputAndShareOverlay(
                shareButtonKey: _shareButtonKey,
                onEnterAmountTap: () async {
                  final preferenceProvider = context.read<PreferenceProvider>();
                  final result = await Bip21AmountBottomSheet.show(
                    context: context,
                    currentUnit: preferenceProvider.currentUnit,
                    initialAmountSats: _enteredReceiveAmountSats,
                    screenName: AnalyticsScreenNames.receiveAddressSetAmountSheet,
                  );
                  if (!mounted || result == null || !result.didEdit) return;
                  setState(() {
                    _enteredReceiveAmountSats = result.amountInSats;
                  });
                },
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                    child: Column(
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
                                          style: CoconutTypography.body2_14.setColor(
                                            context.coconutColors.secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                ShrinkAnimationButton(
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
                                ),
                              ],
                            ),
                          ),
                          qrData: qrData,
                          // The pj URI is long; show the address and copy the whole URI.
                          displayText: _payjoinUri == null ? null : receiveAddress,
                          embedWidget: const CoconutLogoIcon(size: 16),
                          isAddress: true,
                        ),
                        if (_payjoinSigner != null) _buildPayjoinToggle(),
                      ],
                    ),
                  ),
                ),
              )
              : const SizedBox(),
    );
  }

  void _onAddressListButtonPressed() {
    Navigator.pushNamed(
      context,
      AppRouteNames.addressList,
      arguments: AddressListRouteArgs(id: _selectedWalletItem!.id),
    );
  }

  void _onAppBarTitlePressed() {
    if (_walletCount <= 1) return;
    AppGuard.enablePrivacyScreen();
    SelectWalletBottomSheet.show(
      context: context,
      screenName: AnalyticsScreenNames.receiveAddressSelectWalletSheet,
      child: SelectWalletBottomSheet(
        showOnlyMfpWallets: false,

        currentUnit: context.read<PreferenceProvider>().currentUnit,
        walletId: selectedWalletId,
        onWalletChanged: (id) {
          final walletProvider = context.read<WalletProvider>();
          _selectedWalletItem = walletProvider.walletItemList.firstWhere((e) => e.id == id);
          _receiveAddress = walletProvider.getReceiveAddress(_selectedWalletItem!.id);
          _resumePayjoinSession();
          setState(() {});
          Navigator.pop(context);
        },
      ),
    ).whenComplete(() => AppGuard.disablePrivacyScreen());
  }
}
