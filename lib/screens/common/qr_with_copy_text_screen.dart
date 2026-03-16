import 'package:coconut_design_system/coconut_design_system.dart';
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
  });

  @override
  State<QrWithCopyTextScreen> createState() => _QrWithCopyTextScreenState();
}

class _QrWithCopyTextScreenState extends State<QrWithCopyTextScreen> {
  final GlobalKey _pulldownKey = GlobalKey();
  bool _isPulldownOpen = false;

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

  String get _currentQrData {
    if (!widget.showPulldownMenu || widget.qrDataMap == null) {
      return widget.qrData;
    }
    return widget.qrDataMap![_selectedKey] ?? widget.qrData;
  }

  String get _currentTextData {
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

    return Scaffold(
      backgroundColor: CoconutColors.black,
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
        child: SingleChildScrollView(
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
                  textData: displayTextData,
                  textRichText: widget.textRichText,
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
