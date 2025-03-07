import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/fee_bumping/cpfp_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/fee_bumping/fee_bumping_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/fee_bumping/rbf_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/custom_expansion_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

enum FeeBumpingType {
  rbf,
  cpfp,
}

class TransactionFeeBumpingScreen extends StatefulWidget {
  final TransactionRecord transaction;
  final FeeBumpingType feeBumpingType;
  final String walletName;
  final int walletId;
  final Utxo? currentUtxo;

  const TransactionFeeBumpingScreen({
    super.key,
    required this.transaction,
    required this.feeBumpingType,
    required this.walletId,
    required this.walletName,
    required this.currentUtxo,
  });

  @override
  State<TransactionFeeBumpingScreen> createState() =>
      _TransactionFeeBumpingScreenState();
}

class _TransactionFeeBumpingScreenState
    extends State<TransactionFeeBumpingScreen> {
  late dynamic _viewModel;
  late bool _isRbf;

  final GlobalKey _tooltipIconKey = GlobalKey();
  late Size _tooltipIconSize;
  late Offset _tooltipIconPosition;

  bool _isTooltipVisible = false;
  bool _isRecommendFeePannelExpanded = false;
  bool _isRecommendFeePannelPressed = false;

  final FocusNode _feeTextFieldFocusNode = FocusNode();

  final TextEditingController _textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider3<NodeProvider, SendInfoProvider,
        WalletProvider, FeeBumpingViewModel>(
      create: (_) {
        debugPrint('###### ChangeNotifierProxyProvider3 create');

        _viewModel = _getViewModel(context);
        debugPrint('_viewModel Type is $_viewModel');
        _textEditingController.addListener(_textEditingListener);

        debugPrint('###### ChangeNotifierProxyProvider3 create finish');
        return _viewModel;
      },
      update: (_, nodeProvider, sendInfoProvider, walletProvider, viewModel) {
        viewModel ??= _getViewModel(context);
        if (viewModel is RbfViewModel) {
          (viewModel).updateProvider();
        } else if (viewModel is CpfpViewModel) {
          (viewModel).updateProvider();
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
            child: Stack(
              children: [
                Scaffold(
                  resizeToAvoidBottomInset: true,
                  backgroundColor: MyColors.black,
                  appBar: CoconutAppBar.build(
                    title: _isRbf
                        ? t.transaction_fee_bumping_screen.rbf
                        : t.transaction_fee_bumping_screen.cpfp,
                    context: context,
                    actionButtonList: [
                      IconButton(
                        key: _tooltipIconKey,
                        icon: SvgPicture.asset('assets/svg/question-mark.svg'),
                        onPressed: _toggleTooltip,
                      )
                    ],
                  ),
                  body: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoconutLayout.defaultPadding,
                        vertical: 30,
                      ),
                      height: MediaQuery.sizeOf(context).height -
                          kToolbarHeight -
                          MediaQuery.of(context).padding.top,
                      child: Column(
                        children: [
                          _buildExistingFeeWidget(),
                          CoconutLayout.spacing_200h,
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 3,
                            ),
                            child: Divider(
                              color: CoconutColors.gray800,
                              height: 1,
                            ),
                          ),
                          CoconutLayout.spacing_500h,
                          _buildNewFeeWidget(),
                          CoconutLayout.spacing_400h,
                          if (viewModel.isRecommendedFeesFetchSuccess) ...[
                            _buildRecommendFeeWidget(
                                _viewModel.recommendFeeRate),
                            CoconutLayout.spacing_300h,
                            _buildCurrentFeeWidget(
                              viewModel.feeInfos[0].satsPerVb ?? 0,
                              viewModel.feeInfos[1].satsPerVb ?? 0,
                              viewModel.feeInfos[2].satsPerVb ?? 0,
                            ),
                          ] else
                            _buildFetchFailedWidget()
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  child: IgnorePointer(
                    ignoring: true,
                    child: Container(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 40, top: 150),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            CoconutColors.black,
                          ],
                          stops: [0.0, 1.0], // 0%에서 투명, 100%에서 블랙
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                  child: Column(
                    children: [
                      Text(
                        t.transaction_fee_bumping_screen.estimated_fee(
                          fee: addCommasToIntegerPart(6800), // TODO: Value
                        ),
                      ),
                      CoconutLayout.spacing_300h,
                      CoconutButton(
                          onPressed: () {
                            if (viewModel.isLowerFeeError) return;
                            viewModel.updateSendInfoProvider(
                                int.parse(_textEditingController.text));
                            _viewModel.generateUnsignedPsbt().then((value) {
                              viewModel.setTxWaitingForSign(value);
                              Navigator.pushNamed(
                                  context, '/unsigned-transaction-qr',
                                  arguments: {'walletName': widget.walletName});
                            }).catchError((error) {
                              showAlertDialog(
                                context: context,
                                content: t.alert.error_tx.not_created(
                                  error: error.toString(),
                                ),
                              );
                            });
                          },
                          width: MediaQuery.sizeOf(context).width,
                          disabledBackgroundColor: CoconutColors.gray800,
                          disabledForegroundColor: CoconutColors.gray700,
                          isActive: !viewModel.isLowerFeeError &&
                              _textEditingController.text.isNotEmpty,
                          height: 50,
                          backgroundColor: _getNewFeeTextColor(),
                          foregroundColor: CoconutColors.black,
                          pressedTextColor: CoconutColors.black,
                          text: t.complete),
                    ],
                  ),
                ),
                if (_isTooltipVisible) _buildTooltip(context),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  void _textEditingListener() {
    if (_textEditingController.text.isEmpty) {
      _viewModel.setLowerFeeError(false);
      return;
    }

    int? value = int.tryParse(_textEditingController.text);

    if (value == null || value < _viewModel.recommendFeeRate || value == 0) {
      _viewModel.setLowerFeeError(true);
    } else {
      _viewModel.setLowerFeeError(false);
    }
  }

  @override
  void initState() {
    super.initState();
    _isRbf = widget.feeBumpingType == FeeBumpingType.rbf;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tooltipIconRenderBox =
          _tooltipIconKey.currentContext?.findRenderObject() as RenderBox?;

      if (tooltipIconRenderBox != null) {
        setState(() {
          _tooltipIconPosition =
              tooltipIconRenderBox.localToGlobal(Offset.zero);
          _tooltipIconSize = tooltipIconRenderBox.size;
        });
      }
    });
  }

  FeeBumpingViewModel _getViewModel(BuildContext context) {
    final nodeProvider = Provider.of<NodeProvider>(context, listen: false);
    final sendInfoProvider =
        Provider.of<SendInfoProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    if (widget.feeBumpingType == FeeBumpingType.rbf) {
      return RbfViewModel(
        widget.transaction,
        widget.walletId,
        nodeProvider,
        sendInfoProvider,
        walletProvider,
        widget.currentUtxo,
      );
    } else if (widget.feeBumpingType == FeeBumpingType.cpfp) {
      return CpfpViewModel(
        widget.transaction,
        widget.walletId,
        nodeProvider,
        sendInfoProvider,
        walletProvider,
        widget.currentUtxo,
      );
    }
    throw Exception('Invalid FeeBumping Type');
  }

  Widget _buildTooltip(BuildContext context) {
    return Positioned(
      top: _tooltipIconPosition.dy + _tooltipIconSize.height - 10,
      right: 18,
      child: GestureDetector(
        onTap: _removeTooltip,
        child: ClipPath(
          clipper: RightTriangleBubbleClipper(),
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.9,
            padding: const EdgeInsets.only(
              top: 28,
              left: 16,
              right: 16,
              bottom: 12,
            ),
            color: CoconutColors.white,
            child: Text(_isRbf ? t.tooltip.rbf : t.tooltip.cpfp,
                style: CoconutTypography.body2_14
                    .copyWith(color: CoconutColors.gray900, height: 1.3)),
          ),
        ),
      ),
    );
  }

  Widget _buildExistingFeeWidget() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        right: 4,
        bottom: 8,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.transaction_fee_bumping_screen.existing_fee,
                style: CoconutTypography.body2_14_Bold,
              ),
              Text(
                t.transaction_fee_bumping_screen.existing_fee_value(
                  value: widget.transaction.feeRate,
                ),
                style: CoconutTypography.body2_14_Bold,
              ),
            ],
          ),
          CoconutLayout.spacing_50h,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                t.transaction_fee_bumping_screen.total_fee(
                  fee: addCommasToIntegerPart(
                      widget.transaction.amount!.toDouble()),
                  vb: addCommasToIntegerPart(
                      widget.transaction.amount!.toDouble() /
                          widget.transaction.feeRate),
                ),
                style: CoconutTypography.body2_14,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNewFeeWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            t.transaction_fee_bumping_screen.new_fee,
            style: CoconutTypography.body2_14_Bold.setColor(
                _getNewFeeTextColor(isError: _viewModel.isLowerFeeError)),
          ),
          Row(
            children: [
              SizedBox(
                width: 54,
                child: Center(
                  child: CoconutTextField(
                      cursorColor: CoconutColors.white,
                      textInputType: TextInputType.number,
                      errorColor: CoconutColors.hotPink,
                      controller: _textEditingController,
                      activeColor: CoconutColors.white,
                      backgroundColor: CoconutColors.white.withOpacity(0.15),
                      prefix: null,
                      fontFamily: 'SpaceGrotesk',
                      maxLines: 1,
                      maxLength: 4,
                      focusNode: _feeTextFieldFocusNode,
                      padding: const EdgeInsets.symmetric(
                          vertical: 7, horizontal: 5),
                      isLengthVisible: false,
                      textAlign: TextAlign.center,
                      onChanged: (value) => print(value)),
                ),
              ),
              CoconutLayout.spacing_200w,
              Text(
                t.transaction_fee_bumping_screen.sats_vb,
                style: CoconutTypography.body2_14,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRecommendFeeWidget(int recommendFeeRate) {
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
            Text(
              t.transaction_fee_bumping_screen
                  .recommend_fee(fee: _viewModel.recommendFeeRate),
            ),
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
            color: _isRecommendFeePannelPressed
                ? CoconutColors.gray900
                : CoconutColors.gray800,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(1.5),
                  child: SvgPicture.asset('assets/svg/circle-info.svg'),
                ),
                CoconutLayout.spacing_100w,
                Expanded(
                  child: Text(
                    _isRbf
                        ? t.transaction_fee_bumping_screen
                            .recommend_fee_info_rbf
                        : _viewModel.isRecommendedFeesFetchSuccess
                            ? _viewModel.getCpfpFeeInfo()
                            : t.transaction_fee_bumping_screen
                                .recommended_fees_fetch_error,
                    style: CoconutTypography.body2_14,
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

  Widget _buildCurrentFeeWidget(
      int fastestFeeSatsPerVb, int halfhourFeeSatsPerVb, int hourFeeSatsPerVb) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      padding: const EdgeInsets.only(
        top: 14,
        left: 12,
        right: 24,
        bottom: CoconutLayout.defaultPadding,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          CoconutStyles.radius_200,
        ),
        color: CoconutColors.gray800,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.transaction_fee_bumping_screen.current_fee,
            style: CoconutTypography.body2_14_Bold,
          ),
          CoconutLayout.spacing_100h,
          Row(
            children: [
              CoconutLayout.spacing_300w,
              Text(
                TransactionFeeLevel.fastest.text,
                style: CoconutTypography.body2_14,
              ),
              CoconutLayout.spacing_200w,
              Text(
                TransactionFeeLevel.fastest.expectedTime,
                style: CoconutTypography.body2_14_NumberBold.setColor(
                  CoconutColors.gray400,
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      t.transaction_fee_bumping_screen.existing_fee_value(
                        value: fastestFeeSatsPerVb,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              CoconutLayout.spacing_300w,
              Text(
                TransactionFeeLevel.halfhour.text,
                style: CoconutTypography.body2_14,
              ),
              CoconutLayout.spacing_200w,
              Text(
                TransactionFeeLevel.halfhour.expectedTime,
                style: CoconutTypography.body2_14_NumberBold.setColor(
                  CoconutColors.gray400,
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      t.transaction_fee_bumping_screen.existing_fee_value(
                        value: halfhourFeeSatsPerVb,
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              CoconutLayout.spacing_300w,
              Text(
                TransactionFeeLevel.hour.text,
                style: CoconutTypography.body2_14,
              ),
              CoconutLayout.spacing_200w,
              Text(
                TransactionFeeLevel.hour.expectedTime,
                style: CoconutTypography.body2_14_NumberBold.setColor(
                  CoconutColors.gray400,
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      t.transaction_fee_bumping_screen.existing_fee_value(
                        value: hourFeeSatsPerVb,
                      ),
                    )
                  ],
                ),
              ),
            ],
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
        borderRadius: BorderRadius.circular(
          CoconutStyles.radius_200,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: CoconutLayout.defaultPadding,
        vertical: 14,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SvgPicture.asset(
            'assets/svg/triangle-warning.svg',
            colorFilter:
                const ColorFilter.mode(CoconutColors.hotPink, BlendMode.srcIn),
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
}
