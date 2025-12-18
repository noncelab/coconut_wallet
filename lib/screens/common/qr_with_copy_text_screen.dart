import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/widgets/button/copy_text_container.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrWithCopyTextScreen extends StatefulWidget {
  final String title;
  final Widget? tooltipDescription;

  final String qrData;

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

  double _calcQrWidth(BuildContext context) {
    return MediaQuery.of(context).size.width * 0.76;
  }

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
                    top: offset.dy + size.height,
                    right: screenWidth - (offset.dx + size.width),
                    child: CoconutPulldownMenu(
                      entries:
                          _optionKeys.map((key) {
                            final displayTitle = _displayNames[key] ?? key;
                            return CoconutPulldownMenuItem(title: displayTitle);
                          }).toList(),

                      selectedIndex: _selectedIndex,

                      onSelected: (index, title) {
                        setState(() {
                          _selectedKey = _optionKeys[index];
                        });
                        Navigator.pop(context);
                      },

                      backgroundColor: CoconutColors.white,
                      borderRadius: 8,
                      shadowColor: CoconutColors.black.withOpacity(0.1),
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
    final qrWidth = _calcQrWidth(context);
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
                  child: Container(
                    key: _pulldownKey,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 8, right: 16),
                    decoration: BoxDecoration(color: CoconutColors.gray150, borderRadius: BorderRadius.circular(8)),
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

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    CoconutLayout.spacing_300h,

                    if (widget.qrcodeTopWidget != null) ...[widget.qrcodeTopWidget!, CoconutLayout.spacing_300h],

                    Center(
                      child: Container(
                        width: qrWidth,
                        decoration: CoconutBoxDecoration.shadowBoxDecoration,
                        child: QrImageView(
                          data: displayQrData,
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    CoconutLayout.spacing_500h,
                    _buildCopyButton(displayTextData, qrWidth),
                    CoconutLayout.spacing_1500h,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopyButton(String textData, double qrWidth) {
    return SizedBox(
      width: qrWidth,
      child: CopyTextContainer(
        text: textData,
        isAddress: widget.isAddress,
        textStyle: CoconutTypography.body2_14_Number,
        toastMsg: "클립보드에 복사",
        textRichText: widget.textRichText,
      ),
    );
  }
}
