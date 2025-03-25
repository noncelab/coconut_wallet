import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_list_screen.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/qrcode_info.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:provider/provider.dart';

class ReceiveAddressBottomSheet extends StatelessWidget {
  final int id;

  const ReceiveAddressBottomSheet({
    super.key,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletDetailViewModel>(
      builder: (context, viewModel, _) {
        List<String> paths = viewModel.derivationPath.split('/');
        String index = paths[paths.length - 1];

        return Scaffold(
          backgroundColor: CoconutColors.black,
          appBar: CustomAppBar.build(
            title: t.receive,
            context: context,
            hasRightIcon: false,
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
                                  style: CoconutTypography.body1_16,
                                ),
                                Text(
                                  viewModel.derivationPath,
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: CoconutColors.white.withOpacity(0.15),
                                ),
                                child: const Text(
                                  '전체 주소 보기',
                                  style: CoconutTypography.body3_12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      qrData: viewModel.receiveAddress,
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
