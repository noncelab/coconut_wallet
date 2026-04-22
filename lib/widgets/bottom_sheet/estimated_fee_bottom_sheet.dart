import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/utils/fee_rate_mixin.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/ripple_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class EstimatedFeeBottomSheet extends StatelessWidget {
  final ScrollController scrollController;
  final Listenable listenable;
  final String Function() estimatedFeeTextGetter;
  final TextEditingController feeRateController;
  final FocusNode feeRateFocusNode;
  final bool Function(String) onFeeRateChanged;
  final VoidCallback onEditingComplete;
  final RecommendedFeeFetchStatus Function() recommendedFeeFetchStatusGetter;
  final List<FeeInfoWithLevel> Function() feeInfosGetter;
  final VoidCallback refreshRecommendedFees;
  final void Function(double) onFeeRateSelected;

  const EstimatedFeeBottomSheet({
    super.key,
    required this.scrollController,
    required this.listenable,
    required this.estimatedFeeTextGetter,
    required this.feeRateController,
    required this.feeRateFocusNode,
    required this.onFeeRateChanged,
    required this.onEditingComplete,
    required this.recommendedFeeFetchStatusGetter,
    required this.feeInfosGetter,
    required this.refreshRecommendedFees,
    required this.onFeeRateSelected,
  });

  static void show({
    required BuildContext context,
    required Listenable listenable,
    required String Function() estimatedFeeTextGetter,
    required TextEditingController feeRateController,
    required FocusNode feeRateFocusNode,
    required bool Function(String) onFeeRateChanged,
    required VoidCallback onEditingComplete,
    required RecommendedFeeFetchStatus Function() recommendedFeeFetchStatusGetter,
    required List<FeeInfoWithLevel> Function() feeInfosGetter,
    required VoidCallback refreshRecommendedFees,
    required void Function(double) onFeeRateSelected,
  }) {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (context.mounted) {
        feeRateFocusNode.requestFocus();
      }
    });

    CommonBottomSheets.showDraggableBottomSheet(
      context: context,
      title: t.estimated_fee_bottom_sheet.title,
      backgroundColor: CoconutColors.gray900,
      initialChildSize: 0.75,
      minChildSize: 0.74,
      maxChildSize: 0.9,
      childBuilder: (scrollController) {
        return EstimatedFeeBottomSheet(
          scrollController: scrollController,
          listenable: listenable,
          estimatedFeeTextGetter: estimatedFeeTextGetter,
          feeRateController: feeRateController,
          feeRateFocusNode: feeRateFocusNode,
          onFeeRateChanged: onFeeRateChanged,
          onEditingComplete: onEditingComplete,
          recommendedFeeFetchStatusGetter: recommendedFeeFetchStatusGetter,
          feeInfosGetter: feeInfosGetter,
          refreshRecommendedFees: refreshRecommendedFees,
          onFeeRateSelected: onFeeRateSelected,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    children: [_buildExpectedFeeRow(), CoconutLayout.spacing_200h, _buildFeeRateInputRow(context)],
                  ),
                ),
                CoconutLayout.spacing_400h,
              ],
            ),
          ),
        ),
        _buildFeeRateKeyboardToolbar(context),
      ],
    );
  }

  Widget _buildExpectedFeeRow() {
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t.estimated_fee_bottom_sheet.estimated_fee,
              style: CoconutTypography.body3_12.setColor(CoconutColors.gray500),
            ),
            CoconutLayout.spacing_200w,
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerRight,
                fit: BoxFit.scaleDown,
                child: Text(
                  estimatedFeeTextGetter(),
                  style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeeRateInputRow(BuildContext context) {
    return Row(
      children: [
        Text(t.estimated_fee_bottom_sheet.fee_rate, style: CoconutTypography.body3_12.setColor(CoconutColors.gray500)),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: IntrinsicWidth(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 110),
                    child: CoconutTextField(
                      textInputType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                      textInputAction: TextInputAction.done,
                      textInputFormatter: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      enableInteractiveSelection: false,
                      textAlign: TextAlign.end,
                      controller: feeRateController,
                      focusNode: feeRateFocusNode,
                      backgroundColor: CoconutColors.gray700,
                      onEditingComplete: onEditingComplete,
                      height: 30,
                      padding: const EdgeInsets.only(left: 12, right: 2),
                      onChanged: (text) {
                        final isTooLow = onFeeRateChanged(text);
                        if (isTooLow) {
                          Fluttertoast.showToast(
                            msg: t.send_screen.fee_rate_too_low,
                            backgroundColor: CoconutColors.gray700,
                            toastLength: Toast.LENGTH_SHORT,
                          );
                        }
                      },
                      maxLines: 1,
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 14,
                      activeColor: CoconutColors.white,
                      fontWeight: FontWeight.bold,
                      borderRadius: 8,
                      suffix: Container(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          t.send_screen.fee_rate_suffix,
                          style: CoconutTypography.body2_14_NumberBold.setColor(CoconutColors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeeRateKeyboardToolbar(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, child) {
        return ListenableBuilder(
          listenable: listenable,
          builder: (context, child) {
            final recommendedFeeFetchStatus = recommendedFeeFetchStatusGetter();
            final isNetworkOn = connectivity.isInternetOn;

            if (isNetworkOn && recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                refreshRecommendedFees();
              });
            }

            final isFailed = recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed;
            final isFetching = recommendedFeeFetchStatus == RecommendedFeeFetchStatus.fetching;
            final feeInfos = feeInfosGetter();

            return Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              color: const Color(0xFF2E2E2E), // keyboardToolbarGray
              child: Row(
                children: [
                  if (isFailed) ...[
                    SvgPicture.asset(
                      'assets/svg/triangle-warning.svg',
                      colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                      width: 20,
                    ),
                    CoconutLayout.spacing_200w,
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.send_screen.recommended_fee_unavailable,
                          style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                        ),
                        Text(
                          t.send_screen.recommended_fee_unavailable_description,
                          style: CoconutTypography.body3_12.setColor(CoconutColors.gray300),
                        ),
                      ],
                    ),
                  ] else ...[
                    _buildFeeItem(context, 'assets/svg/fee-rate/low.svg', feeInfos[2].satsPerVb, isFetching),
                    CoconutLayout.spacing_150w,
                    _buildFeeItem(context, 'assets/svg/fee-rate/medium.svg', feeInfos[1].satsPerVb, isFetching),
                    CoconutLayout.spacing_150w,
                    _buildFeeItem(context, 'assets/svg/fee-rate/high.svg', feeInfos[0].satsPerVb, isFetching),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeeItem(BuildContext context, String imagePath, double? sats, bool isFetching) {
    final child = MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(width: 1, color: CoconutColors.gray700),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              imagePath,
              height: 12,
              colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
            ),
            CoconutLayout.spacing_100w,
            Text(
              "${sats != null ? sats.toStringAsFixed(1) : "-"} ${t.send_screen.fee_rate_suffix}",
              style: CoconutTypography.body2_14.setColor(CoconutColors.white),
            ),
          ],
        ),
      ),
    );

    return Expanded(
      child: RippleEffect(
        borderRadius: 8,
        onTap: () {
          if (isFetching) return;
          if (sats != null) {
            onFeeRateSelected(sats);
          }
        },
        child:
            !isFetching
                ? child
                : Shimmer.fromColors(
                  baseColor: CoconutColors.white.withValues(alpha: 0.2),
                  highlightColor: CoconutColors.white.withValues(alpha: 0.6),
                  child: child,
                ),
      ),
    );
  }
}
