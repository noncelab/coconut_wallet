import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/view_model/donation/onchain_donation_info_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/button/copy_text_container.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math' as math;

class OnchainDonationInfoScreen extends StatefulWidget {
  final int donationAmount;
  const OnchainDonationInfoScreen({
    super.key,
    required this.donationAmount,
  });

  @override
  State<OnchainDonationInfoScreen> createState() => _OnchainDonationInfoScreenState();
}

class _OnchainDonationInfoScreenState extends State<OnchainDonationInfoScreen> {
  late OnchainDonationInfoViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = OnchainDonationInfoViewModel(
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<NodeProvider>(context, listen: false),
      Provider.of<SendInfoProvider>(context, listen: false),
      Provider.of<UpbitConnectModel>(context, listen: false).bitcoinPriceKrw,
      Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn,
      widget.donationAmount,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  void dispose() {
    _viewModel.clearSendInfoProvider();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CoconutAppBar.build(
        title: t.donation.donate,
        context: context,
        backgroundColor: CoconutColors.black,
      ),
      resizeToAvoidBottomInset: false,
      body: ChangeNotifierProxyProvider3<ConnectivityProvider, WalletProvider, UpbitConnectModel,
          OnchainDonationInfoViewModel>(
        create: (_) => _viewModel,
        update: (_, connectivityProvider, walletProvider, upbitConnectModel, viewModel) {
          if (viewModel!.isNetworkOn != connectivityProvider.isNetworkOn) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              viewModel.setIsNetworkOn(connectivityProvider.isNetworkOn);
            });
          }
          if (upbitConnectModel.bitcoinPriceKrw != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              viewModel.setBitcoinPriceKrw(upbitConnectModel.bitcoinPriceKrw!);
            });
          }

          // 지갑 동기화가 끝났을 때 initialize를 호출하여 지갑 목록 업데이트
          if (viewModel.prevIsSyncing && !walletProvider.isSyncing) {
            viewModel.initialize();
          }
          viewModel.prevIsSyncing = walletProvider.isSyncing;

          return viewModel;
        },
        child: Consumer<OnchainDonationInfoViewModel>(
          builder: (context, viewModel, child) {
            WidgetsBinding.instance.addPostFrameCallback((duration) {
              if (viewModel.isRecommendedFeeFetchSuccess != null &&
                  !viewModel.isRecommendedFeeFetchSuccess! &&
                  !viewModel.hasShownFeeErrorToast) {
                CoconutToast.showWarningToast(
                  context: context,
                  text: ErrorCodes.feeEstimationError.message,
                );
                viewModel.setHasShownFeeErrorToast(true);
              }

              if (!viewModel.isSyncing &&
                  viewModel.isRecommendedFeeFetchSuccess == true &&
                  viewModel.availableDonationWalletList.isEmpty &&
                  !viewModel.hasShownNotEnoughBalanceToast) {
                CoconutToast.showWarningToast(
                  context: context,
                  text: t.donation.empty_enough_balance_wallet,
                );
                viewModel.setHasShownNotEnoughBalanceToast(true);
              }
            });
            return SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Container(
                      width: MediaQuery.sizeOf(context).width,
                      padding: const EdgeInsets.only(left: 28, right: 28, top: 30, bottom: 60),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: (viewModel.singlesigWalletList.isNotEmpty &&
                                    (viewModel.isSyncing ||
                                        viewModel.isRecommendedFeeFetchSuccess == null ||
                                        viewModel.availableDonationWalletList.isNotEmpty))
                                ? Stack(
                                    children: [
                                      Column(
                                        children: [
                                          _buildWalletSelectionWidget(),
                                          _divider(topPaddingWidget: CoconutLayout.spacing_300h),
                                          _buildDonationAmountInfoWidget(),
                                          _divider(),
                                        ],
                                      ),
                                      if (viewModel.isSyncing ||
                                          viewModel.isRecommendedFeeFetchSuccess == null)
                                        // 동기화 중이거나 수수료 조회중 일 때
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: Container(
                                              alignment: Alignment.topCenter,
                                              color: CoconutColors.black.withOpacity(0.6),
                                              child: const CoconutCircularIndicator(
                                                size: 150,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  )
                                : const SizedBox(),
                          ),
                          _buildDonationAddressWidget(),
                        ],
                      ),
                    ),
                  ),
                  if (viewModel.availableDonationWalletList.isNotEmpty ||
                      viewModel.isRecommendedFeeFetchSuccess == null) ...[
                    FixedBottomButton(
                      onButtonClicked: () {
                        if (!viewModel.isNetworkOn) {
                          CoconutToast.showWarningToast(
                              context: context, text: ErrorCodes.networkError.message);
                          return;
                        }

                        viewModel.setIsLoading(true);
                        viewModel.saveFinalSendInfo();
                        viewModel.setIsLoading(false);

                        final walletName = viewModel
                            .availableDonationWalletList[viewModel.selectedIndex!].wallet.name;
                        Navigator.pushNamed(context, '/unsigned-transaction-qr',
                            arguments: {'walletName': walletName});
                      },
                      // 버튼 보이지 않을 때: 수수료 조회에 실패, 잔액이 충분한 지갑이 없음
                      // 비활성화 상태로 보일 때: 지갑 동기화 진행 중, 수수료 조회 중,
                      // 활성화 상태로 보일 때: 모든 지갑 동기화 완료, 지갑별 수수료 조회 성공
                      isActive:
                          !viewModel.isSyncing && viewModel.isRecommendedFeeFetchSuccess != null,
                      text: t.next,
                      backgroundColor: CoconutColors.gray100,
                      pressedBackgroundColor: CoconutColors.gray500,
                    ),
                  ],
                  if (viewModel.isLoading) const CoconutCircularIndicator(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _divider(
      {Widget topPaddingWidget = CoconutLayout.spacing_400h,
      Widget bottomPaddingWidget = CoconutLayout.spacing_400h}) {
    return Column(
      children: [
        topPaddingWidget,
        const Divider(
          height: 1,
          color: CoconutColors.gray600,
        ),
        bottomPaddingWidget,
      ],
    );
  }

  Widget _buildWalletSelectionWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            t.donation.donation_wallet,
            style: CoconutTypography.body2_14_Bold.setColor(
              CoconutColors.white,
            ),
          ),
          SizedBox(
            width: _viewModel.availableDonationWalletList.length == 1 ? 60 : 130,
            height: 35,
            child: Row(
              children: [
                if (_viewModel.availableDonationWalletList.length > 1)
                  InkWell(
                    onTap: () {
                      _viewModel.minusSelectedIndex();
                    },
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: Transform.rotate(
                          angle: math.pi / 2,
                          child: SvgPicture.asset(
                            'assets/svg/caret-down.svg',
                            fit: BoxFit.contain,
                            colorFilter:
                                const ColorFilter.mode(CoconutColors.gray400, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_viewModel.selectedIndex != null)
                  Expanded(
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (_viewModel.availableDonationWalletList.length <= 1) return;
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! < -30) {
                            // 왼쪽으로 드래그
                            _viewModel.plusSelectedIndex();
                          } else if (details.primaryVelocity! > 30) {
                            // 오른쪽으로 드래그
                            _viewModel.minusSelectedIndex();
                          }
                        }
                      },
                      child: SizedBox(
                        height: 35,
                        child: Text(
                          _viewModel
                              .availableDonationWalletList[_viewModel.selectedIndex!].wallet.name,
                          style: CoconutTypography.body2_14_Number
                              .setColor(
                                CoconutColors.gray400,
                              )
                              .merge(const TextStyle(
                                height: 2.4,
                              )),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                if (_viewModel.availableDonationWalletList.length > 1)
                  InkWell(
                    onTap: () {
                      _viewModel.plusSelectedIndex();
                    },
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: Transform.rotate(
                          angle: math.pi / 2 * 3,
                          child: SvgPicture.asset(
                            'assets/svg/caret-down.svg',
                            fit: BoxFit.contain,
                            colorFilter:
                                const ColorFilter.mode(CoconutColors.gray400, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationAmountInfoWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.donation.total_donation_amount,
                style: CoconutTypography.body2_14_Bold.setColor(
                  CoconutColors.white,
                ),
              ),
              Text(
                '${_viewModel.selectedIndex == null ? '-' : widget.donationAmount - _viewModel.availableDonationWalletList[_viewModel.selectedIndex!].estimatedFee} sats',
                style: CoconutTypography.body2_14_NumberBold.setColor(
                  CoconutColors.gray400,
                ),
              ),
            ],
          ),
          CoconutLayout.spacing_300h,
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.donation.donation_amount,
                  style: CoconutTypography.body2_14_Bold.setColor(
                    CoconutColors.white,
                  ),
                ),
                Text(
                  '${widget.donationAmount} ${t.sats}',
                  style: CoconutTypography.body2_14_NumberBold.setColor(
                    CoconutColors.gray400,
                  ),
                ),
              ],
            ),
          ),
          CoconutLayout.spacing_300h,
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.fee,
                  style: CoconutTypography.body2_14_Bold.setColor(
                    CoconutColors.white,
                  ),
                ),
                Text(
                  // TODO 수수료
                  '${_viewModel.selectedIndex == null ? '-' : _viewModel.availableDonationWalletList[_viewModel.selectedIndex!].estimatedFee} ${t.sats}',
                  style: CoconutTypography.body2_14_NumberBold.setColor(
                    CoconutColors.gray400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationAddressWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            t.donation.donation_address,
            style: CoconutTypography.body2_14_Bold.setColor(
              CoconutColors.white,
            ),
          ),
        ),
        CoconutLayout.spacing_500h,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
            child: QrImageView(
              backgroundColor: CoconutColors.white,
              data: CoconutWalletApp.kDonationAddress,
              version: QrVersions.auto,
            ),
          ),
        ),
        CoconutLayout.spacing_600h,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CopyTextContainer(
            text: CoconutWalletApp.kDonationAddress,
            textStyle: CoconutTypography.body2_14,
          ),
        ),
      ],
    );
  }

  // 후원 잔액이 충분한 지갑 확인 함수
  // bool isBalanceEnough(int? estimatedFee) {
  //   if (estimatedFee == null || estimatedFee == 0) return false;
  //   return (_confirmedBalance - estimatedFee) > dustLimit;
  // }

  // void saveFinalSendInfo(int estimatedFee, int satsPerVb) {
  //   double finalAmount =
  //       _isMaxMode ? UnitUtil.satoshiToBitcoin(_confirmedBalance - estimatedFee) : _amount;
  //   _sendInfoProvider.setAmount(finalAmount);
  //   _sendInfoProvider.setEstimatedFee(estimatedFee);
  //   _sendInfoProvider.setTransaction(_createTransaction(satsPerVb));
  //   _sendInfoProvider.setFeeBumpfingType(null);
  //   _sendInfoProvider.setWalletImportSource(_walletListItemBase.walletImportSource);
  // }
}
