import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/address_search_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/common/qrcode_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/body/send_address/send_address_body.dart';
import 'package:coconut_wallet/widgets/card/address_list_address_item_card.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key, required this.id});
  final int id;

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  late final AddressSearchViewModel viewModel;
  final _addressController = TextEditingController();
  final _addressFocusNode = FocusNode();
  QRViewController? _qrViewController;
  bool _isQrDataHandling = false;
  String _addressOldText = "";
  Timer? _debounce;
  bool isSearched = false;

  bool get canShowResult => isSearched && _addressController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressChanged);
    viewModel =
        AddressSearchViewModel(Provider.of<WalletProvider>(context, listen: false), widget.id);
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressChanged);
    _addressController.dispose();
    _addressFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onAddressChanged() {
    // 키워드가 동일한 상태에서 키보드가 내려가는 경우 _onAddressChanged 이벤트가 들어오는 현상이 있어서 무시
    if (_addressOldText == _addressController.text) return;
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      viewModel.searchWalletAddressList(_addressController.text);
      isSearched = true;
      setState(() {});
    });

    _addressOldText = _addressController.text;
    isSearched = false;
    setState(() {});
  }

  void _showAddressScanner() async {
    final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
    final String? scannedAddress = await CommonBottomSheets.showBottomSheet_100(
        context: context,
        child: Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: CoconutAppBar.build(
                title: '',
                context: context,
                actionButtonList: [
                  IconButton(
                    icon: SvgPicture.asset('assets/svg/arrow-reload.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          CoconutColors.white,
                          BlendMode.srcIn,
                        )),
                    onPressed: () {
                      _qrViewController?.flipCamera();
                    },
                  ),
                ],
                onBackPressed: () {
                  _disposeQrViewController();
                  Navigator.of(context).pop<String>('');
                }),
            body: SendAddressBody(
              qrKey: qrKey,
              onQrViewCreated: _onQRViewCreated,
            )));
    if (scannedAddress != null) {
      _addressController.text = scannedAddress;
      _onAddressChanged();
    }
    _disposeQrViewController();
  }

  void _onQRViewCreated(QRViewController qrViewController) {
    _qrViewController = qrViewController;
    qrViewController.scannedDataStream.listen((scanData) {
      if (_isQrDataHandling || scanData.code == null) return;
      if (scanData.code!.isEmpty) return;

      _isQrDataHandling = true;
      viewModel.validateAddress(scanData.code!).then((_) {
        if (mounted) {
          Navigator.pop(context, scanData.code!);
        }
      }).catchError((e) {
        if (mounted) {
          CoconutToast.showToast(isVisibleIcon: true, context: context, text: e.toString());
        }
      }).whenComplete(() async {
        // 하나의 QR 스캔으로, 동시에 여러번 호출되는 것을 방지하기 위해
        await Future.delayed(const Duration(seconds: 1));
        _isQrDataHandling = false;
      });
    });
  }

  void _disposeQrViewController() {
    _qrViewController?.dispose();
    _qrViewController = null;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => viewModel,
        child: PopScope(
          canPop: true,
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: Stack(
              children: [
                Scaffold(
                    backgroundColor: CoconutColors.black,
                    appBar: AppBar(
                      scrolledUnderElevation: 0,
                      backgroundColor: CoconutColors.black,
                      leading: IconButton(
                        icon: SvgPicture.asset(
                          'assets/svg/arrow-back.svg',
                          colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                          width: 24,
                          height: 24,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      title: Padding(
                        padding: const EdgeInsets.only(right: Sizes.size16, top: Sizes.size4),
                        child: CoconutTextField(
                          controller: _addressController,
                          focusNode: _addressFocusNode,
                          onChanged: (_) {},
                          maxLines: 1,
                          padding: const EdgeInsets.only(),
                          height: Sizes.size40,
                          prefix: IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.search_rounded, color: CoconutColors.gray600),
                            iconSize: Sizes.size22,
                          ),
                          suffix: IconButton(
                            iconSize: 14,
                            padding: EdgeInsets.zero,
                            onPressed: _addressController.text.isEmpty
                                ? () {
                                    _addressFocusNode.requestFocus();
                                    _showAddressScanner();
                                  }
                                : () {
                                    _addressFocusNode.requestFocus();
                                    _addressController.clear();
                                  },
                            icon: _addressController.text.isEmpty
                                ? SvgPicture.asset('assets/svg/scan.svg')
                                : SvgPicture.asset(
                                    'assets/svg/text-field-clear.svg',
                                    colorFilter: const ColorFilter.mode(
                                        CoconutColors.white, BlendMode.srcIn),
                                  ),
                          ),
                          placeholderText: t.address_search_screen.address_placeholder,
                          activeColor: CoconutColors.gray100,
                          cursorColor: CoconutColors.gray100,
                          placeholderColor: CoconutColors.gray600,
                          backgroundColor: CoconutColors.gray800,
                        ),
                      ),
                      titleSpacing: 0,
                    ),
                    body: canShowResult
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
                            child: SingleChildScrollView(
                              child: Consumer<AddressSearchViewModel>(
                                  builder: (context, viewModel, child) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CoconutLayout.spacing_100h,
                                    Text(
                                      "'${_addressController.text}' ${t.address_search_screen.search_result} ${viewModel.searchedAddressLength > 0 ? t.address_search_screen.address_n_found(n: viewModel.searchedAddressLength) : ""}",
                                      style:
                                          CoconutTypography.body3_12.setColor(CoconutColors.white),
                                    ),
                                    CoconutLayout.spacing_1000h,
                                    if (viewModel.receivingAddressList.isNotEmpty) ...[
                                      Text(t.address_search_screen.receiving_address,
                                          style: CoconutTypography.body2_14_Bold
                                              .setColor(CoconutColors.white)),
                                      CoconutLayout.spacing_300h,
                                      _buildWalletAddressList(viewModel.receivingAddressList),
                                      CoconutLayout.spacing_1000h,
                                    ],
                                    if (viewModel.changeAddressList.isNotEmpty) ...[
                                      Text(t.address_search_screen.change_address,
                                          style: CoconutTypography.body2_14_Bold
                                              .setColor(CoconutColors.white)),
                                      CoconutLayout.spacing_300h,
                                      _buildWalletAddressList(viewModel.changeAddressList),
                                    ],
                                    if (viewModel.searchedAddressLength == 0) _buildNotFoundView(),
                                  ],
                                );
                              }),
                            ),
                          )
                        : Container()),
              ],
            ),
          ),
        ));
  }

  Widget _buildNotFoundView() {
    return Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(Sizes.size12)),
          color: CoconutColors.gray800,
        ),
        padding: const EdgeInsets.only(top: Sizes.size20, bottom: Sizes.size28),
        child: Column(
          children: [
            Text(t.address_search_screen.address_not_found,
                style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Sizes.size12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/svg/circle-info.svg',
                    colorFilter: const ColorFilter.mode(
                      CoconutColors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  CoconutLayout.spacing_100w,
                  Text(t.address_search_screen.search_range,
                      style: CoconutTypography.body3_12.setColor(CoconutColors.white)),
                ],
              ),
            ),
            Text(
                t.address_search_screen
                    .receiving_address_index(start: 0, end: viewModel.generatedReceiveIndex),
                style: CoconutTypography.body3_12.setColor(CoconutColors.white)),
            Text(
                t.address_search_screen
                    .change_address_index(start: 0, end: viewModel.generatedChangeIndex),
                style: CoconutTypography.body3_12.setColor(CoconutColors.white)),
          ],
        ));
  }

  Widget _buildWalletAddressList(List<WalletAddress> addressList) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: addressList.length,
      itemBuilder: (context, index) => AddressItemCard(
        onPressed: () {
          CommonBottomSheets.showBottomSheet_90(
              context: context,
              child: QrcodeBottomSheet(
                  qrcodeTopWidget: Text(
                    addressList[index].derivationPath,
                    style: CoconutTypography.body2_14.merge(
                      TextStyle(
                        color: CoconutColors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                  qrData: addressList[index].address,
                  title: t.address_list_screen.address_index(index: index)));
        },
        address: addressList[index].address,
        derivationPath: addressList[index].derivationPath,
        isUsed: addressList[index].isUsed,
        balanceInSats: addressList[index].total,
        currentUnit: context.read<PreferenceProvider>().currentUnit,
      ),
    );
  }
}
