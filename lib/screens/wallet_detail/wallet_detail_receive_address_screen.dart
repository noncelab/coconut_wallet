import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/refactor/select_wallet_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_list_screen.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/qrcode_info.dart';
import 'package:provider/provider.dart';

class ReceiveAddressScreen extends StatefulWidget {
  final int id;

  const ReceiveAddressScreen({
    super.key,
    required this.id,
  });

  @override
  State<ReceiveAddressScreen> createState() => _ReceiveAddressScreenState();
}

class _ReceiveAddressScreenState extends State<ReceiveAddressScreen> {
  WalletListItemBase? _selectedWalletItem;
  WalletAddress? _receiveAddress;

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

  int get selectedWalletId => _selectedWalletItem != null ? _selectedWalletItem!.id : -1;

  @override
  void initState() {
    super.initState();
    if (widget.id == -1) return;

    final walletProvider = context.read<WalletProvider>();
    _selectedWalletItem = walletProvider.walletItemList.where((e) => e.id == widget.id).first;
    _receiveAddress = walletProvider.getReceiveAddress(_selectedWalletItem!.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(
          title: t.receive,
          customTitle: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_selectedWalletItem?.name ?? t.send_screen.select_wallet,
                      style: CoconutTypography.body1_16),
                  CoconutLayout.spacing_50w,
                  const Icon(Icons.keyboard_arrow_down_sharp, color: CoconutColors.white, size: 16),
                ],
              ),
            ],
          ),
          onTitlePressed: _onAppBarTitlePressed,
          context: context,
          isBottom: true,
          actionButtonList: [
            const SizedBox(width: 24, height: 24),
          ],
          onBackPressed: () {
            Navigator.of(context).pop();
          }),
      body: _selectedWalletItem != null
          ? SafeArea(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      QrCodeInfo(
                        qrcodeTopWidget: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                                        t.address_list_screen
                                            .address_index(index: receiveAddressIndex),
                                        style: CoconutTypography.body1_16,
                                      ),
                                      Text(
                                        derivationPath,
                                        style: CoconutTypography.body2_14.setColor(
                                          CoconutColors.white.withOpacity(0.7),
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
                                    color: CoconutColors.white.withOpacity(0.15),
                                  ),
                                  child: Text(
                                    t.view_all_addresses,
                                    style: CoconutTypography.body3_12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        qrData: receiveAddress,
                        isAddress: true,
                      )
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  void _onAddressListButtonPressed() {
    CommonBottomSheets.showBottomSheet_90(
        context: context,
        child: AppGuard(
          child: AddressListScreen(
            id: _selectedWalletItem!.id,
            isFullScreen: false,
          ),
        ));
  }

  void _onAppBarTitlePressed() {
    CommonBottomSheets.showDraggableBottomSheetWithAppGuard(
        context: context,
        childBuilder: (scrollController) => AppGuard(
                child: SelectWalletBottomSheet(
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
            )));
  }
}
