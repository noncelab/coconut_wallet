import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_detail_view_model.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/button/copy_text_container.dart';
import 'package:coconut_wallet/widgets/card/transaction_input_output_card.dart';
import 'package:coconut_wallet/widgets/card/underline_button_item_card.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
import 'package:coconut_wallet/widgets/highlighted_info_area.dart';
import 'package:coconut_wallet/screens/common/tag_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
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
        child: Builder(builder: (context) {
          return GestureDetector(
            onTap: _removeUtxoTooltip,
            child: Stack(
              children: [
                _buildScaffold(context),
                if (_isUtxoTooltipVisible) _buildTooltip(context),
              ],
            ),
          );
        }));
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

  Widget _buildScaffold(BuildContext context) {
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
          child: Selector<
                  UtxoDetailViewModel,
                  Tuple5<TransactionRecord?, List<String>, List<UtxoTag>, List<UtxoTag>,
                      UtxoStatus>>(
              selector: (_, viewModel) => Tuple5(
                    viewModel.transaction,
                    viewModel.dateString,
                    viewModel.utxoTagList,
                    viewModel.selectedUtxoTagList,
                    viewModel.utxoStatus,
                  ),
              builder: (_, data, __) {
                final tx = data.item1;
                final dateString = data.item2;
                final tags = data.item3;
                final selectedTags = data.item4;
                final utxoStatus = data.item5;

                return Column(
                  children: [
                    if (tx == null)
                      const Center(child: CircularProgressIndicator())
                    else ...{
                      _buildDateTime(dateString),
                      _buildAmount(),
                      if (utxoStatus == UtxoStatus.unspent)
                        _buildPrice()
                      else ...{_buildPendingStatus(utxoStatus)},
                      TransactionInputOutputCard(
                        transaction: tx,
                        isSameAddress: (address, _) {
                          return address == widget.utxo.to;
                        },
                        isForTransaction: false,
                      ),
                      _buildAddress(),
                      _buildTxMemo(
                        tx.memo,
                      ),
                      _buildTagSection(context, tags, selectedTags),
                      _buildTxId(),
                      _buildBlockHeight(),
                      CoconutLayout.spacing_1000h,
                      _buildBalanceWidthCheck(),
                    }
                  ],
                );
              }),
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
                style:
                    CoconutTypography.body3_12.copyWith(color: CoconutColors.gray900, height: 1.3)),
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
          _utxoTooltipIconPosition = utxoTooltipIconRenderBox.localToGlobal(Offset.zero);
          _utxoTooltipIconSize = utxoTooltipIconRenderBox.size;
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

  Widget _buildBalanceWidthCheck() {
    return Text(
      key: _balanceWidthKey,
      '0.0000 0000',
      style: CoconutTypography.body2_14_Number.copyWith(color: Colors.transparent, height: 16 / 14),
    );
  }

  Widget _buildDateTime(List<String> timeString) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28.0),
      child:
          HighlightedInfoArea(textList: timeString, textStyle: CoconutTypography.body2_14_Number),
    );
  }

  // TODO: 공통 위젯으로 빼서 여러 화면에서 재사용하기
  // wallet-detail, tx-detail, utxo-list, utxo-detail
  Widget _buildAmount() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Center(
          child: RichText(
              text: TextSpan(
                  text: satoshiToBitcoinString(widget.utxo.amount),
                  style: CoconutTypography.heading2_28_NumberBold,
                  children: <InlineSpan>[
            WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Text(" ${t.btc}", style: CoconutTypography.heading3_21_Number))
          ]))),
    );
  }

  Widget _buildPrice() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Center(
          child: FiatPrice(
        satoshiAmount: widget.utxo.amount,
      )),
    );
  }

  Widget _buildPendingStatus(UtxoStatus status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: status == UtxoStatus.incoming
                  ? CoconutColors.cyan.withOpacity(0.2)
                  : CoconutColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Lottie.asset(
              status == UtxoStatus.incoming
                  ? 'assets/lottie/arrow-down.json'
                  : 'assets/lottie/arrow-up.json',
              width: 20,
              height: 20,
            ),
          ),
          CoconutLayout.spacing_200w,
          Text(
            status == UtxoStatus.incoming ? t.status_receiving : t.status_sending,
            style: CoconutTypography.body2_14_Number.copyWith(color: CoconutColors.gray200),
          ),
        ],
      ),
    );
  }

  Widget _buildAddress() {
    List<String> path = widget.utxo.derivationPath.split('/');
    int changeIndex = path.length - 2;

    return Column(
      children: [
        UnderlineButtonItemCard(
            label: t.utxo_detail_screen.address,
            underlineButtonLabel: t.view_mempool,
            onTapUnderlineButton: () =>
                launchUrl(Uri.parse("${CoconutWalletApp.kMempoolHost}/address/${widget.utxo.to}")),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CopyTextContainer(
                  text: widget.utxo.to,
                  textStyle: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
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
                                : CoconutTypography.body3_12_Number.setColor(CoconutColors.gray500),
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
                        style: CoconutTypography.body3_12.setColor(CoconutColors.gray500))
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
            style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
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
            Navigator.pushNamed(context, '/transaction-detail',
                arguments: {'id': widget.id, 'txHash': widget.utxo.transactionHash});
          },
          child: CopyTextContainer(
            text: widget.utxo.transactionHash,
            textStyle: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
          ),
        ),
        _divider,
      ],
    );
  }

  Widget _buildBlockHeight() {
    return UnderlineButtonItemCard(
        label: t.block_num,
        underlineButtonLabel: widget.utxo.status == UtxoStatus.unspent ? t.view_mempool : '',
        onTapUnderlineButton: () {
          widget.utxo.status == UtxoStatus.unspent
              ? launchUrl(
                  Uri.parse("${CoconutWalletApp.kMempoolHost}/block/${widget.utxo.blockHeight}"))
              : ();
        },
        child: Text(
          widget.utxo.blockHeight != 0 ? widget.utxo.blockHeight.toString() : '-',
          style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
        ));
  }

  Widget _buildTagSection(
    BuildContext context,
    List<UtxoTag> tags,
    List<UtxoTag> selectedTags,
  ) {
    final viewModel = context.read<UtxoDetailViewModel>();
    return Column(
      children: [
        UnderlineButtonItemCard(
          label: t.tag,
          underlineButtonLabel: t.edit,
          onTapUnderlineButton: () => _showTagBottomSheet(context, tags, selectedTags, viewModel),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectedTags.isEmpty) ...{
                Text(
                  '-',
                  style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
                )
              } else ...{
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: List.generate(
                    selectedTags.length,
                    (index) {
                      Color foregroundColor = selectedTags[index].colorIndex != 8
                          ? CoconutColors.colorPalette[selectedTags[index].colorIndex]
                          : CoconutColors
                              .gray400; // colorIndex == 8(gray)일 때 화면상으로 잘 보이지 않기 때문에 gray400으로 설정
                      return IntrinsicWidth(
                        child: CoconutChip(
                          minWidth: 40,
                          color: CoconutColors
                              .backgroundColorPaletteDark[selectedTags[index].colorIndex],
                          borderColor: foregroundColor,
                          label: '#${selectedTags[index].name}',
                          labelSize: 12,
                          labelColor: foregroundColor,
                        ),
                      );
                    },
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
