import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/view_model/send/fee_selection_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/widgets/overlays/network_error_tooltip.dart';
import 'package:coconut_wallet/widgets/overlays/number_key_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class FeeSelectionScreen extends StatefulWidget {
  const FeeSelectionScreen({super.key});

  @override
  State<FeeSelectionScreen> createState() => _FeeSelectionScreenState();
}

class _FeeSelectionScreenState extends State<FeeSelectionScreen> {
  late FeeSelectionViewModel _viewModel;
  late BitcoinUnit _currentUnit;

  String get recommendedFeeTooltipText => t.tooltip
      .recommended_fee2(bitcoin: UnitUtil.satoshiToBitcoin(_viewModel.maxFeeLimit), unit: t.btc);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider3<ConnectivityProvider, WalletProvider, UpbitConnectModel,
        FeeSelectionViewModel>(
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

        return viewModel;
      },
      child: Consumer<FeeSelectionViewModel>(
        builder: (context, viewModel, child) {
          int? estimatedFee = viewModel.estimatedFee;
          bool? isLoading = viewModel.isLoading;
          bool isCustomSelected = viewModel.isCustomSelected;
          bool canGoNext = viewModel.canGoNext();
          FeeInfo? customFeeInfo = viewModel.customFeeInfo;
          return Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: CoconutAppBar.buildWithNext(
                title: t.fee,
                context: context,
                isActive: canGoNext,
                onBackPressed: () {
                  Navigator.pop(context);
                },
                usePrimaryActiveColor: true,
                nextButtonTitle: t.complete,
                onNextPressed: () {
                  double finalFeeRate = isCustomSelected
                      ? customFeeInfo!.satsPerVb!
                      : viewModel.feeInfos
                          .firstWhere((element) => element.level == viewModel.selectedLevel)
                          .satsPerVb!;

                  _viewModel.saveFinalSendInfo(viewModel.estimatedFee!, finalFeeRate);
                  Navigator.pushNamed(context, '/send-confirm');
                }),
            body: Stack(
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height -
                      kToolbarHeight -
                      MediaQuery.of(context).padding.top,
                  width: MediaQuery.sizeOf(context).width,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        height: 80,
                      ),
                      // Fee 선택 현황
                      if (viewModel.selectedLevel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(CoconutStyles.radius_150),
                            color: CoconutColors.white.withOpacity(0.2),
                          ),
                          child: Text(viewModel.selectedLevel!.text, style: Styles.caption),
                        ),
                      CoconutLayout.spacing_300h,
                      // sat/vB
                      Text(
                        '${viewModel.input.isEmpty ? 0 : viewModel.input} ${t.sat_vb}',
                        style: TextStyle(
                          fontFamily: CustomFonts.number.getFontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 38,
                          color: viewModel.input.isEmpty
                              ? CoconutColors.white.withOpacity(0.2)
                              : CoconutColors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (viewModel.isCustomFeeTooLow && viewModel.minimumSatsPerVb != null)
                        Column(
                          children: [
                            CoconutLayout.spacing_100h,
                            Text(
                              t.minimum_fee_rate_message(minimum: viewModel.minimumSatsPerVb!),
                              style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink),
                            ),
                          ],
                        ),
                      CoconutLayout.spacing_300h,
                      Text(
                        t.total_sats(value: addCommasToIntegerPart(estimatedFee!.toDouble())),
                        style: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray500),
                      ),
                    ],
                  ),
                ),
                if (viewModel.isNetworkOn == true &&
                    viewModel.isRecommendedFeeFetchSuccess == false)
                  _buildFixedTooltip(
                      tooltipState: CoconutTooltipState.error,
                      richText: RichText(text: TextSpan(text: t.tooltip.recommended_fee1))),
                if (estimatedFee >= _viewModel.maxFeeLimit)
                  _buildFixedTooltip(
                    tooltipState: CoconutTooltipState.warning,
                    richText: RichText(text: TextSpan(text: recommendedFeeTooltipText)),
                  ),
                if (estimatedFee != 0 &&
                    !_viewModel.isBalanceEnough(estimatedFee) &&
                    estimatedFee < _viewModel.maxFeeLimit)
                  _buildFixedTooltip(
                    tooltipState: CoconutTooltipState.warning,
                    richText: RichText(text: TextSpan(text: t.errors.insufficient_balance)),
                  ),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      _recommendedFeeRowWidget(),
                      CoconutLayout.spacing_700h,
                      NumberKeyPad(
                        currentUnit: _currentUnit,
                        onKeyTap: _viewModel.onKeyTap,
                      ),
                    ],
                  ),
                ),
                NetworkErrorTooltip(isNetworkOn: viewModel.isNetworkOn),
                if (isLoading) const CoconutLoadingOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentUnit = context.read<PreferenceProvider>().currentUnit;
    _viewModel = FeeSelectionViewModel(
        Provider.of<SendInfoProvider>(context, listen: false),
        Provider.of<WalletProvider>(context, listen: false),
        Provider.of<NodeProvider>(context, listen: false),
        Provider.of<UpbitConnectModel>(context, listen: false).bitcoinPriceKrw,
        Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_viewModel.isNetworkOn) {
        _viewModel.startToSetRecommendedFee();
      }
    });
  }

  Widget _recommendedFeeRowWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: _buildRecommendedFeeButtons(),
    );
  }

  Widget _buildRecommendedFeeButtons() {
    bool? isRecommendedFeeFetchSuccess = _viewModel.isRecommendedFeeFetchSuccess;
    bool isFeeFetchedSuccess = isRecommendedFeeFetchSuccess != null && isRecommendedFeeFetchSuccess;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Flexible(
          child: _recommendedFeeButtonWidget(
            isFeeFetchedSuccess,
            'assets/svg/rocket.svg',
            t.transaction_enums.high,
          ),
        ),
        Flexible(
          child: _recommendedFeeButtonWidget(
            isFeeFetchedSuccess,
            'assets/svg/car.svg',
            t.transaction_enums.medium,
          ),
        ),
        Flexible(
          child: _recommendedFeeButtonWidget(
            isFeeFetchedSuccess,
            'assets/svg/foot.svg',
            t.transaction_enums.low,
          ),
        ),
      ],
    );
  }

  Widget _recommendedFeeButtonWidget(bool isFeeFetchedSuccess, String iconPath, String text) {
    FeeInfoWithLevel selectedFeeInfo = text == t.transaction_enums.high
        ? _viewModel.feeInfos[0]
        : text == t.transaction_enums.medium
            ? _viewModel.feeInfos[1]
            : _viewModel.feeInfos[2];
    return Stack(
      children: [
        ShrinkAnimationButton(
          onPressed: () {
            _viewModel.setSelectedLevel(selectedFeeInfo.level);
            _viewModel.setSelectedFeeLevelText(selectedFeeInfo.level.text);
            _viewModel.setEstimatedFee(selectedFeeInfo.estimatedFee!);
            _viewModel.setCustomSelected(false);
            debugPrint('selectedFeeLevel : ${selectedFeeInfo.level} ${_viewModel.estimatedFee}');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: CoconutColors.black,
              borderRadius: BorderRadius.circular(CoconutStyles.radius_100),
              border: Border.all(
                color: isFeeFetchedSuccess ? CoconutColors.gray700 : CoconutColors.gray800,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  iconPath,
                  colorFilter: isFeeFetchedSuccess
                      ? null
                      : const ColorFilter.mode(CoconutColors.gray700, BlendMode.srcIn),
                ),
                CoconutLayout.spacing_200w,
                Text(
                  text,
                  style: CoconutTypography.body3_12.setColor(
                    isFeeFetchedSuccess ? CoconutColors.white : CoconutColors.gray700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isFeeFetchedSuccess)
          Shimmer.fromColors(
            baseColor: CoconutColors.white.withOpacity(0.2),
            highlightColor: CoconutColors.white.withOpacity(0.6),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: CoconutColors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(CoconutStyles.radius_100),
                border: Border.all(
                  color: Colors.transparent,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '',
                    style: CoconutTypography.body3_12,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFixedTooltip(
      {required RichText richText, CoconutTooltipState tooltipState = CoconutTooltipState.info}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: CoconutLayout.defaultPadding),
      child: CoconutToolTip(
        richText: richText,
        showIcon: true,
        tooltipType: CoconutTooltipType.fixed,
        tooltipState: tooltipState,
      ),
    );
  }
}
