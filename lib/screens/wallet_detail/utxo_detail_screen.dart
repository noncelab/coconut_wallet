import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/widgets/overlays/tag_bottom_sheet.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_chip.dart';
import 'package:coconut_wallet/widgets/custom_tag_chip.dart';
import 'package:coconut_wallet/widgets/highlighted_Info_area.dart';
import 'package:coconut_wallet/widgets/input_output_detail_row.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/model/utxo/utxo.dart' as model;
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class UtxoDetailScreen extends StatefulWidget {
  final int id;
  final model.UTXO utxo;
  final bool isChange;

  const UtxoDetailScreen({
    super.key,
    required this.id,
    required this.utxo,
    this.isChange = false,
  });

  @override
  State<UtxoDetailScreen> createState() => _UtxoDetailScreenState();
}

class _UtxoDetailScreenState extends State<UtxoDetailScreen> {
  late AppStateModel _model;
  late List<String> _dateString;
  late bool _isUtxoTooltipVisible;

  final GlobalKey _utxoTooltipIconKey = GlobalKey();
  late Size _utxoTooltipIconSize;
  late Offset _utxoTooltipIconPosition;

  final String _utxoTip =
      'UTXO란 Unspent Tx Output을 줄인 말로 아직 쓰이지 않은 잔액이란 뜻이에요. 비트코인에는 잔액 개념이 없어요. 지갑에 표시되는 잔액은 UTXO의 총합이라는 것을 알아두세요.';

  final GlobalKey _balanceWidthKey = GlobalKey();
  Size _balanceWidthSize = const Size(0, 0);

  int initialInputMaxCount = 3;
  int initialOutputMaxCount = 2;

  @override
  void initState() {
    super.initState();
    _model = Provider.of<AppStateModel>(context, listen: false);
    _dateString = DateTimeUtil.formatDatetime(widget.utxo.timestamp).split('|');
    _isUtxoTooltipVisible = false;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _model.initUtxoDetailScreenTagData(
          widget.id, widget.utxo.txHash, widget.utxo.index);

      await Future.delayed(const Duration(milliseconds: 100));

      RenderBox utxoTooltipIconRenderBox =
          _utxoTooltipIconKey.currentContext?.findRenderObject() as RenderBox;
      _utxoTooltipIconPosition =
          utxoTooltipIconRenderBox.localToGlobal(Offset.zero);
      _utxoTooltipIconSize = utxoTooltipIconRenderBox.size;

      RenderBox balanceWidthRenderBox =
          _balanceWidthKey.currentContext?.findRenderObject() as RenderBox;
      setState(() {
        _balanceWidthSize = balanceWidthRenderBox.size;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _removeUtxoTooltip();
      },
      child: GestureDetector(
        onTap: () => _removeUtxoTooltip(),
        child: Stack(
          children: [
            Selector<AppStateModel, Map<String, dynamic>>(
              selector: (_, model) => {
                'transaction': model.transaction,
                'utxoTagList': model.utxoTagList,
                'selectedUtxoTags': model.selectedTagList,
              },
              builder: (context, dataMap, child) {
                final tx = dataMap['transaction'] as Transfer?;
                final utxoTagList = dataMap['utxoTagList'] as List<UtxoTag>;
                final selectedUtxoTags =
                    dataMap['selectedUtxoTags'] as List<UtxoTag>;

                if (tx == null) return Container();
                initialInputMaxCount = tx.inputAddressList.length <= 3
                    ? tx.inputAddressList.length
                    : 3;
                initialOutputMaxCount = tx.outputAddressList.length <= 2
                    ? tx.outputAddressList.length
                    : 2;
                if (tx.inputAddressList.length <= initialInputMaxCount) {
                  initialInputMaxCount = tx.inputAddressList.length;
                }
                if (tx.outputAddressList.length <= initialOutputMaxCount) {
                  initialOutputMaxCount = tx.outputAddressList.length;
                }

                if (tx.outputAddressList.isNotEmpty) {
                  tx.outputAddressList.sort((a, b) {
                    if (a.address == widget.utxo.to) return -1;
                    if (b.address == widget.utxo.to) return 1;
                    return 0;
                  });
                }

                return Scaffold(
                  backgroundColor: MyColors.black,
                  appBar: CustomAppBar.build(
                    title: 'UTXO',
                    context: context,
                    showTestnetLabel: false,
                    hasRightIcon: true,
                    onBackPressed: () {
                      Navigator.pop(context);
                    },
                    rightIconButton: IconButton(
                      key: _utxoTooltipIconKey,
                      icon: SvgPicture.asset('assets/svg/question-mark.svg'),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _isUtxoTooltipVisible = !_isUtxoTooltipVisible;
                          });
                        }
                      },
                    ),
                  ),
                  body: SafeArea(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        child: Column(
                          children: [
                            HighlightedInfoArea(
                              textList: _dateString,
                              textStyle: Styles.body2Number.merge(
                                const TextStyle(
                                  color: MyColors.white,
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 24,
                            ),
                            Center(
                                child: RichText(
                                    text: TextSpan(
                                        text: satoshiToBitcoinString(
                                            widget.utxo.amount),
                                        style: Styles.h1Number.merge(
                                            const TextStyle(
                                                fontSize: 24, height: 1)),
                                        children: const <TextSpan>[
                                  TextSpan(
                                      text: ' BTC', style: Styles.body2Number)
                                ]))),
                            const SizedBox(
                              height: 8,
                            ),
                            Center(
                                child: Selector<UpbitConnectModel, int?>(
                              selector: (context, model) =>
                                  model.bitcoinPriceKrw,
                              builder: (context, bitcoinPriceKrw, child) {
                                return Text(
                                  bitcoinPriceKrw != null
                                      ? '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(widget.utxo.amount, bitcoinPriceKrw).toDouble())} ${CurrencyCode.KRW.code}'
                                      : '',
                                  style: Styles.balance2,
                                );
                              },
                            )),
                            const SizedBox(height: 10),
                            Visibility(
                              maintainAnimation: true,
                              maintainState: true,
                              maintainSize: true,
                              visible: int.parse(widget.utxo.blockHeight) == 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '승인 대기중',
                                    style: Styles.body3.merge(
                                      const TextStyle(
                                        color: MyColors.secondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    height: 24,
                                    child: Lottie.asset(
                                      'assets/lottie/loading-three-dots.json',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: MyColors.transparentWhite_12),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: initialInputMaxCount,
                                      padding: EdgeInsets.zero,
                                      itemBuilder: (context, index) {
                                        return Column(
                                          children: [
                                            InputOutputDetailRow(
                                              address: tx
                                                  .inputAddressList[index]
                                                  .address,
                                              balance: tx
                                                  .inputAddressList[index]
                                                  .amount,
                                              balanceMaxWidth:
                                                  _balanceWidthSize.width > 0
                                                      ? _balanceWidthSize.width
                                                      : 100,
                                              rowType: InputOutputRowType.input,
                                              isCurrentAddress: tx
                                                      .inputAddressList[index]
                                                      .address ==
                                                  widget.utxo.to,
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        );
                                      },
                                    ),
                                    Visibility(
                                      visible: tx.inputAddressList.length >
                                          initialInputMaxCount,
                                      child: Text(
                                        '...',
                                        style: Styles.caption.merge(
                                            const TextStyle(
                                                color: MyColors
                                                    .transparentWhite_40,
                                                height: 8 / 12)),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InputOutputDetailRow(
                                      address: '수수료',
                                      balance: 142,
                                      balanceMaxWidth:
                                          _balanceWidthSize.width > 0
                                              ? _balanceWidthSize.width
                                              : 100,
                                      rowType: InputOutputRowType.fee,
                                    ),
                                    const SizedBox(height: 8),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: initialOutputMaxCount,
                                      padding: EdgeInsets.zero,
                                      itemBuilder: (context, index) {
                                        return Column(
                                          children: [
                                            InputOutputDetailRow(
                                              address: tx
                                                  .outputAddressList[index]
                                                  .address,
                                              balance: tx
                                                  .outputAddressList[index]
                                                  .amount,
                                              balanceMaxWidth:
                                                  _balanceWidthSize.width > 0
                                                      ? _balanceWidthSize.width
                                                      : 100,
                                              rowType:
                                                  InputOutputRowType.output,
                                              isCurrentAddress: tx
                                                      .outputAddressList[index]
                                                      .address ==
                                                  widget.utxo.to,
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        );
                                      },
                                    ),
                                    Visibility(
                                      visible: tx.outputAddressList.length >
                                          initialOutputMaxCount,
                                      child: Text(
                                        '...',
                                        style: Styles.caption.merge(
                                            const TextStyle(
                                                color: MyColors
                                                    .transparentWhite_40,
                                                height: 8 / 12)),
                                      ),
                                    ),
                                  ]),
                            ),
                            const SizedBox(height: 25),
                            InfoRow(
                                label: '보유 주소',
                                subLabel: '멤풀 보기',
                                onSubLabelClicked: () => launchUrl(Uri.parse(
                                    "${CoconutWalletApp.kMempoolHost}/address/${widget.utxo.to}")),
                                isChangeTagVisible: widget.isChange,
                                value: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.utxo.to,
                                      style: Styles.body2Number.merge(
                                          const TextStyle(height: 22 / 14)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.utxo.derivationPath,
                                      style: Styles.caption.merge(
                                          const TextStyle(
                                              color: MyColors.white,
                                              height: 18 / 12,
                                              fontFamily: 'Pretendard')),
                                    )
                                  ],
                                )),
                            _divider,
                            InfoRow(
                              label: '거래 메모',
                              value: Text(
                                tx.memo?.isNotEmpty == true ? tx.memo! : '-',
                                style: Styles.body2Number
                                    .merge(const TextStyle(height: 22 / 14)),
                              ),
                            ),
                            _divider,
                            InfoRow(
                              label: '태그',
                              subLabel: '편집',
                              onSubLabelClicked: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: MyColors.black,
                                  isScrollControlled: true,
                                  builder: (context) => TagBottomSheet(
                                    type: TagBottomSheetType.select,
                                    utxoTags: utxoTagList,
                                    selectedUtxoTagNames: selectedUtxoTags
                                        .map((e) => e.name)
                                        .toList(),
                                    onSelected: (selectedNames, addTags) {
                                      _model.updateUtxoTagList(
                                        selectedNames: selectedNames,
                                        addTags: addTags,
                                        walletId: widget.id,
                                        txHashIndex: widget.utxo.utxoId,
                                      );
                                    },
                                  ),
                                );
                              },
                              value: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (selectedUtxoTags.isEmpty) ...{
                                    Text(
                                      '-',
                                      style: Styles.body2Number.merge(
                                        const TextStyle(height: 22 / 14),
                                      ),
                                    ),
                                  } else ...{
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: List.generate(
                                        selectedUtxoTags.length,
                                        (index) => IntrinsicWidth(
                                          child: CustomTagChip(
                                            tag: selectedUtxoTags[index].name,
                                            colorIndex: selectedUtxoTags[index]
                                                .colorIndex,
                                            type: CustomTagChipType.fix,
                                          ),
                                        ),
                                      ),
                                    ),
                                  },
                                ],
                              ),
                            ),
                            _divider,
                            InfoRow(
                              label: '트랜잭션 ID',
                              subLabel: '거래 자세히 보기',
                              onSubLabelClicked: () {
                                Navigator.pushNamed(
                                    context, '/transaction-detail', arguments: {
                                  'id': widget.id,
                                  'txHash': widget.utxo.txHash
                                });
                              },
                              value: Text(
                                widget.utxo.txHash,
                                style: Styles.body2Number
                                    .merge(const TextStyle(height: 22 / 14)),
                              ),
                            ),
                            _divider,
                            InfoRow(
                                label: '블록 번호',
                                subLabel: '멤풀 보기',
                                onSubLabelClicked: () => launchUrl(Uri.parse(
                                    "${CoconutWalletApp.kMempoolHost}/block/${widget.utxo.blockHeight}")),
                                value: Text(
                                  widget.utxo.blockHeight,
                                  style: Styles.body2Number
                                      .merge(const TextStyle(height: 22 / 14)),
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
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            _utxoTooltipWidget(context),
          ],
        ),
      ),
    );
  }

  Widget _utxoTooltipWidget(BuildContext context) {
    return _isUtxoTooltipVisible
        ? Positioned(
            top: _utxoTooltipIconPosition.dy + _utxoTooltipIconSize.height - 10,
            right: 5,
            child: GestureDetector(
              onTap: _removeUtxoTooltip,
              child: ClipPath(
                clipper: RightTriangleBubbleClipper(),
                child: Container(
                  width: MediaQuery.sizeOf(context).width * 0.68,
                  padding: const EdgeInsets.only(
                    top: 25,
                    left: 18,
                    right: 18,
                    bottom: 10,
                  ),
                  color: MyColors.white,
                  child: Text(
                    _utxoTip,
                    style: Styles.caption.merge(TextStyle(
                      height: 1.3,
                      fontFamily: CustomFonts.text.getFontFamily,
                      color: MyColors.darkgrey,
                    )),
                  ),
                ),
              ),
            ),
          )
        : Container();
  }

  void _removeUtxoTooltip() {
    // if (_overlayEntry != null) {
    //   _faucetTipVisible = false;
    //   _overlayEntry!.remove();
    //   _overlayEntry = null;
    // }
    setState(() {
      _isUtxoTooltipVisible = false;
    });
  }
}

const _divider = Divider(color: MyColors.transparentWhite_15);

class InfoRow extends StatelessWidget {
  final String label;
  final bool isChangeTagVisible;
  final Widget value;
  final String? subLabel;
  final VoidCallback? onSubLabelClicked;

  const InfoRow(
      {super.key,
      required this.label,
      this.isChangeTagVisible = false,
      required this.value,
      this.subLabel,
      this.onSubLabelClicked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(
              label,
              style: Styles.body2.merge(
                const TextStyle(
                  color: MyColors.transparentWhite_70,
                  height: 21 / 14,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (isChangeTagVisible) const CustomChip(text: '잔돈'),
            if (subLabel != null)
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: CustomUnderlinedButton(
                    text: subLabel!,
                    onTap: () {
                      if (onSubLabelClicked != null) {
                        onSubLabelClicked!();
                      }
                    },
                    fontSize: 12,
                    lineHeight: 18,
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          value
        ],
      ),
    );
  }
}
