import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_detail_view_model.dart';
import 'package:coconut_wallet/screens/common/tag_apply_bottom_sheet.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/button/copy_text_container.dart';
import 'package:coconut_wallet/widgets/card/transaction_input_output_card.dart';
import 'package:coconut_wallet/widgets/card/underline_button_item_card.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
import 'package:coconut_wallet/widgets/highlighted_info_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';

const _divider = Divider(color: CoconutColors.gray800);

class UtxoDetailScreen extends StatefulWidget {
  final int id;
  final UtxoState utxo;

  const UtxoDetailScreen({super.key, required this.id, required this.utxo});

  @override
  State<UtxoDetailScreen> createState() => _UtxoDetailScreenState();
}

class _UtxoDetailScreenState extends State<UtxoDetailScreen> {
  final GlobalKey _utxoTooltipIconKey = GlobalKey();
  late Size _utxoTooltipIconSize;
  late Offset _utxoTooltipIconPosition;

  final GlobalKey _balanceWidthKey = GlobalKey();
  bool _isUtxoTooltipVisible = false;
  late UtxoDetailViewModel _viewModel;
  late UtxoState _utxoState;
  late WalletProvider _walletProvider;
  late BitcoinUnit _currentUnit;
  late Stream<WalletUpdateInfo> _walletSyncStateStream;
  late StreamSubscription<WalletUpdateInfo>? _walletSyncStateSubscription;

  @override
  void initState() {
    super.initState();
    _utxoState = widget.utxo;
    _currentUnit = context.read<PreferenceProvider>().currentUnit;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _walletProvider = Provider.of<WalletProvider>(context, listen: false);
    _walletSyncStateStream = Provider.of<NodeProvider>(context, listen: false).getWalletStateStream(widget.id);
    _walletSyncStateSubscription = _walletSyncStateStream.listen(_onWalletUpdate);
  }

  @override
  void dispose() {
    _walletSyncStateSubscription?.cancel();
    super.dispose();
  }

  void _onWalletUpdate(WalletUpdateInfo info) {
    final updatedUtxo = _walletProvider.getUtxoState(widget.id, widget.utxo.utxoId);
    if (updatedUtxo != null) {
      setState(() {
        _utxoState = updatedUtxo;
      });
    }
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit.next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UtxoDetailViewModel>(
      create: (_) {
        _viewModel = UtxoDetailViewModel(
          widget.id,
          _utxoState,
          Provider.of<UtxoTagProvider>(context, listen: false),
          Provider.of<TransactionProvider>(context, listen: false),
          Provider.of<WalletProvider>(context, listen: false),
          Provider.of<NodeProvider>(context, listen: false).getWalletStateStream(widget.id),
          Provider.of<BlockExplorerProvider>(context, listen: false),
        );
        return _viewModel;
      },
      child: Builder(
        builder: (context) {
          return GestureDetector(
            onTap: _removeUtxoTooltip,
            child: Stack(children: [_buildScaffold(context), if (_isUtxoTooltipVisible) _buildTooltip(context)]),
          );
        },
      ),
    );
  }

  Future<void> showTagBottomSheet() async {
    final List<String> currentUtxoIds = [widget.utxo.utxoId];

    final result = await showModalBottomSheet<TagApplyResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TagApplyBottomSheet(walletId: widget.id, selectedUtxoIds: currentUtxoIds),
    );

    if (result == null) return;
    if (!mounted) return;

    final mode = result.mode;
    final tagStates = result.tagStates;

    if (mode == UtxoTagApplyEditMode.add ||
        mode == UtxoTagApplyEditMode.update ||
        mode == UtxoTagApplyEditMode.delete) {
      _viewModel.refreshTagList();
      return;
    }

    if (mode == UtxoTagApplyEditMode.changeAppliedTags) {
      final tagProvider = context.read<UtxoTagProvider>();

      await tagProvider.applyTagsToUtxos(
        walletId: widget.id,
        selectedUtxoIds: currentUtxoIds,
        tagStates: tagStates,
        getCurrentTagsCallback: (_) => _viewModel.appliedUtxoTagList.map((e) => e.name).toList(),
      );

      _viewModel.refreshTagList();

      if (mounted) {
        CoconutToast.showToast(
          context: context,
          isVisibleIcon: true,
          iconPath: 'assets/svg/circle-info.svg',
          text: t.utxo_list_screen.utxo_tag_updated,
        );
      }
    }
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Selector<UtxoDetailViewModel, Tuple4<TransactionRecord?, List<String>, List<UtxoTag>, UtxoStatus>>(
          selector:
              (_, viewModel) => Tuple4(
                viewModel.transaction,
                viewModel.dateString,
                viewModel.appliedUtxoTagList,
                viewModel.utxoStatus,
              ),
          builder: (_, data, __) {
            final tx = data.item1;
            final dateString = data.item2;
            final appliedTags = data.item3;
            final utxoStatus = data.item4;

            return Column(
              children: [
                if (tx == null)
                  const Center(child: CircularProgressIndicator())
                else ...{
                  _buildDateTime(dateString),
                  _buildAmount(),
                  if (utxoStatus == UtxoStatus.unspent || utxoStatus == UtxoStatus.locked)
                    _buildPrice()
                  else ...{
                    _buildPendingStatus(utxoStatus),
                  },
                  if (utxoStatus == UtxoStatus.unspent || utxoStatus == UtxoStatus.locked)
                    UtxoLockToggleButton(
                      isLocked: utxoStatus == UtxoStatus.locked,
                      onPressed: () async {
                        final viewModel = context.read<UtxoDetailViewModel>();
                        final result = await viewModel.toggleUtxoLockStatus();
                        if (context.mounted && !result) {
                          CoconutToast.showWarningToast(
                            context: context,
                            text:
                                utxoStatus == UtxoStatus.locked ? t.errors.utxo_unlock_error : t.errors.utxo_lock_error,
                          );
                          return;
                        }
                        _removeUtxoTooltip();
                        vibrateLight();
                        if (context.mounted) {
                          CoconutToast.showToast(
                            context: context,
                            isVisibleIcon: true,
                            iconPath: 'assets/svg/circle-info.svg',
                            text:
                                utxoStatus != UtxoStatus.locked
                                    ? t.utxo_detail_screen.utxo_locked_toast_msg
                                    : t.utxo_detail_screen.utxo_unlocked_toast_msg,
                          );
                        }
                      },
                    ),
                  TransactionInputOutputCard(
                    transaction: tx,
                    isSameAddress: (address, index) {
                      return address == widget.utxo.to && index == widget.utxo.index;
                    },
                    isForTransaction: false,
                    currentUnit: _currentUnit,
                  ),
                  _buildAddress(),
                  _buildTxMemo(tx.memo),
                  _buildTagSection(appliedTags),
                  _buildTxId(),
                  _buildBlockHeight(),
                  CoconutLayout.spacing_1000h,
                  _buildBalanceWidthCheck(),
                },
              ],
            );
          },
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
        ),
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
            padding: const EdgeInsets.only(top: 28, left: 16, right: 16, bottom: 12),
            color: CoconutColors.white,
            child: Text(
              t.tooltip.utxo,
              style: CoconutTypography.body3_12.copyWith(color: CoconutColors.gray900, height: 1.3),
            ),
          ),
        ),
      ),
    );
  }

  void _removeUtxoTooltip() {
    if (_isUtxoTooltipVisible) {
      setState(() {
        _isUtxoTooltipVisible = false;
      });
    }
  }

  void _toggleUtxoTooltip() {
    if (!_isUtxoTooltipVisible) {
      final renderBox = _utxoTooltipIconKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        _utxoTooltipIconPosition = renderBox.localToGlobal(Offset.zero);
        _utxoTooltipIconSize = renderBox.size;
      }
    }
    setState(() {
      _isUtxoTooltipVisible = !_isUtxoTooltipVisible;
    });
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
      child: HighlightedInfoArea(textList: timeString, textStyle: CoconutTypography.body2_14_Number),
    );
  }

  Widget _buildAmount() {
    return GestureDetector(
      onTap: _toggleUnit,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2.0),
        child: Center(
          child: FittedBox(
            child: BitcoinAmountUnit(
              currentUnit: _currentUnit,
              unitStyle: CoconutTypography.heading4_18_Number,
              child: Text(
                _currentUnit.displayBitcoinAmount(widget.utxo.amount),
                style: CoconutTypography.heading2_28_NumberBold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrice() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Center(child: GestureDetector(onTap: _toggleUnit, child: FiatPrice(satoshiAmount: widget.utxo.amount))),
    );
  }

  Widget _buildPendingStatus(UtxoStatus status) {
    final isIncoming = status == UtxoStatus.incoming;
    final bgColor =
        isIncoming ? CoconutColors.cyan.withValues(alpha: 0.2) : CoconutColors.primary.withValues(alpha: 0.2);
    final lottiePath = isIncoming ? 'assets/lottie/arrow-down.json' : 'assets/lottie/arrow-up.json';
    final statusText = isIncoming ? t.status_receiving : t.status_sending;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(100)),
            child: Lottie.asset(lottiePath, width: 20, height: 20),
          ),
          CoconutLayout.spacing_200w,
          Text(statusText, style: CoconutTypography.body2_14_Number.copyWith(color: CoconutColors.gray200)),
        ],
      ),
    );
  }

  List<InlineSpan> _buildPathSpans() {
    List<String> path = widget.utxo.derivationPath.split('/');
    if (path.isEmpty) return [];

    int changeIndex = path.length - 2;
    return [
      for (int i = 0; i < path.length; i++) ...[
        TextSpan(
          text: path[i],
          style:
              (i == changeIndex && path[changeIndex] == '1')
                  ? CoconutTypography.body3_12_NumberBold.setColor(CoconutColors.gray200)
                  : CoconutTypography.body3_12_Number.setColor(CoconutColors.gray500),
        ),
        if (i < path.length - 1)
          TextSpan(text: "/", style: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray500)),
      ],
    ];
  }

  Widget _buildAddress() {
    List<String> path = widget.utxo.derivationPath.split('/');
    final isChange = path.length >= 2 && path[path.length - 2] == '1';

    return Column(
      children: [
        UnderlineButtonItemCard(
          label: t.utxo_detail_screen.address,
          underlineButtonLabel: t.view_mempool,
          onTapUnderlineButton: () => launchUrl(Uri.parse("${_viewModel.mempoolHost}/address/${widget.utxo.to}")),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CopyTextContainer(
                text: widget.utxo.to,
                textStyle: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text.rich(TextSpan(children: _buildPathSpans())),
                  if (isChange) ...[
                    CoconutLayout.spacing_100w,
                    Text('(${t.change})', style: CoconutTypography.body3_12.setColor(CoconutColors.gray500)),
                  ],
                ],
              ),
            ],
          ),
        ),
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
            (memo == null || memo.isEmpty) ? '-' : memo,
            style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
          ),
        ),
        _divider,
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
            Navigator.pushNamed(
              context,
              '/transaction-detail',
              arguments: {'id': widget.id, 'txHash': widget.utxo.transactionHash},
            );
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
            ? launchUrl(Uri.parse("${_viewModel.mempoolHost}/block/${widget.utxo.blockHeight}"))
            : ();
      },
      child: Text(
        widget.utxo.blockHeight != 0 ? widget.utxo.blockHeight.toString() : '-',
        style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
      ),
    );
  }

  Widget _buildTagSection(List<UtxoTag> appliedTags) {
    return Column(
      children: [
        UnderlineButtonItemCard(
          label: t.tag,
          underlineButtonLabel: t.edit,
          onTapUnderlineButton: showTagBottomSheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (appliedTags.isEmpty) ...{
                Text('-', style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white)),
              } else ...{
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children:
                      appliedTags.map((tag) {
                        final foregroundColor = tagColorPalette[tag.colorIndex];
                        return IntrinsicWidth(
                          child: CoconutChip(
                            minWidth: 40,
                            color: CoconutColors.backgroundColorPaletteDark[tag.colorIndex],
                            borderColor: foregroundColor,
                            label: '#${tag.name}',
                            labelSize: 12,
                            labelColor: foregroundColor,
                          ),
                        );
                      }).toList(),
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

class UtxoLockToggleButton extends StatefulWidget {
  final bool isLocked;
  final VoidCallback onPressed;
  const UtxoLockToggleButton({super.key, required this.isLocked, required this.onPressed});

  @override
  State<UtxoLockToggleButton> createState() => _UtxoLockToggleButton();
}

class _UtxoLockToggleButton extends State<UtxoLockToggleButton> {
  bool isPressing = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown:
              (details) => setState(() {
                isPressing = true;
              }),
          onTapCancel:
              () => setState(() {
                isPressing = false;
              }),
          onTap: () {
            setState(() {
              isPressing = false;
            });
            widget.onPressed();
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/svg/${widget.isLocked ? 'lock' : 'unlock'}_simple.svg',
                  colorFilter: ColorFilter.mode(
                    isPressing ? CoconutColors.gray800 : CoconutColors.white,
                    BlendMode.srcIn,
                  ),
                  width: 16,
                  height: 16,
                ),
                CoconutLayout.spacing_50w,
                Text(
                  widget.isLocked ? t.utxo_detail_screen.utxo_locked : t.utxo_detail_screen.utxo_unlocked,
                  style: CoconutTypography.body3_12.setColor(isPressing ? CoconutColors.gray800 : CoconutColors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
