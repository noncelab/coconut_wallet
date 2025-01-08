import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/screens/bottomsheet/memo_bottom_sheet_container.dart';
import 'package:coconut_wallet/screens/utxo_detail_screen.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/highlighted_Info_area.dart';
import 'package:coconut_wallet/widgets/label_value.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_state_model.dart';

class TransactionDetailScreen extends StatefulWidget {
  final int id;
  final String txHash;
  // late final TransactionStatus? status;

  TransactionDetailScreen({super.key, required this.id, required this.txHash}) {
    // status = TransactionUtil.getStatus(tx);
  }

  static const _divider = Divider(color: MyColors.transparentWhite_15);

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late AppStateModel _model;
  late AddressBook _addressBook;
  // TransactionStatus? status = TransactionStatus.received;
  int? _currentBlockHeight;
  bool canSeeMoreInputs = false;
  bool canSeeMoreOutputs = false;
  int itemsToShowInput = 5;
  int itemsToShowOutput = 5;

  final GlobalKey _balanceWidthKey = GlobalKey();
  Size _balanceWidthSize = const Size(0, 0);

  @override
  void initState() {
    super.initState();
    _model = Provider.of<AppStateModel>(context, listen: false);
    _addressBook = _model.getWalletById(widget.id).walletBase.addressBook;

    _model.initTransactionDetailScreenTagData(widget.id, widget.txHash);
    _initSeeMoreButtons();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 100));

      _model.getCurrentBlockHeight().then((value) {
        RenderBox balanceWidthRenderBox =
            _balanceWidthKey.currentContext?.findRenderObject() as RenderBox;
        setState(() {
          _currentBlockHeight = value;
          _balanceWidthSize = balanceWidthRenderBox.size;
        });
      });
    });
  }

  void _initSeeMoreButtons() {
    Transfer? tx = _model.transaction;
    if (tx == null) {
      CustomDialogs.showCustomAlertDialog(context,
          title: '트랜잭션 가져오기 실패',
          message: '잠시 후 다시 시도해 주세요',
          onConfirm: () => Navigator.pop(context));
      return;
    }

    final status = TransactionUtil.getStatus(tx);

    int initialInputMaxCount = (status == TransactionStatus.sending ||
            status == TransactionStatus.sent ||
            status == TransactionStatus.self ||
            status == TransactionStatus.selfsending)
        ? 5
        : 3;
    int initialOutputMaxCount = (status == TransactionStatus.sending ||
            status == TransactionStatus.sent ||
            status == TransactionStatus.self ||
            status == TransactionStatus.selfsending)
        ? 2
        : 4;

    if (tx.inputAddressList.length <= initialInputMaxCount) {
      canSeeMoreInputs = false;
      itemsToShowInput = tx.inputAddressList.length;
    } else {
      canSeeMoreInputs = true;
      itemsToShowInput = initialInputMaxCount;
    }
    if (tx.outputAddressList.length <= initialOutputMaxCount) {
      canSeeMoreOutputs = false;
      itemsToShowOutput = tx.outputAddressList.length;
    } else {
      canSeeMoreOutputs = true;
      itemsToShowOutput = initialOutputMaxCount;
    }
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
        prefix = '';
        color = MyColors.white;
        break;
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

  String _confirmedCountText(Transfer tx) {
    if (_currentBlockHeight == null) {
      return '';
    }

    if (tx.blockHeight != null &&
        tx.blockHeight != 0 &&
        _currentBlockHeight != 0) {
      final confirmationCount = _currentBlockHeight! - tx.blockHeight! + 1;
      if (confirmationCount > 0) {
        return confirmationCount.toString();
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppStateModel, Transfer?>(
      selector: (_, model) => model.transaction,
      builder: (context, tx, child) {
        if (tx == null) return Container();

        final status = TransactionUtil.getStatus(tx);

        if (tx.outputAddressList.isNotEmpty == true) {
          tx.outputAddressList.sort((a, b) {
            if (_addressBook.contains(a.address)) return -1;
            if (_addressBook.contains(b.address)) return 1;
            return 0;
          });
        }

        return Scaffold(
            backgroundColor: MyColors.black,
            appBar: CustomAppBar.build(
              title: '거래 자세히 보기',
              context: context,
              hasRightIcon: false,
              showTestnetLabel: false,
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
                      if (tx.timestamp != null)
                        HighlightedInfoArea(
                            textList: DateTimeUtil.formatTimeStamp(
                                tx.timestamp!.toLocal())),
                      const SizedBox(
                        height: 24,
                      ),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _amountText(tx),
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
                                ? '₩ ${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(tx.amount!, bitcoinPriceKrw).toDouble().abs())}'
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
                            itemCount: itemsToShowInput,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              return Column(
                                children: [
                                  InputOutputDetailRow(
                                    address: tx.inputAddressList[index].address,
                                    balance: tx.inputAddressList[index].amount,
                                    balanceMaxWidth: _balanceWidthSize.width > 0
                                        ? _balanceWidthSize.width
                                        : 100,
                                    rowType: InputOutputRowType.input,
                                    isCurrentAddress: _addressBook.contains(
                                        tx.inputAddressList[index].address),
                                    transactionStatus: status,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              );
                            },
                          ),
                          Visibility(
                            visible: canSeeMoreInputs,
                            child: Center(
                              child: CustomUnderlinedButton(
                                text: '더보기',
                                onTap: () {
                                  setState(() {
                                    itemsToShowInput = (itemsToShowInput + 5)
                                        .clamp(
                                            0,
                                            tx.inputAddressList
                                                .length); // 최대 길이를 초과하지 않도록 제한
                                    if (itemsToShowInput ==
                                        tx.inputAddressList.length) {
                                      canSeeMoreInputs = false;
                                    }
                                  });
                                },
                                fontSize: 12,
                                lineHeight: 14,
                              ),
                            ),
                          ),
                          SizedBox(height: canSeeMoreInputs ? 8 : 16),
                          InputOutputDetailRow(
                            address: '수수료',
                            balance: tx.fee!,
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
                            itemCount: itemsToShowOutput,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              return Column(
                                children: [
                                  InputOutputDetailRow(
                                    address:
                                        tx.outputAddressList[index].address,
                                    balance: tx.outputAddressList[index].amount,
                                    balanceMaxWidth: _balanceWidthSize.width > 0
                                        ? _balanceWidthSize.width
                                        : 100,
                                    rowType: InputOutputRowType.output,
                                    isCurrentAddress: _addressBook.contains(
                                        tx.outputAddressList[index].address),
                                    transactionStatus: status,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              );
                            },
                          ),
                          Visibility(
                            visible: canSeeMoreOutputs,
                            child: Center(
                              child: CustomUnderlinedButton(
                                text: '더보기',
                                onTap: () {
                                  setState(() {
                                    itemsToShowOutput = (itemsToShowOutput + 5)
                                        .clamp(
                                            0,
                                            tx.outputAddressList
                                                .length); // 최대 길이를 초과하지 않도록 제한
                                    if (itemsToShowOutput ==
                                        tx.outputAddressList.length) {
                                      canSeeMoreOutputs = false;
                                    }
                                  });
                                },
                                fontSize: 12,
                                lineHeight: 14,
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      InfoRow(
                        label: '블록 번호',
                        subLabel: '멤풀 보기',
                        onSubLabelClicked: () {
                          launchUrl(Uri.parse(
                              "${PowWalletApp.kMempoolHost}/block/${tx.blockHeight}"));
                        },
                        value: Text(
                          '${tx.blockHeight.toString()} (${_confirmedCountText(tx)} 승인)',
                          style: Styles.body1Number,
                        ),
                      ),
                      TransactionDetailScreen._divider,
                      InfoRow(
                          label: '트랜잭션 ID',
                          subLabel: '멤풀 보기',
                          onSubLabelClicked: () {
                            // TODO: 멤풀 주소
                            launchUrl(Uri.parse(
                                "${PowWalletApp.kMempoolHost}/tx/${tx.transactionHash}"));
                          },
                          value: Text(
                            tx.transactionHash,
                            style: Styles.body1Number,
                          )),
                      TransactionDetailScreen._divider,
                      InfoRow(
                          label: '거래 메모',
                          subLabel: '편집',
                          onSubLabelClicked: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) => MemoBottomSheetContainer(
                                updateMemo: tx.memo ?? '',
                                onComplete: (updateMemo) {
                                  _model.updateTransactionMemo(
                                      widget.id, widget.txHash, updateMemo);
                                },
                              ),
                            );
                          },
                          value: Text(
                            tx.memo?.isNotEmpty == true ? tx.memo! : '-',
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
    );
  }
}

class TransactionInfo extends StatelessWidget {
  final String label;
  final Widget value;

  const TransactionInfo({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Label(text: label), value],
      ),
    );
  }
}
