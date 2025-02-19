import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_list_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/qrcode_info.dart';

class ReceiveAddressBottomSheet extends StatelessWidget {
  final int id;
  final String address;
  final String derivationPath;
  const ReceiveAddressBottomSheet({
    super.key,
    required this.id,
    required this.address,
    required this.derivationPath,
  });

  @override
  Widget build(BuildContext context) {
    List<String> paths = derivationPath.split('/');
    String index = paths[paths.length - 1];

    return CoconutBottomSheet(
      appBar: CoconutAppBar.build(
        context: context,
        title: t.receive,
        hasRightIcon: false,
        isBottom: true,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: Paddings.container,
          child: Column(
            children: [
              QRCodeInfo(
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
                            '주소 - $index',
                            style: Styles.body1,
                          ),
                          Text(
                            derivationPath,
                            style: Styles.body2.copyWith(
                              color: MyColors.transparentWhite_70,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          // TODO: AddressListScreen Appbar
                          CommonBottomSheets.showBottomSheetWithScreen(
                            context: context,
                            child: AddressListScreen(
                              id: id,
                              isFullScreen: false,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: MyColors.transparentWhite_15,
                          ),
                          child: Text(
                            t.view_all_addresses,
                            style: Styles.caption.copyWith(
                                fontFamily: CustomFonts.text.getFontFamily),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                qrData: address,
              )
            ],
          ),
        ),
      ),
    );
  }
}
