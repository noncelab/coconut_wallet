import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_detail_view_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/card/underline_button_item_card.dart';
import 'package:coconut_wallet/widgets/custom_tag_chip.dart';
import 'package:coconut_wallet/widgets/highlighted_Info_area.dart';
import 'package:coconut_wallet/widgets/input_output_detail_row.dart';
import 'package:coconut_wallet/screens/common/tag_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

const _divider = Divider(color: CoconutColors.gray800);

class UtxoDetailScreen extends StatefulWidget {
  final int id;
  final UtxoState utxo;

  const UtxoDetailScreen({
    super.key,
    required this.id,
    required this.utxo,
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
          // FIXME: tx should be not null
          final tx = viewModel.transaction ?? _getTransaction(viewModel);
          final allTags = viewModel.utxoTagList;
          final tagsApplied = viewModel.selectedUtxoTagList;

          return GestureDetector(
            onTap: _removeUtxoTooltip,
            child: Stack(
              children: [
                _buildScaffold(context, viewModel, tx, allTags, tagsApplied),
                if (_isUtxoTooltipVisible) _buildTooltip(context),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTagBottomSheet(
    BuildContext context,
    List<UtxoTag> tags,
    List<UtxoTag> selectedTags,
    UtxoDetailViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CoconutColors.black,
      isScrollControlled: true,
      builder: (context) => TagBottomSheet(
        type: TagBottomSheetType.attach,
        utxoTags: tags,
        selectedUtxoTagNames: selectedTags.map((e) => e.name).toList(),
        onSelected: (selectedNames, addTags) {
          viewModel.updateUtxoTags(widget.utxo.utxoId, selectedNames, addTags);
        },
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    UtxoDetailViewModel viewModel,
    TransactionRecord tx,
    List<UtxoTag> tags,
    List<UtxoTag> selectedTags,
  ) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          child: Column(
            children: [
              _buildDateTime(viewModel.dateString),
              CoconutLayout.spacing_600h,
              _buildAmount(),
              _buildPrice(),
              CoconutLayout.spacing_600h,
              _buildTxInputOutputSection(viewModel, tx),
              CoconutLayout.spacing_400h,
              _buildAddress(),
              _buildTxMemo(
                tx.memo,
              ),
              _buildTagSection(
                context,
                tags,
                selectedTags,
                viewModel,
              ),
              _buildTxId(),
              _buildBlockHeight(),
              CoconutLayout.spacing_1000h,
              _buildBalanceWidthCheck(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
      title: t.utxo,
      context: context,
      onBackPressed: () {
        Navigator.pop(context);
      },
      actionButtonList: [
        IconButton(
          key: _utxoTooltipIconKey,
          icon: SvgPicture.asset('assets/svg/question-mark.svg'),
          onPressed: _toggleUtxoTooltip,
        )
      ],
    );
  }

  Widget _buildTxInputOutputSection(
      UtxoDetailViewModel viewModel, TransactionRecord tx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: CoconutColors.gray800,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInputOutputList(tx.inputAddressList, InputOutputRowType.input),
          _buildFeeSection(),
          _buildInputOutputList(
              tx.outputAddressList, InputOutputRowType.output),
        ],
      ),
    );
  }

  Widget _buildInputOutputList(
      List<TransactionAddress> addressList, InputOutputRowType type) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: addressList.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) => Column(
        children: [
          InputOutputDetailRow(
            address: addressList[index].address,
            balance: addressList[index].amount,
            balanceMaxWidth:
                _balanceWidthSize.width > 0 ? _balanceWidthSize.width : 100,
            rowType: type,
            isCurrentAddress: addressList[index].address == widget.utxo.to,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFeeSection() {
    return Column(
      children: [
        const SizedBox(height: 8),
        InputOutputDetailRow(
          address: t.fee,
          balance: 142,
          balanceMaxWidth:
              _balanceWidthSize.width > 0 ? _balanceWidthSize.width : 100,
          rowType: InputOutputRowType.fee,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTooltip(BuildContext context) {
    return Positioned(
      top: _utxoTooltipIconPosition.dy + _utxoTooltipIconSize.height - 10,
      right: 18,
      child: GestureDetector(
        onTap: _removeUtxoTooltip,
        child: ClipPath(
          clipper: RightTriangleBubbleClipper(),
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.68,
            padding: const EdgeInsets.only(
              top: 28,
              left: 16,
              right: 16,
              bottom: 12,
            ),
            color: CoconutColors.white,
            child: Text(t.tooltip.utxo,
                style: CoconutTypography.body3_12
                    .copyWith(color: CoconutColors.gray900, height: 1.3)),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final utxoTooltipIconRenderBox =
          _utxoTooltipIconKey.currentContext?.findRenderObject() as RenderBox?;

      if (utxoTooltipIconRenderBox != null) {
        setState(() {
          _utxoTooltipIconPosition =
              utxoTooltipIconRenderBox.localToGlobal(Offset.zero);
          _utxoTooltipIconSize = utxoTooltipIconRenderBox.size;
        });
      }

      final balanceWidthRenderBox =
          _balanceWidthKey.currentContext?.findRenderObject() as RenderBox?;

      if (balanceWidthRenderBox != null) {
        setState(() {
          _balanceWidthSize = balanceWidthRenderBox.size;
        });
      }
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

  // FIXME: viewModel의 transaction이 null로 나와서 임의 데이터로 생성했습니다.
  TransactionRecord _getTransaction(UtxoDetailViewModel viewModel) {
    return viewModel.transaction ??
        TransactionRecord(
          'dummy_tx_hash',
          DateTime.now(),
          1,
          TransactionTypeEnum.received.name,
          null,
          2,
          1,
          [TransactionAddress('dummy_address', 1)],
          [TransactionAddress('dummy_address', 1)],
          DateTime.now(),
        );
  }

  Widget _buildBalanceWidthCheck() {
    return Text(
      key: _balanceWidthKey,
      '0.0000 0000',
      style: CoconutTypography.body2_14_Number
          .copyWith(color: Colors.transparent, height: 16 / 14),
    );
  }

  Widget _buildDateTime(List<String> timeString) {
    return HighlightedInfoArea(
        textList: timeString, textStyle: CoconutTypography.body2_14_Number);
  }

  Widget _buildAmount() {
    return Center(
        child: RichText(
            text: TextSpan(
                text: satoshiToBitcoinString(widget.utxo.amount),
                style: CoconutTypography.heading3_21_NumberBold,
                children: <TextSpan>[
          TextSpan(text: " ${t.btc}", style: CoconutTypography.body2_14_Number)
        ])));
  }

  Widget _buildPrice() {
    return Center(
        child: Selector<UpbitConnectModel, int?>(
      selector: (context, model) => model.bitcoinPriceKrw,
      builder: (context, bitcoinPriceKrw, child) {
        return Text(
          bitcoinPriceKrw != null
              ? '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(widget.utxo.amount, bitcoinPriceKrw).toDouble())} ${CurrencyCode.KRW.code}'
              : '',
          style: CoconutTypography.body2_14_Number
              .copyWith(color: CoconutColors.gray500),
        );
      },
    ));
  }

  Widget _buildAddress() {
    List<String> path = widget.utxo.derivationPath.split('/');
    int changeIndex = path.length - 2;

    return Column(
      children: [
        UnderlineButtonItemCard(
            label: t.utxo_detail_screen.address,
            underlineButtonLabel: t.view_mempool,
            onTapUnderlineButton: () => launchUrl(Uri.parse(
                "${CoconutWalletApp.kMempoolHost}/address/${widget.utxo.to}")),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.utxo.to,
                  style: Styles.body2Number
                      .merge(const TextStyle(height: 22 / 14)),
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        for (int i = 0; i < path.length; i++) ...[
                          TextSpan(
                            text: path[i],
                            style: i == changeIndex && path[changeIndex] == '1'
                                ? CoconutTypography.body3_12_NumberBold
                                    .setColor(CoconutColors.gray200)
                                : CoconutTypography.body3_12_Number
                                    .setColor(CoconutColors.gray500),
                          ),
                          if (i < path.length - 1)
                            TextSpan(
                                text: "/",
                                style: CoconutTypography.body3_12_Number
                                    .setColor(CoconutColors.gray500)),
                        ]
                      ],
                    ),
                  ),
                  CoconutLayout.spacing_100w,
                  if (path[changeIndex] == '1') ...{
                    Text('(${t.change})',
                        style: CoconutTypography.body3_12
                            .setColor(CoconutColors.gray500))
                  }
                ])
              ],
            )),
        _divider,
      ],
    );
  }

  Widget _buildTxMemo(String? memo) {
    return Column(
      children: [
        UnderlineButtonItemCard(
          label: t.tx_memo,
          child: Text(
            memo?.isNotEmpty == true ? memo! : '-',
            style: CoconutTypography.body2_14_Number,
          ),
        ),
        _divider
      ],
    );
  }

  Widget _buildTxId() {
    return Column(
      children: [
        UnderlineButtonItemCard(
          label: t.tx_id,
          underlineButtonLabel: t.view_tx_details,
          onTapUnderlineButton: () {
            Navigator.pushNamed(context, '/transaction-detail', arguments: {
              'id': widget.id,
              'txHash': widget.utxo.transactionHash
            });
          },
          child: Text(
            widget.utxo.transactionHash,
            style: CoconutTypography.body2_14_Number,
          ),
        ),
        _divider,
      ],
    );
  }

  Widget _buildBlockHeight() {
    return UnderlineButtonItemCard(
        label: t.block_num,
        underlineButtonLabel: t.view_mempool,
        onTapUnderlineButton: () => launchUrl(Uri.parse(
            "${CoconutWalletApp.kMempoolHost}/block/${widget.utxo.blockHeight}")),
        child: Text(
          widget.utxo.blockHeight.toString(),
          style: CoconutTypography.body2_14_Number,
        ));
  }

  Widget _buildTagSection(BuildContext context, List<UtxoTag> tags,
      List<UtxoTag> selectedTags, UtxoDetailViewModel viewModel) {
    return Column(
      children: [
        UnderlineButtonItemCard(
          label: t.tag,
          underlineButtonLabel: t.edit,
          onTapUnderlineButton: () =>
              _showTagBottomSheet(context, tags, selectedTags, viewModel),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectedTags.isEmpty) ...{
                Text('-', style: CoconutTypography.body2_14_Number)
              } else ...{
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: List.generate(
                    selectedTags.length,
                    (index) => IntrinsicWidth(
                      child: CustomTagChip(
                        tag: selectedTags[index].name,
                        colorIndex: selectedTags[index].colorIndex,
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
      ],
    );
  }
}
