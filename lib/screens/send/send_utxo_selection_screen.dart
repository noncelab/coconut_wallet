import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/data/wallet_type.dart';
import 'package:coconut_wallet/model/send_info.dart';
import 'package:coconut_wallet/model/utxo.dart' as model;
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/screens/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/cconut_wallet_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_dropdown.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class SendUtxoSelectionScreen extends StatefulWidget {
  final int id;
  final SendInfo sendInfo;

  const SendUtxoSelectionScreen({
    super.key,
    required this.id,
    required this.sendInfo,
  });

  @override
  State<SendUtxoSelectionScreen> createState() =>
      _SendUtxoSelectionScreenState();
}

class _SendUtxoSelectionScreenState extends State<SendUtxoSelectionScreen> {
  late AppStateModel _model;
  late WalletListItemBase _walletBaseItem;
  late WalletFeature _walletFeature;
  late WalletType _walletType;

  static String changeField = 'change';
  static String accountIndexField = 'accountIndex';
  late final ScrollController _scrollController;
  late List<model.UTXO> _utxoList;
  late List<model.UTXO> _selectedUtxoList;

  final GlobalKey _filterDropdownButtonKey = GlobalKey();
  final bool _positionedTopWidgetVisible = false; // 스크롤시 상단에 붙어있는 위젯
  bool _isFilterDropdownVisible = false; // 필터 드롭다운(확장형)
  bool _isScrolledFilterDropdownVisible = false; // 필터 드롭다운(축소형)
  Size _filterDropdownButtonSize = const Size(0, 0); // 필터 버튼(확장형)
  late Offset _filterDropdownButtonPosition;
  late RenderBox _filterDropdownButtonRenderBox;

  final GlobalKey _headerTopContainerKey = GlobalKey();
  Size _headerTopContainerSize = const Size(0, 0);
  late Offset _headerTopContainerPosition;
  late RenderBox _headerTopContainerRenderBox;
  bool _afterScrolledHeaderContainerVisible = false;

  late double _totalUtxoAmountWidgetPaddingLeft;
  late double _totalUtxoAmountWidgetPaddingRight;
  late double _totalUtxoAmountWidgetPaddingTop;
  late double _totalUtxoAmountWidgetPaddingBottom;

  @override
  void initState() {
    super.initState();
    _model = Provider.of<AppStateModel>(context, listen: false);
    _scrollController = ScrollController();

    _walletBaseItem = _model.getWalletById(widget.id);
    _walletFeature = getWalletFeatureByWalletType(_walletBaseItem);

    _walletType = _walletBaseItem.walletType;
    if (_model.walletInitState == WalletInitState.finished) {
      _utxoList = getUtxoListWithHoldingAddress(_walletFeature.getUtxoList(),
          _walletBaseItem, accountIndexField, changeField, _walletType);
      _selectedUtxoList = [];
    } else {
      _utxoList = _selectedUtxoList = [];
    }

    _totalUtxoAmountWidgetPaddingLeft = _totalUtxoAmountWidgetPaddingRight =
        _totalUtxoAmountWidgetPaddingTop = 24;
    _totalUtxoAmountWidgetPaddingBottom = 20;

    _scrollController.addListener(() {
      double threshold = _headerTopContainerSize.height + 10;
      double offset = _scrollController.offset;

      setState(() {
        _afterScrolledHeaderContainerVisible = offset >= threshold;

        // 부드럽게 패딩 값 계산
        double progress = (offset / threshold).clamp(0.0, 1.0);

        if (_afterScrolledHeaderContainerVisible) {
          _totalUtxoAmountWidgetPaddingLeft =
              _totalUtxoAmountWidgetPaddingRight =
                  _totalUtxoAmountWidgetPaddingTop = 17;
          _totalUtxoAmountWidgetPaddingBottom = 15;
        } else {
          _totalUtxoAmountWidgetPaddingLeft =
              _totalUtxoAmountWidgetPaddingRight =
                  _totalUtxoAmountWidgetPaddingTop = 24 - (7 * progress);
          _totalUtxoAmountWidgetPaddingBottom = 20 - (5 * progress);
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _filterDropdownButtonRenderBox = _filterDropdownButtonKey.currentContext
          ?.findRenderObject() as RenderBox;
      _filterDropdownButtonSize = _filterDropdownButtonRenderBox.size;
      _filterDropdownButtonPosition =
          _filterDropdownButtonRenderBox.localToGlobal(Offset.zero);

      _headerTopContainerRenderBox = _headerTopContainerKey.currentContext
          ?.findRenderObject() as RenderBox;
      _headerTopContainerSize = _headerTopContainerRenderBox.size;
      _headerTopContainerPosition =
          _headerTopContainerRenderBox.localToGlobal(Offset.zero);
      debugPrint('_headerTopContainerSize: $_headerTopContainerSize');
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// UTXO 선택 상태를 토글하는 함수
  void _toggleSelection(model.UTXO utxo) {
    setState(() {
      if (_selectedUtxoList.contains(utxo)) {
        _selectedUtxoList.remove(utxo);

        /// 이미 선택된 경우 제거
      } else {
        _selectedUtxoList.add(utxo);

        /// 선택되지 않은 경우 추가
      }
    });
  }

  Widget _divider() => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: const Divider(
          height: 1,
          color: MyColors.transparentWhite_10,
        ),
      );

  /// 필터 드롭다운 위젯
  Widget _filterDropDownWidget() {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: CustomDropdown(
        buttons: const [
          '최신순',
          '오래된 순',
          '큰 금액순',
          '작은 금액순',
        ],
        dividerColor: Colors.black,
        onTapButton: (index) {
          setState(() {
            _isFilterDropdownVisible = _isScrolledFilterDropdownVisible = false;
          });
          switch (index) {
            case 0: // 최신순
              debugPrint('최신순 필터링');
              break;
            case 1: // 오래된 순
              debugPrint('오래된 순 필터링');
              break;
            case 2: // 큰 금액순
              debugPrint('쿤 금액순 필터링');
              break;
            case 3: // 작은 금액순
              debugPrint('작은 금액순 필터링');
              break;
          }
        },
      ),
    );
  }

  Widget _totalUtxoAmountWidget(bool delayOption) {
    /// delayOption: _afterScrolledHeaderContainerVisible일 경우 변화가 즉각적으로 일어나기 때문에 별도로 관리
    return Column(
      children: [
        Container(
          width: MediaQuery.sizeOf(context).width,
          decoration: BoxDecoration(
            color: _getSelectedUtxoTotalSatoshi() <
                        UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount) &&
                    _selectedUtxoList.isNotEmpty
                ? MyColors.transparentRed
                : MyColors.transparentWhite_10,
            borderRadius: BorderRadius.circular(24),
          ),
          margin: const EdgeInsets.only(
            top: 10,
          ),
          child: AnimatedPadding(
            padding: EdgeInsets.only(
              left: _totalUtxoAmountWidgetPaddingLeft,
              right: _totalUtxoAmountWidgetPaddingRight,
              top: _totalUtxoAmountWidgetPaddingTop,
              bottom: _totalUtxoAmountWidgetPaddingBottom,
            ),
            duration: const Duration(milliseconds: 10),
            child: Row(
              children: [
                Text(
                  'UTXO 합계',
                  style: Styles.body2Bold.merge(
                    TextStyle(
                      color: _getSelectedUtxoTotalSatoshi() <
                                  UnitUtil.bitcoinToSatoshi(
                                      widget.sendInfo.amount) &&
                              _selectedUtxoList.isNotEmpty
                          ? MyColors.warningRed
                          : MyColors.white,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 4,
                ),
                Visibility(
                  visible: _selectedUtxoList.isNotEmpty,
                  child: Text(
                    '(${_selectedUtxoList.length}개)',
                    style: Styles.caption.merge(
                      TextStyle(
                        fontFamily: 'Pretendard',
                        color: _getSelectedUtxoTotalSatoshi() <
                                UnitUtil.bitcoinToSatoshi(
                                    widget.sendInfo.amount)
                            ? MyColors.transparentWarningRed
                            : MyColors.transparentWhite_70,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        // Transaction.estimatedFee,
                        _selectedUtxoList.isEmpty
                            ? '0 BTC'
                            : '${satoshiToBitcoinString(_getSelectedUtxoTotalSatoshi()).normalizeToFullCharacters()} BTC',
                        style: Styles.body2Number.merge(TextStyle(
                            color: _getSelectedUtxoTotalSatoshi() <
                                        UnitUtil.bitcoinToSatoshi(
                                            widget.sendInfo.amount) &&
                                    _selectedUtxoList.isNotEmpty
                                ? MyColors.warningRed
                                : MyColors.white,
                            fontWeight: FontWeight.w700,
                            height: 16.8 / 14)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: !_afterScrolledHeaderContainerVisible
              ? Visibility(
                  visible: _selectedUtxoList.isEmpty ||
                      _getSelectedUtxoTotalSatoshi() <
                          UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount),
                  maintainSize: true,
                  maintainState: true,
                  maintainAnimation: true,
                  child: _selectedUtxoList.isEmpty
                      ? Text(
                          '아래 목록에서 UTXO를 선택해 주세요',
                          style: Styles.warning.merge(
                            const TextStyle(
                              color: MyColors.white,
                              height: 16 / 12,
                            ),
                          ),
                        )
                      : Text(
                          'UTXO 합계가 모자라요',
                          style: Styles.warning.merge(
                            const TextStyle(
                              height: 16 / 12,
                            ),
                          ),
                        ),
                )
              : Container(),
        ),
        Row(children: [
          IgnorePointer(
            ignoring: _positionedTopWidgetVisible,
            child: Visibility(
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              maintainSemantics: false,
              maintainInteractivity: false,
              visible: !_positionedTopWidgetVisible,
              child: CupertinoButton(
                onPressed: () {
                  setState(
                    () {
                      if (_isFilterDropdownVisible) {
                        _removeFilterDropdown();
                      } else {
                        _isFilterDropdownVisible = true;
                      }
                    },
                  );
                },
                minSize: 0,
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      key: _afterScrolledHeaderContainerVisible
                          ? GlobalKey()
                          : _filterDropdownButtonKey,
                      '큰 금액순',

                      /// TODO: 정렬 Text 대입
                      style: Styles.caption2.merge(
                        const TextStyle(
                          color: MyColors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    SvgPicture.asset(
                      'assets/svg/arrow-down.svg',
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomUnderlinedButton(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  text: '모두 해제',
                  onTap: () {},
                ),
                SvgPicture.asset('assets/svg/row-divider.svg'),
                CustomUnderlinedButton(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  text: '모두 선택',
                  onTap: () {
                    debugPrint('모두 선택');
                  },
                )
              ],
            ),
          )
        ]),
      ],
    );
  }

  void _removeFilterDropdown() {
    setState(() {
      _isFilterDropdownVisible = false;
      _isScrolledFilterDropdownVisible = false;
    });
  }

  int _getSelectedUtxoTotalSatoshi() {
    if (_selectedUtxoList.isEmpty) return 0;
    return _selectedUtxoList
        .map((utxo) => utxo.amount)
        .reduce((value, element) => value + element);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _removeFilterDropdown();
      },
      child: GestureDetector(
        onVerticalDragDown: (details) => _removeFilterDropdown(),
        child: Scaffold(
          appBar: CustomAppBar.buildWithNext(
            backgroundColor: MyColors.black,
            title: 'UTXO 고르기',
            context: context,
            onNextPressed: () {},
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 10,
                        bottom: 10,
                      ),
                      alignment: Alignment.center,
                      color: MyColors.black,
                      child: Column(
                        children: [
                          Container(
                            key: _headerTopContainerKey,
                            width: MediaQuery.sizeOf(context).width,
                            decoration: BoxDecoration(
                              color: MyColors.transparentWhite_10,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.only(
                              left: 24,
                              right: 24,
                              top: 24,
                              bottom: 20,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      '보낼 수량',
                                      style: Styles.body2Bold,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${satoshiToBitcoinString(
                                              UnitUtil.bitcoinToSatoshi(
                                                widget.sendInfo.amount,
                                              ),
                                            ).normalizeToFullCharacters()} BTC',
                                            style: Styles.body2Number,
                                          ),
                                          Selector<UpbitConnectModel, int?>(
                                            selector: (context, model) =>
                                                model.bitcoinPriceKrw,
                                            builder: (context, bitcoinPriceKrw,
                                                child) {
                                              return Text(
                                                bitcoinPriceKrw != null
                                                    ? '₩ ${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount), bitcoinPriceKrw).toDouble())}'
                                                    : '',
                                                style: Styles.balance2,
                                              );
                                            },
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                _divider(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      '수수료',
                                      style: Styles.body2Bold,
                                    ),
                                    CustomUnderlinedButton(
                                        text: '변경', onTap: () {}),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            // Transaction.estimatedFee,
                                            '',
                                            style: Styles.body2Number,
                                          ),
                                          Text(
                                            // Transaction.estimatedFee,
                                            '',
                                            style: Styles.body2Number,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                _divider(),
                                const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '잔돈',
                                      style: Styles.body2Bold,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            // Transaction.estimatedFee,
                                            'BTC',
                                            style: Styles.body2Number,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _totalUtxoAmountWidget(false),
                        ],
                      ),
                    ),
                    ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(
                            top: 0, bottom: 30, left: 16, right: 16),
                        itemCount: _utxoList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return UtxoSelectableCard(
                            utxo: _utxoList[index],
                            isSelected:
                                _selectedUtxoList.contains(_utxoList[index]),
                            onSelected: _toggleSelection,
                          );
                        }),
                  ],
                ),
              ),
              if (_afterScrolledHeaderContainerVisible) ...{
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                      color: MyColors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      child: _totalUtxoAmountWidget(true)),
                ),
              },
              if (_isFilterDropdownVisible && _utxoList.isNotEmpty) ...{
                Positioned(
                  top: _filterDropdownButtonPosition.dy -
                      _scrollController.offset -
                      kToolbarHeight -
                      8,
                  left: 16,
                  child: _filterDropDownWidget(),
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class UtxoSelectableCard extends StatefulWidget {
  final model.UTXO utxo;
  final bool isSelected;
  final Function(model.UTXO) onSelected;

  const UtxoSelectableCard({
    super.key,
    required this.utxo,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  State<UtxoSelectableCard> createState() => _UtxoSelectableCardState();
}

class _UtxoSelectableCardState extends State<UtxoSelectableCard> {
  late bool _isPressing;
  late List<String> dateString;

  @override
  void initState() {
    super.initState();
    _isPressing = false;
    dateString = DateTimeUtil.formatDatetime(widget.utxo.timestamp).split('|');
    dateString[0] = dateString[0].replaceAll('.', '/');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        setState(() {
          _isPressing = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _isPressing = false;
        });
      },
      onTap: () {
        setState(() {
          _isPressing = false;
        });
        widget.onSelected(widget.utxo);
      },
      child: Container(
        decoration: BoxDecoration(
          color: _isPressing ? MyColors.transparentWhite_10 : MyColors.black,
          borderRadius: BorderRadius.circular(
            20,
          ),
          border: Border.all(
            width: 1,
            color: widget.isSelected ? MyColors.primary : MyColors.borderGrey,
          ),
        ),
        padding: const EdgeInsets.only(
          top: 23,
          bottom: 22,
          left: 18,
          right: 23,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  satoshiToBitcoinString(widget.utxo.amount),
                  style: Styles.h2Number,
                ),
                const SizedBox(
                  height: 8,
                ),
                Row(
                  children: [
                    Text(
                      dateString[0],
                      style: Styles.caption,
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: MyColors.transparentWhite_40,
                      width: 1,
                      height: 10,
                    ),
                    Text(
                      dateString[1],
                      style: Styles.caption,
                    ),
                  ],
                )
              ],
            ),
            SvgPicture.asset(
              widget.isSelected
                  ? 'assets/svg/circle-check-green.svg'
                  : 'assets/svg/circle-check-gray.svg',
            ),
          ],
        ),
      ),
    );
  }
}
