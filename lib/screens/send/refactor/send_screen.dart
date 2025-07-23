import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/refactor/send_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/refactor/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/screens/send/refactor/select_wallet_with_options_bottom_sheet.dart';
import 'package:coconut_wallet/screens/send/send_utxo_selection_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_list_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/dashed_border_painter.dart';
import 'package:coconut_wallet/utils/text_field_filter_util.dart';
import 'package:coconut_wallet/widgets/body/send_address/send_address_body.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/ripple_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tuple/tuple.dart';

class SendScreen extends StatefulWidget {
  final int? walletId;

  const SendScreen({super.key, this.walletId});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final Color keyboardToolbarGray = const Color(0xFF2E2E2E);
  final Color feeRateFieldGray = const Color(0xFF2B2B2B);
  final double kCoconutAppbarHeight = 60;
  final double kPageViewHeight = 225;
  final double kAddressBoardPosition = 185;
  final double kTooltipHeight = 39;
  final double kTooltipPadding = 5;
  final double kAmountHeight = 34;

  late final SendViewModel _viewModel;
  final _recipientPageController = PageController();
  int _focusedPageIndex = 0;

  final List<TextEditingController> _addressControllerList = [];
  final List<FocusNode> _addressFocusNodeList = [];
  final List<VoidCallback> _addressTextListenerList = [];

  final TextEditingController _feeRateController = TextEditingController();
  final FocusNode _feeRateFocusNode = FocusNode();

  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  QRViewController? _qrViewController;
  bool _isQrDataHandling = false;
  String _previousAmountText = "";

  bool get _hasKeyboard =>
      _amountFocusNode.hasFocus || _feeRateFocusNode.hasFocus || _isAddressFocused;

  bool get _isAddressFocused => _addressFocusNodeList.any((e) => e.hasFocus);

  double get _keyboardHeight => MediaQuery.of(context).viewInsets.bottom;

  double get walletAddressListHeight => _viewModel.walletItemList.length >= 2 ? 80 : 40;

  double get feeBoardHeight => _viewModel.isMaxMode ? 100 : 147;

  String get incomingBalanceTooltipText => t.tooltip.amount_to_be_sent(
      bitcoin: _viewModel.currentUnit.displayBitcoinAmount(_viewModel.incomingBalance),
      unit: _viewModel.currentUnit.symbol);

  @override
  void initState() {
    super.initState();
    _addAddressField();
    _viewModel = SendViewModel(
        context.read<WalletProvider>(),
        context.read<SendInfoProvider>(),
        context.read<NodeProvider>(),
        context.read<ConnectivityProvider>().isNetworkOn,
        context.read<PreferenceProvider>().currentUnit,
        _onAmountTextUpdate,
        _onFeeRateTextUpdate,
        _onRecipientPageDeleted,
        widget.walletId);

    _amountFocusNode.addListener(() => setState(() {}));
    _feeRateFocusNode.addListener(() => setState(() {}));
    _amountController.addListener(_amountTextListener);
    _recipientPageController.addListener(_recipientPageListener);
  }

  @override
  void dispose() {
    _recipientPageController.dispose();
    _feeRateController.dispose();
    _feeRateFocusNode.dispose();
    _amountController.dispose();
    _amountFocusNode.dispose();

    for (var focusNode in _addressFocusNodeList) {
      focusNode.dispose();
    }
    for (var controller in _addressControllerList) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // usableHeight: height - safeArea - toolbar
    final usableHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom -
        kCoconutAppbarHeight;

    return ChangeNotifierProxyProvider2<ConnectivityProvider, WalletProvider, SendViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, walletProvider, viewModel) {
        if (connectivityProvider.isNetworkOn != viewModel!.isNetworkOn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            viewModel.setIsNetworkOn(connectivityProvider.isNetworkOn);
          });
        }
        return viewModel;
      },
      child: GestureDetector(
        onTap: _clearFocus,
        child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.black,
            appBar: _buildAppBar(context),
            body: SizedBox(
              height: usableHeight,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Selector<SendViewModel, bool>(
                      selector: (_, viewModel) => viewModel.showAddressBoard,
                      builder: (context, data, child) {
                        return SizedBox(
                          height: _getScrollableHeight(usableHeight),
                          child: child,
                        );
                      },
                      child: Stack(
                        children: [
                          _buildInvisibleAmountField(),
                          _buildCounter(context),
                          _buildPageView(context),
                          _buildBoard(context),
                          if (_amountFocusNode.hasFocus || _feeRateFocusNode.hasFocus)
                            _buildKeyboardToolbar(context),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: Sizes.size24,
                    left: Sizes.size16,
                    right: Sizes.size16,
                    child: _buildFinalButton(context),
                  ),
                ],
              ),
            )),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
        height: kCoconutAppbarHeight,
        customTitle:
            Selector<SendViewModel, Tuple5<WalletListItemBase?, bool, int, int, BitcoinUnit>>(
                selector: (_, viewModel) => Tuple5(
                    viewModel.selectedWalletItem,
                    viewModel.isUtxoSelectionAuto,
                    viewModel.selectedUtxoAmountSum,
                    viewModel.selectedUtxoListLength,
                    viewModel.currentUnit),
                builder: (context, data, child) {
                  final selectedWalletItem = data.item1;
                  final isUtxoSelectionAuto = data.item2;
                  final selectedUtxoListLength = data.item4;
                  final currentUnit = data.item5;

                  if (selectedWalletItem == null) {
                    return Center(
                      child: Text(
                        '-',
                        style: CoconutTypography.body1_16.setColor(CoconutColors.white),
                      ),
                    );
                  }

                  String amountText =
                      currentUnit.displayBitcoinAmount(_viewModel.balance, withUnit: true);
                  if (!isUtxoSelectionAuto && selectedUtxoListLength > 0) {
                    amountText += t.send_screen.n_utxos(count: selectedUtxoListLength);
                  }

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(selectedWalletItem.name,
                              style: CoconutTypography.body1_16.setColor(CoconutColors.white)),
                          CoconutLayout.spacing_50w,
                          const Icon(Icons.keyboard_arrow_down_sharp,
                              color: CoconutColors.white, size: 16),
                        ],
                      ),
                      Text(amountText,
                          style:
                              CoconutTypography.body3_12_NumberBold.setColor(CoconutColors.white)),
                    ],
                  );
                }),
        onTitlePressed: () {
          if (_viewModel.selectedWalletItem != null) {
            _onAppBarTitlePressed();
          }
        },
        context: context,
        isBottom: true,
        actionButtonList: [
          const SizedBox(width: 24, height: 24),
        ],
        onBackPressed: () {
          Navigator.of(context).pop();
        });
  }

  Widget _buildInvisibleAmountField() {
    return SizedBox(
      width: 0,
      height: 0,
      child: TextField(
        controller: _amountController,
        focusNode: _amountFocusNode,
        showCursor: false,
        enableInteractiveSelection: false,
        keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
      ),
    );
  }

  Widget _buildFinalButton(BuildContext context) {
    return Selector<SendViewModel, Tuple2<String, bool>>(
        selector: (_, viewModel) => Tuple2(viewModel.finalErrorMessage, viewModel.hasFinalError),
        builder: (context, data, child) {
          return Column(
            children: [
              Text(
                _viewModel.finalErrorMessage,
                style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink),
              ),
              CoconutLayout.spacing_300h,
              CoconutButton(
                backgroundColor: CoconutColors.white,
                isActive: !_viewModel.hasFinalError,
                onPressed: () async {
                  FocusScope.of(context).unfocus();
                  if (mounted) {
                    _viewModel.setTxWaitingForSign();
                    Navigator.pushNamed(context, '/unsigned-transaction-qr',
                        arguments: {'walletName': _viewModel.selectedWalletItem!.name});
                  }
                },
                text: t.complete,
              ),
            ],
          );
        });
  }

  Widget _buildFeeItem(String imagePath, double? sats, bool isFetching) {
    final child = Container(
        height: 30,
        decoration: BoxDecoration(
            border: Border.all(
              width: 1,
              color: CoconutColors.gray600,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(8))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              imagePath,
              width: 12,
              colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
            ),
            CoconutLayout.spacing_150w,
            Text("${sats ?? "-"} ${t.send_screen.fee_rate_suffix}",
                style: CoconutTypography.body3_12_Number.setColor(CoconutColors.white)),
          ],
        ));

    return Expanded(
      child: RippleEffect(
        borderRadius: 8,
        onTap: () {
          if (isFetching) return;
          _feeRateController.text = sats.toString();
          _clearFocus();
        },
        child: !isFetching
            ? child
            : Shimmer.fromColors(
                baseColor: CoconutColors.white.withOpacity(0.2),
                highlightColor: CoconutColors.white.withOpacity(0.6),
                child: child),
      ),
    );
  }

  Widget _buildKeyboardToolbar(BuildContext context) {
    return Positioned(
      bottom: _keyboardHeight,
      child: GestureDetector(
          onTap: () {}, // ignore
          child: Container(
              width: MediaQuery.of(context).size.width,
              height: 50,
              color: keyboardToolbarGray,
              child: _amountFocusNode.hasFocus
                  ? _buildAmountKeyboardToolbar(context)
                  : _buildFeeRateKeyboardToolbar(context))),
    );
  }

  Widget _buildAmountKeyboardToolbar(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        GestureDetector(
          onTap: _viewModel.toggleUnit,
          child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Selector<SendViewModel, BitcoinUnit>(
                  selector: (_, viewModel) => viewModel.currentUnit,
                  builder: (context, data, child) {
                    return Row(
                      children: [
                        SvgPicture.asset(
                          'assets/svg/check.svg',
                          colorFilter: ColorFilter.mode(
                              _viewModel.isBtcUnit ? CoconutColors.white : CoconutColors.gray700,
                              BlendMode.srcIn),
                          width: 10,
                          height: 10,
                        ),
                        CoconutLayout.spacing_100w,
                        Text(t.send_screen.use_btc_unit,
                            style: CoconutTypography.body3_12.setColor(CoconutColors.white)),
                      ],
                    );
                  })),
        ),
      ],
    );
  }

  Widget _buildFeeRateKeyboardToolbar(BuildContext context) {
    return Selector<SendViewModel, RecommendedFeeFetchStatus>(
        selector: (_, viewModel) => _viewModel.recommendedFeeFetchStatus,
        builder: (context, recommendedFeeFetchStatus, child) {
          final isFailed = recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed;
          final isFetching = recommendedFeeFetchStatus == RecommendedFeeFetchStatus.fetching;
          return Row(
            children: [
              CoconutLayout.spacing_200w,
              if (isFailed) ...[
                SvgPicture.asset('assets/svg/triangle-warning.svg',
                    colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                    width: 24),
                CoconutLayout.spacing_200w,
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.send_screen.recommended_fee_unavailable,
                        style: CoconutTypography.body3_12_Bold.setColor(CoconutColors.white)),
                    Text(t.send_screen.recommended_fee_unavailable_description,
                        style: CoconutTypography.body3_12.setColor(CoconutColors.white)),
                  ],
                ),
              ] else ...[
                _buildFeeItem(
                    'assets/svg/rocket.svg', _viewModel.feeInfos[0].satsPerVb, isFetching),
                CoconutLayout.spacing_200w,
                _buildFeeItem('assets/svg/car.svg', _viewModel.feeInfos[1].satsPerVb, isFetching),
                CoconutLayout.spacing_200w,
                _buildFeeItem(
                    'assets/svg/barefoot.svg', _viewModel.feeInfos[2].satsPerVb, isFetching),
              ],
              CoconutLayout.spacing_200w,
            ],
          );
        });
  }

  Widget _buildBottomTooltips(BuildContext context) {
    return Selector<SendViewModel, Tuple3<bool, int, String>>(
        selector: (_, viewModel) =>
            Tuple3(viewModel.isMaxMode, _viewModel.recipientList.length, viewModel.amountSumText),
        builder: (context, data, child) {
          return Column(
            children: [
              if (_viewModel.isBatchMode)
                Padding(
                  padding: EdgeInsets.only(bottom: kTooltipPadding),
                  child: CoconutToolTip(
                    backgroundColor: CoconutColors.gray800,
                    borderColor: CoconutColors.gray800,
                    borderRadius: 12,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    icon: SvgPicture.asset(
                      'assets/svg/receipt.svg',
                      colorFilter: const ColorFilter.mode(
                        CoconutColors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                    tooltipType: CoconutTooltipType.fixed,
                    richText: RichText(
                      text: TextSpan(
                        text: t.send_screen.tooltip_text(
                            count: _viewModel.recipientList.length,
                            amount: _viewModel.amountSumText),
                        style: CoconutTypography.body3_12_Bold,
                      ),
                    ),
                  ),
                ),
              if (_viewModel.isMaxMode)
                CoconutToolTip(
                  backgroundColor: CoconutColors.gray800,
                  borderColor: CoconutColors.gray800,
                  borderRadius: 12,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  icon: SvgPicture.asset(
                    'assets/svg/broom.svg',
                    colorFilter: const ColorFilter.mode(
                      CoconutColors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  tooltipType: CoconutTooltipType.fixed,
                  richText: RichText(
                    text: TextSpan(
                      text: t.send_screen.tooltip_max_mode_text,
                      style: CoconutTypography.body3_12_Bold,
                    ),
                  ),
                ),
            ],
          );
        });
  }

  Widget _buildFeeBoard(BuildContext context) {
    return Column(
      children: [
        Selector<SendViewModel, Tuple3<bool, int?, int>>(
            selector: (_, viewModel) =>
                Tuple3(viewModel.showFeeBoard, viewModel.estimatedFeeInSats, viewModel.balance),
            builder: (context, data, child) {
              if (!_viewModel.showFeeBoard) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.only(left: 14, right: 14, top: 12, bottom: 20),
                  margin: const EdgeInsets.only(top: 0),
                  decoration: BoxDecoration(
                      border: Border.all(
                        color: CoconutColors.gray700,
                        width: 1,
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(8))),
                  child: Column(
                    children: [
                      child!,
                      CoconutLayout.spacing_200h,
                      Row(
                        children: [
                          Text(
                            t.send_screen.estimated_fee,
                            style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                          ),
                          const Spacer(),
                          Text(
                            "${_viewModel.estimatedFeeInSats ?? '-'} sats",
                            style: CoconutTypography.body2_14_NumberBold.setColor(
                                _viewModel.isEstimatedFeeGreaterThanBalance
                                    ? CoconutColors.hotPink
                                    : CoconutColors.white),
                          ),
                        ],
                      ),
                      _buildFeeSubtractedFromSendAmount(),
                    ],
                  ),
                ),
              );
            },
            child: _buildFeeRateRow()),
        _buildBottomTooltips(context),
      ],
    );
  }

  Widget _buildFeeSubtractedFromSendAmount() {
    return Selector<SendViewModel, Tuple2<bool, bool>>(
        selector: (_, viewModel) =>
            Tuple2(viewModel.isMaxMode, viewModel.isFeeSubtractedFromSendAmount),
        builder: (context, data, child) {
          if (_viewModel.isMaxMode) return const SizedBox();
          return Column(
            children: [
              CoconutLayout.spacing_400h,
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.send_screen.fee_subtracted_from_send_amount,
                        style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                      ),
                      Text(
                        _viewModel.isFeeSubtractedFromSendAmount
                            ? t.send_screen.fee_subtracted_from_send_amount_enabled_description
                            : t.send_screen.fee_subtracted_from_send_amount_disabled_description,
                        style: CoconutTypography.caption_10.setColor(CoconutColors.gray400),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Align(
                      alignment: Alignment.centerRight,
                      child: CoconutSwitch(
                          scale: 0.7,
                          isOn: _viewModel.isFeeSubtractedFromSendAmount,
                          activeColor: CoconutColors.gray100,
                          trackColor: CoconutColors.gray600,
                          thumbColor: CoconutColors.gray800,
                          onChanged: (isOn) => _viewModel.setIsFeeSubtractedFromSendAmount(isOn))),
                ],
              )
            ],
          );
        });
  }

  Widget _buildFeeRateRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          t.send_screen.fee_rate,
          style: CoconutTypography.body3_12.setColor(CoconutColors.white),
        ),
        const Spacer(),
        IntrinsicWidth(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: CoconutTextField(
              textInputType: const TextInputType.numberWithOptions(signed: false, decimal: true),
              textInputFormatter: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              enableInteractiveSelection: false,
              textAlign: TextAlign.end,
              controller: _feeRateController,
              focusNode: _feeRateFocusNode,
              backgroundColor: feeRateFieldGray,
              height: 30,
              padding: const EdgeInsets.only(left: 10),
              onChanged: (text) {
                if (text == "-") return;
                String formattedText = filterNumericInput(text, integerPlaces: 8, decimalPlaces: 2);
                _feeRateController.text = formattedText;
                _viewModel.setFeeRateText(formattedText);
              },
              maxLines: 1,
              fontFamily: 'SpaceGrotesk',
              fontSize: 12,
              activeColor: CoconutColors.white,
              fontWeight: FontWeight.bold,
              borderRadius: 8,
              suffix: Container(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(t.send_screen.fee_rate_suffix,
                      style: CoconutTypography.body3_12_NumberBold.setColor(CoconutColors.white))),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildPageView(BuildContext context) {
    return SizedBox(
        height: kPageViewHeight,
        width: MediaQuery.of(context).size.width,
        child: Selector<SendViewModel, Tuple3<int, bool, bool>>(
            selector: (_, viewModel) =>
                Tuple3(viewModel.recipientList.length, viewModel.isMaxMode, viewModel.showFeeBoard),
            builder: (context, data, child) {
              final recipientListLength = data.item1;
              final isMaxMode = data.item2;
              final showFeeBoard = data.item3;
              return PageView.builder(
                controller: _recipientPageController,
                onPageChanged: (index) => _viewModel.setCurrentPage(index),
                itemCount: recipientListLength + (!isMaxMode && showFeeBoard ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == recipientListLength) {
                    return _buildAddRecipientCard();
                  }
                  return _buildRecipientPage(context, index);
                },
              );
            }));
  }

  Widget _buildAddRecipientCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 25),
      child: ShrinkAnimationButton(
        defaultColor: CoconutColors.black,
        onPressed: () {
          _viewModel.addRecipient();
          _addAddressField();
        },
        child: CustomPaint(
          painter:
              DashedBorderPainter(dashSpace: 4.0, dashWidth: 4.0, color: CoconutColors.gray600),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/svg/plus.svg'),
              CoconutLayout.spacing_100w,
              Text(
                t.send_screen.add_recipient,
                style: CoconutTypography.body2_14.setColor(CoconutColors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientPage(BuildContext context, int index) {
    return Stack(
      children: [
        // Amount Touch Event Panel
        GestureDetector(
            onTap: () {
              // keyboard > amount request focus
              if (_hasKeyboard) {
                _clearFocus();
                return;
              }
              if (_viewModel.isAmountDisabled) return;
              _amountFocusNode.requestFocus();
            },
            child: Container(
                color: Colors.transparent,
                width: MediaQuery.of(context).size.width,
                height: kAmountHeight + Sizes.size80)),
        Padding(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
          child: Column(
            children: [
              Selector<SendViewModel, Tuple7<BitcoinUnit, String, bool, bool, bool, bool, int?>>(
                  selector: (_, viewModel) => Tuple7(
                      viewModel.currentUnit,
                      viewModel.recipientList[index].amount,
                      viewModel.isMaxMode,
                      viewModel.hasInsufficientBalanceError,
                      viewModel.hasInsufficientBalanceErrorOfLastRecipient,
                      viewModel.recipientList[index].minimumAmountError.isError,
                      viewModel.estimatedFeeInSats),
                  builder: (context, data, child) {
                    String amountText = data.item2;
                    final isMinimumAmount = data.item6;
                    final hasInsufficientBalanceErrorOfLastRecipient =
                        data.item5 && index == _viewModel.lastIndex;

                    Color amountTextColor;
                    if (_viewModel.hasInsufficientBalanceError ||
                        isMinimumAmount ||
                        hasInsufficientBalanceErrorOfLastRecipient) {
                      amountTextColor = CoconutColors.hotPink;
                    } else if (_viewModel.isMaxModeIndex(index)) {
                      amountTextColor = CoconutColors.gray600;
                    } else if (amountText.isEmpty) {
                      amountTextColor = MyColors.transparentWhite_20;
                    } else {
                      amountTextColor = CoconutColors.white;
                    }

                    final isKorean = context.read<PreferenceProvider>().isKorean;
                    final maxButtonBaseText = t.send_screen.input_maximum_amount;
                    final maxButtonText = _viewModel.isMaxMode
                        ? (isKorean
                            ? '$maxButtonBaseText ${t.cancel}'
                            : '${t.cancel} $maxButtonBaseText')
                        : maxButtonBaseText;

                    return Column(
                      children: [
                        IgnorePointer(
                          child: SizedBox(
                            height: kAmountHeight,
                            child: FittedBox(
                              child: RichText(
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                text: _viewModel.isAmountInsufficient(index)
                                    ? TextSpan(
                                        text: t.send_screen.max_mode_insufficient_balance,
                                        style: CoconutTypography.heading3_21_Bold
                                            .setColor(CoconutColors.hotPink),
                                      )
                                    : TextSpan(
                                        text:
                                            '${amountText.isEmpty ? 0 : amountText.toThousandsSeparatedString()} ',
                                        style: CoconutTypography.heading2_28_NumberBold
                                            .setColor(amountTextColor),
                                        children: [
                                          TextSpan(
                                              text: _viewModel.currentUnit.symbol,
                                              style: CoconutTypography.heading4_18_Number)
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                        CoconutLayout.spacing_200h,
                        IgnorePointer(
                          ignoring: index != _viewModel.lastIndex,
                          child: GestureDetector(
                            onTap: () {
                              _viewModel.setMaxMode(!_viewModel.isMaxMode);
                              _clearFocus();
                            },
                            child: Opacity(
                              opacity: index == _viewModel.lastIndex ? 1.0 : 0.0,
                              child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.5),
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4.0),
                                      color: MyColors.grey),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/svg/broom.svg',
                                        colorFilter: ColorFilter.mode(
                                            CoconutColors.white
                                                .withOpacity(_viewModel.isMaxMode ? 1.0 : 0.3),
                                            BlendMode.srcIn),
                                      ),
                                      CoconutLayout.spacing_100w,
                                      Text(maxButtonText,
                                          style: Styles.caption.merge(TextStyle(
                                              color: CoconutColors.white,
                                              fontFamily: CustomFonts.text.getFontFamily))),
                                    ],
                                  )),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
              CoconutLayout.spacing_500h,
              Selector<SendViewModel, Tuple2<String, SendError>>(
                  selector: (_, viewModel) => Tuple2(viewModel.recipientList[index].address,
                      viewModel.recipientList[index].addressError),
                  builder: (context, data, child) {
                    final isAddressError = data.item2.isError;
                    final controller = _addressControllerList[index];
                    return CoconutTextField(
                      controller: _addressControllerList[index],
                      focusNode: _addressFocusNodeList[index],
                      backgroundColor: CoconutColors.black,
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
                      onChanged: (text) {},
                      maxLines: 1,
                      suffix: IconButton(
                        iconSize: 14,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          if (controller.text.isEmpty) {
                            _showAddressScanner(index);
                          } else {
                            controller.clear();
                          }
                        },
                        icon: controller.text.isEmpty
                            ? SvgPicture.asset('assets/svg/scan.svg')
                            : SvgPicture.asset(
                                'assets/svg/text-field-clear.svg',
                                colorFilter: ColorFilter.mode(
                                    isAddressError ? CoconutColors.hotPink : CoconutColors.white,
                                    BlendMode.srcIn),
                              ),
                      ),
                      placeholderText: t.send_screen.address_placeholder,
                      isError: isAddressError,
                    );
                  }),
              CoconutLayout.spacing_100h,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    const Spacer(),
                    Selector<SendViewModel, int>(
                        selector: (_, viewModel) => viewModel.recipientList.length,
                        builder: (context, data, child) {
                          if (!_viewModel.isBatchMode) return const SizedBox();
                          return CoconutUnderlinedButton(
                            text: t.send_screen.delete,
                            onTap: () {
                              _deleteAddressField(_viewModel.currentIndex);
                              _viewModel.deleteRecipient();
                            },
                            textStyle: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                            padding: EdgeInsets.zero,
                          );
                        }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCounter(BuildContext context) {
    return Selector<SendViewModel, Tuple2<int, int>>(
        selector: (_, viewModel) => Tuple2(viewModel.currentIndex, viewModel.recipientList.length),
        builder: (context, data, child) {
          final currentIndex = data.item1;
          final recipientListLength = data.item2;
          if (recipientListLength == 1 || currentIndex >= recipientListLength) {
            return const SizedBox();
          }
          return Positioned(
            right: 16,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20), color: CoconutColors.gray800),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("${currentIndex + 1} ",
                      style: CoconutTypography.body3_12.setColor(CoconutColors.white)),
                  Text("/ $recipientListLength",
                      style: CoconutTypography.body3_12.setColor(CoconutColors.gray600)),
                ],
              ),
            ),
          );
        });
  }

  Widget _buildAddressRow(int index, String address, String walletName, String derivationPath) {
    double bottomPadding = index == _viewModel.walletItemList.length - 1 ? 0.0 : 10.0;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _addressControllerList[_viewModel.currentIndex].text = address;
          _viewModel.markWalletAddressForUpdate(index);
          _clearFocus();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shortenAddress(address, head: 10),
              style: CoconutTypography.body3_12_Number.setColor(CoconutColors.white),
            ),
            Text(
              "$walletName • $derivationPath",
              style: CoconutTypography.caption_10.setColor(CoconutColors.gray400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressBoard(BuildContext context) {
    return Column(
      children: [
        CoconutLayout.spacing_50h,
        GestureDetector(
          onTap: () => {}, // ignore
          child: Container(
            decoration: BoxDecoration(
                color: CoconutColors.black,
                border: Border.all(
                  color: CoconutColors.gray700,
                  width: 1,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(8))),
            child: Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                      children: [
                        Text(
                          t.send_screen.my_address,
                          style: CoconutTypography.body3_12_Bold.setColor(CoconutColors.white),
                        ),
                        const Spacer(),
                        CoconutUnderlinedButton(
                          text: t.close,
                          onTap: () => _viewModel.setShowAddressBoard(false),
                          textStyle: CoconutTypography.body3_12,
                          padding: const EdgeInsets.only(right: 14, left: 24),
                        ),
                      ],
                    ),
                  ),
                  CoconutLayout.spacing_200h,
                  SizedBox(
                    height: walletAddressListHeight,
                    child: ListView.builder(
                        itemCount: _viewModel.walletItemList.length,
                        itemBuilder: (BuildContext context, int index) {
                          final walletListItem = _viewModel.walletItemList[index];
                          final walletAddress = _viewModel.walletAddressMap[walletListItem.id]!;
                          return _buildAddressRow(index, walletAddress.address, walletListItem.name,
                              walletAddress.derivationPath);
                        }),
                  ),
                  CoconutLayout.spacing_200h,
                  CoconutUnderlinedButton(
                    text: t.view_more,
                    onTap: () {
                      _clearFocus();
                      if (_viewModel.walletItemList.length == 1) {
                        _showAddressListBottomSheet(_viewModel.walletItemList[0].id);
                        return;
                      }

                      CommonBottomSheets.showDraggableBottomSheet(
                          context: context,
                          childBuilder: (scrollController) => SelectWalletBottomSheet(
                                scrollController: scrollController,
                                currentUnit: _viewModel.currentUnit,
                                walletId: -1,
                                onWalletChanged: (id) {
                                  Navigator.pop(context);
                                  _showAddressListBottomSheet(id);
                                },
                              ));
                    },
                    textStyle: CoconutTypography.body3_12,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoard(BuildContext context) {
    return Selector<SendViewModel, bool>(
        selector: (_, viewModel) => viewModel.showAddressBoard,
        builder: (context, data, child) {
          return Positioned(
            left: 16,
            right: 16,
            top: !_viewModel.showAddressBoard ? kPageViewHeight : kAddressBoardPosition,
            child: !_viewModel.showAddressBoard
                ? _buildFeeBoard(context)
                : _buildAddressBoard(context),
          );
        });
  }

  double _getScrollableHeight(double usableHeight) {
    double scrollbarHeight = usableHeight;
    if (_viewModel.showAddressBoard) {
      // AddressBoard와 키보드간 간격만큼 스크롤 범위를 조정한다.
      final addressBoardHeight = walletAddressListHeight + 80;
      final addressBoardBottomPos = kAddressBoardPosition + addressBoardHeight;
      final keyboardGap = usableHeight - _keyboardHeight - addressBoardBottomPos;
      if (keyboardGap < 0) scrollbarHeight += -keyboardGap + CoconutLayout.defaultPadding;
    } else if (_viewModel.showFeeBoard && _isAddressFocused) {
      // FeeBoard와 키보드간 간격만큼 스크롤 범위를 조정한다.
      double bottomPos = kPageViewHeight + feeBoardHeight;
      int tooltipCount = 0;
      if (_viewModel.isBatchMode) ++tooltipCount;
      if (_viewModel.isMaxMode) ++tooltipCount;
      if (tooltipCount > 0) bottomPos += 12;
      if (tooltipCount == 2) bottomPos += kTooltipPadding;
      bottomPos += tooltipCount * kTooltipHeight;
      final keyboardGap = usableHeight - _keyboardHeight - bottomPos;
      if (keyboardGap < 0) scrollbarHeight += -keyboardGap + CoconutLayout.defaultPadding;
    }

    // amount, fee는 스크롤 허용하지 않음
    return scrollbarHeight;
  }

  void _onAppBarTitlePressed() {
    _clearFocus();
    CommonBottomSheets.showBottomSheet_50(
        context: context,
        child: SelectWalletWithOptionsBottomSheet(
          currentUnit: _viewModel.currentUnit,
          selectedWalletId: _viewModel.selectedWalletId,
          onWalletInfoUpdated: _viewModel.onWalletInfoUpdated,
          isUtxoSelectionAuto: _viewModel.isUtxoSelectionAuto,
          selectedUtxoList: _viewModel.selectedUtxoList,
        ));
  }

  void _showAddressListBottomSheet(int walletId) {
    CommonBottomSheets.showBottomSheet_90(
        context: context,
        child: AddressListScreen(
          id: walletId,
          isFullScreen: false,
        ));
  }

  void _onQRViewCreated(QRViewController qrViewController) {
    _qrViewController = qrViewController;
    qrViewController.scannedDataStream.listen((scanData) async {
      if (_isQrDataHandling || scanData.code == null) return;
      if (scanData.code!.isEmpty) return;

      _isQrDataHandling = true;
      if (_viewModel.validateAddress(scanData.code!)) {
        if (mounted) {
          Navigator.pop(context, scanData.code!);
        }
      } else {
        if (mounted) {
          CoconutToast.showToast(
              isVisibleIcon: true, context: context, text: _viewModel.qrErrorMessage);
        }
      }

      // 하나의 QR 스캔으로, 동시에 여러번 호출되는 것을 방지하기 위해
      await Future.delayed(const Duration(seconds: 1));
      _isQrDataHandling = false;
    });
  }

  void _showAddressScanner(int index) async {
    final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
    final String? scannedAddress = await CommonBottomSheets.showBottomSheet_100(
        context: context,
        child: Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: CoconutAppBar.build(
                title: t.send,
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
            body: SendAddressBody(qrKey: qrKey, onQrViewCreated: _onQRViewCreated)));
    if (scannedAddress != null) {
      _addressControllerList[index].text = scannedAddress;
    }
    _disposeQrViewController();
  }

  void _disposeQrViewController() {
    _qrViewController?.dispose();
    _qrViewController = null;
  }

  void _recipientPageListener() {
    final page = _recipientPageController.page;

    // 페이지가 완전히 변경되었고 이전에 Address 필드에 포커싱이 있었다면, 새로운 페이지의 Address 필드를 포커싱한다.
    if (page == page!.roundToDouble() && page != _focusedPageIndex) {
      _focusedPageIndex = page.toInt();

      if (_isAddressFocused && _focusedPageIndex < _viewModel.recipientList.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _addressFocusNodeList[_focusedPageIndex].requestFocus();
          _addressControllerList[_focusedPageIndex].selection = TextSelection.fromPosition(
            TextPosition(offset: _addressControllerList[_focusedPageIndex].text.length),
          );
        });
      }
    }
  }

  void _onRecipientPageDeleted(int page) {
    if (_recipientPageController.page == page) return;
    _recipientPageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _onFeeRateTextUpdate(String text) {
    _feeRateController.text = text;
  }

  void _onAmountTextUpdate(String text) {
    // 단위변환시 문자열 길이가 달라지므로 viewModel text와 길이를 맞춘다.
    _previousAmountText = text;
    _amountController.text = text;
  }

  void _amountTextListener() {
    // 최대 금액 보내기 모드인 경우에는 무시
    if (_viewModel.isAmountDisabled) {
      if (_amountController.text != _previousAmountText) {
        _amountController.text = _previousAmountText;
      }
      return;
    }

    // 문자가 입력된 경우와 삭제된 경우를 인식한다.
    String currentText = _amountController.text;
    if (currentText.length > _previousAmountText.length) {
      String lastInserted = currentText.substring(_previousAmountText.length);
      _viewModel.onKeyTap(lastInserted);
    } else if (currentText.length < _previousAmountText.length) {
      _viewModel.onKeyTap('<');
      // 삭제 버튼을 꾹 누른 경우에 대한 처리
      if (currentText.isEmpty) {
        _viewModel.clearAmountText();
      }
    }

    _previousAmountText = currentText;
  }

  void _addAddressField() {
    final controller = TextEditingController();
    final index = _addressControllerList.length;
    addressTextListener() => _viewModel.setAddressText(controller.text, index);

    controller.addListener(addressTextListener);
    _addressTextListenerList.add(addressTextListener);
    _addressControllerList.add(controller);

    final focusNode = FocusNode();
    focusNode.addListener(() => setState(() {
          final shouldShowBoard = focusNode.hasFocus && _viewModel.selectedWalletItem != null;
          _viewModel.setShowAddressBoard(shouldShowBoard);
        }));
    _addressFocusNodeList.add(focusNode);
  }

  void _deleteAddressField(int index) {
    _addressControllerList[index].dispose();
    _addressFocusNodeList[index].dispose();

    _addressControllerList.removeAt(index);
    _addressFocusNodeList.removeAt(index);
    _addressTextListenerList.removeAt(index);
    _rebindAddressTextListeners(index);
  }

  void _rebindAddressTextListeners(int index) {
    for (int i = index; i < _addressTextListenerList.length; ++i) {
      final controller = _addressControllerList[i];
      newAddressTextListener() => _viewModel.setAddressText(controller.text, i);
      controller.removeListener(_addressTextListenerList[i]);
      controller.addListener(newAddressTextListener);
      _addressTextListenerList[i] = newAddressTextListener;
    }
  }

  void _clearFocus() => FocusManager.instance.primaryFocus?.unfocus();
}
