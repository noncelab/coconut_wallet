import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/screens/utxo_detail_screen.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/button/small_action_button.dart';
import 'package:coconut_wallet/widgets/highlighted_Info_area.dart';
import 'package:coconut_wallet/widgets/label_value.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_state_model.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Transfer tx;
  final int id;
  late final TransactionStatus? status;

  TransactionDetailScreen({super.key, required this.tx, required this.id}) {
    status = TransactionUtil.getStatus(tx);
  }

  static const _divider = Divider(color: MyColors.transparentWhite_15);

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late AddressBook _addressBook;
  int? _currentBlockHeight;
  late bool canSeeMoreInputs;
  late bool canSeeMoreOutputs;
  int itemsToShowInput = 5;
  int itemsToShowOutput = 5;

  @override
  void initState() {
    super.initState();
    final model = Provider.of<AppStateModel>(context, listen: false);
    _addressBook = model.getWalletById(widget.id).walletBase.addressBook;
    _initSeeMoreButtons();
    model.getCurrentBlockHeight().then((value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentBlockHeight = value;
        });
      });
    });
  }

  void _initSeeMoreButtons() {
    int initialInputMaxCount = (widget.status == TransactionStatus.sending ||
            widget.status == TransactionStatus.sent ||
            widget.status == TransactionStatus.self ||
            widget.status == TransactionStatus.selfsending)
        ? 5
        : 2;
    int initialOutputMaxCount = (widget.status == TransactionStatus.sending ||
            widget.status == TransactionStatus.sent ||
            widget.status == TransactionStatus.self ||
            widget.status == TransactionStatus.selfsending)
        ? 3
        : 4;
    if (widget.tx.inputAddressList.length <= initialInputMaxCount) {
      canSeeMoreInputs = false;
      itemsToShowInput = widget.tx.inputAddressList.length;
    } else {
      canSeeMoreInputs = true;
    }
    if (widget.tx.outputAddressList.length <= initialOutputMaxCount) {
      canSeeMoreOutputs = false;
      itemsToShowOutput = widget.tx.outputAddressList.length;
    } else {
      canSeeMoreOutputs = true;
    }
  }

  Widget _amountText() {
    String prefix;
    Color color;

    switch (widget.status) {
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
      '$prefix${satoshiToBitcoinString(widget.tx.amount!)}',
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

  String _confirmedCountText() {
    if (_currentBlockHeight == null) {
      return '';
    }

    if (widget.tx.blockHeight != null &&
        widget.tx.blockHeight != 0 &&
        _currentBlockHeight != 0) {
      final confirmationCount =
          _currentBlockHeight! - widget.tx.blockHeight! + 1;
      if (confirmationCount > 0) {
        return confirmationCount.toString();
      }
    }
    return '';
  }

  Widget _addressText(List<String> addresses) {
    List<TextSpan> textSpans = List.generate(addresses.length, (index) {
      String address = addresses[index];
      bool isLast = index == addresses.length - 1;
      return TextSpan(
        text: isLast ? address : '$address\n',
        style: TextStyle(
          color: _addressBook.contains(address)
              ? MyColors.white
              : MyColors.borderGrey,
        ),
      );
    });

    return RichText(
      text: TextSpan(
        children: textSpans,
        style: Styles.body1.merge(
            const TextStyle(fontFamily: 'SpaceGrotesk', letterSpacing: 0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  if (widget.tx.timestamp != null)
                    HighlightedInfoArea(
                        textList:
                            DateTimeUtil.formatTimeStamp(widget.tx.timestamp!)),
                  const SizedBox(
                    height: 24,
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _amountText(),
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
                            ? '₩ ${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(widget.tx.amount!, bitcoinPriceKrw).toDouble())}'
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
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: itemsToShowInput,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          return Column(
                            children: [
                              InputOutputDetailRow(
                                address:
                                    widget.tx.inputAddressList[index].address,
                                balance:
                                    widget.tx.inputAddressList[index].amount,
                                rowType: InputOutputRowType.input,
                                isCurrentAddress: _addressBook.contains(
                                    widget.tx.inputAddressList[index].address),
                                transactionStatus: widget.status,
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
                                itemsToShowInput = (itemsToShowInput + 5).clamp(
                                    0,
                                    widget.tx.inputAddressList
                                        .length); // 최대 길이를 초과하지 않도록 제한
                                if (itemsToShowInput ==
                                    widget.tx.inputAddressList.length) {
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
                        balance: widget.tx.fee!,
                        rowType: InputOutputRowType.fee,
                        transactionStatus: widget.status,
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      for (var inputAddress in widget.tx.outputAddressList) ...{
                        InputOutputDetailRow(
                          address: inputAddress.address,
                          balance: inputAddress.amount,
                          rowType: InputOutputRowType.output,
                          isCurrentAddress:
                              _addressBook.contains(inputAddress.address),
                          transactionStatus: widget.status,
                        ),
                        const SizedBox(height: 8),
                      },
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
                                        widget.tx.outputAddressList
                                            .length); // 최대 길이를 초과하지 않도록 제한
                                if (itemsToShowOutput ==
                                    widget.tx.outputAddressList.length) {
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
                          "${PowWalletApp.kMempoolHost}/block/${widget.tx.blockHeight}"));
                    },
                    value: Text(
                      '${widget.tx.blockHeight.toString() ?? ''} (${_confirmedCountText()} 승인)',
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
                            "${PowWalletApp.kMempoolHost}/tx/${widget.tx.transactionHash}"));
                      },
                      value: Text(
                        widget.tx.transactionHash,
                        style: Styles.body1Number,
                      )),
                  TransactionDetailScreen._divider,
                  InfoRow(
                      label: '거래 메모',
                      subLabel: '편집',
                      onSubLabelClicked: () {
                        // TODO: 멤풀 주소
                        launchUrl(Uri.parse(
                            "${PowWalletApp.kMempoolHost}/tx/${widget.tx.transactionHash}"));
                      },
                      value: const Text(
                        '-',
                        style: Styles.body1Number,
                      )),
                  TransactionDetailScreen._divider,
                  // InfoRow(
                  //     label: '보낸 주소',
                  //     value: _addressText(widget.tx.inputAddressList)),
                  // TransactionDetailScreen._divider,
                  // InfoRow(
                  //     label: '받은 주소',
                  //     value: _addressText(widget.tx.outputAddressList)),
                  const SizedBox(
                    height: 40,
                  ),
                ]),
          ),
        ));
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
