import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/widgets/adaptive_qr_image.dart';
import 'package:coconut_wallet/widgets/animated_bottom_action_overlay.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/receive_amount_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/button/copy_text_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:coconut_wallet/widgets/qrcode_info.dart';
import 'package:flutter/material.dart';

class QrWithCopyTextScreen extends StatefulWidget {
  final String title;
  final Widget? tooltipDescription;

  final String qrData;

  // Data map used only when backing up a multisig wallet
  final Map<String, String>? qrDataMap;
  final Map<String, String>? textDataMap;

  final RichText? textRichText;
  final Widget? footer;

  final bool showPulldownMenu;

  final Widget? qrcodeTopWidget;

  final Widget? actionButton;

  final bool isAddress;

  final bool isBottom;

  final double? receiveAmount;
  final ScrollController? scrollController;
  final bool showBottomActions;
  final bool showQrEmbedImage;

  const QrWithCopyTextScreen({
    super.key,
    required this.title,
    required this.qrData,
    this.tooltipDescription,
    this.qrDataMap,
    this.textDataMap,
    this.textRichText,
    this.footer,
    required this.showPulldownMenu,
    this.qrcodeTopWidget,
    this.actionButton,
    this.isAddress = false,
    this.isBottom = false,
    this.receiveAmount,
    this.scrollController,
    this.showBottomActions = false,
    this.showQrEmbedImage = false,
  });

  @override
  State<QrWithCopyTextScreen> createState() => _QrWithCopyTextScreenState();
}

class _QrWithCopyTextScreenState extends State<QrWithCopyTextScreen> {
  final GlobalKey _pulldownKey = GlobalKey();
  final GlobalKey _qrCaptureKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();
  bool _isPulldownOpen = false;
  int? _enteredReceiveAmountSats;

  String _selectedKey = "";

  final Map<String, String> _displayNames = {
    "BSMS": "BSMS",
    "BlueWallet Vault Multisig": "BlueWallet",
    "Coldcard Multisig": "Coldcard",
    "Keystone Multisig": "Keystone",
    "Output Descriptor": "Descriptor",
    "Specter Desktop": "Specter",
  };

  @override
  void initState() {
    super.initState();
    if (widget.qrDataMap != null && widget.qrDataMap!.isNotEmpty) {
      _selectedKey = widget.qrDataMap!.keys.first;
    }
  }

  List<String> get _optionKeys {
    if (widget.qrDataMap == null || widget.qrDataMap!.isEmpty) {
      return [];
    }
    return widget.qrDataMap!.keys.toList();
  }

  int get _selectedIndex => _optionKeys.indexOf(_selectedKey);

  String get _displayTitle => _displayNames[_selectedKey] ?? _selectedKey;

  ImageProvider? get _qrEmbedImage {
    if (!widget.showQrEmbedImage) return null;
    final path =
        NetworkType.currentNetworkType == NetworkType.regtest
            ? 'assets/images/splash_logo_regtest.png'
            : 'assets/images/splash_logo_mainnet.png';
    return AssetImage(path);
  }

  double _calcQrWidth(BuildContext context) {
    return MediaQuery.of(context).size.width * 0.76;
  }

  String get _currentQrData {
    final baseQrData =
        (!widget.showPulldownMenu || widget.qrDataMap == null)
            ? widget.qrData
            : widget.qrDataMap![_selectedKey] ?? widget.qrData;

    if (!widget.isAddress || _enteredReceiveAmountSats == null) {
      return baseQrData;
    }

    return buildBip21Uri(extractAddressFromBip21(baseQrData), amount: _enteredReceiveAmountSats);
  }

  String get _currentTextData {
    if (widget.isAddress && _enteredReceiveAmountSats != null) {
      return _currentQrData;
    }

    if (!widget.showPulldownMenu) {
      return widget.qrData;
    }

    if (widget.textDataMap != null && widget.textDataMap!.containsKey(_selectedKey)) {
      return widget.textDataMap![_selectedKey]!;
    }

    if (widget.qrDataMap != null && widget.qrDataMap!.containsKey(_selectedKey)) {
      return widget.qrDataMap![_selectedKey]!;
    }

    return widget.qrData;
  }

  void _showDropdownMenu() {
    final RenderBox? renderBox = _pulldownKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenWidth = MediaQuery.of(context).size.width;

    Navigator.of(context)
        .push(
          PageRouteBuilder(
            opaque: false,
            barrierDismissible: true,
            barrierColor: Colors.transparent,
            transitionDuration: Duration.zero,
            pageBuilder: (context, _, __) {
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.translucent,
                    child: const SizedBox.expand(),
                  ),
                  Positioned(
                    top: offset.dy + size.height + 8.0,
                    right: screenWidth - (offset.dx + size.width),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
                      child: CoconutPulldownMenu(
                        entries:
                            _optionKeys.map((key) {
                              return CoconutPulldownMenuItem(title: key);
                            }).toList(),

                        selectedIndex: _selectedIndex,

                        onSelected: (index, title) {
                          setState(() {
                            _selectedKey = _optionKeys[index];
                          });
                          Navigator.pop(context);
                        },

                        backgroundColor: CoconutColors.gray800,
                        borderRadius: 8,
                        isSelectedItemBold: true,
                        buttonPadding: const EdgeInsets.only(right: 16, left: 16),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        )
        .then((_) {
          setState(() {
            _isPulldownOpen = false;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final displayQrData = _currentQrData;
    final displayTextData = _currentTextData;
    final currentUnit = context.read<PreferenceProvider>().currentUnit;

    return Scaffold(
      backgroundColor: CoconutColors.black,
      resizeToAvoidBottomInset: false,
      appBar: CoconutAppBar.build(
        title: widget.title,
        context: context,

        isBottom: widget.isBottom,
        onBackPressed: () {
          Navigator.pop(context);
        },
        actionButtonList: widget.actionButton != null ? [widget.actionButton!] : [],
      ),
      body: SafeArea(
        child: EnterInputAndShareBottomActionOverlay(
          scrollController: widget.scrollController,
          showBottomActions: widget.showBottomActions,
          shareButtonKey: _shareButtonKey,
          onEnterAmountTap: () async {
            final sats = await ReceiveAmountBottomSheet.show(
              context: context,
              currentUnit: currentUnit,
              initialAmountSats: _enteredReceiveAmountSats,
            );
            if (!mounted || sats == null || sats == _enteredReceiveAmountSats) return;
            setState(() {
              _enteredReceiveAmountSats = sats;
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
                ShareParams(files: [XFile(file.path)], text: displayTextData, sharePositionOrigin: sharePositionOrigin),
              );
            } catch (e, stack) {
              debugPrint('Failed to capture and share: $e');
              debugPrint('Stack: $stack');
            } finally {
              AppGuard.enablePrivacyScreen();
            }
          },
          child: Column(
            children: [
              if (widget.tooltipDescription != null) ...[
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: widget.tooltipDescription!),
              ],
              if (widget.showPulldownMenu && _optionKeys.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8, right: 16),
                    child: Container(
                      key: _pulldownKey,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: CoconutColors.gray800, borderRadius: BorderRadius.circular(8)),
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
                        child: CoconutPulldown(
                          title: _displayTitle,
                          isOpen: _isPulldownOpen,
                          onChanged: (isOpen) {
                            setState(() {
                              _isPulldownOpen = true;
                            });
                            _showDropdownMenu();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                child: QrCodeInfo(
                  qrcodeTopWidget: widget.qrcodeTopWidget,
                  qrData: displayQrData,
                  displayText: displayTextData,
                  isAddress: widget.isAddress,
                ),
              ),
              if (widget.footer != null) widget.footer!,
            ],
          ),
        ),
      ),
    );
  }
}
