import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/transaction_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/card/underline_button_item_card.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:coconut_wallet/widgets/highlighted_Info_area.dart';
import 'package:coconut_wallet/widgets/input_output_detail_row.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_detail_memo_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/shimmer_text.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TransactionDetailScreen extends StatefulWidget {
  static const _divider = Divider(color: CoconutColors.gray800);
  final int id;

  final String txHash;

  const TransactionDetailScreen({
    super.key,
    required this.id,
    required this.txHash,
  });

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen>
    with TickerProviderStateMixin {
  Timer? _timer; // timeGap을 최신화 하기 위한 타이머
  final GlobalKey _balanceWidthKey = GlobalKey();
  Size _balanceWidthSize = Size.zero;
  late TransactionDetailViewModel _viewModel;
  late AnimationController _animationController;
  late Animation<Offset> _slideInAnimation;
  late Animation<Offset> _slideOutAnimation;

  bool isAnimating = false; // 애니메이션 실행 중 여부 확인

  TransactionStatus? status;

  late bool rbfType;
  List<FeeHistory> feeBumpingHistoryList = [];
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<WalletProvider, TransactionProvider,
        TransactionDetailViewModel>(
      create: (_) {
        _viewModel = TransactionDetailViewModel(
          widget.id,
          widget.txHash,
          Provider.of<WalletProvider>(_, listen: false),
          Provider.of<TransactionProvider>(_, listen: false),
          Provider.of<NodeProvider>(_, listen: false),
          Provider.of<AddressRepository>(_, listen: false),
        );

        _viewModel.showDialogNotifier.addListener(_showDialogListener);
        _viewModel.loadCompletedNotifier.addListener(_loadCompletedListener);
        _updateAnimation();

        status = TransactionUtil.getStatus(_viewModel
            .transactionList![_viewModel.selectedTransactionIndex]
            .transaction!);
        rbfType = status == TransactionStatus.sending ||
            status == TransactionStatus.selfsending ||
            status == TransactionStatus.sent;

        return _viewModel;
      },
      update: (_, walletProvider, txProvider, viewModel) {
        _syncFeeHistoryList();
        viewModel!.updateProvider();
        return viewModel;
      },
      child: Consumer<TransactionDetailViewModel>(
        builder: (_, viewModel, child) {
          if (viewModel.transactionList == null ||
              viewModel.transactionList!.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactionDetail =
              viewModel.transactionList![viewModel.selectedTransactionIndex];

          return Scaffold(
              backgroundColor: MyColors.black,
              appBar: CustomAppBar.build(
                title: t.view_tx_details,
                context: context,
                hasRightIcon: false,
              ),
              body: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        HighlightedInfoArea(
                          textList: DateTimeUtil.formatTimeStamp(
                            viewModel
                                .transactionList![
                                    viewModel.selectedTransactionIndex]
                                .transaction!
                                .timestamp!
                                .toLocal(),
                          ),
                        ),
                        const SizedBox(
                          height: 24,
                        ),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              _amountText(viewModel
                                  .transactionList![
                                      _viewModel.selectedTransactionIndex]
                                  .transaction!),
                              const SizedBox(
                                width: 4,
                              ),
                              Text(t.btc, style: Styles.body2Number),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        Center(
                            child: Selector<UpbitConnectModel, int?>(
                          selector: (context, model) => model.bitcoinPriceKrw,
                          builder: (context, bitcoinPriceKrw, child) {
                            return Text(
                              bitcoinPriceKrw != null
                                  ? '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(viewModel.transactionList![_viewModel.selectedTransactionIndex].transaction!.amount!, bitcoinPriceKrw).toDouble().abs())} ${CurrencyCode.KRW.code}'
                                  : '',
                              style: Styles.balance2,
                            );
                          },
                        )),
                        const SizedBox(height: 20),
                        if (_isTransactionStatusPending(
                            viewModel.transactionList!.last.transaction!)) ...{
                          Column(
                            children: [
                              _pendingWidget(
                                  viewModel.transactionList!.last.transaction!),
                              if (rbfType)
                                (viewModel.transactionList!.last.transaction!
                                                .rbfHistoryList !=
                                            null &&
                                        viewModel
                                            .transactionList!
                                            .last
                                            .transaction!
                                            .rbfHistoryList!
                                            .isNotEmpty)
                                    ? _rbfHistoryWidget()
                                    : Container()
                              else
                                viewModel.transactionList!.last.transaction!
                                            .cpfpHistory !=
                                        null
                                    ? _cpfpHistoryWidget()
                                    : Container(),
                              CoconutLayout.spacing_300h,
                            ],
                          )
                        },
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: CoconutColors.gray800),
                          child: Stack(
                            children: [
                              if (_viewModel.previousTransactionIndex !=
                                  _viewModel.selectedTransactionIndex)
                                AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    return SlideTransition(
                                      position: _slideOutAnimation,
                                      child: Opacity(
                                        opacity:
                                            1.0 - _animationController.value,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _buildTransactionDetail(
                                      _viewModel.previousTransactionIndex),
                                ),
                              AnimatedBuilder(
                                animation: _animationController,
                                builder: (context, child) {
                                  return SlideTransition(
                                    position: _slideInAnimation,
                                    child: Opacity(
                                      opacity: _animationController.value,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildTransactionDetail(
                                    _viewModel.selectedTransactionIndex),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        UnderlineButtonItemCard(
                          label: t.block_num,
                          underlineButtonLabel:
                              transactionDetail.transaction!.blockHeight != 0
                                  ? t.view_mempool
                                  : '',
                          onTapUnderlineButton: () {
                            transactionDetail.transaction!.blockHeight != 0
                                ? launchUrl(Uri.parse(
                                    '${CoconutWalletApp.kMempoolHost}/block/${transactionDetail.transaction!.blockHeight}'))
                                : ();
                          },
                          child: Text(
                            transactionDetail.transaction!.blockHeight != 0
                                ? t.transaction_detail_screen.confirmation(
                                    height: transactionDetail
                                        .transaction!.blockHeight
                                        .toString(),
                                    count: _confirmedCountText(
                                        transactionDetail.transaction,
                                        viewModel.currentBlock?.height))
                                : '-',
                            style: Styles.body1Number,
                          ),
                        ),
                        TransactionDetailScreen._divider,
                        UnderlineButtonItemCard(
                            label: t.tx_id,
                            underlineButtonLabel: t.view_mempool,
                            onTapUnderlineButton: () {
                              launchUrl(Uri.parse(
                                  "${CoconutWalletApp.kMempoolHost}/tx/${transactionDetail.transaction!.transactionHash}"));
                            },
                            child: Text(
                              transactionDetail.transaction!.transactionHash,
                              style: Styles.body1Number,
                            )),
                        TransactionDetailScreen._divider,
                        UnderlineButtonItemCard(
                            label: t.tx_memo,
                            underlineButtonLabel: t.edit,
                            onTapUnderlineButton: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) => MemoBottomSheet(
                                  originalMemo:
                                      transactionDetail.transaction!.memo ?? '',
                                  onComplete: (memo) {
                                    if (!viewModel
                                        .updateTransactionMemo(memo)) {
                                      CustomToast.showWarningToast(
                                        context: context,
                                        text: t.toast.memo_update_failed,
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                            child: Text(
                              transactionDetail.transaction!.memo?.isNotEmpty ==
                                      true
                                  ? transactionDetail.transaction!.memo!
                                  : '-',
                              style: Styles.body1Number,
                            )),
                        const SizedBox(
                          height: 40,
                        ),
                        Text(
                          /// inputOutput 위젯에 들어갈 balance 최대 너비 체크용
                          key: _balanceWidthKey,
                          '0.0000 0000',
                          style: Styles.body2Number.merge(
                            const TextStyle(
                              color: Colors.transparent,
                              fontSize: 14,
                              height: 16 / 14,
                            ),
                          ),
                        ),
                      ]),
                ),
              ));
        },
      ),
    );
  }

  Widget _buildTransactionDetail(int index) {
    final transactionDetail = _viewModel.transactionList![index];

    return Column(
      key: ValueKey(_viewModel
          .transactionList![_viewModel.selectedTransactionIndex]
          .transaction!
          .transactionHash),
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactionDetail.inputCountToShow,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            final address = _viewModel.getInputAddress(index);
            final amount = _viewModel.getInputAmount(index);
            return Column(
              children: [
                InputOutputDetailRow(
                  address: address,
                  balance: amount,
                  balanceMaxWidth: _balanceWidthSize.width > 0
                      ? _balanceWidthSize.width
                      : 100,
                  rowType: InputOutputRowType.input,
                  isCurrentAddress: _viewModel.isSameAddress(address, index),
                  transactionStatus: status,
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
        Visibility(
          visible: _viewModel
              .transactionList![_viewModel.selectedTransactionIndex]
              .canSeeMoreInputs,
          child: Center(
            child: CustomUnderlinedButton(
              text: t.view_more,
              onTap: () {
                _viewModel.onTapViewMoreInputs();
              },
              fontSize: 12,
              lineHeight: 14,
            ),
          ),
        ),
        SizedBox(height: transactionDetail.canSeeMoreInputs ? 8 : 16),
        InputOutputDetailRow(
          address: t.fee,
          balance: transactionDetail.transaction?.fee ?? 0,
          balanceMaxWidth:
              _balanceWidthSize.width > 0 ? _balanceWidthSize.width : 100,
          rowType: InputOutputRowType.fee,
          transactionStatus: status,
        ),
        const SizedBox(
          height: 8,
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactionDetail.outputCountToShow,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            final address = _viewModel.getOutputAddress(index);
            final amount = _viewModel.getOutputAmount(index);
            return Column(
              children: [
                InputOutputDetailRow(
                  address: address,
                  balance: amount,
                  balanceMaxWidth: _balanceWidthSize.width > 0
                      ? _balanceWidthSize.width
                      : 100,
                  rowType: InputOutputRowType.output,
                  isCurrentAddress: _viewModel.isSameAddress(address, index),
                  transactionStatus: status,
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
        Visibility(
          visible: transactionDetail.canSeeMoreOutputs,
          child: Center(
            child: CustomUnderlinedButton(
              text: t.view_more,
              onTap: () {
                _viewModel.onTapViewMoreOutputs();
              },
              fontSize: 12,
              lineHeight: 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_timer != null) {
      _timer = null;
    }
    _animationController.dispose();
    // _viewModel.init();
    _viewModel.showDialogNotifier.removeListener(_showDialogListener);
    _viewModel.showDialogNotifier.removeListener(_loadCompletedListener);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompletedListener();
      _animationController.value = 1.0;
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _syncFeeHistoryList() {
    if (_viewModel.transactionList == null ||
        _viewModel.transactionList!.isEmpty) {
      return;
    }

    feeBumpingHistoryList =
        _viewModel.transactionList!.map((transactionDetail) {
      return FeeHistory(
        feeRate: transactionDetail.transaction!.feeRate.toInt(),
        isSlected: _viewModel.selectedTransactionIndex ==
            _viewModel.transactionList!.indexOf(transactionDetail),
      );
    }).toList();
    for (var fee in feeBumpingHistoryList) {
      debugPrint(
          'feeHIstoryList[${feeBumpingHistoryList.indexOf(fee)}] ::::: ${fee.feeRate}');
    }
  }

  void _updateAnimation() {
    final bool slideRight = _viewModel.selectedTransactionIndex >
        _viewModel.previousTransactionIndex;

    _slideInAnimation = Tween<Offset>(
      begin: slideRight ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideOutAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: slideRight ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  Widget _rbfHistoryWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: List.generate(
          feeBumpingHistoryList.length,
          (index) {
            final feeHistory = feeBumpingHistoryList[index];
            bool isLast = index == feeBumpingHistoryList.length - 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 타임라인 선
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          children: [
                            Container(
                                width: 1,
                                height: isLast ? 18 : 36,
                                color: CoconutColors.gray700),
                            if (isLast)
                              Container(
                                width: 1,
                                height: 11,
                                color: Colors.transparent,
                              ),
                          ],
                        ),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: CoconutColors.gray700,
                            shape: BoxShape.circle,
                          ),
                        ),
                        // )
                      ],
                    ),
                    CoconutLayout.spacing_100w,
                    Row(
                      children: [
                        CoconutChip(
                          color: _viewModel.selectedTransactionIndex == index
                              ? CoconutColors.primary
                              : CoconutColors.gray800,
                          label: index == 0
                              ? t.transaction_fee_bumping_screen.new_fee
                              : t.transaction_fee_bumping_screen.existing_fee,
                          labelColor:
                              _viewModel.selectedTransactionIndex == index
                                  ? CoconutColors.black
                                  : CoconutColors.white,
                          isSelected:
                              _viewModel.selectedTransactionIndex == index,
                          onTap: () {
                            _changeTransaction(index);
                          },
                        ),
                        CoconutLayout.spacing_200w,
                        Text(
                          t.transaction_fee_bumping_screen
                              .existing_fee_value(value: feeHistory.feeRate),
                          style: CoconutTypography.body2_14_NumberBold,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _changeTransaction(int newIndex) {
    if (newIndex == _viewModel.selectedTransactionIndex ||
        _animationController.isAnimating) {
      return;
    }

    setState(() {
      _viewModel.setPreviousTransactionIndex();
      _viewModel.setSelectedTransactionIndex(newIndex);
      _updateAnimation();
    });

    _animationController.forward(from: 0);
  }

  Widget _cpfpHistoryWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        children: List.generate(
          feeBumpingHistoryList.length,
          (index) {
            final feeHistory = feeBumpingHistoryList[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 타임라인 선
                Padding(
                  padding: EdgeInsets.only(left: (20 * index).toDouble()),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 2.5),
                            child: Column(
                              children: [
                                Container(
                                  width: 1,
                                  height: 22,
                                  color: const Color.fromRGBO(81, 81, 96, 1),
                                ),
                                Container(
                                  width: 1,
                                  height: 11,
                                  color: Colors.transparent,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 16.5),
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color.fromRGBO(81, 81, 96, 1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        ],
                      ),
                      CoconutLayout.spacing_100w,
                      Row(
                        children: [
                          CoconutChip(
                            color: CoconutColors.gray800,
                            label: index == 0
                                ? t.transaction_fee_bumping_screen.new_fee
                                : t.transaction_fee_bumping_screen.existing_fee,
                            labelColor: CoconutColors.white,
                          ),
                          CoconutLayout.spacing_200w,
                          Text(
                            t.transaction_fee_bumping_screen
                                .existing_fee_value(value: feeHistory.feeRate),
                            style: CoconutTypography.body2_14_NumberBold,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _isTransactionStatusPending(TransactionRecord tx) {
    return tx.blockHeight == 0;
  }

  Widget _pendingWidget(TransactionRecord tx) {
    if (status == null) {
      return Container();
    }
    return Container(
      width: MediaQuery.sizeOf(context).width,
      decoration: BoxDecoration(
        border: Border.all(
          width: 1,
          color: CoconutColors.gray700,
        ),
        borderRadius: BorderRadius.circular(
          CoconutStyles.radius_200,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rbfType
                  ? CoconutColors.primary.withOpacity(0.2)
                  : CoconutColors.cyan.withOpacity(0.2),
            ),
            child: Center(
              child: rbfType
                  ? Lottie.asset('assets/lottie/arrow-up.json',
                      fit: BoxFit.fill, repeat: true)
                  : Lottie.asset('assets/lottie/arrow-down.json',
                      fit: BoxFit.fill, repeat: true),
            ),
          ),
          Text.rich(
            TextSpan(
              text: rbfType ? t.status_sending : t.status_receiving,
              style: CoconutTypography.body2_14
                  .copyWith(fontWeight: FontWeight.w500),
              children: [
                TextSpan(
                  text: ' (${_getTimeGapString()})',
                  style: CoconutTypography.body3_12
                      .copyWith(fontWeight: FontWeight.w300),
                ),
              ],
            ),
          ),
          CoconutLayout.spacing_50w,
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () async {
                  Navigator.pushNamed(context, '/transaction-fee-bumping',
                      arguments: {
                        'transaction': tx,
                        'feeBumpingType':
                            rbfType ? FeeBumpingType.rbf : FeeBumpingType.cpfp,
                        'walletId': widget.id,
                        'walletName': _viewModel.getWalletName(),
                        'currentUtxo': _viewModel.currentUtxo,
                      });
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    rbfType ? t.quick_send : t.quick_receive,
                    style: CoconutTypography.body2_14.setColor(
                        rbfType ? CoconutColors.primary : CoconutColors.cyan),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  String _getTimeGapString() {
    if (_viewModel.transactionList?.last.transaction?.timestamp == null) {
      return '';
    }

    DateTime? timeStamp =
        _viewModel.transactionList?.last.transaction!.timestamp!;
    if (timeStamp == null) return '';

    DateTime now = DateTime.now();
    Duration difference = now.difference(timeStamp);

    if (difference.inMinutes < 1) {
      return "방금 전"; // 1분 미만일 경우
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes}분 째"; // 1~59분
    } else if (difference.inHours < 24) {
      return "${difference.inHours}시간 째"; // 1~23시간
    } else {
      return "${difference.inDays}일 째"; // 1일 이상
    }
  }

  Widget _amountText(TransactionRecord tx) {
    String prefix;
    Color color;

    switch (TransactionUtil.getStatus(tx)) {
      case TransactionStatus.receiving:
      case TransactionStatus.received:
        prefix = '+';
        color = MyColors.secondary;
        break;
      case TransactionStatus.self:
      case TransactionStatus.selfsending:
      case TransactionStatus.sent:
      case TransactionStatus.sending:
        prefix = '';
        color = MyColors.primary;
        break;
      default:
        // 기본 값으로 처리될 수 있도록 한 경우
        return const SizedBox();
    }

    return Text(
      '$prefix${satoshiToBitcoinString(tx.amount!)}',
      style: Styles.h1Number.merge(
        TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 24,
          height: 1,
        ),
      ),
    );
  }

  String _confirmedCountText(TransactionRecord? tx, int? blockHeight) {
    if (blockHeight == null || tx == null) {
      return '';
    }

    if (tx.blockHeight != null && tx.blockHeight != 0 && blockHeight != 0) {
      final confirmationCount = blockHeight - tx.blockHeight! + 1;
      if (confirmationCount > 0) {
        return '$confirmationCount ';
      }
    }
    return '';
  }

  void _loadCompletedListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = _balanceWidthKey.currentContext?.findRenderObject();
      if (renderBox is RenderBox) {
        setState(() {
          _balanceWidthSize = renderBox.size;
        });
      }
    });
  }

  void _showDialogListener() {
    CustomDialogs.showCustomAlertDialog(
      context,
      title: t.alert.tx_detail.fetch_failed,
      message: t.alert.tx_detail.fetch_failed_description,
      onConfirm: () {
        Navigator.pop(context); // 팝업 닫기
        Navigator.pop(context); // 지갑 상세 이동
      },
    );
  }
}

class FeeHistory {
  final int feeRate;
  final bool isSlected;

  FeeHistory({
    required this.feeRate,
    this.isSlected = false,
  });
}
