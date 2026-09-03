import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
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
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/extensions/num_extensions.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/fee_bumping_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/common/clipper/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/panel/custom_expansion_panel.dart';
import 'package:coconut_wallet/widgets/common/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/widgets/common/overlays/error_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

enum FeeBumpingType { rbf, cpfp }

class TransactionFeeBumpingScreen extends StatefulWidget {
  final TransactionRecord transaction;
  final FeeBumpingType feeBumpingType;
  final String walletName;
  final int walletId;

  const TransactionFeeBumpingScreen({
    super.key,
    required this.transaction,
    required this.feeBumpingType,
    required this.walletId,
    required this.walletName,
  });

  @override
  State<TransactionFeeBumpingScreen> createState() => _TransactionFeeBumpingScreenState();
}

class _TransactionFeeBumpingScreenState extends State<TransactionFeeBumpingScreen> {
  late FeeBumpingViewModel _viewModel;
  late bool _isRbf;

  final GlobalKey _tooltipIconKey = GlobalKey();
  late Size _tooltipIconSize;
  late Offset _tooltipIconPosition;

  bool _isTooltipVisible = false;
  bool _isRecommendFeePannelExpanded = false;
  bool _isRecommendFeePannelPressed = false;

  bool _isLoading = false;

  final FocusNode _feeTextFieldFocusNode = FocusNode();

  final TextEditingController _textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _viewModel.clearSendInfo();
        }
      },
      child: ChangeNotifierProxyProvider<ConnectivityProvider, FeeBumpingViewModel>(
        create: (_) => _viewModel,
        update: (_, connectivityProvider, viewModel) {
          if (connectivityProvider.isInternetOn != viewModel!.isNetworkOn) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              viewModel.setIsNetworkOn(connectivityProvider.isInternetOn);
            });
          }
          return viewModel;
        },
        child: Consumer<FeeBumpingViewModel>(
          builder: (_, viewModel, child) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _removeTooltip();
                _feeTextFieldFocusNode.unfocus();
              },
              child: ColoredBox(
                color: context.coconutColors.background,
                child: SafeArea(
                  child: Stack(
                    children: [
                      Scaffold(
                        resizeToAvoidBottomInset: true,
                        backgroundColor: context.coconutColors.background,
                        appBar: CoconutAppBar.build(
                          title: _isRbf ? t.transaction_fee_bumping_screen.rbf : t.transaction_fee_bumping_screen.cpfp,
                          context: context,
                          actionButtonList: [
                            IconButton(
                              key: _tooltipIconKey,
                              icon: SvgPicture.asset(
                                CommonStateIconPath.questionMark,
                                colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                              ),
                              onPressed: _toggleTooltip,
                            ),
                          ],
                        ),
                        body: Stack(
                          children: [
                            Column(
                              children: [
                                Visibility(
                                  visible: !viewModel.isNetworkOn,
                                  maintainSize: false,
                                  maintainAnimation: false,
                                  maintainState: false,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
                                    child: ErrorTooltip(
                                      isShown: !viewModel.isNetworkOn,
                                      errorMessage: t.errors.network_error,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: CoconutLayout.defaultPadding,
                                      vertical: 30,
                                    ),
                                    child: Column(
                                      children: [
                                        _buildPendingTxFeeWidget(),
                                        CoconutLayout.spacing_200h,
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                          child: Divider(color: context.coconutColors.divider, height: 1),
                                        ),
                                        CoconutLayout.spacing_500h,
                                        _buildBumpingFeeTextFieldWidget(),
                                        CoconutLayout.spacing_400h,
                                        if (viewModel.isInitializedSuccess == true) ...[
                                          _buildRecommendFeeWidget(),
                                          CoconutLayout.spacing_300h,
                                          _buildCurrentMempoolFeesWidget(
                                            viewModel.feeInfos[0].satsPerVb ?? 0,
                                            viewModel.feeInfos[1].satsPerVb ?? 0,
                                            viewModel.feeInfos[2].satsPerVb ?? 0,
                                          ),
                                          CoconutLayout.spacing_300h,
                                          _buildUtxoSelectionOptionWidget(viewModel),
                                        ] else if (viewModel.didFetchRecommendedFeesSuccessfully == false)
                                          _buildFetchFailedWidget(),
                                        CoconutLayout.spacing_2500h,
                                        CoconutLayout.spacing_2500h,
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            FixedBottomButton(
                              onButtonClicked: () async {
                                _onCompleteButtonPressed(context, viewModel);
                              },
                              text: t.done,
                              backgroundColor: _getFeeBumpingAccentColor(),
                              showSurroundings: true,
                              surroundingsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 40, top: 95),
                              isActive:
                                  viewModel.hasValidTransaction &&
                                  viewModel.unexpectedError == null &&
                                  !viewModel.isFeeBumpingImpossible &&
                                  !viewModel.isUtxoInsufficient &&
                                  !viewModel.isEstimatedFeeTooLow &&
                                  _textEditingController.text.isNotEmpty &&
                                  viewModel.isNetworkOn &&
                                  viewModel.hasMfp,
                              subWidget: _buildBottomStatusWidget(viewModel),
                            ),
                            if (_isLoading) const CoconutLoadingOverlay(),
                          ],
                        ),
                      ),
                      if (_isTooltipVisible) _buildTooltip(context),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    setState(() {
      _isLoading = true;
    });
    //_textEditingController.clear();
    _isRbf = widget.feeBumpingType == FeeBumpingType.rbf;
    _viewModel = _getViewModel(context);
    _viewModel
        .initialize()
        .onError((e, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              String title = t.alert.error_occurs;
              String description = t.alert.contact_admin(error: e.toString());

              if (e is DuplicatedOutputException) {
                title = t.transaction_fee_bumping_screen.dialog.rbf_duplicated_output_title;
                description = t.transaction_fee_bumping_screen.dialog.rbf_duplicated_output;
              } else if (e is UtxoNotFoundException) {
                title = t.transaction_fee_bumping_screen.dialog.utxo_not_found_title;
                description = t.transaction_fee_bumping_screen.dialog.utxo_not_found;
              }

              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return CoconutPopup(
                    languageCode: context.read<PreferenceProvider>().language,
                    title: title,
                    description: description,
                    onTapRight: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    rightButtonText: t.OK,
                  );
                },
              );
            }
          });
        })
        .whenComplete(() {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            // WidgetsBinding.instance.addPostFrameCallback((_) async {
            //   if (_viewModel.isUtxoInsufficient) {
            //     _showInsufficientUtxoToast(context);
            //   }
            // });
          }
        });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tooltipIconRenderBox = _tooltipIconKey.currentContext?.findRenderObject() as RenderBox?;

      if (tooltipIconRenderBox != null) {
        setState(() {
          _tooltipIconPosition = tooltipIconRenderBox.localToGlobal(Offset.zero);
          _tooltipIconSize = tooltipIconRenderBox.size;
        });
      }
    });
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  void _onCompleteButtonPressed(BuildContext context, FeeBumpingViewModel viewModel) async {
    _feeTextFieldFocusNode.unfocus();
    if (viewModel.isEstimatedFeeTooLow) return;
    bool canContinue = await _showConfirmationDialog(context);

    if (!canContinue) return;

    bool success = viewModel.prepareToSend(_textEditingController.text.toDoubleSafe()!);

    if (success && context.mounted) {
      Navigator.pushNamed(context, AppRouteNames.sendConfirm, arguments: const SendConfirmRouteArgs());
    }
  }

  Widget? _buildBottomStatusWidget(FeeBumpingViewModel viewModel) {
    if (viewModel.isFeeBumpingImpossible) {
      return buildErrorText(t.transaction_fee_bumping_screen.insufficient_balance_error);
    }

    final double? feeInput = _textEditingController.text.toDoubleSafe();
    if (_textEditingController.text.isEmpty || feeInput == null || feeInput == 0) {
      return null;
    }

    // 빌드 에러 (fee 무관)
    if (viewModel.unexpectedError != null) {
      return buildErrorText(viewModel.unexpectedError!.toString());
    }

    // Fee 관련 상태
    return buildFeeStatusWidget(viewModel, feeInput);
  }

  Widget buildFeeStatusWidget(FeeBumpingViewModel viewModel, double feeInput) {
    assert(feeInput > 0);

    if (viewModel.deficitSats != null) {
      return buildErrorText(
        t.transaction_fee_bumping_screen.please_select_more_utxo(
          amount: BalanceFormatUtil.formatSatoshiToReadableBitcoin(viewModel.deficitSats!),
        ),
      );
    }

    if (viewModel.isEstimatedFeeTooLow) {
      return buildErrorText(t.transaction_fee_bumping_screen.fee_rate_too_low_error);
    }

    final widgets = [];
    if (viewModel.isEstimatedFeeTooHigh) {
      widgets.add(buildErrorText(t.transaction_fee_bumping_screen.estimated_fee_too_high_error));
      widgets.add(CoconutLayout.spacing_100h);
    }

    return Column(
      children: [
        ...widgets,
        Text(
          t.transaction_fee_bumping_screen.estimated_fee(
            fee: viewModel.getTotalEstimatedFee(feeInput).toThousandsSeparatedString(),
          ),
          style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
          textScaler: const TextScaler.linear(1.0),
        ),
      ],
    );
  }

  Widget buildErrorText(String message) {
    return Text(
      message,
      style: CoconutTypography.body2_14.setColor(context.coconutColors.danger),
      textScaler: const TextScaler.linear(1.0),
    );
  }

  void _onFeeRateChanged(String input) async {
    if (_viewModel.isInitializedSuccess == false) {
      return;
    }

    final feeRate = input.toDoubleSafe();
    _viewModel.onFeeRateChanged(feeRate);
  }

  Future<bool> _showConfirmationDialog(BuildContext context) async {
    if (_viewModel.hasTransactionConfirmed()) {
      await TransactionUtil.showTransactionConfirmedDialog(context);
      return false;
    }
    if (!_viewModel.isEstimatedFeeTooHigh) return true;
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return CoconutPopup(
              languageCode: context.read<PreferenceProvider>().language,
              title: t.transaction_fee_bumping_screen.dialog.fee_alert_title,
              description: t.transaction_fee_bumping_screen.dialog.fee_alert_description,
              onTapRight: () {
                Navigator.pop(context, true);
              },
              onTapLeft: () {
                Navigator.pop(context, false);
              },
            );
          },
        ) ??
        false;
  }

  FeeBumpingViewModel _getViewModel(BuildContext context) {
    final sendInfoProvider = Provider.of<SendInfoProvider>(context, listen: false);
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final nodeProvider = Provider.of<NodeProvider>(context, listen: false);
    final addressRepository = Provider.of<AddressRepository>(context, listen: false);
    final utxoRepositry = Provider.of<UtxoRepository>(context, listen: false);
    final preferenceProvider = Provider.of<PreferenceProvider>(context, listen: false);
    final walletPreferencesRepository = Provider.of<WalletPreferencesRepository>(context, listen: false);

    return FeeBumpingViewModel(
      widget.feeBumpingType,
      widget.transaction,
      widget.walletId,
      sendInfoProvider,
      nodeProvider,
      txProvider,
      walletProvider,
      addressRepository,
      utxoRepositry,
      preferenceProvider,
      walletPreferencesRepository,
      Provider.of<ConnectivityProvider>(context, listen: false).isInternetOn,
    );
  }

  Widget _buildTooltip(BuildContext context) {
    return Positioned(
      top: _tooltipIconPosition.dy + _tooltipIconSize.height - MediaQuery.of(context).padding.top - 10,
      right: 18,
      child: GestureDetector(
        onTap: _removeTooltip,
        child: ClipPath(
          clipper: RightTriangleBubbleClipper(),
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.9,
            padding: const EdgeInsets.only(top: 28, left: 16, right: 16, bottom: 12),
            color: context.coconutColors.popoverBackground,
            child: Text(
              _isRbf ? t.tooltip.rbf : t.tooltip.cpfp,
              style: CoconutTypography.body2_14.copyWith(color: context.coconutColors.popoverText, height: 1.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingTxFeeWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.transaction_fee_bumping_screen.existing_fee,
                style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
              ),
              Text(
                t.transaction_fee_bumping_screen.existing_fee_value(value: widget.transaction.feeRate.toLocaleString()),
                style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
              ),
            ],
          ),
          CoconutLayout.spacing_50h,
          Row(
            children: [
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Text(
                  t.transaction_fee_bumping_screen.existing_fee,
                  style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
                ),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    t.transaction_fee_bumping_screen.total_fee(
                      fee: widget.transaction.fee.toThousandsSeparatedString(),
                      vB: widget.transaction.vSize.toInt().toThousandsSeparatedString(),
                    ),
                    style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBumpingFeeTextFieldWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Selector<FeeBumpingViewModel, ({bool isEstimatedFeeTooLow, bool isUtxoInsufficient})>(
            selector:
                (_, viewModel) => (
                  isEstimatedFeeTooLow: viewModel.isEstimatedFeeTooLow,
                  isUtxoInsufficient: viewModel.isUtxoInsufficient,
                ),
            builder: (_, state, __) {
              return Text(
                t.transaction_fee_bumping_screen.new_fee,
                style: CoconutTypography.body2_14_Bold.setColor(
                  _getFeeBumpingAccentColor(isError: state.isEstimatedFeeTooLow || state.isUtxoInsufficient),
                ),
              );
            },
          ),
          Row(
            children: [
              SizedBox(
                width: 54,
                child: Center(
                  child: CoconutTextField(
                    controller: _textEditingController,
                    focusNode: _feeTextFieldFocusNode,
                    size: CoconutTextFieldSize.compact,
                    textInputType: const TextInputType.numberWithOptions(decimal: true),
                    textInputFormatter: const [RateInputFormatter()],
                    prefix: null,
                    fontFamily: 'SpaceGrotesk',
                    maxLines: 1,
                    isLengthVisible: false,
                    textAlign: TextAlign.center,
                    onChanged: _onFeeRateChanged,
                  ),
                ),
              ),
              CoconutLayout.spacing_200w,
              Text(
                t.transaction_fee_bumping_screen.sats_vb,
                style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendFeeWidget() {
    assert(_viewModel.recommendFeeRate != null);

    return ClipRRect(
      borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      child: CustomExpansionPanel(
        isChildPressed: _isRecommendFeePannelPressed,
        onPannelPressed: (value) {
          setState(() {
            _isRecommendFeePannelPressed = value;
          });
        },
        unExpansionWidget: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 1000),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) {
                    final fadeAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOut);

                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        final t = animation.value;
                        final highlightStrength = 1 - ((t - 0.5).abs() * 2);
                        final color =
                            Color.lerp(
                              context.coconutColors.recommendFeeAnimStart,
                              context.coconutColors.recommendFeeAnimHighlight,
                              highlightStrength,
                            )!;

                        return DefaultTextStyle.merge(
                          style: TextStyle(color: color),
                          child: FadeTransition(opacity: fadeAnimation, child: child),
                        );
                      },
                    );
                  },
                  child: Text(
                    t.transaction_fee_bumping_screen.recommend_fee(fee: _viewModel.recommendFeeRate!.toLocaleString()),
                    key: ValueKey(_viewModel.recommendFeeRate),
                    style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                  ),
                ),
              ),
            ),
            CoconutLayout.spacing_200w,
            AnimatedRotation(
              turns: _isRecommendFeePannelExpanded ? -0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: SvgPicture.asset(
                CommonNavigationIconPath.caretDown,
                colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
              ),
            ),
          ],
        ),
        expansionWidget: GestureDetector(
          onTapDown: (_) {
            setState(() {
              _isRecommendFeePannelPressed = true;
            });
          },
          onTapUp: (_) {
            setState(() {
              _isRecommendFeePannelPressed = false;
              _isRecommendFeePannelExpanded = false;
            });
          },
          onTapCancel: () {
            setState(() {
              _isRecommendFeePannelPressed = false;
            });
          },
          child: Container(
            color:
                _isRecommendFeePannelPressed
                    ? context.coconutColors.surfacePressOverlay
                    : context.coconutColors.surface,
            padding: const EdgeInsets.only(
              left: CoconutLayout.defaultPadding,
              right: CoconutLayout.defaultPadding,
              bottom: CoconutLayout.defaultPadding,
              top: 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(1.5),
                  child: SvgPicture.asset(
                    CommonStateIconPath.circleInfo,
                    colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
                  ),
                ),
                CoconutLayout.spacing_100w,
                if (_viewModel.isInitializedSuccess != null)
                  Expanded(
                    child: Text(
                      _viewModel.isInitializedSuccess == true
                          ? _viewModel.recommendFeeRateDescription!
                          : t.transaction_fee_bumping_screen.recommended_fees_fetch_error,
                      style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                      textScaler: const TextScaler.linear(1.0),
                    ),
                  ),
              ],
            ),
          ),
        ),
        isExpanded: _isRecommendFeePannelExpanded,
        onExpansionChanged: toggleRecommendFeePannel,
      ),
    );
  }

  Widget _buildCurrentMempoolFeesWidget(
    double fastestFeeSatsPerVb,
    double halfhourFeeSatsPerVb,
    double hourFeeSatsPerVb,
  ) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      padding: const EdgeInsets.all(CoconutLayout.defaultPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
        color: context.coconutColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.transaction_fee_bumping_screen.current_fee,
            style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
          ),
          CoconutLayout.spacing_100h,
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Text(
                              TransactionFeeLevel.fastest.text,
                              style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                            ),
                            CoconutLayout.spacing_200w,
                            Text(
                              TransactionFeeLevel.fastest.expectedTime,
                              style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.secondaryText),
                              textScaler: const TextScaler.linear(1.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              t.transaction_fee_bumping_screen.existing_fee_value(
                                value: fastestFeeSatsPerVb.toLocaleString(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Text(
                              TransactionFeeLevel.halfhour.text,
                              style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                            ),
                            CoconutLayout.spacing_200w,
                            Text(
                              TransactionFeeLevel.halfhour.expectedTime,
                              style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.secondaryText),
                              textScaler: const TextScaler.linear(1.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          t.transaction_fee_bumping_screen.existing_fee_value(
                            value: halfhourFeeSatsPerVb.toLocaleString(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Text(
                              TransactionFeeLevel.hour.text,
                              style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                            ),
                            CoconutLayout.spacing_200w,
                            Text(
                              TransactionFeeLevel.hour.expectedTime,
                              style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.secondaryText),
                              textScaler: const TextScaler.linear(1.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          t.transaction_fee_bumping_screen.existing_fee_value(value: hourFeeSatsPerVb.toLocaleString()),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFetchFailedWidget() {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      decoration: BoxDecoration(
        color: context.coconutColors.danger,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SvgPicture.asset(
            CommonStateIconPath.triangleWarning,
            colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
          ),
          CoconutLayout.spacing_200w,
          Text(
            t.transaction_fee_bumping_screen.recommended_fees_fetch_error,
            style: CoconutTypography.body2_14.setColor(context.coconutColors.danger),
          ),
        ],
      ),
    );
  }

  Widget _buildUtxoSelectionOptionWidget(FeeBumpingViewModel viewModel) {
    Widget child;
    if (viewModel.isFeeBumpingImpossible) {
      child = const SizedBox.shrink(key: ValueKey('empty'));
    } else if (!viewModel.isAdditionalInputRequired && !viewModel.isUtxoInsufficient) {
      child = const SizedBox.shrink(key: ValueKey('empty'));
    } else {
      int selectedUtxoSum = viewModel.selectedUtxoList.fold(0, (sum, item) => sum + item.amount);

      String selectedUtxoAmountText = viewModel.currentUnit.displayBitcoinAmount(selectedUtxoSum, withUnit: true);

      if (!viewModel.isUtxoSelectionAuto) {
        if (viewModel.selectedUtxoList.isNotEmpty) {
          selectedUtxoAmountText += t.transaction_fee_bumping_screen.n_utxos(count: viewModel.selectedUtxoList.length);
        } else {
          selectedUtxoAmountText += t.transaction_fee_bumping_screen.no_utxos_selected;
        }
      }

      Color textColor =
          viewModel.selectedUtxoList.isNotEmpty ? context.coconutColors.accentForeground : context.coconutColors.danger;

      child = Container(
        key: const ValueKey('content'),
        width: MediaQuery.sizeOf(context).width,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 27),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
          color: context.coconutColors.surface,
        ),
        child: Column(
          children: [
            buildUtxoOption(viewModel),
            if (!viewModel.isUtxoSelectionAuto) ...[
              Column(children: [CoconutLayout.spacing_400h, buildDivider(), CoconutLayout.spacing_400h]),
              Row(
                children: [
                  Expanded(child: buildSelectedUtxoAmount(selectedUtxoAmountText, textColor: textColor)),
                  CoconutLayout.spacing_200w,
                  buildSelectUtxoButton(viewModel),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(seconds: 1),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: child,
    );
  }

  Widget buildSelectedUtxoAmount(String amountText, {Color? textColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(child: Text(amountText, style: CoconutTypography.body2_14_Number.copyWith(color: textColor))),
      ],
    );
  }

  Widget buildSelectUtxoButton(FeeBumpingViewModel viewModel) {
    return IgnorePointer(
      ignoring: viewModel.isUtxoSelectionAuto,
      child: Opacity(
        opacity: viewModel.isUtxoSelectionAuto ? 0.0 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CoconutButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRouteNames.utxoSelection,
                  arguments: UtxoSelectionRouteArgs(
                    selectedUtxoList: viewModel.selectedUtxoList,
                    id: widget.walletId,
                    currentUnit: viewModel.currentUnit,
                  ),
                ).then((utxoList) {
                  if (utxoList != null) {
                    viewModel.updateSelectedUtxos(utxoList as List<UtxoState>);
                  }
                });
              },
              disabledBackgroundColor: context.coconutColors.surfaceDisabled,
              disabledForegroundColor: context.coconutColors.iconDisabled,
              backgroundColor: context.coconutColors.surfaceButton,
              borderColor: context.coconutColors.border,
              buttonType: CoconutButtonType.outlined,
              borderRadius: 8,
              isActive: true,
              text: t.select_wallet_with_options_bottom_sheet.select_utxo,
              textStyle: CoconutTypography.caption_10.setColor(context.coconutColors.primaryText),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            ),
            CoconutLayout.spacing_100h,
          ],
        ),
      ),
    );
  }

  Widget buildDivider() {
    return Container(color: context.coconutColors.divider, height: 1);
  }

  Widget buildUtxoOption(FeeBumpingViewModel viewModel) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        viewModel.toggleUtxoSelectionAuto();
      },
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.transaction_fee_bumping_screen.utxo_auto_selection,
                    style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                  ),
                  Text(
                    t.transaction_fee_bumping_screen.utxo_auto_selection_description,
                    style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                  ),
                ],
              ),
            ),
          ),
          CoconutLayout.spacing_300w,
          Align(
            alignment: Alignment.centerRight,
            child: CoconutSwitch(
              scale: 0.7,
              isOn: viewModel.isUtxoSelectionAuto,
              activeTrackColor: context.coconutColors.switchActiveTrack,
              activeThumbColor: context.coconutColors.switchActiveThumb,
              inactiveTrackColor: context.coconutColors.switchInactiveTrack,
              inactiveThumbColor: context.coconutColors.switchInactiveThumb,
              onChanged: (_) {
                viewModel.toggleUtxoSelectionAuto();
              },
            ),
          ),
          CoconutLayout.spacing_100w,
        ],
      ),
    );
  }

  Color _getFeeBumpingAccentColor({bool isError = false}) {
    if (isError) {
      return context.coconutColors.danger;
    }
    return _isRbf ? context.coconutColors.rbfAccent : context.coconutColors.cpfpAccent;
  }

  void _removeTooltip() {
    setState(() {
      _isTooltipVisible = false;
    });
  }

  void _toggleTooltip() {
    setState(() {
      _isTooltipVisible = !_isTooltipVisible;
    });
  }

  void toggleRecommendFeePannel() {
    setState(() {
      _isRecommendFeePannelExpanded = !_isRecommendFeePannelExpanded;
    });
  }
}
