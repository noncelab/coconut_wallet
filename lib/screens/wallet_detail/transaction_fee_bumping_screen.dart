import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
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
import 'package:coconut_wallet/utils/text_field_filter_util.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/utils/wallet_util.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/custom_expansion_panel.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/widgets/overlays/network_error_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

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

  bool _isEstimatedFeeTooLow = false;
  bool _isEstimatedFeeTooHigh = false;

  bool _isLoading = false;

  final FocusNode _feeTextFieldFocusNode = FocusNode();

  final TextEditingController _textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<ConnectivityProvider, FeeBumpingViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, viewModel) {
        if (connectivityProvider.isNetworkOn != viewModel!.isNetworkOn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            viewModel.setIsNetworkOn(connectivityProvider.isNetworkOn);
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
            child: SafeArea(
              child: Stack(
                children: [
                  Scaffold(
                    resizeToAvoidBottomInset: true,
                    backgroundColor: CoconutColors.black,
                    appBar: CoconutAppBar.build(
                      title: _isRbf ? t.transaction_fee_bumping_screen.rbf : t.transaction_fee_bumping_screen.cpfp,
                      context: context,
                      actionButtonList: [
                        IconButton(
                          key: _tooltipIconKey,
                          icon: SvgPicture.asset('assets/svg/question-mark.svg'),
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
                              child: NetworkErrorTooltip(isNetworkOn: viewModel.isNetworkOn),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
                                  margin: const EdgeInsets.symmetric(vertical: 30),
                                  height:
                                      MediaQuery.sizeOf(context).height -
                                      kToolbarHeight -
                                      MediaQuery.of(context).padding.top -
                                      60,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        _buildPendingTxFeeWidget(),
                                        CoconutLayout.spacing_200h,
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 3),
                                          child: Divider(color: CoconutColors.gray800, height: 1),
                                        ),
                                        CoconutLayout.spacing_500h,
                                        _buildBumpingFeeTextFieldWidget(),
                                        CoconutLayout.spacing_400h,
                                        if (viewModel.isInitializedSuccess == true) ...[
                                          _buildRecommendFeeWidget(),
                                          CoconutLayout.spacing_300h,
                                          _buildCurrentMempoolFeesWidget(
                                            viewModel.feeInfos[0].satsPerVb?.toInt() ?? 0,
                                            viewModel.feeInfos[1].satsPerVb?.toInt() ?? 0,
                                            viewModel.feeInfos[2].satsPerVb?.toInt() ?? 0,
                                          ),
                                          CoconutLayout.spacing_300h,
                                          _buildUtxoSelectionOptionWidget(viewModel),
                                        ] else if (viewModel.didFetchRecommendedFeesSuccessfully == false)
                                          _buildFetchFailedWidget(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        FixedBottomButton(
                          onButtonClicked: () async {
                            _onCompleteButtonPressed(context, viewModel);
                          },
                          text: t.complete,
                          backgroundColor: _getNewFeeTextColor(),
                          showGradient: true,
                          gradientPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 40, top: 150),
                          isActive:
                              !viewModel.insufficientUtxos &&
                              !_isEstimatedFeeTooLow &&
                              _textEditingController.text.isNotEmpty &&
                              viewModel.isNetworkOn,
                          subWidget:
                              _textEditingController.text.isEmpty || _textEditingController.text == '0'
                                  ? Container()
                                  : Column(
                                    children: [
                                      if (_isEstimatedFeeTooHigh) ...[
                                        Text(
                                          t.transaction_fee_bumping_screen.estimated_fee_too_high_error,
                                          style: CoconutTypography.body2_14.setColor(CoconutColors.hotPink),
                                          textScaler: const TextScaler.linear(1.0),
                                        ),
                                        CoconutLayout.spacing_100h,
                                      ],
                                      if (_viewModel.insufficientUtxos) ...[
                                        Text(
                                          t.transaction_fee_bumping_screen.insufficient_balance_error,
                                          style: CoconutTypography.body2_14.setColor(CoconutColors.hotPink),
                                          textScaler: const TextScaler.linear(1.0),
                                        ),
                                      ] else if (_isEstimatedFeeTooLow) ...[
                                        Text(
                                          t.transaction_fee_bumping_screen.fee_rate_too_low_error,
                                          style: CoconutTypography.body2_14.setColor(CoconutColors.hotPink),
                                          textScaler: const TextScaler.linear(1.0),
                                        ),
                                      ] else ...[
                                        Text(
                                          t.transaction_fee_bumping_screen.estimated_fee(
                                            fee:
                                                viewModel
                                                    .getTotalEstimatedFee(
                                                      double.tryParse(_textEditingController.text) ?? 0.0,
                                                    )
                                                    .toThousandsSeparatedString(),
                                          ),
                                          style: CoconutTypography.body2_14,
                                          textScaler: const TextScaler.linear(1.0),
                                        ),
                                      ],
                                    ],
                                  ),
                        ),
                        if (_isLoading) const CoconutLoadingOverlay(),
                      ],
                    ),
                  ),
                  if (_isTooltipVisible) _buildTooltip(context),
                ],
              ),
            ),
          );
        },
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
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return CoconutPopup(
                    languageCode: context.read<PreferenceProvider>().language,
                    title: t.alert.error_occurs,
                    description: t.alert.contact_admin(error: e.toString()),
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
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (_viewModel.insufficientUtxos) {
                _showInsufficientUtxoToast(context);
              }
            });
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
    if (_isEstimatedFeeTooLow) return;
    bool canContinue = await _showConfirmationDialog(context);

    if (!canContinue) return;

    bool success = await viewModel.prepareToSend(double.parse(_textEditingController.text));

    if (success && context.mounted) {
      Navigator.pushNamed(context, '/unsigned-transaction-qr', arguments: {'walletName': widget.walletName});
    }
  }

  void _onFeeRateChanged(String input) async {
    if (_viewModel.isInitializedSuccess == false) {
      return;
    }

    if (input.isEmpty) {
      _viewModel.initializeBumpingTransaction(0);
      setState(() {
        _isEstimatedFeeTooLow = false;
        _isEstimatedFeeTooHigh = false;
      });
      return;
    }

    _textEditingController.text = filterNumericInput(input, decimalPlaces: 2);
    _textEditingController.selection = TextSelection.collapsed(offset: _textEditingController.text.length);

    double? value = double.tryParse(_textEditingController.text);

    if (value == null) {
      setState(() {
        _isEstimatedFeeTooLow = true;
        _isEstimatedFeeTooHigh = false;
      });

      return;
    }

    bool isFeeTooLow = _viewModel.isFeeRateTooLow(value);

    await _viewModel.initializeBumpingTransaction(value).then((_) {
      if (_viewModel.insufficientUtxos) {
        if (mounted) {
          _showInsufficientUtxoToast(context);
        }
      }
    });

    setState(() {
      _isEstimatedFeeTooHigh = _viewModel.getTotalEstimatedFee(value) >= 1000000;
      _isEstimatedFeeTooLow = isFeeTooLow;
    });
  }

  Future<bool> _showConfirmationDialog(BuildContext context) async {
    if (_viewModel.hasTransactionConfirmed()) {
      await TransactionUtil.showTransactionConfirmedDialog(context);
      return false;
    }
    if (!_isEstimatedFeeTooHigh) return true;
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
      Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn,
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
            color: CoconutColors.white,
            child: Text(
              _isRbf ? t.tooltip.rbf : t.tooltip.cpfp,
              style: CoconutTypography.body2_14.copyWith(color: CoconutColors.gray900, height: 1.3),
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
              Text(t.transaction_fee_bumping_screen.existing_fee, style: CoconutTypography.body2_14_Bold),
              Text(
                t.transaction_fee_bumping_screen.existing_fee_value(value: widget.transaction.feeRate),
                style: CoconutTypography.body2_14_Bold,
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
                child: Text(t.transaction_fee_bumping_screen.existing_fee, style: CoconutTypography.body2_14_Bold),
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
                    style: CoconutTypography.body2_14,
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
          Text(
            t.transaction_fee_bumping_screen.new_fee,
            style: CoconutTypography.body2_14_Bold.setColor(
              _getNewFeeTextColor(isError: _isEstimatedFeeTooLow || _viewModel.insufficientUtxos),
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 54,
                child: Center(
                  child: CoconutTextField(
                    controller: _textEditingController,
                    focusNode: _feeTextFieldFocusNode,
                    cursorColor: CoconutColors.white,
                    textInputType: const TextInputType.numberWithOptions(decimal: true),
                    errorColor: CoconutColors.hotPink,
                    activeColor: CoconutColors.white,
                    backgroundColor: CoconutColors.white.withOpacity(0.15),
                    prefix: null,
                    fontFamily: 'SpaceGrotesk',
                    maxLines: 1,
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
                    isLengthVisible: false,
                    textAlign: TextAlign.center,
                    onChanged: _onFeeRateChanged,
                  ),
                ),
              ),
              CoconutLayout.spacing_200w,
              Text(t.transaction_fee_bumping_screen.sats_vb, style: CoconutTypography.body2_14),
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
                child: Text(t.transaction_fee_bumping_screen.recommend_fee(fee: _viewModel.recommendFeeRate!)),
              ),
            ),
            CoconutLayout.spacing_200w,
            AnimatedRotation(
              turns: _isRecommendFeePannelExpanded ? -0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: SvgPicture.asset('assets/svg/caret-down.svg'),
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
            color: _isRecommendFeePannelPressed ? CoconutColors.gray900 : CoconutColors.gray800,
            padding: const EdgeInsets.only(
              left: CoconutLayout.defaultPadding,
              right: CoconutLayout.defaultPadding,
              bottom: CoconutLayout.defaultPadding,
              top: 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.all(1.5), child: SvgPicture.asset('assets/svg/circle-info.svg')),
                CoconutLayout.spacing_100w,
                if (_viewModel.isInitializedSuccess != null)
                  Expanded(
                    child: Text(
                      _viewModel.isInitializedSuccess == true
                          ? _viewModel.recommendFeeRateDescription!
                          : t.transaction_fee_bumping_screen.recommended_fees_fetch_error,
                      style: CoconutTypography.body2_14,
                      textScaler: const TextScaler.linear(1.0),
                    ),
                  ),
              ],
            ),
          ),
        ),
        isExpanded: _isRecommendFeePannelExpanded,
        onExpansionChanged: _toggleRecommendFeePannel,
      ),
    );
  }

  Widget _buildCurrentMempoolFeesWidget(int fastestFeeSatsPerVb, int halfhourFeeSatsPerVb, int hourFeeSatsPerVb) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      padding: const EdgeInsets.all(CoconutLayout.defaultPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
        color: CoconutColors.gray800,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.transaction_fee_bumping_screen.current_fee, style: CoconutTypography.body2_14_Bold),
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
                            Text(TransactionFeeLevel.fastest.text, style: CoconutTypography.body2_14),
                            CoconutLayout.spacing_200w,
                            Text(
                              TransactionFeeLevel.fastest.expectedTime,
                              style: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray400),
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
                            Text(t.transaction_fee_bumping_screen.existing_fee_value(value: fastestFeeSatsPerVb)),
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
                            Text(TransactionFeeLevel.halfhour.text, style: CoconutTypography.body2_14),
                            CoconutLayout.spacing_200w,
                            Text(
                              TransactionFeeLevel.halfhour.expectedTime,
                              style: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray400),
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
                        child: Text(t.transaction_fee_bumping_screen.existing_fee_value(value: halfhourFeeSatsPerVb)),
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
                            Text(TransactionFeeLevel.hour.text, style: CoconutTypography.body2_14),
                            CoconutLayout.spacing_200w,
                            Text(
                              TransactionFeeLevel.hour.expectedTime,
                              style: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray400),
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
                        child: Text(t.transaction_fee_bumping_screen.existing_fee_value(value: hourFeeSatsPerVb)),
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
        color: CoconutColors.hotPink150,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SvgPicture.asset(
            'assets/svg/triangle-warning.svg',
            colorFilter: const ColorFilter.mode(CoconutColors.hotPink, BlendMode.srcIn),
          ),
          CoconutLayout.spacing_200w,
          Text(
            t.transaction_fee_bumping_screen.recommended_fees_fetch_error,
            style: CoconutTypography.body2_14.setColor(CoconutColors.hotPink),
          ),
        ],
      ),
    );
  }

  Widget _buildUtxoSelectionOptionWidget(FeeBumpingViewModel viewModel) {
    Widget child;

    if (!viewModel.isAdditionalInputRequired) {
      child = const SizedBox.shrink(key: ValueKey('empty'));
    } else {
      int balanceInt = viewModel.selectedUtxoList.fold(0, (sum, item) => sum + item.amount);

      String selectedUtxoAmountText = viewModel.currentUnit.displayBitcoinAmount(balanceInt, withUnit: true);

      if (!viewModel.isUtxoSelectionAuto) {
        if (viewModel.selectedUtxoList.isNotEmpty) {
          selectedUtxoAmountText += t.transaction_fee_bumping_screen.n_utxos(count: viewModel.selectedUtxoList.length);
        } else {
          selectedUtxoAmountText += t.transaction_fee_bumping_screen.no_utxos_selected;
        }
      }

      Color textColor = viewModel.selectedUtxoList.isNotEmpty ? CoconutColors.primary : CoconutColors.hotPink;

      child = Container(
        key: const ValueKey('content'),
        width: MediaQuery.sizeOf(context).width,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 27),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
          color: CoconutColors.gray800,
        ),
        child: Column(
          children: [
            _buildUtxoOption(viewModel),
            if (!viewModel.isUtxoSelectionAuto) ...[
              Column(children: [CoconutLayout.spacing_400h, _buildDivider(), CoconutLayout.spacing_400h]),
              Row(
                children: [
                  Expanded(child: _buildSelectedUtxoAmount(selectedUtxoAmountText, textColor: textColor)),
                  CoconutLayout.spacing_200w,
                  _buildSelectUtxoButton(viewModel),
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

  Widget _buildSelectedUtxoAmount(String amountText, {Color? textColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(child: Text(amountText, style: CoconutTypography.body2_14_Number.copyWith(color: textColor))),
      ],
    );
  }

  Widget _buildSelectUtxoButton(FeeBumpingViewModel viewModel) {
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
                  "/utxo-selection",
                  arguments: {
                    "selectedUtxoList": viewModel.selectedUtxoList,
                    "walletId": widget.walletId,
                    "currentUnit": viewModel.currentUnit,
                  },
                ).then((utxoList) {
                  if (utxoList != null) {
                    viewModel.updateSelectedUtxos(utxoList as List<UtxoState>);
                  }
                });
              },
              disabledBackgroundColor: CoconutColors.gray800,
              disabledForegroundColor: CoconutColors.gray700,
              backgroundColor: CoconutColors.white,
              borderColor: CoconutColors.gray400,
              buttonType: CoconutButtonType.outlined,
              borderRadius: 8,
              isActive: true,
              text: t.select_wallet_with_options_bottom_sheet.select_utxo,
              textStyle: CoconutTypography.caption_10,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            ),
            CoconutLayout.spacing_100h,
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(color: CoconutColors.gray700, height: 1);
  }

  Widget _buildUtxoOption(FeeBumpingViewModel viewModel) {
    bool isNonMpfWallet = isWalletWithoutMfp(_viewModel.walletListItemBase);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (isNonMpfWallet) return;
        viewModel.toggleUtxoSelectionAuto(!viewModel.isUtxoSelectionAuto);
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
                  Text(t.transaction_fee_bumping_screen.utxo_auto_selection, style: CoconutTypography.body2_14),
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
              activeColor: CoconutColors.white.withValues(alpha: isNonMpfWallet ? 0.3 : 1.0),
              trackColor: viewModel.isUtxoSelectionAuto ? CoconutColors.white : CoconutColors.gray600,
              thumbColor: viewModel.isUtxoSelectionAuto ? CoconutColors.black : CoconutColors.gray500,
              onChanged: (isOn) {
                if (isNonMpfWallet) return;
                viewModel.toggleUtxoSelectionAuto(isOn);
              },
            ),
          ),
          CoconutLayout.spacing_100w,
        ],
      ),
    );
  }

  Color _getNewFeeTextColor({bool isError = false}) {
    if (isError) {
      return CoconutColors.hotPink;
    }
    return _isRbf ? CoconutColors.primary : CoconutColors.cyan;
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

  void _toggleRecommendFeePannel() {
    setState(() {
      _isRecommendFeePannelExpanded = !_isRecommendFeePannelExpanded;
    });
  }

  void _showInsufficientUtxoToast(BuildContext context) {
    CoconutToast.showToast(
      isVisibleIcon: true,
      context: context,
      text: t.transaction_fee_bumping_screen.toast.insufficient_utxo,
      seconds: 10,
    );
    return;
  }
}
