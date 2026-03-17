import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/transaction_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/button/copy_text_container.dart';
import 'package:coconut_wallet/widgets/card/send_transaction_flow_card.dart';
import 'package:coconut_wallet/widgets/card/transaction_input_output_card.dart';
import 'package:coconut_wallet/widgets/card/underline_button_item_card.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
import 'package:coconut_wallet/widgets/highlighted_info_area.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_detail_memo_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class TransactionDetailScreen extends StatefulWidget {
  final int id;

  final String txHash;

  const TransactionDetailScreen({super.key, required this.id, required this.txHash});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> with TickerProviderStateMixin {
  Timer? _timer; // timeGap을 최신화 하기 위한 타이머
  late TransactionDetailViewModel _viewModel;
  late AnimationController _animationController;
  late Animation<Offset> _slideInAnimation;
  late Animation<Offset> _slideOutAnimation;
  bool isAnimating = false; // 애니메이션 실행 중 여부 확인
  late BitcoinUnit _currentUnit;

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit.next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<WalletProvider, TransactionProvider, TransactionDetailViewModel>(
      create: (_) {
        _viewModel = TransactionDetailViewModel(
          widget.id,
          widget.txHash,
          Provider.of<WalletProvider>(context, listen: false),
          Provider.of<TransactionProvider>(context, listen: false),
          Provider.of<NodeProvider>(context, listen: false),
          Provider.of<AddressRepository>(context, listen: false),
          Provider.of<ConnectivityProvider>(context, listen: false),
          Provider.of<SendInfoProvider>(context, listen: false),
          Provider.of<BlockExplorerProvider>(context, listen: false),
        );

        _viewModel.showDialogNotifier.addListener(_showDialogListener);
        _viewModel.setTransactionStatus(
          TransactionUtil.getStatus(_viewModel.transactionList![_viewModel.selectedTransactionIndex]),
        );

        _updateAnimation();
        return _viewModel;
      },
      update: (_, walletProvider, txProvider, viewModel) {
        viewModel!.updateProvider();
        return viewModel;
      },
      child: Consumer<TransactionDetailViewModel>(
        builder: (_, viewModel, child) {
          final txList = viewModel.transactionList;
          if (txList == null || txList.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final tx = viewModel.transactionList![viewModel.selectedTransactionIndex];
          final txMemo = viewModel.fetchTransactionMemo();

          return Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: CoconutAppBar.build(title: t.view_tx_details, context: context),
            body: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: () async => viewModel.onRefresh(),
                  refreshTriggerPullDistance: 100,
                ),
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        HighlightedInfoArea(textList: DateTimeUtil.formatTimestamp(tx.timestamp.toLocal())),
                        CoconutLayout.spacing_500h,
                        _buildAmount(tx),
                        CoconutLayout.spacing_400h,
                        if (_isTransactionStatusPending(txList.last) && viewModel.isSendType != null) ...[
                          _buildFeeBumpingWidget(txList, viewModel),
                        ],
                        if (viewModel.isFetchingFromMempool) ...[
                          _buildTransactionFlowCardSkeleton(),
                        ] else if (tx.inputAddressList.isNotEmpty) ...[
                          _buildTransactionFlowCard(context, tx, viewModel),
                        ],
                        CoconutLayout.spacing_300h,

                        _buildTxInputOutputDetail(context, tx, viewModel),
                        CoconutLayout.spacing_800h,
                        _buildTxId(tx, viewModel),
                        _buildFeeRate(tx),
                        _buildTxMemo(context, txMemo, viewModel),
                        _buildBlockHeight(tx, viewModel),
                        _buildTagSection(context, widget.id, tx),
                        CoconutLayout.spacing_1000h,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_timer != null) {
      _timer = null;
    }
    _animationController.dispose();
    _viewModel.showDialogNotifier.removeListener(_showDialogListener);
    _viewModel.clearTransationList();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _currentUnit = context.read<PreferenceProvider>().currentUnit;
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.value = 1.0;
    });
  }

  void _updateAnimation() {
    final bool slideRight = _viewModel.selectedTransactionIndex > _viewModel.previousTransactionIndex;

    _slideInAnimation = Tween<Offset>(
      begin: slideRight ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _slideOutAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: slideRight ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0),
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  Widget _rbfHistoryWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: List.generate(_viewModel.feeBumpingHistoryList!.length, (index) {
          final feeHistory = _viewModel.feeBumpingHistoryList![index];
          bool isLast = index == _viewModel.feeBumpingHistoryList!.length - 1;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index == 0)
                SizedBox(width: 7, child: Center(child: Container(width: 1, height: 4, color: CoconutColors.gray700))),
              // 타임라인 선
              Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        children: [
                          Container(width: 1, height: isLast ? 16 : 33, color: CoconutColors.gray700),
                          if (isLast) Container(width: 1, height: 16, color: Colors.transparent),
                        ],
                      ),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(color: CoconutColors.gray700, shape: BoxShape.circle),
                      ),
                      // )
                    ],
                  ),
                  CoconutLayout.spacing_100w,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CoconutChip(
                        color:
                            _viewModel.selectedTransactionIndex == index
                                ? CoconutColors.primary
                                : CoconutColors.gray800,
                        label:
                            !isLast
                                ? t.transaction_fee_bumping_screen.new_fee
                                : t.transaction_fee_bumping_screen.existing_fee,
                        labelColor:
                            _viewModel.selectedTransactionIndex == index ? CoconutColors.black : CoconutColors.white,
                        isSelected: _viewModel.selectedTransactionIndex == index,
                        onTap: () {
                          _changeTransaction(index);
                        },
                      ),
                      CoconutLayout.spacing_200w,
                      Text(
                        t.transaction_fee_bumping_screen.existing_fee_value(value: feeHistory.feeRate),
                        style: CoconutTypography.body2_14_Number,
                        textScaler: const TextScaler.linear(1.0),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  void _changeTransaction(int newIndex) {
    if (newIndex == _viewModel.selectedTransactionIndex || _animationController.isAnimating) {
      return;
    }

    setState(() {
      _viewModel.updateTransactionIndex(newIndex);
      _updateAnimation();
    });

    _animationController.forward(from: 0);
  }

  Widget _cpfpHistoryWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: List.generate(_viewModel.feeBumpingHistoryList!.length, (index) {
          final feeHistory = _viewModel.feeBumpingHistoryList![index];
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
                              Container(width: 1, height: 22, color: const Color.fromRGBO(81, 81, 96, 1)),
                              Container(width: 1, height: 11, color: Colors.transparent),
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
                        ),
                      ],
                    ),
                    CoconutLayout.spacing_100w,
                    Row(
                      children: [
                        CoconutChip(
                          color: CoconutColors.gray800,
                          label:
                              index == 0
                                  ? t.transaction_fee_bumping_screen.existing_fee
                                  : t.transaction_fee_bumping_screen.new_fee,
                          labelColor: CoconutColors.white,
                        ),
                        CoconutLayout.spacing_200w,
                        Text(
                          t.transaction_fee_bumping_screen.existing_fee_value(value: feeHistory.feeRate),
                          style: CoconutTypography.body2_14_Number,
                          textScaler: const TextScaler.linear(1.0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  bool _isTransactionStatusPending(TransactionRecord tx) {
    _timer?.cancel();

    if (tx.blockHeight != 0) {
      _timer?.cancel();
      if (_timer != null) {
        _timer = null;
      }
      return false;
    }

    // 'n분 째' 최신화를 위한 타이머, pending 상태인 tx일 때만 타이머가 작동합니다.
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
    return true;
  }

  Widget _pendingWidget(TransactionRecord tx) {
    if (_viewModel.transactionStatus == null || _viewModel.isSendType == null) {
      return Container();
    }
    bool canBumpingTx = _viewModel.canBumpingTx;

    return Container(
      width: MediaQuery.sizeOf(context).width,
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: CoconutColors.gray700),
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
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
              color:
                  _viewModel.isSendType!
                      ? CoconutColors.primary.withValues(alpha: 0.2)
                      : CoconutColors.cyan.withValues(alpha: 0.2),
            ),
            child: Center(
              child:
                  _viewModel.isSendType!
                      ? Lottie.asset('assets/lottie/arrow-up.json', fit: BoxFit.fill, repeat: true)
                      : Lottie.asset('assets/lottie/arrow-down.json', fit: BoxFit.fill, repeat: true),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  text: _viewModel.isSendType! ? t.status_sending : t.status_receiving,
                  style: CoconutTypography.body2_14.copyWith(fontWeight: FontWeight.w500),
                  children: [
                    TextSpan(
                      text: ' (${_getTimeGapString()})',
                      style: CoconutTypography.body3_12.copyWith(fontWeight: FontWeight.w300),
                    ),
                  ],
                ),
              ),
            ),
          ),
          CoconutLayout.spacing_50w,
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Align(
                alignment: Alignment.centerRight,
                child: Visibility(
                  visible: _viewModel.isSendType! || (_viewModel.feeBumpingHistoryList?.length ?? 0) < 2,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: GestureDetector(
                    onTap: () async {
                      if (!_viewModel.isNetworkOn) {
                        CoconutToast.showWarningToast(context: context, text: ErrorCodes.networkError.message);
                        return;
                      }

                      if (!canBumpingTx) return;

                      _viewModel.clearSendInfo();
                      Navigator.pushNamed(
                        context,
                        '/transaction-fee-bumping',
                        arguments: {
                          'transaction': tx,
                          'feeBumpingType': _viewModel.isSendType! ? FeeBumpingType.rbf : FeeBumpingType.cpfp,
                          'walletId': widget.id,
                          'walletName': _viewModel.getWalletName(),
                        },
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _viewModel.isSendType! ? t.quick_send : t.quick_receive,
                        style: CoconutTypography.body2_14.setColor(
                          _viewModel.isSendType!
                              ? CoconutColors.primary.withValues(alpha: canBumpingTx ? 1.0 : 0.5)
                              : CoconutColors.cyan.withValues(alpha: canBumpingTx ? 1.0 : 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeGapString() {
    if (_viewModel.transactionList?.last.timestamp == null) {
      return '';
    }

    DateTime? timeStamp = _viewModel.transactionList?.last.timestamp;
    if (timeStamp == null) return '';

    DateTime now = DateTime.now();
    Duration difference = now.difference(timeStamp);

    if (difference.inMinutes < 1) {
      return t.transaction_detail_screen.time_ago.just_now; // 1분 미만일 경우
    } else if (difference.inMinutes < 60) {
      return t.transaction_detail_screen.time_ago.minutes(count: difference.inMinutes); // 1~59분
    } else if (difference.inHours < 24) {
      return t.transaction_detail_screen.time_ago.hours(count: difference.inHours); // 1~23시간
    } else {
      return t.transaction_detail_screen.time_ago.days(count: difference.inDays); // 1일 이상
    }
  }

  Widget _buildTransactionFlowCardSkeleton() {
    return Shimmer.fromColors(
      baseColor: CoconutColors.gray850,
      highlightColor: CoconutColors.gray800,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: CoconutColors.gray850,
          borderRadius: BorderRadius.circular(CoconutStyles.radius_400),
        ),
      ),
    );
  }

  bool _isOutputNavigable(BuildContext context, TransactionRecord tx, String address, int outputIndex) {
    final walletProvider = context.read<WalletProvider>();
    if (!walletProvider.containsAddressInAnyWallet(address)) return false;
    final walletId = walletProvider.findWalletIdContainingAddress(address);
    if (walletId == null) return false;
    final utxoId = getUtxoId(tx.transactionHash, outputIndex);
    return walletProvider.getUtxoState(walletId, utxoId) != null;
  }

  Widget _buildTxInputOutputDetail(BuildContext context, TransactionRecord tx, TransactionDetailViewModel viewModel) {
    return Stack(
      children: [
        if (viewModel.previousTransactionIndex != viewModel.selectedTransactionIndex)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return SlideTransition(
                position: _slideOutAnimation,
                child: Opacity(opacity: 1.0 - _animationController.value, child: child),
              );
            },
            child: TransactionInputOutputCard(
              key: ValueKey(viewModel.getTransactionKey(viewModel.previousTransactionIndex)),
              transaction: viewModel.transactionList![viewModel.previousTransactionIndex],
              isSameAddress: viewModel.isSameAddress,
              currentUnit: _currentUnit,
              isOutputNavigable:
                  (address, outputIndex) => _isOutputNavigable(
                    context,
                    viewModel.transactionList![viewModel.previousTransactionIndex],
                    address,
                    outputIndex,
                  ),
              onOutputTap:
                  (address, outputIndex, amount) => _navigateToUtxoDetailFromFlow(
                    viewModel.transactionList![viewModel.previousTransactionIndex],
                    FlowOutputTapTarget(address: address, amount: amount, outputIndex: outputIndex),
                    viewModel,
                  ),
            ),
          ),
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return SlideTransition(
              position: _slideInAnimation,
              child: Opacity(opacity: _animationController.value, child: child),
            );
          },
          child: TransactionInputOutputCard(
            key: ValueKey(viewModel.getTransactionKey(viewModel.selectedTransactionIndex)),
            transaction: viewModel.transactionList![viewModel.selectedTransactionIndex],
            isSameAddress: viewModel.isSameAddress,
            currentUnit: _currentUnit,
            isOutputNavigable:
                (address, outputIndex) => _isOutputNavigable(
                  context,
                  viewModel.transactionList![viewModel.selectedTransactionIndex],
                  address,
                  outputIndex,
                ),
            onOutputTap:
                (address, outputIndex, amount) => _navigateToUtxoDetailFromFlow(
                  tx,
                  FlowOutputTapTarget(address: address, amount: amount, outputIndex: outputIndex),
                  viewModel,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmount(TransactionRecord tx) {
    return GestureDetector(
      onTap: _toggleUnit,
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [_amountText(tx)],
            ),
          ),
          CoconutLayout.spacing_100h,
          FiatPrice(
            satoshiAmount: tx.amount.abs(),
            textStyle: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray500),
          ),
        ],
      ),
    );
  }

  List<UtxoTag> _getOutputTagsForTransaction(BuildContext context, int walletId, TransactionRecord tx) {
    final tagProvider = context.read<UtxoTagProvider>();
    final isOutputMine = context.read<WalletProvider>().containsAddressInAnyWallet;
    final selectedTags = <String, UtxoTag>{};

    for (var i = 0; i < tx.outputAddressList.length; i++) {
      final output = tx.outputAddressList[i];
      if (!isOutputMine(output.address)) continue;

      final utxoId = getUtxoId(tx.transactionHash, i);
      final tags = tagProvider.getUtxoTagsByUtxoId(walletId, utxoId);
      for (final tag in tags) {
        selectedTags[tag.id] = tag;
      }
    }
    return selectedTags.values.toList();
  }

  Widget _buildTagSection(BuildContext context, int walletId, TransactionRecord tx) {
    final selectedTags = _getOutputTagsForTransaction(context, walletId, tx);
    return UnderlineButtonItemCard(
      label: 'UTXO ${t.tag}',
      underlineButtonLabel: null,
      onTapUnderlineButton: null,
      showDivider: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedTags.isEmpty)
              Text('-', style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white))
            else
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: List.generate(selectedTags.length, (index) {
                  final foregroundColor = tagColorPalette[selectedTags[index].colorIndex];
                  return IntrinsicWidth(
                    child: CoconutChip(
                      minWidth: 40,
                      color: CoconutColors.backgroundColorPaletteDark[selectedTags[index].colorIndex],
                      borderColor: foregroundColor,
                      label: '#${selectedTags[index].name}',
                      labelSize: 12,
                      labelColor: foregroundColor,
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTxMemo(BuildContext context, String? txMemo, TransactionDetailViewModel viewModel) {
    return Column(
      children: [
        UnderlineButtonItemCard(
          label: t.tx_memo,
          underlineButtonLabel: t.edit,
          onTapUnderlineButton: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder:
                  (context) => MemoBottomSheet(
                    originalMemo: txMemo ?? '',
                    onComplete: (memo) {
                      if (!viewModel.updateTransactionMemo(memo)) {
                        CoconutToast.showWarningToast(context: context, text: t.toast.memo_update_failed);
                      }
                    },
                  ),
            );
          },
          child: Text(
            txMemo?.isNotEmpty == true ? txMemo! : '-',
            style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildTxId(TransactionRecord tx, TransactionDetailViewModel viewModel) {
    return UnderlineButtonItemCard(
      label: t.tx_id,
      underlineButtonLabel: t.view_mempool,
      onTapUnderlineButton: () {
        launchUrl(Uri.parse('${viewModel.mempoolHost}/tx/${tx.transactionHash}'));
      },
      child: CopyTextContainer(
        text: viewModel.isSendType! ? tx.transactionHash : widget.txHash,
        textStyle: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
      ),
    );
  }

  Widget _buildFeeRate(TransactionRecord tx) {
    return UnderlineButtonItemCard(
      label: t.fee_rate,
      underlineButtonLabel: '',
      onTapUnderlineButton: () {},
      child: Text(
        // 인풋을 조회할 수 없는 경우, 수수료 표시 안 함.
        tx.inputAddressList.isNotEmpty ? '${tx.feeRate.toStringAsFixed(2)} sats/vB' : '-',
        style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
      ),
    );
  }

  Widget _buildBlockHeight(TransactionRecord tx, TransactionDetailViewModel viewModel) {
    return UnderlineButtonItemCard(
      label: t.block_num,
      underlineButtonLabel: tx.blockHeight != 0 ? t.view_mempool : '',
      onTapUnderlineButton: () {
        tx.blockHeight != 0 ? launchUrl(Uri.parse('${_viewModel.mempoolHost}/block/${tx.blockHeight}')) : ();
      },

      child: Text(
        tx.blockHeight != 0
            ? t.transaction_detail_screen.confirmation(
              height: tx.blockHeight.toString(),
              count: _confirmedCountText(tx, viewModel.currentBlock?.height),
            )
            : '-',
        style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
      ),
    );
  }

  Widget _buildFeeBumpingWidget(List<TransactionRecord> txList, TransactionDetailViewModel viewModel) {
    return Column(
      children: [
        _pendingWidget(txList.first),
        if (viewModel.isSendType!)
          (txList.last.rbfHistoryList != null && txList.last.rbfHistoryList!.isNotEmpty)
              ? _rbfHistoryWidget()
              : Container()
        else
          txList.last.cpfpHistory != null ? _cpfpHistoryWidget() : Container(),
        CoconutLayout.spacing_300h,
      ],
    );
  }

  Widget _buildTransactionFlowCard(BuildContext context, TransactionRecord tx, TransactionDetailViewModel viewModel) {
    final inputAmounts = tx.inputAddressList.map((a) => a.amount.abs()).toList();
    final externalOutputAmounts = <int>[];
    final changeOutputAmounts = <int>[];
    final externalOutputTapTargets = <FlowOutputTapTarget>[];
    final navigableOutputTapTargets = <FlowOutputTapTarget>[];
    final orderedOutputs = <FlowOutputTapTarget>[];

    // isOutputMine: output 중 navigable 목록 추출
    // isOutputToMyWallet: flow 색상 추출 시 현재 지갑 주소 여부 확인 필요
    // incoming: utxo 존재 시에만 navigable, walletId 주소만 cyan
    // outgoing: 내 지갑 주소 & utxo 존재에만 navigable, walletId 주소만 white
    final walletProvider = context.read<WalletProvider>();
    final isOutputMine = walletProvider.containsAddressInAnyWallet;
    final isOutputToMyWallet = walletProvider.containsAddress;
    final status = viewModel.transactionStatus;
    final isIncoming = status == TransactionStatus.received || status == TransactionStatus.receiving;
    final isOutgoing =
        status == TransactionStatus.sent ||
        status == TransactionStatus.sending ||
        status == TransactionStatus.self ||
        status == TransactionStatus.selfsending;
    FlowOutputTapTarget? changeTapTarget;

    for (var i = 0; i < tx.outputAddressList.length; i++) {
      final output = tx.outputAddressList[i];
      final amount = output.amount.abs();
      final isChangeOutput =
          isOutputMine(output.address) && walletProvider.containsAddress(widget.id, output.address, isChange: true);
      final target = FlowOutputTapTarget(
        address: output.address,
        amount: amount,
        outputIndex: i,
        isChange: isChangeOutput,
      );
      orderedOutputs.add(target);
      if (isOutputMine(output.address)) {
        if (isChangeOutput) {
          changeOutputAmounts.add(amount);
        } else {
          externalOutputAmounts.add(amount);
          externalOutputTapTargets.add(target);
        }
        final walletId = walletProvider.findWalletIdContainingAddress(output.address);
        if (walletId != null) {
          final utxoId = getUtxoId(tx.transactionHash, i);
          final utxoState = walletProvider.getUtxoState(walletId, utxoId);
          if (isIncoming) {
            if (utxoState != null) {
              if (isChangeOutput) {
                changeTapTarget = target;
              } else {
                navigableOutputTapTargets.add(target);
              }
            }
          } else if (isOutgoing) {
            if (utxoState != null) {
              if (isChangeOutput) {
                changeTapTarget = target;
              } else {
                navigableOutputTapTargets.add(target);
              }
            }
          }
        }
      } else {
        externalOutputAmounts.add(amount);
        externalOutputTapTargets.add(target);
      }
    }

    if (changeTapTarget != null) {
      navigableOutputTapTargets.insert(0, changeTapTarget);
    }

    if (inputAmounts.isEmpty || (externalOutputAmounts.isEmpty && changeOutputAmounts.isEmpty)) {
      return const SizedBox.shrink();
    }

    return SendTransactionFlowCard(
      inputAmounts: List<int?>.from(inputAmounts),
      externalOutputAmounts: externalOutputAmounts,
      changeOutputAmounts: changeOutputAmounts,
      fee: tx.fee,
      currentUnit: _currentUnit,
      mode: SendTransactionFlowCardMode.navigable,
      externalOutputTapTargets: externalOutputTapTargets,
      navigableOutputTapTargets: navigableOutputTapTargets,
      isOutputMine: isOutputMine,
      walletId: widget.id,
      isOutputToMyWallet: isOutputToMyWallet,
      onOutputTap: (target) => _navigateToUtxoDetailFromFlow(tx, target, viewModel),
      transactionStatus: viewModel.transactionStatus,
      orderedOutputs: orderedOutputs,
    );
  }

  void _navigateToUtxoDetailFromFlow(
    TransactionRecord tx,
    FlowOutputTapTarget target,
    TransactionDetailViewModel viewModel,
  ) {
    final walletProvider = context.read<WalletProvider>();
    final walletId = walletProvider.findWalletIdContainingAddress(target.address);
    if (walletId == null) return;

    final derivationPath = context.read<AddressRepository>().getDerivationPath(walletId, target.address);
    final status =
        tx.blockHeight == 0
            ? (viewModel.isSendType == true ? UtxoStatus.outgoing : UtxoStatus.incoming)
            : UtxoStatus.unspent;

    final utxo = UtxoState(
      transactionHash: tx.transactionHash,
      index: target.outputIndex,
      amount: target.amount,
      derivationPath: derivationPath,
      blockHeight: tx.blockHeight,
      to: target.address,
      timestamp: tx.timestamp,
      status: status,
    );

    Navigator.pushNamed(context, '/utxo-detail', arguments: {'utxo': utxo, 'id': walletId});
  }

  String _getPrefix(TransactionRecord tx) {
    switch (TransactionUtil.getStatus(tx)) {
      case TransactionStatus.receiving:
      case TransactionStatus.received:
        return '+';
      case TransactionStatus.self:
      case TransactionStatus.selfsending:
      case TransactionStatus.sent:
      case TransactionStatus.sending:
        return '-';
      default:
        return '';
    }
  }

  Widget _amountText(TransactionRecord tx) {
    final bool isPositive = _getPrefix(tx) != '-';
    final Color color = isPositive ? CoconutColors.cyan : CoconutColors.primary;
    final String sign = isPositive ? '+' : '-';
    final String absAmount = _currentUnit.displayBitcoinAmount(tx.amount.abs());
    final String symbol = _currentUnit.symbol;
    final boldStyle = CoconutTypography.heading2_28_NumberBold.copyWith(fontSize: 24, color: color);
    final unitStyle = CoconutTypography.heading4_18_NumberBold.copyWith(color: color);

    if (_currentUnit.isPrefixSymbol) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(sign, style: boldStyle),
          Text(symbol, style: unitStyle),
          CoconutLayout.spacing_50w,
          Text(absAmount, style: boldStyle),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [Text('$sign$absAmount', style: boldStyle), CoconutLayout.spacing_50w, Text(symbol, style: unitStyle)],
    );
  }

  String _confirmedCountText(TransactionRecord? tx, int? blockHeight) {
    if (blockHeight == null || tx == null) {
      return '';
    }

    if (tx.blockHeight != 0 && blockHeight != 0) {
      final confirmationCount = blockHeight - tx.blockHeight + 1;
      if (confirmationCount > 0) {
        return '$confirmationCount ';
      }
    }
    return '';
  }

  void _showDialogListener() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.alert.tx_detail.fetch_failed,
          description: t.alert.tx_detail.fetch_failed_description,
          onTapRight: () {
            Navigator.pop(context); // 팝업 닫기
            Navigator.pop(context); // 지갑 상세 이동
          },
          rightButtonText: t.OK,
        );
      },
    );
  }
}

class FeeHistory {
  final double feeRate;
  final bool isSelected;

  FeeHistory({required this.feeRate, this.isSelected = false});
}
