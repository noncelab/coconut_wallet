import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/transaction_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/card/underline_button_item_card.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/highlighted_Info_area.dart';
import 'package:coconut_wallet/widgets/input_output_detail_row.dart';
import 'package:coconut_wallet/widgets/overlays/memo_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TransactionDetailScreen extends StatefulWidget {
  static const _divider = Divider(color: MyColors.transparentWhite_15);
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

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final GlobalKey _balanceWidthKey = GlobalKey();
  Size _balanceWidthSize = Size.zero;
  TransactionDetailViewModel? _viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<WalletProvider, TransactionProvider,
        TransactionDetailViewModel>(
      create: (_) => TransactionDetailViewModel(widget.id, widget.txHash),
      update: (_, wallet, transaction, viewModel) {
        if (_viewModel == null) {
          _viewModel = viewModel;
          _viewModel?.showDialogNotifier.addListener(_showDialogListener);
          _viewModel?.loadCompletedNotifier.addListener(_loadCompletedListener);
        }

        return viewModel!..updateProvider(wallet, transaction);
      },
      child: Consumer<TransactionDetailViewModel>(
        builder: (_, viewModel, child) {
          if (viewModel.transaction == null) return Container();
          final status = TransactionUtil.getStatus(viewModel.transaction!);
          return Scaffold(
              backgroundColor: MyColors.black,
              appBar: CustomAppBar.build(
                title: '거래 자세히 보기',
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
                        if (viewModel.transaction!.timestamp != null)
                          HighlightedInfoArea(
                              textList: DateTimeUtil.formatTimeStamp(
                                  viewModel.transaction!.timestamp!.toLocal())),
                        const SizedBox(
                          height: 24,
                        ),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              _amountText(viewModel.transaction!),
                              const SizedBox(
                                width: 2,
                              ),
                              const Text(' BTC', style: Styles.body2),
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
                                  ? '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(viewModel.transaction!.amount!, bitcoinPriceKrw).toDouble().abs())} ${CurrencyCode.KRW.code}'
                                  : '',
                              style: Styles.balance2,
                            );
                          },
                        )),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: MyColors.transparentWhite_12),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: viewModel.inputCountToShow,
                              padding: EdgeInsets.zero,
                              itemBuilder: (context, index) {
                                return Column(
                                  children: [
                                    InputOutputDetailRow(
                                      address: viewModel.transaction!
                                          .inputAddressList[index].address,
                                      balance: viewModel.transaction!
                                          .inputAddressList[index].amount,
                                      balanceMaxWidth:
                                          _balanceWidthSize.width > 0
                                              ? _balanceWidthSize.width
                                              : 100,
                                      rowType: InputOutputRowType.input,
                                      isCurrentAddress: viewModel.addressBook
                                          ?.contains(viewModel.transaction!
                                              .inputAddressList[index].address),
                                      transactionStatus: status,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                );
                              },
                            ),
                            Visibility(
                              visible: viewModel.canSeeMoreInputs,
                              child: Center(
                                child: CustomUnderlinedButton(
                                  text: '더보기',
                                  onTap: () {
                                    viewModel.txModel?.viewMoreInput();
                                  },
                                  fontSize: 12,
                                  lineHeight: 14,
                                ),
                              ),
                            ),
                            SizedBox(
                                height: viewModel.canSeeMoreInputs ? 8 : 16),
                            InputOutputDetailRow(
                              address: '수수료',
                              balance: viewModel.transaction?.fee ?? 0,
                              balanceMaxWidth: _balanceWidthSize.width > 0
                                  ? _balanceWidthSize.width
                                  : 100,
                              rowType: InputOutputRowType.fee,
                              transactionStatus: status,
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: viewModel.outputCountToShow,
                              padding: EdgeInsets.zero,
                              itemBuilder: (context, index) {
                                return Column(
                                  children: [
                                    InputOutputDetailRow(
                                      address: viewModel.transaction!
                                          .outputAddressList[index].address,
                                      balance: viewModel.transaction!
                                          .outputAddressList[index].amount,
                                      balanceMaxWidth:
                                          _balanceWidthSize.width > 0
                                              ? _balanceWidthSize.width
                                              : 100,
                                      rowType: InputOutputRowType.output,
                                      isCurrentAddress: viewModel.addressBook
                                          ?.contains(viewModel
                                              .transaction!
                                              .outputAddressList[index]
                                              .address),
                                      transactionStatus: status,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                );
                              },
                            ),
                            Visibility(
                              visible: viewModel.canSeeMoreOutputs,
                              child: Center(
                                child: CustomUnderlinedButton(
                                  text: '더보기',
                                  onTap: () {
                                    viewModel.txModel?.viewMoreOutput();
                                  },
                                  fontSize: 12,
                                  lineHeight: 14,
                                ),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        UnderlineButtonItemCard(
                          label: '블록 번호',
                          underlineButtonLabel: '멤풀 보기',
                          onTapUnderlineButton: () {
                            launchUrl(Uri.parse(
                                '${CoconutWalletApp.kMempoolHost}/block/${viewModel.transaction!.blockHeight}'));
                          },
                          child: Text(
                            viewModel.transaction!.blockHeight != 0
                                ? '${viewModel.transaction!.blockHeight.toString()} (${_confirmedCountText(viewModel.transaction, viewModel.currentBlockHeight)} 승인)'
                                : '-',
                            style: Styles.body1Number,
                          ),
                        ),
                        TransactionDetailScreen._divider,
                        UnderlineButtonItemCard(
                            label: '트랜잭션 ID',
                            underlineButtonLabel: '멤풀 보기',
                            onTapUnderlineButton: () {
                              launchUrl(Uri.parse(
                                  "${CoconutWalletApp.kMempoolHost}/tx/${viewModel.transaction!.transactionHash}"));
                            },
                            child: Text(
                              viewModel.transaction!.transactionHash,
                              style: Styles.body1Number,
                            )),
                        TransactionDetailScreen._divider,
                        UnderlineButtonItemCard(
                            label: '거래 메모',
                            underlineButtonLabel: '편집',
                            onTapUnderlineButton: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) => MemoBottomSheet(
                                  originalMemo:
                                      viewModel.transaction!.memo ?? '',
                                  onComplete: (memo) {
                                    if (!viewModel
                                        .updateTransactionMemo(memo)) {
                                      CustomToast.showWarningToast(
                                        context: context,
                                        text: '메모 업데이트에 실패 했습니다.',
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                            child: Text(
                              viewModel.transaction!.memo?.isNotEmpty == true
                                  ? viewModel.transaction!.memo!
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

  @override
  void dispose() {
    _viewModel?.showDialogNotifier.removeListener(_showDialogListener);
    _viewModel?.showDialogNotifier.removeListener(_loadCompletedListener);
    super.dispose();
  }

  Widget _amountText(Transfer tx) {
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

  String _confirmedCountText(Transfer? tx, int? blockHeight) {
    if (blockHeight == null || tx == null) {
      return '';
    }

    if (tx.blockHeight != null && tx.blockHeight != 0 && blockHeight != 0) {
      final confirmationCount = blockHeight - tx.blockHeight! + 1;
      if (confirmationCount > 0) {
        return confirmationCount.toString();
      }
    }
    return '';
  }

  void _showDialogListener() {
    CustomDialogs.showCustomAlertDialog(
      context,
      title: '트랜잭션 가져오기 실패',
      message: '잠시 후 다시 시도해 주세요',
      onConfirm: () {
        Navigator.pop(context); // 팝업 닫기
        Navigator.pop(context); // 지갑 상세 이동
      },
    );
  }

  void _loadCompletedListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final box =
          _balanceWidthKey.currentContext?.findRenderObject() as RenderBox;
      _balanceWidthSize = box.size;
      setState(() {});
    });
  }
}
