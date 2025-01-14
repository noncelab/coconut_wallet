import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_list_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/bottom_sheet.dart';
import 'package:coconut_wallet/widgets/qrcode_info.dart';
import 'package:provider/provider.dart';

// TODO: ViewModel - 위젯 내부 Provider 제거
class ReceiveAddressBottomSheet extends StatefulWidget {
  final int id;

  const ReceiveAddressBottomSheet({super.key, required this.id});

  @override
  State<ReceiveAddressBottomSheet> createState() =>
      _ReceiveAddressBottomSheetState();
}

class _ReceiveAddressBottomSheetState extends State<ReceiveAddressBottomSheet> {
  late String _address;
  late String _derivationPath;

  @override
  void initState() {
    super.initState();
    final model = Provider.of<AppStateModel>(context, listen: false);
    Address address =
        model.getWalletById(widget.id).walletBase.getReceiveAddress();
    _address = address.address;
    _derivationPath = address.derivationPath;
  }

  @override
  Widget build(BuildContext context) {
    List<String> paths = _derivationPath.split('/');
    String index = paths[paths.length - 1];
    return Scaffold(
      backgroundColor: MyColors.black,
      appBar: CustomAppBar.build(
        title: '받기',
        context: context,
        hasRightIcon: false,
        isBottom: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                                _derivationPath,
                                style: Styles.body2.merge(const TextStyle(
                                    color: MyColors.transparentWhite_70)),
                              ),
                            ]),
                        GestureDetector(
                            onTap: () {
                              MyBottomSheet.showBottomSheet_90(
                                  context: context,
                                  child: AddressListScreen(
                                    id: widget.id,
                                    isFullScreen: false,
                                  ));
                            },
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: MyColors.transparentWhite_15,
                                ),
                                child: Text('전체 주소 보기',
                                    style: Styles.caption.merge(TextStyle(
                                        fontFamily:
                                            CustomFonts.text.getFontFamily)))))
                      ],
                    ),
                  ),
                  qrData: _address,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
