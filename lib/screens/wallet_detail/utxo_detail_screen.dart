import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo.dart' as model;
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_detail_view_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/card/underline_button_item_card.dart';
import 'package:coconut_wallet/widgets/custom_tag_chip.dart';
import 'package:coconut_wallet/widgets/highlighted_Info_area.dart';
import 'package:coconut_wallet/widgets/input_output_detail_row.dart';
import 'package:coconut_wallet/screens/common/tag_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

const _divider = Divider(color: MyColors.transparentWhite_15);

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
  final GlobalKey _utxoTooltipIconKey = GlobalKey();
  late Size _utxoTooltipIconSize;
  late Offset _utxoTooltipIconPosition;

  final GlobalKey _balanceWidthKey = GlobalKey();
  Size _balanceWidthSize = const Size(0, 0);

  bool _isUtxoTooltipVisible = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UtxoDetailViewModel>(
      create: (_) => UtxoDetailViewModel(
        widget.id,
        widget.utxo,
        Provider.of<UtxoTagProvider>(_, listen: false),
        Provider.of<TransactionProvider>(_, listen: false),
      ),
      child: Consumer<UtxoDetailViewModel>(
        builder: (_, viewModel, child) {
          if (viewModel.transaction == null) return Container();
          final tx = viewModel.transaction;
          final tags = viewModel.tagList;
          final selectedTags = viewModel.selectedTagList;
          return GestureDetector(
            onTap: _removeUtxoTooltip,
            child: Stack(
              children: [
                Scaffold(
                  backgroundColor: MyColors.black,
                  appBar: CustomAppBar.build(
                    title: t.utxo,
                    context: context,
                    showTestnetLabel: false,
                    hasRightIcon: true,
                    onBackPressed: () {
                      Navigator.pop(context);
                    },
                    rightIconButton: IconButton(
                      key: _utxoTooltipIconKey,
                      icon: SvgPicture.asset('assets/svg/question-mark.svg'),
                      onPressed: _toggleUtxoTooltip,
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
                              textList:
                                  viewModel.dateString ?? ['--.--.--', '--:--'],
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
                                        children: <TextSpan>[
                                  TextSpan(
                                      text: " ${t.btc}",
                                      style: Styles.body2Number)
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
                                    t.utxo_detail_screen.pending,
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
                                      itemCount: viewModel.utxoInputMaxCount,
                                      padding: EdgeInsets.zero,
                                      itemBuilder: (context, index) {
                                        return Column(
                                          children: [
                                            InputOutputDetailRow(
                                              address: tx!
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
                                      visible: tx!.inputAddressList.length >
                                          viewModel.utxoInputMaxCount,
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
                                      address: t.fee,
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
                                      itemCount: viewModel.utxoOutputMaxCount,
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
                                          viewModel.utxoOutputMaxCount,
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
                            UnderlineButtonItemCard(
                                label: t.utxo_detail_screen.address,
                                underlineButtonLabel: t.view_mempool,
                                onTapUnderlineButton: () => launchUrl(Uri.parse(
                                    "${CoconutWalletApp.kMempoolHost}/address/${widget.utxo.to}")),
                                isChangeTagVisible: widget.isChange,
                                child: Column(
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
                            UnderlineButtonItemCard(
                              label: t.tx_memo,
                              child: Text(
                                tx.memo?.isNotEmpty == true ? tx.memo! : '-',
                                style: Styles.body2Number
                                    .merge(const TextStyle(height: 22 / 14)),
                              ),
                            ),
                            _divider,
                            UnderlineButtonItemCard(
                              label: t.tag,
                              underlineButtonLabel: t.edit,
                              onTapUnderlineButton: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: MyColors.black,
                                  isScrollControlled: true,
                                  builder: (context) => TagBottomSheet(
                                    type: TagBottomSheetType.select,
                                    utxoTags: tags,
                                    selectedUtxoTagNames: selectedTags
                                        .map((e) => e.name)
                                        .toList(),
                                    onSelected: (selectedNames, addTags) {
                                      viewModel.tagProvider?.updateUtxoTagList(
                                        walletId: widget.id,
                                        utxoId: widget.utxo.utxoId,
                                        selectedNames: selectedNames,
                                        addTags: addTags,
                                      );
                                    },
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (selectedTags.isEmpty) ...{
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
                                        selectedTags.length,
                                        (index) => IntrinsicWidth(
                                          child: CustomTagChip(
                                            tag: selectedTags[index].name,
                                            colorIndex:
                                                selectedTags[index].colorIndex,
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
                            UnderlineButtonItemCard(
                              label: t.tx_id,
                              underlineButtonLabel: t.view_tx_details,
                              onTapUnderlineButton: () {
                                Navigator.pushNamed(
                                    context, '/transaction-detail', arguments: {
                                  'id': widget.id,
                                  'txHash': widget.utxo.txHash
                                });
                              },
                              child: Text(
                                widget.utxo.txHash,
                                style: Styles.body2Number
                                    .merge(const TextStyle(height: 22 / 14)),
                              ),
                            ),
                            _divider,
                            UnderlineButtonItemCard(
                                label: t.block_num,
                                underlineButtonLabel: t.view_mempool,
                                onTapUnderlineButton: () => launchUrl(Uri.parse(
                                    "${CoconutWalletApp.kMempoolHost}/block/${widget.utxo.blockHeight}")),
                                child: Text(
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
                ),
                // TODO: Tooltip widget 분리
                _isUtxoTooltipVisible
                    ? Positioned(
                        top: _utxoTooltipIconPosition.dy +
                            _utxoTooltipIconSize.height -
                            10,
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
                                t.tooltip.utxo,
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
                    : Container(),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      RenderBox utxoTooltipIconRenderBox =
          _utxoTooltipIconKey.currentContext?.findRenderObject() as RenderBox;
      _utxoTooltipIconPosition =
          utxoTooltipIconRenderBox.localToGlobal(Offset.zero);
      _utxoTooltipIconSize = utxoTooltipIconRenderBox.size;

      final RenderBox balanceWidthRenderBox =
          _balanceWidthKey.currentContext?.findRenderObject() as RenderBox;

      setState(() {
        _balanceWidthSize = balanceWidthRenderBox.size;
      });
    });
  }

  void _removeUtxoTooltip() {
    _isUtxoTooltipVisible = false;
    setState(() {});
  }

  void _toggleUtxoTooltip() {
    _isUtxoTooltipVisible = !_isUtxoTooltipVisible;
    setState(() {});
  }
}
