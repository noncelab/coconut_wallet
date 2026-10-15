import 'dart:async';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup,
        CoconutTextField,
        CoconutTextFieldStyle;
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/address_search_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/common/qr_with_copy_text_screen.dart';
import 'package:coconut_wallet/utils/address_scan_util.dart';
import 'package:coconut_wallet/widgets/features/wallet/address/address_list_address_item_card.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

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
  String _addressOldText = "";
  Timer? _debounce;
  bool isSearched = false;

  bool get canShowResult => isSearched && _addressController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressChanged);
    viewModel = AddressSearchViewModel(Provider.of<WalletProvider>(context, listen: false), widget.id);
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
    final scannedAddress = await showAddressScannerBottomSheet(context, title: '');
    if (scannedAddress == null || scannedAddress.isEmpty || !mounted) {
      return;
    }

    try {
      await viewModel.validateAddress(scannedAddress);
      if (!mounted) return;
      _addressController.text = scannedAddress;
      _onAddressChanged();
    } catch (e) {
      if (!mounted) return;
      CoconutToast.showToast(isVisibleIcon: true, context: context, text: e.toString());
    }
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
                backgroundColor: context.coconutColors.background,
                appBar: AppBar(
                  scrolledUnderElevation: 0,
                  toolbarHeight: 56,
                  backgroundColor: context.coconutColors.background,
                  leading: IconButton(
                    icon: SvgPicture.asset(
                      CommonNavigationIconPath.arrowBack,
                      colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
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
                      size: CoconutTextFieldSize.search,
                      backgroundColor: context.coconutColors.background,
                      maxLines: 1,
                      clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
                      onClear: () {
                        _addressFocusNode.requestFocus();
                        _addressController.clear();
                      },
                      prefix: IgnorePointer(
                        ignoring: true,
                        child: IconButton(
                          onPressed: null,
                          icon: Icon(Icons.search_rounded, color: context.coconutColors.iconSecondary),
                          iconSize: Sizes.size22,
                        ),
                      ),
                      onSuffixPressed: () {
                        _addressFocusNode.requestFocus();
                        _showAddressScanner();
                      },
                      suffixIconAsset: CommonActionIconPath.scan,
                      suffixIconColor: context.coconutColors.iconPrimary,
                    ),
                  ),
                  titleSpacing: 0,
                ),
                body:
                    canShowResult
                        ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CoconutLayout.spacing_200h,
                              Text(
                                "'${_addressController.text}' ${t.address_search_screen.search_result} ${viewModel.searchedAddressLength > 0 ? t.address_search_screen.address_n_found(n: viewModel.searchedAddressLength) : ""}",
                                style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                              ),
                              CoconutLayout.spacing_200h,
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Consumer<AddressSearchViewModel>(
                                    builder: (context, viewModel, child) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CoconutLayout.spacing_700h,
                                          if (viewModel.receivingAddressList.isNotEmpty) ...[
                                            Text(
                                              t.address_search_screen.receiving_address,
                                              style: CoconutTypography.body2_14_Bold.setColor(
                                                context.coconutColors.primaryText,
                                              ),
                                            ),
                                            CoconutLayout.spacing_300h,
                                            _buildWalletAddressList(viewModel.receivingAddressList),
                                            CoconutLayout.spacing_1000h,
                                          ],
                                          if (viewModel.changeAddressList.isNotEmpty) ...[
                                            Text(
                                              t.address_search_screen.change_address,
                                              style: CoconutTypography.body2_14_Bold.setColor(
                                                context.coconutColors.primaryText,
                                              ),
                                            ),
                                            CoconutLayout.spacing_300h,
                                            _buildWalletAddressList(viewModel.changeAddressList),
                                          ],
                                          if (viewModel.searchedAddressLength == 0) _buildNotFoundView(),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        : Container(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotFoundView() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(Sizes.size12)),
        color: context.coconutColors.surface,
      ),
      padding: const EdgeInsets.only(top: Sizes.size20, bottom: Sizes.size28),
      child: Column(
        children: [
          Text(
            t.address_search_screen.address_not_found,
            style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Sizes.size12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  CommonStateIconPath.circleInfo,
                  colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
                ),
                CoconutLayout.spacing_100w,
                Text(
                  t.address_search_screen.search_range,
                  style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                ),
              ],
            ),
          ),
          Text(
            t.address_search_screen.receiving_address_index(start: 0, end: viewModel.generatedReceiveIndex),
            style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
          ),
          Text(
            t.address_search_screen.change_address_index(start: 0, end: viewModel.generatedChangeIndex),
            style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletAddressList(List<WalletAddress> addressList) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: addressList.length,
      itemBuilder:
          (context, index) => AddressItemCard(
            onPressed: () async {
              FocusManager.instance.primaryFocus?.unfocus();

              await Future.delayed(const Duration(milliseconds: 150));

              if (!context.mounted) return;

              CommonBottomSheets.showCustomHeightBottomSheet(
                context: context,
                screenName: AnalyticsScreenNames.addressSearchAddressQrSheet,
                heightRatio: 0.9,
                child: QrWithCopyTextScreen(
                  backgroundColor: context.coconutColors.surfaceBottomSheet,
                  qrcodeTopWidget: Text(
                    addressList[index].derivationPath,
                    style: CoconutTypography.body2_14.merge(
                      TextStyle(color: context.coconutColors.primaryText.withValues(alpha: 0.7)),
                    ),
                  ),
                  qrData: addressList[index].address,
                  title: t.address_list_screen.address_index(index: index),
                  isBottom: true,
                  showPulldownMenu: false,
                  isAddress: true,
                ),
              );
            },
            address: addressList[index].address,
            derivationPath: addressList[index].derivationPath,
            isUsed: addressList[index].isUsed,
            isWatched: viewModel.isAddressWatched(addressList[index]),
            balanceInSats: addressList[index].total,
            currentUnit: context.read<PreferenceProvider>().currentUnit,
          ),
    );
  }
}
