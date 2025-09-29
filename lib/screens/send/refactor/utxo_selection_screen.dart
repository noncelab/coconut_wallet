import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/refactor/utxo_selection_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/card/locked_utxo_item_card.dart';
import 'package:coconut_wallet/widgets/card/selectable_utxo_item_card.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/overlays/network_error_tooltip.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class UtxoSelectionScreen extends StatefulWidget {
  final List<UtxoState> selectedUtxoList;
  final int walletId;
  final BitcoinUnit currentUnit;

  const UtxoSelectionScreen({
    super.key,
    required this.currentUnit,
    required this.selectedUtxoList,
    required this.walletId,
  });

  @override
  State<UtxoSelectionScreen> createState() => _UtxoSelectionScreenState();
}

class _UtxoSelectionScreenState extends State<UtxoSelectionScreen> {
  final String allLabelName = t.all;
  final ScrollController _scrollController = ScrollController();
  late UtxoSelectionViewModel _viewModel;

  final List<UtxoOrder> _utxoOrderOptions = [
    UtxoOrder.byAmountDesc,
    UtxoOrder.byAmountAsc,
    UtxoOrder.byTimestampDesc,
    UtxoOrder.byTimestampAsc,
  ];

  final GlobalKey _orderDropdownButtonKey = GlobalKey();
  bool _isOrderDropdownVisible = false; // 필터 드롭다운
  late Offset _orderDropdownButtonPosition;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<ConnectivityProvider, UtxoSelectionViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, viewModel) {
        if (connectivityProvider.isNetworkOn != viewModel!.isNetworkOn) {
          viewModel.setIsNetworkOn(connectivityProvider.isNetworkOn);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            // 네트워크 알림 툴팁이 생성되면 위젯이 밀리기 때문에 드롭다운 버튼 위치를 다시 계산
            RenderBox orderDropdownButtonRenderBox =
                _orderDropdownButtonKey.currentContext?.findRenderObject() as RenderBox;

            _orderDropdownButtonPosition = orderDropdownButtonRenderBox.localToGlobal(Offset.zero);
          });
        }
        return viewModel;
      },
      child: Consumer<UtxoSelectionViewModel>(
        builder: (context, viewModel, child) => Stack(
          children: [
            GestureDetector(
              onTap: () => _removeUtxoOrderDropdown(),
              child: Scaffold(
                appBar: CoconutAppBar.build(
                  backgroundColor: CoconutColors.black,
                  title: t.utxo_selection_screen.title,
                  context: context,
                  onBackPressed: () => Navigator.pop(context),
                ),
                body: Stack(
                  children: [
                    Column(
                      children: [
                        Visibility(
                          visible: !viewModel.isNetworkOn,
                          maintainSize: false,
                          maintainAnimation: false,
                          maintainState: false,
                          child: NetworkErrorTooltip(
                            isNetworkOn: viewModel.isNetworkOn,
                          ),
                        ),
                        _buildSendInfoHeader(
                          viewModel,
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              SingleChildScrollView(
                                controller: _scrollController,
                                child: Column(
                                  children: [
                                    _buildUtxoTagList(viewModel),
                                    _buildUtxoList(viewModel),
                                    CoconutLayout.spacing_400h,
                                    const SizedBox(height: 50)
                                  ],
                                ),
                              ),
                              FixedBottomButton(
                                buttonHeight: 50,
                                onButtonClicked: () {
                                  vibrateLight();
                                  Navigator.pop(context, _viewModel.selectedUtxoList);
                                },
                                text: t.complete,
                                isActive: _viewModel.hasSelectionChanged,
                                showGradient: true,
                                gradientPadding: const EdgeInsets.only(
                                    left: 16, right: 16, bottom: 40, top: 110),
                                horizontalPadding: 16,
                                backgroundColor: CoconutColors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _buildUtxoOrderDropdown(viewModel),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    try {
      super.initState();

      _viewModel = UtxoSelectionViewModel(
        Provider.of<WalletProvider>(context, listen: false),
        Provider.of<UtxoTagProvider>(context, listen: false),
        Provider.of<PriceProvider>(context, listen: false),
        Provider.of<PreferenceProvider>(context, listen: false),
        Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn,
        widget.walletId,
        widget.selectedUtxoList,
      );

      _scrollController.addListener(() {
        if (_isOrderDropdownVisible) {
          _removeUtxoOrderDropdown();
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        RenderBox orderDropdownButtonRenderBox =
            _orderDropdownButtonKey.currentContext?.findRenderObject() as RenderBox;

        _orderDropdownButtonPosition = orderDropdownButtonRenderBox.localToGlobal(Offset.zero);
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        CustomDialogs.showCustomAlertDialog(
          context,
          title: t.alert.error_occurs,
          message: t.alert.contact_admin(error: e.toString()),
          onConfirm: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        );
      });
    }
  }

  void _deselectAll() {
    _removeUtxoOrderDropdown();
    _viewModel.deselectAllUtxo();
  }

  void _removeUtxoOrderDropdown() {
    setState(() {
      _isOrderDropdownVisible = false;
    });
  }

  void _selectAll() {
    _removeUtxoOrderDropdown();
    _viewModel.selectAllUtxo();
  }

  void _toggleSelection(UtxoState utxo) {
    _removeUtxoOrderDropdown();
    _viewModel.toggleUtxoSelection(utxo);
  }

  Widget _buildTotalUtxoAmount(
      Widget textKeyWidget, int selectedUtxoListLength, int totalSelectedUtxoAmount) {
    String utxoSumText = widget.currentUnit
        .displayBitcoinAmount(totalSelectedUtxoAmount, defaultWhenZero: '0', shouldCheckZero: true);
    String unitText = widget.currentUnit.symbol;

    return Column(
      children: [
        Container(
          width: MediaQuery.sizeOf(context).width,
          decoration: BoxDecoration(
            color: MyColors.transparentWhite_10,
            borderRadius: BorderRadius.circular(24),
          ),
          margin: const EdgeInsets.only(
            top: 0,
          ),
          child: Container(
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 20,
            ),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Text(
                          t.utxo_total,
                          style: Styles.body2Bold.merge(
                            const TextStyle(color: CoconutColors.white),
                          ),
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Visibility(
                          visible: selectedUtxoListLength != 0,
                          child: Text(
                            t.utxo_count(count: selectedUtxoListLength),
                            style: Styles.caption.merge(
                              const TextStyle(
                                  fontFamily: 'Pretendard', color: MyColors.transparentWhite_70),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "$utxoSumText $unitText",
                      style: Styles.body1Number.merge(const TextStyle(
                          color: CoconutColors.white,
                          fontWeight: FontWeight.w700,
                          height: 16.8 / 14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(
          height: 32,
        ),
        Row(children: [
          CupertinoButton(
            onPressed: () {
              setState(
                () {
                  if (_scrollController.offset < 0) {
                    _scrollController.jumpTo(0);
                  } else if (_scrollController.offset >
                      _scrollController.position.maxScrollExtent) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }

                  if (_isOrderDropdownVisible) {
                    _removeUtxoOrderDropdown();
                  } else {
                    _scrollController.jumpTo(_scrollController.offset);

                    _isOrderDropdownVisible = true;
                  }
                },
              );
            },
            minSize: 0,
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                textKeyWidget,
                const SizedBox(
                  width: 4,
                ),
                SvgPicture.asset(
                  'assets/svg/arrow-down.svg',
                  colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(
                  width: 16,
                ),
                CustomUnderlinedButton(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  text: t.unselect_all,
                  isEnable: true,
                  onTap: () {
                    _removeUtxoOrderDropdown();
                    _deselectAll();
                  },
                ),
                SvgPicture.asset('assets/svg/row-divider.svg'),
                CustomUnderlinedButton(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  text: t.select_all,
                  isEnable: true,
                  onTap: () async {
                    _removeUtxoOrderDropdown();
                    _selectAll();
                  },
                )
              ],
            ),
          )
        ]),
      ],
    );
  }

  Widget _utxoOrderDropdownMenu() {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: CoconutPulldownMenu(
        entries:
            _utxoOrderOptions.map((order) => CoconutPulldownMenuItem(title: order.text)).toList(),
        dividerColor: CoconutColors.black,
        onSelected: (index, selectedText) async {
          bool isChanged = _viewModel.utxoOrder != _utxoOrderOptions[index];
          setState(() {
            _isOrderDropdownVisible = false;
          });

          if (!isChanged) return;
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            _viewModel.changeUtxoOrder(_utxoOrderOptions[index]);
          }
        },
        selectedIndex: _getIndexBySelectedFilter(),
      ),
    );
  }

  int _getIndexBySelectedFilter() {
    switch (_viewModel.utxoOrder) {
      case UtxoOrder.byAmountDesc:
        return 0;
      case UtxoOrder.byAmountAsc:
        return 1;
      case UtxoOrder.byTimestampDesc:
        return 2;
      case UtxoOrder.byTimestampAsc:
        return 3;
    }
  }

  Widget _buildUtxoOrderDropdown(UtxoSelectionViewModel viewModel) {
    if (_isOrderDropdownVisible && viewModel.confirmedUtxoList.isNotEmpty) {
      return Positioned(
        top: _orderDropdownButtonPosition.dy - kToolbarHeight,
        left: 16,
        child: _utxoOrderDropdownMenu(),
      );
    }

    return Container();
  }

  Widget _buildUtxoTagList(UtxoSelectionViewModel viewModel) {
    return Visibility(
      visible: !viewModel.isUtxoTagListEmpty,
      child: Container(
        margin: const EdgeInsets.only(left: 4, bottom: 12),
        child: CustomTagHorizontalSelector(
          tags: viewModel.utxoTagList.map((e) => e.name).toList(),
          showDefaultTags: false,
          selectedName: viewModel.selectedUtxoTagName,
          onSelectedTag: (tagName) {
            viewModel.setSelectedUtxoTagName(tagName);
          },
          settingLock: false,
        ),
      ),
    );
  }

  Widget _buildUtxoList(UtxoSelectionViewModel viewModel) {
    return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 0, bottom: 30, left: 16, right: 16),
        itemCount: viewModel.confirmedUtxoList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 0),
        itemBuilder: (context, index) {
          final utxo = viewModel.confirmedUtxoList[index];
          final utxoHasSelectedTag = viewModel.selectedUtxoTagName == allLabelName ||
              viewModel.utxoTagMap[utxo.utxoId]
                      ?.any((e) => e.name == viewModel.selectedUtxoTagName) ==
                  true;

          if (utxoHasSelectedTag) {
            if (viewModel.selectedUtxoTagName != allLabelName && !utxoHasSelectedTag) {
              return const SizedBox();
            }

            if (utxo.isLocked) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: LockedUtxoItemCard(
                  key: ValueKey(utxo.transactionHash),
                  utxo: utxo,
                  utxoTags: viewModel.utxoTagMap[utxo.utxoId],
                  currentUnit: widget.currentUnit,
                ),
              );
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: SelectableUtxoItemCard(
                key: ValueKey(utxo.transactionHash),
                currentUnit: widget.currentUnit,
                utxo: utxo,
                isSelectable: true,
                isSelected: viewModel.selectedUtxoList.contains(utxo),
                utxoTags: viewModel.utxoTagMap[utxo.utxoId],
                onSelected: _toggleSelection,
              ),
            );
          } else {
            return const SizedBox();
          }
        });
  }

  Widget _buildSendInfoHeader(UtxoSelectionViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12,
      ),
      alignment: Alignment.center,
      color: CoconutColors.black,
      child: _buildTotalUtxoAmount(
        Text(
          key: _orderDropdownButtonKey,
          _viewModel.utxoOrder.text,
          style: Styles.caption2.merge(
            const TextStyle(
              color: CoconutColors.white,
              fontSize: 12,
            ),
          ),
        ),
        viewModel.selectedUtxoList.length,
        viewModel.selectedUtxoAmountSum,
      ),
    );
  }
}
