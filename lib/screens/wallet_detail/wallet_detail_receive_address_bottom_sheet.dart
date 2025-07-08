import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_list_screen.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/qrcode_info.dart';

class ReceiveAddressBottomSheet extends StatelessWidget {
  final int id;
  final String derivationPath;
  final String receiveAddressIndex;
  final String receiveAddress;

  const ReceiveAddressBottomSheet({
    super.key,
    required this.id,
    required this.derivationPath,
    required this.receiveAddressIndex,
    required this.receiveAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(
        title: t.receive,
        context: context,
        isBottom: true,
      ),
      body: SafeArea(
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.address_list_screen.address_index(index: receiveAddressIndex),
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
                        GestureDetector(
                          onTap: () {
                            CommonBottomSheets.showBottomSheet_90(
                              context: context,
                              child: AddressListScreen(
                                id: id,
                                isFullScreen: false,
                              ),
                            );
                          },
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
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
