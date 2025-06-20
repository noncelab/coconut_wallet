import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
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
import 'package:coconut_wallet/widgets/overlays/network_error_tooltip.dart';
import 'package:coconut_wallet/widgets/overlays/number_key_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class FeeSelectionScreen extends StatefulWidget {
  static const String customInputField = 'customInputField';
  static const String selectedOptionField = 'selectedOption';
  static const String feeInfoField = 'feeInfo';
  final bool isBottom;
  final List<FeeInfoWithLevel>? feeInfos;
  final List<UtxoState>? selectedUtxo;
  final TransactionFeeLevel? selectedFeeLevel;
  final FeeInfo? customFeeInfo;
  final int? minimumSatsPerVb;
  final bool? isRecommendedFeeFetchSuccess;
  final int Function(double)? estimateFee;

  const FeeSelectionScreen({
    super.key,
    this.isBottom = false,
    this.feeInfos,
    this.selectedUtxo,
    this.selectedFeeLevel,
    this.customFeeInfo,
    this.minimumSatsPerVb,
    this.isRecommendedFeeFetchSuccess,
    this.estimateFee,
  });

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
                isBottom: widget.isBottom,
                onBackPressed: () {
                  Navigator.pop(context);
                },
                usePrimaryActiveColor: true,
                nextButtonTitle: t.complete,
                onNextPressed: () {
                  if (widget.isBottom) {
                    _onBottomSheetCompleteTap();
                    return;
                  }
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

                      Visibility(
                        visible: viewModel.input.isNotEmpty &&
                            (viewModel.selectedLevel != null || viewModel.isCustomSelected),
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        maintainSemantics: true,
                        maintainInteractivity: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(CoconutStyles.radius_150),
                            color: CoconutColors.white.withOpacity(0.2),
                          ),
                          child: Text(
                              viewModel.isCustomSelected
                                  ? t.input_directly
                                  : viewModel.selectedLevel?.text ?? '',
                              style: Styles.caption),
                        ),
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
                // 추천 수수료 조회 실패 툴팁
                _buildFixedTooltip(
                  opacity: viewModel.isNetworkOn == true &&
                          viewModel.isRecommendedFeeFetchSuccess == false &&
                          viewModel.input.isEmpty
                      ? 1.0
                      : 0.0,
                  tooltipState: CoconutTooltipState.error,
                  richText: RichText(
                    text: TextSpan(text: t.tooltip.recommended_fee1),
                  ),
                ),
                // 최대 수수료 초과 툴팁
                _buildFixedTooltip(
                  opacity: estimatedFee >= _viewModel.maxFeeLimit ? 1.0 : 0.0,
                  tooltipState: CoconutTooltipState.warning,
                  richText: RichText(text: TextSpan(text: recommendedFeeTooltipText)),
                ),
                // 잔액 부족 툴팁
                _buildFixedTooltip(
                  opacity: estimatedFee != 0 &&
                          !_viewModel.isBalanceEnough(estimatedFee) &&
                          estimatedFee < _viewModel.maxFeeLimit
                      ? 1.0
                      : 0.0,
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
                        isEnabled: !isLoading,
                      ),
                    ],
                  ),
                ),
                // 네트워크 연결 실패 툴팁
                NetworkErrorTooltip(isNetworkOn: viewModel.isNetworkOn),
                // if (isLoading) const CoconutLoadingOverlay(),
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
      Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn,
      feeInfos: widget.feeInfos,
      selectedUtxo: widget.selectedUtxo,
      customFeeInfo: widget.customFeeInfo,
      minimumSatsPerVb: widget.minimumSatsPerVb,
      isRecommendedFeeFetchSuccess: widget.isRecommendedFeeFetchSuccess,
      estimateFee: widget.estimateFee,
    );

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Flexible(
          child: _recommendedFeeButtonWidget(
            isRecommendedFeeFetchSuccess,
            'assets/svg/rocket.svg',
            _viewModel.feeInfos[0],
          ),
        ),
        Flexible(
          child: _recommendedFeeButtonWidget(
            isRecommendedFeeFetchSuccess,
            'assets/svg/car.svg',
            _viewModel.feeInfos[1],
          ),
        ),
        Flexible(
          child: _recommendedFeeButtonWidget(
            isRecommendedFeeFetchSuccess,
            'assets/svg/foot.svg',
            _viewModel.feeInfos[2],
          ),
        ),
      ],
    );
  }

  Widget _recommendedFeeButtonWidget(
      bool? isFeeFetchedSuccess, String iconPath, FeeInfoWithLevel feeInfoWithLevel) {
    if (isFeeFetchedSuccess == false) return Container();
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: ShrinkAnimationButton(
            onPressed: () {
              _viewModel.setSelectedLevel(feeInfoWithLevel);
              _viewModel.setEstimatedFee(feeInfoWithLevel.estimatedFee!);
            },
            pressedColor: CoconutColors.gray700,
            borderRadius: CoconutStyles.radius_100 - 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: CoconutColors.black,
                borderRadius: BorderRadius.circular(CoconutStyles.radius_100),
                border: Border.all(
                  color: isFeeFetchedSuccess == true
                      ? !_viewModel.isCustomSelected &&
                              _viewModel.selectedLevel == feeInfoWithLevel.level
                          ? CoconutColors.white
                          : CoconutColors.gray700
                      : CoconutColors.gray800,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    iconPath,
                    colorFilter: isFeeFetchedSuccess == true
                        ? null
                        : const ColorFilter.mode(CoconutColors.gray700, BlendMode.srcIn),
                  ),
                  CoconutLayout.spacing_200w,
                  Text(
                    feeInfoWithLevel.level.text,
                    style: CoconutTypography.body3_12.setColor(
                      isFeeFetchedSuccess == true ? CoconutColors.white : CoconutColors.gray700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isFeeFetchedSuccess == null)
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
      {required RichText richText,
      double opacity = 1,
      CoconutTooltipState tooltipState = CoconutTooltipState.info}) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: CoconutLayout.defaultPadding),
        child: CoconutToolTip(
          richText: richText,
          showIcon: true,
          tooltipType: CoconutTooltipType.fixed,
          tooltipState: tooltipState,
        ),
      ),
    );
  }

  void _onBottomSheetCompleteTap() {
    Map<String, dynamic> returnData = {
      FeeSelectionScreen.customInputField: _viewModel.isCustomSelected,
      FeeSelectionScreen.selectedOptionField: _viewModel.selectedLevel,
      FeeSelectionScreen.feeInfoField: (_viewModel.customFeeInfo?.satsPerVb != null)
          ? FeeInfo(
              estimatedFee: _viewModel.estimatedFee, satsPerVb: _viewModel.customFeeInfo?.satsPerVb)
          : _viewModel.findFeeInfoWithLevel(),
    };

    Navigator.pop(context, returnData);
  }
}
