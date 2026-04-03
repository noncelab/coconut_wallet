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
import 'package:coconut_wallet/repository/realm/address_repository.dart';
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
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final utxoTooltipIconRenderBox = _utxoTooltipIconKey.currentContext?.findRenderObject() as RenderBox?;

      if (utxoTooltipIconRenderBox != null) {
        setState(() {
          _utxoTooltipIconPosition = utxoTooltipIconRenderBox.localToGlobal(Offset.zero);
          _utxoTooltipIconSize = utxoTooltipIconRenderBox.size;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _walletProvider = Provider.of<WalletProvider>(context, listen: false);
    _walletSyncStateStream = Provider.of<NodeProvider>(context, listen: false).getWalletStateStream(widget.id);
    _walletSyncStateSubscription = _walletSyncStateStream.listen(_onWalletUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final utxoTooltipIconRenderBox = _utxoTooltipIconKey.currentContext?.findRenderObject() as RenderBox?;

      if (utxoTooltipIconRenderBox != null) {
        setState(() {
          _utxoTooltipIconPosition = utxoTooltipIconRenderBox.localToGlobal(Offset.zero);
          _utxoTooltipIconSize = utxoTooltipIconRenderBox.size;
        });
      }
    });
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
          Provider.of<AddressRepository>(context, listen: false),
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

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Selector<
            UtxoDetailViewModel,
            Tuple7<TransactionRecord?, List<String>, List<UtxoTag>, List<UtxoTag>, UtxoStatus, bool, bool>
          >(
            selector:
                (_, viewModel) => Tuple7(
                  viewModel.transaction,
                  viewModel.dateString,
                  viewModel.utxoTagList,
                  viewModel.selectedUtxoTagList,
                  viewModel.utxoStatus,
                  viewModel.isFetchingFromMempool,
                  viewModel.isSuspiciousDustUtxo,
                ),
            builder: (_, data, __) {
              final tx = data.item1;
              final dateString = data.item2;
              final tags = data.item3;
              final selectedTags = data.item4;
              final utxoStatus = data.item5;
              final isFetchingFromMempool = data.item6;
              final isSuspiciousDustUtxo = data.item7;

              return Column(
                children: [
                  _buildSuspiciousDustUtxoWarning(isSuspiciousDustUtxo, utxoStatus == UtxoStatus.locked),
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
                    CoconutLayout.spacing_800h,
                    _buildAddress(),
                    _buildLockStatus(utxoStatus == UtxoStatus.locked, isSuspiciousDustUtxo),
                    _buildTagSection(context, tags, selectedTags),
                    _buildTxId(
                      context,
                      child:
                          isFetchingFromMempool && tx.inputAddressList.isEmpty
                              ? _buildTransactionInputOutputSkeleton()
                              : TransactionInputOutputCard(
                                transaction: tx,
                                isSameAddress: (address, index) {
                                  return address == widget.utxo.to && index == widget.utxo.index;
                                },
                                isForTransaction: false,
                                currentUnit: _currentUnit,
                              ),
                    ),
                    _buildTxMemo(tx.memo),
                    _buildBlockHeight(),
                    CoconutLayout.spacing_1000h,
                    _buildBalanceWidthCheck(),
                  },
                ],
              );
            },
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color:
                  status == UtxoStatus.incoming
                      ? CoconutColors.cyan.withValues(alpha: 0.2)
                      : CoconutColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Lottie.asset(
              status == UtxoStatus.incoming ? 'assets/lottie/arrow-down.json' : 'assets/lottie/arrow-up.json',
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
    final path = widget.utxo.derivationPath.split('/');

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
                suffixText: '${path.join('/')} · ${_viewModel.walletNameDisplay}',
                suffixTextStyle: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTxMemo(String? memo) {
    return UnderlineButtonItemCard(
      label: t.tx_memo,
      child: Text(
        memo?.isNotEmpty == true ? memo! : '-',
        style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
      ),
    );
  }

  Widget _buildTxId(BuildContext context, {required Widget child}) {
    return UnderlineButtonItemCard(
      label: t.tx_id,
      underlineButtonLabel: t.view_tx_details,
      onTapUnderlineButton: () async {
        await Navigator.pushNamed(
          context,
          '/transaction-detail',
          arguments: {'id': widget.id, 'txHash': widget.utxo.transactionHash},
        );
        if (!context.mounted) return;
        context.read<UtxoDetailViewModel>().refreshTransaction();
      },
      child: Column(
        children: [
          CopyTextContainer(
            text: widget.utxo.transactionHash,
            textStyle: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
          ),
          CoconutLayout.spacing_300h,
          child,
        ],
      ),
    );
  }

  Widget _buildBlockHeight() {
    return UnderlineButtonItemCard(
      label: t.block_num,
      underlineButtonLabel: widget.utxo.status == UtxoStatus.unspent ? t.view_mempool : '',
      showDivider: false,
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

  Widget _buildTransactionInputOutputSkeleton() {
    return Shimmer.fromColors(
      baseColor: CoconutColors.gray850,
      highlightColor: CoconutColors.gray800,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: CoconutColors.gray850,
          borderRadius: BorderRadius.circular(CoconutStyles.radius_300),
        ),
      ),
    );
  }

  Widget _buildTagSection(BuildContext context, List<UtxoTag> tags, List<UtxoTag> selectedTags) {
    return UnderlineButtonItemCard(
      label: t.tag,
      underlineButtonLabel: t.edit,
      onTapUnderlineButton: showTagBottomSheet, //() => _showTagBottomSheet(context, tags, selectedTags, viewModel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedTags.isEmpty) ...{
            Text('-', style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white)),
          } else ...{
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: List.generate(selectedTags.length, (index) {
                Color foregroundColor =
                    tagColorPalette[selectedTags[index]
                        .colorIndex]; // colorIndex == 8(gray)일 때 화면상으로 잘 보이지 않기 때문에 gray400으로 설정
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
          },
        ],
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

  Future<void> _toggleUtxoLock({required bool lock, bool showToast = true}) async {
    final result = await _viewModel.toggleUtxoLockStatus();
    if (mounted && !result && showToast) {
      CoconutToast.showToast(
        context: context,
        isVisibleIcon: true,
        iconPath: 'assets/svg/triangle-warning.svg',
        text: lock ? t.errors.utxo_lock_error : t.errors.utxo_unlock_error,
        level: CoconutToastLevel.warning,
      );
      return;
    }
    _removeUtxoTooltip();
    vibrateLight();
    if (mounted && showToast) {
      CoconutToast.showToast(
        context: context,
        isVisibleIcon: true,
        iconPath: 'assets/svg/circle-info.svg',
        text: lock ? t.utxo_detail_screen.utxo_locked_toast_msg : t.utxo_detail_screen.utxo_unlocked_toast_msg,
      );
    }
  }

  Widget _buildSuspiciousDustUtxoWarning(bool isSuspiciousDustUtxo, bool isLocked) {
    if (!isSuspiciousDustUtxo) return const SizedBox(height: 20);

    final color = isLocked ? CoconutColors.white : CoconutColors.red;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 28),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: SvgPicture.asset(
                'assets/svg/dust.svg',
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
            CoconutLayout.spacing_100w,
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  isLocked ? t.utxo_detail_screen.suspicious_dust_locked : t.utxo_detail_screen.suspicious_dust_warning,
                  key: ValueKey(isLocked),
                  style: CoconutTypography.body3_12.setColor(color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockStatus(bool isLocked, bool isSuspiciousDustUtxo) {
    return UnderlineButtonItemCard(
      label: t.utxo_detail_screen.lock_status,
      underlineButtonLabel:
          isLocked ? t.utxo_detail_screen.utxo_unlocked_button : t.utxo_detail_screen.utxo_locked_button,
      onTapUnderlineButton: () => _toggleUtxoLock(lock: !isLocked, showToast: !isSuspiciousDustUtxo),
      child: UtxoLockStatusChip(isLocked: isLocked, isSuspiciousDustUtxo: isSuspiciousDustUtxo),
    );
  }
}

class UtxoLockStatusChip extends StatefulWidget {
  final bool isLocked;
  final bool isSuspiciousDustUtxo;
  const UtxoLockStatusChip({super.key, required this.isLocked, required this.isSuspiciousDustUtxo});

  @override
  State<UtxoLockStatusChip> createState() => _UtxoLockStatusChip();
}

class _UtxoLockStatusChip extends State<UtxoLockStatusChip> {
  @override
  Widget build(BuildContext context) {
    final color = widget.isSuspiciousDustUtxo && !widget.isLocked ? CoconutColors.red : CoconutColors.white;

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(CoconutStyles.radius_300),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/svg/${widget.isLocked ? 'lock_simple' : 'unlock_simple'}.svg',
                  width: 14,
                  height: 14,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
                CoconutLayout.spacing_100w,
                Text(
                  widget.isLocked ? t.utxo_detail_screen.utxo_locked : t.utxo_detail_screen.utxo_unlocked,
                  style: CoconutTypography.body3_12.copyWith(color: color, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
