import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/screens/bottomsheet/memo_bottom_sheet_container.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/button/small_action_button.dart';
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
  //late AddressBook _addressBook;
  int? _currentBlockHeight;

  @override
  void initState() {
    super.initState();
    _model = Provider.of<AppStateModel>(context, listen: false);
    //_addressBook = _model.getWalletById(widget.id).walletBase.addressBook;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _model.getCurrentBlockHeight().then((value) {
        setState(() {
          _currentBlockHeight = value;
        });
      });
      _model.loadTransaction(widget.id, widget.txHash);
    });
  }

  Widget _amountText(Transfer tx) {
    String prefix;
    Color color;

    switch (TransactionUtil.getStatus(tx)) {
      case TransactionStatus.receiving:
      case TransactionStatus.received:
        prefix = '+';
        color = MyColors.white;
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
      style: Styles.body1Number.merge(TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      )),
    );
  }

  Widget _confirmedCountText(Transfer tx) {
    if (_currentBlockHeight == null) {
      return const Text('');
    }

    if (tx.blockHeight != null &&
        tx.blockHeight != 0 &&
        _currentBlockHeight != 0) {
      final confirmationCount = _currentBlockHeight! - tx.blockHeight! + 1;
      if (confirmationCount > 0) {
        return Text(
          '($confirmationCount 승인)',
          style: Styles.body1
              .merge(const TextStyle(color: MyColors.transparentWhite_70)),
        );
      }
    }
    return const Text('');
  }

  /*Widget _addressText(List<String> addresses) {
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
  }*/

  @override
  Widget build(BuildContext context) {
    return Selector<AppStateModel, Transfer>(
      selector: (_, model) => model.transaction!,
      builder: (context, tx, child) {
        return Scaffold(
            backgroundColor: MyColors.black,
            appBar: CustomAppBar.build(
              title: '거래 자세히 보기',
              context: context,
              hasRightIcon: false,
              showTestnetLabel: false,
            ),
            body: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (tx.timestamp != null)
                        HighlightedInfoArea(
                            textList: DateTimeUtil.formatTimeStamp(
                                tx.timestamp!.toLocal())),
                      const SizedBox(
                        height: 20,
                      ),
                      TransactionInfo(
                          label: '수량',
                          value: Row(children: [
                            _amountText(tx),
                            const Text(' BTC', style: Styles.unit),
                            const SizedBox(width: 4),
                            _confirmedCountText(tx)
                          ])),
                      TransactionDetailScreen._divider,
                      TransactionInfo(
                          label: '수수료',
                          value: Text(
                            tx.fee != null
                                ? '${satoshiToBitcoinString(tx.fee!)} BTC'
                                : "알 수 없음",
                            style: Styles.body1Number,
                          )),
                      TransactionDetailScreen._divider,
                      TransactionInfo(
                          label: '트랜잭션 ID',
                          value: Text(
                            tx.transactionHash,
                            style: Styles.body1Number,
                          )),
                      TransactionDetailScreen._divider,
                      GestureDetector(
                        onTap: () {
                          // TODO: 메모 등록 테스트
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => MemoBottomSheetContainer(
                              updateMemo: tx.memo ?? '',
                              onComplete: (memo) {
                                _model.updateTransactionMemoWithTxHash(
                                    widget.id, widget.txHash, memo);
                              },
                            ),
                          );
                        },
                        child: TransactionInfo(
                          label: '메모',
                          value: Text(
                            tx.memo?.isNotEmpty == true ? tx.memo! : '-',
                            style: Styles.body1Number,
                          ),
                        ),
                      ),
                      TransactionDetailScreen._divider,
                      // TransactionInfo(
                      //     label: '보낸 주소',
                      //     value: _addressText(widget.tx.inputAddressList)),
                      // TransactionDetailScreen._divider,
                      // TransactionInfo(
                      //     label: '받은 주소',
                      //     value: _addressText(widget.tx.outputAddressList)),
                      const SizedBox(
                        height: 40,
                      ),
                      SmallActionButton(
                        text: '멤풀에서 보기',
                        backgroundColor: MyColors.transparentWhite_20,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () {
                          launchUrl(Uri.parse(
                              "${PowWalletApp.kMempoolHost}/tx/${tx.transactionHash}"));
                        },
                        textStyle: const TextStyle(
                            color: MyColors.white, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(
                        height: 40,
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
