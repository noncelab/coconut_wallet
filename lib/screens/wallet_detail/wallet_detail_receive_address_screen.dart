import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/refactor/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/widgets/input_and_share_overlay.dart';
import 'package:coconut_wallet/utils/bip21_amount_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_list_screen.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/qrcode_info.dart';
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
  WalletListItemBase? _selectedWalletItem;
  WalletAddress? _receiveAddress;
  int? _enteredReceiveAmountSats;
  late int _walletCount;
  final GlobalKey _qrCaptureKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

  ImageProvider get _qrEmbedImage {
    final path =
        NetworkType.currentNetworkType == NetworkType.regtest
            ? 'assets/images/splash_logo_regtest.png'
            : 'assets/images/splash_logo_mainnet.png';
    return AssetImage(path);
  }

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
    if (_enteredReceiveAmountSats == null) return _receiveAddress!.address;
    return buildBip21UriFromWalletAddress(_receiveAddress!, amount: _enteredReceiveAmountSats);
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
  }

  @override
  void dispose() {
    AppGuard.enablePrivacyScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      resizeToAvoidBottomInset: false,
      appBar: CoconutAppBar.build(
        title: t.receive,
        customTitle: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_selectedWalletItem?.name ?? t.send_screen.select_wallet, style: CoconutTypography.body1_16),
                if (_walletCount > 1) ...[
                  CoconutLayout.spacing_50w,
                  const Icon(Icons.keyboard_arrow_down_sharp, color: CoconutColors.white, size: 16),
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
              ? SafeArea(
                child: InputAndShareOverlay(
                  shareButtonKey: _shareButtonKey,
                  onEnterAmountTap: () async {
                    final currentUnit = context.read<PreferenceProvider>().currentUnit;
                    final result = await Bip21AmountBottomSheet.show(
                      context: context,
                      currentUnit: currentUnit,
                      initialAmountSats: _enteredReceiveAmountSats,
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
                          box != null
                              ? box.localToGlobal(Offset.zero) & box.size
                              : const Rect.fromLTWH(0, 400, 300, 50); // fallback

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
                                          style: CoconutTypography.body1_16,
                                        ),
                                        Text(
                                          derivationPath,
                                          style: CoconutTypography.body2_14.setColor(
                                            CoconutColors.white.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _onAddressListButtonPressed,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: CoconutColors.white.withValues(alpha: 0.15),
                                    ),
                                    child: Text(t.view_all_addresses, style: CoconutTypography.body3_12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          qrData: qrData,
                          embedImage: _qrEmbedImage,
                          isAddress: true,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              : const SizedBox(),
    );
  }

  void _onAddressListButtonPressed() {
    CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      heightRatio: 0.9,
      child: AddressListScreen(id: _selectedWalletItem!.id, isFullScreen: false),
    );
  }

  void _onAppBarTitlePressed() {
    if (_walletCount <= 1) return;
    AppGuard.enablePrivacyScreen();
    CommonBottomSheets.showDraggableBottomSheet(
      context: context,
      childBuilder:
          (scrollController) => SelectWalletBottomSheet(
            showOnlyMfpWallets: false,
            scrollController: scrollController,
            currentUnit: context.read<PreferenceProvider>().currentUnit,
            walletId: selectedWalletId,
            onWalletChanged: (id) {
              final walletProvider = context.read<WalletProvider>();
              _selectedWalletItem = walletProvider.walletItemList.firstWhere((e) => e.id == id);
              _receiveAddress = walletProvider.getReceiveAddress(_selectedWalletItem!.id);
              setState(() {});
              Navigator.pop(context);
            },
          ),
    ).whenComplete(() => AppGuard.disablePrivacyScreen());
  }
}
