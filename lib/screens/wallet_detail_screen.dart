import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/data/wallet_type.dart';
import 'package:coconut_wallet/model/manager/converter/transaction.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/utils/cconut_wallet_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/custom_dropdown.dart';
import 'package:coconut_wallet/widgets/utxo_item_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:coconut_wallet/model/app_error.dart';
import 'package:coconut_wallet/model/utxo.dart' as model;
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/screens/faucet_request_screen.dart';
import 'package:coconut_wallet/screens/receive_address_screen.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/bottom_sheet.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/button/small_action_button.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:provider/provider.dart';
import '../model/enums.dart';

class WalletDetailScreen extends StatefulWidget {
  const WalletDetailScreen({super.key, required this.id, this.syncResult});

  final int id;
  final SyncResult? syncResult;

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

enum Unit { btc, sats }

enum SelectedListType { Transaction, UTXO }

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  static const SizedBox gapOfTxRowItems = SizedBox(
    height: 8,
  );
  final GlobalKey _faucetIconKey = GlobalKey();
  final GlobalKey _appBarKey = GlobalKey();
  final GlobalKey _topToggleButtonKey = GlobalKey();
  final GlobalKey _topSelectorWidgetKey = GlobalKey();
  final GlobalKey _topHeaderWidgetKey = GlobalKey();
  final GlobalKey _positionedTopWidgetKey = GlobalKey();
  final GlobalKey _filterDropdownButtonKey = GlobalKey();
  final GlobalKey _scrolledFilterDropdownButtonKey = GlobalKey();
  final GlobalKey _txSliverListKey = GlobalKey();
  final GlobalKey _utxoSliverListKey = GlobalKey();
  late RenderBox _faucetRenderBox;
  late RenderBox _appBarRenderBox;
  late RenderBox _topToggleButtonRenderBox;
  late RenderBox _topSelectorWidgetRenderBox;
  late RenderBox _topHeaderWidgetRenderBox;
  late RenderBox _positionedTopWidgetRenderBox;
  late RenderBox _filterDropdownButtonRenderBox;
  RenderBox? _scrolledFilterDropdownButtonRenderBox;
  late Size _faucetIconSize;
  Size _appBarSize = const Size(0, 0);
  Size _topToggleButtonSize = const Size(0, 0); // BTC sats 버튼
  Size _topSelectorWidgetSize = const Size(0, 0); // 원화 영역
  Size _topHeaderWidgetSize = const Size(0, 0); // 거래내역 - UTXO 리스트 위젯 영역
  Size _positionedTopWidgetSize = const Size(0, 0); // 거래내역 - UTXO 리스트 위젯 영역
  Size _filterDropdownButtonSize = const Size(0, 0); // 필터 버튼(확장형)
  Size _scrolledFilterDropdownButtonSize = const Size(0, 0); // 필터 버튼(축소형))
  Size _txSliverListSize = const Size(0, 0); // 거래내역 리스트 사이즈
  Size _utxoSliverListSize = const Size(0, 0); // utxo 리스트 사이즈
  late Offset _faucetIconPosition;
  late Offset _filterDropdownButtonPosition;
  late Offset _scrolledFilterDropdownButtonPosition;
  double topPadding = 0;

  SelectedListType _selectedListType = SelectedListType.Transaction;

  bool _positionedTopWidgetVisible = false; // 스크롤시 상단에 붙어있는 위젯
  bool _isFilterDropdownVisible = false; // 필터 드롭다운(확장형)
  bool _isScrolledFilterDropdownVisible = false; // 필터 드롭다운(축소형)
  bool _isUtxoListLoadComplete = false;

  int _selectedAccountIndex = 0;
  Unit _current = Unit.btc;
  List<Transfer> _txList = [];

  // 실 데이터 반영시 _utxoList.isNotEmpty 체크 부분을 꼭 확인할 것.
  List<model.UTXO> _utxoList = [];
  UtxoOrderEnum _selectedFilter = UtxoOrderEnum.byAmountDesc; // 초기 정렬 방식

  late WalletType _walletType;
  static String changeField = 'change';
  static String accountIndexField = 'accountIndex';

  bool _isPullToRefeshing = false;
  late WalletListItemBase _walletBaseItem;
  late WalletFeature _walletFeature;
  String faucetTip = '테스트용 비트코인으로 마음껏 테스트 해보세요';
  bool _faucetTipVisible = false;
  bool _faucetTooltipVisible = false;

  late AppStateModel _model;
  late WalletInitState _prevWalletInitState;
  late int? _prevTxCount;
  late bool _prevIsLatestTxBlockHeightZero;

  final SharedPrefs _sharedPrefs = SharedPrefs();

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _model = Provider.of<AppStateModel>(context, listen: false);
    _prevWalletInitState = _model.walletInitState;
    _scrollController = ScrollController();

    _walletBaseItem = _model.getWalletById(widget.id);
    _walletFeature = getWalletFeatureByWalletType(_walletBaseItem);
    _prevTxCount = _walletBaseItem.txCount;
    _prevIsLatestTxBlockHeightZero = _walletBaseItem.isLatestTxBlockHeightZero;

    _walletType = _walletBaseItem.walletType;
    if (_model.walletInitState == WalletInitState.finished) {
      getUtxoListWithHoldingAddress(_walletFeature.walletStatus!.utxoList,
          _walletBaseItem, accountIndexField, changeField, _walletType);
    }

    if (_utxoList.isNotEmpty && mounted) {
      setState(() {
        model.UTXO.sortUTXO(_utxoList, _selectedFilter);
        _isUtxoListLoadComplete = true;
      });
    }

    List<TransferDTO>? newTxList = _model.getTxList(widget.id);
    if (newTxList != null) {
      _txList = newTxList;
    }

    _model.addListener(_stateListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appBarRenderBox =
          _appBarKey.currentContext?.findRenderObject() as RenderBox;
      _topToggleButtonRenderBox =
          _topToggleButtonKey.currentContext?.findRenderObject() as RenderBox;
      _topSelectorWidgetRenderBox =
          _topSelectorWidgetKey.currentContext?.findRenderObject() as RenderBox;
      _topHeaderWidgetRenderBox =
          _topHeaderWidgetKey.currentContext?.findRenderObject() as RenderBox;
      _positionedTopWidgetRenderBox = _positionedTopWidgetKey.currentContext
          ?.findRenderObject() as RenderBox;

      // _filterDropdownButtonKey가 할당된 오브젝트가 생성되기 전이기 때문에 기본값으로 초기화 합니다.
      _filterDropdownButtonRenderBox = RenderConstrainedBox(
          additionalConstraints:
              const BoxConstraints.tightFor(width: 0, height: 0));

      _filterDropdownButtonPosition = Offset.zero;
      _scrolledFilterDropdownButtonPosition = Offset.zero;

      _appBarSize = _appBarRenderBox.size;
      _topToggleButtonSize = _topToggleButtonRenderBox.size;
      _topSelectorWidgetSize = _topSelectorWidgetRenderBox.size;
      _topHeaderWidgetSize = _topHeaderWidgetRenderBox.size;
      _positionedTopWidgetSize = _positionedTopWidgetRenderBox.size;
      _filterDropdownButtonSize = const Size(0, 0);
      _scrolledFilterDropdownButtonSize = const Size(0, 0);

      setState(() {
        topPadding = _topToggleButtonSize.height +
            _topSelectorWidgetSize.height +
            _topHeaderWidgetSize.height -
            _positionedTopWidgetSize.height;
      });

      if (_txList.isNotEmpty) {
        final RenderBox txSliverListRenderBox =
            _txSliverListKey.currentContext?.findRenderObject() as RenderBox;
        _txSliverListSize = txSliverListRenderBox.size;
      }

      _scrollController.addListener(() {
        if (_isFilterDropdownVisible || _isScrolledFilterDropdownVisible) {
          _removeFilterDropdown();
        }

        if (_scrollController.offset > topPadding) {
          if (!_isPullToRefeshing) {
            setState(() {
              _positionedTopWidgetVisible = true;
              _isFilterDropdownVisible = false;
            });
            if (_scrolledFilterDropdownButtonRenderBox == null &&
                _utxoList.isNotEmpty &&
                _selectedListType == SelectedListType.UTXO) {
              _scrolledFilterDropdownButtonRenderBox =
                  _scrolledFilterDropdownButtonKey.currentContext
                      ?.findRenderObject() as RenderBox;
              _scrolledFilterDropdownButtonPosition =
                  _scrolledFilterDropdownButtonRenderBox!
                      .localToGlobal(Offset.zero);
              _scrolledFilterDropdownButtonSize =
                  _scrolledFilterDropdownButtonRenderBox!.size;
            }
          }
        } else {
          if (!_isPullToRefeshing) {
            setState(() {
              _positionedTopWidgetVisible = false;
              _isScrolledFilterDropdownVisible = false;
            });
          }
        }
      });

      _faucetRenderBox =
          _faucetIconKey.currentContext?.findRenderObject() as RenderBox;
      _faucetIconPosition = _faucetRenderBox.localToGlobal(Offset.zero);
      _faucetIconSize = _faucetRenderBox.size;

      if (widget.syncResult != null) {
        String message = "";
        switch (widget.syncResult) {
          case SyncResult.newWalletAdded:
            message = "새로운 지갑을 추가했어요";
          case SyncResult.existingWalletUpdated:
            message = "지갑 정보가 업데이트 됐어요";
          case SyncResult.existingWalletNoUpdate:
            message = "이미 추가한 지갑이에요";
          default:
        }

        if (message.isNotEmpty) {
          CustomToast.showToast(context: context, text: message);
        }
      }

      final faucetHistory = SharedPrefs().getFaucetHistoryWithId(widget.id);
      if (_walletBaseItem.balance == 0 && faucetHistory.count < 3) {
        setState(() {
          _faucetTooltipVisible = true;
        });
        Future.delayed(const Duration(milliseconds: 500)).then((_) {
          setState(() {
            _faucetTipVisible = true;
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _model.removeListener(_stateListener);
    super.dispose();
  }

  // _stateListener start
  void _stateListener() {
    // _prevWalletInitState != WalletInitState.finished 조건 걸어주지 않으면 삭제 시 getWalletById 과정에서 에러 발생
    if (_prevWalletInitState != WalletInitState.finished &&
        _model.walletInitState == WalletInitState.finished) {
      _checkTxCount(
          _walletBaseItem.txCount, _walletBaseItem.isLatestTxBlockHeightZero);
      getUtxoListWithHoldingAddress(_walletFeature.walletStatus!.utxoList,
          _walletBaseItem, accountIndexField, changeField, _walletType);
      if (mounted) {
        setState(() {
          _isUtxoListLoadComplete = true;
          model.UTXO.sortUTXO(_utxoList, _selectedFilter);
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_filterDropdownButtonKey.currentContext?.findRenderObject() !=
              null) {
            _filterDropdownButtonRenderBox =
                _filterDropdownButtonKey.currentContext!.findRenderObject()
                    as RenderBox;

            _filterDropdownButtonSize = _filterDropdownButtonRenderBox.size;
            _filterDropdownButtonPosition =
                _filterDropdownButtonRenderBox.localToGlobal(Offset.zero);
          }
        });
      }
    }
    _prevWalletInitState = _model.walletInitState;
  }

  void _applyFilter(UtxoOrderEnum orderEnum) async {
    if (orderEnum == _selectedFilter) return;
    _scrollController.jumpTo(0);
    setState(() {
      _selectedFilter = orderEnum;
      //_selectedUtxoList.clear();
    });
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        model.UTXO.sortUTXO(_utxoList, orderEnum);
      });
    }
  }

  _checkTxCount(int? txCount, bool isLatestTxBlockHeightZero) {
    Logger.log('--> prevTxCount: $_prevTxCount, wallet.txCount: $txCount');
    Logger.log(
        '--> prevIsZero: $_prevIsLatestTxBlockHeightZero, wallet.isZero: $isLatestTxBlockHeightZero');

    /// _walletListItem의 txCount, isLatestTxBlockHeightZero가 변경되었을 때만 트랜잭션 목록 업데이트
    if (_prevTxCount != txCount ||
        _prevIsLatestTxBlockHeightZero != isLatestTxBlockHeightZero) {
      // TODO: pagination?
      List<Transfer>? newTxList = _model.getTxList(widget.id);
      if (newTxList != null) {
        print('--> [detail화면] newTxList.length: ${newTxList.length}');
        _txList = newTxList;
        setState(() {});
      }
    }
    _prevTxCount = txCount;
    _prevIsLatestTxBlockHeightZero = isLatestTxBlockHeightZero;
  }
  // setListener end

  void _toggleUnit() {
    setState(() {
      _current = _current == Unit.btc ? Unit.sats : Unit.btc;
    });
  }

  void _toggleListType(SelectedListType type) async {
    if (type == SelectedListType.Transaction) {
      setState(() {
        _selectedListType = SelectedListType.Transaction;
        _isFilterDropdownVisible = false;
        _isScrolledFilterDropdownVisible = false;
      });
    } else {
      setState(() {
        _selectedListType = SelectedListType.UTXO;
      });
      if (_utxoList.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 200));
        _filterDropdownButtonRenderBox = _filterDropdownButtonKey.currentContext
            ?.findRenderObject() as RenderBox;
        _filterDropdownButtonSize = _filterDropdownButtonRenderBox.size;

        _filterDropdownButtonPosition =
            _filterDropdownButtonRenderBox.localToGlobal(Offset.zero);
        final RenderBox utxoSliverListRenderBox =
            _utxoSliverListKey.currentContext?.findRenderObject() as RenderBox;
        _utxoSliverListSize = utxoSliverListRenderBox.size;
      }
    }
  }

  void changeSelectedAccount(int index) {
    setState(() => _selectedAccountIndex = index);
  }

  Widget _listTypeSelectionRow() {
    return Row(
      children: [
        CupertinoButton(
          pressedOpacity: 0.8,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minSize: 0,
          onPressed: () {
            _toggleListType(SelectedListType.Transaction);
          },
          child: Text(
            '거래 내역',
            style: Styles.h3.merge(
              TextStyle(
                color: _selectedListType == SelectedListType.Transaction
                    ? MyColors.white
                    : MyColors.transparentWhite_50,
              ),
            ),
          ),
        ),
        const SizedBox(
          width: 24,
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          pressedOpacity: 0.8,
          // focusColor: MyColors.white,
          minSize: 0,
          onPressed: () {
            _toggleListType(SelectedListType.UTXO);
          },
          child: Text.rich(TextSpan(
              text: 'UTXO 목록',
              style: Styles.h3.merge(
                TextStyle(
                  color: _selectedListType == SelectedListType.UTXO
                      ? MyColors.white
                      : MyColors.transparentWhite_50,
                ),
              ),
              children: [
                if (_utxoList.isNotEmpty) ...{
                  TextSpan(
                    text: ' (${_utxoList.length}개)',
                    style: Styles.caption.merge(
                      TextStyle(
                        color: _selectedListType == SelectedListType.UTXO
                            ? MyColors.transparentWhite_70
                            : MyColors.transparentWhite_50,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                }
              ])),
        ),
      ],
    );
  }

  /// 필터 드롭다운 위젯
  Widget _filterDropDownWidget() {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: CustomDropdown(
        buttons: const [
          '큰 금액순',
          '작은 금액순',
          '최신순',
          '오래된 순',
        ],
        dividerColor: Colors.black,
        onTapButton: (index) {
          setState(() {
            _isFilterDropdownVisible = _isScrolledFilterDropdownVisible = false;
          });
          switch (index) {
            case 0: // 큰 금액순
              _applyFilter(UtxoOrderEnum.byAmountDesc);
              break;
            case 1: // 작은 금액순
              _applyFilter(UtxoOrderEnum.byAmountAsc);
              break;
            case 2: // 최신순
              _applyFilter(UtxoOrderEnum.byTimestampDesc);
              break;
            case 3: // 오래된 순
              _applyFilter(UtxoOrderEnum.byTimestampAsc);
              break;
          }
        },
      ),
    );
  }

  Widget _afterScrolledWidget() {
    return Positioned(
      top: _appBarSize.height,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_positionedTopWidgetVisible,
        child: AnimatedOpacity(
          opacity: _positionedTopWidgetVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            key: _positionedTopWidgetKey,
            children: [
              Container(
                color: MyColors.black,
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16,
                  top: 20.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: _walletBaseItem.balance != null
                              ? (_current == Unit.btc
                                  ? satoshiToBitcoinString(
                                      _walletBaseItem.balance!)
                                  : addCommasToIntegerPart(
                                      _walletBaseItem.balance!.toDouble()))
                              : '잔액 조회 불가',
                          style: Styles.h2Number,
                          children: [
                            TextSpan(
                              text: _walletBaseItem.balance != null
                                  ? _current == Unit.btc
                                      ? ' BTC'
                                      : ' sats'
                                  : '잔액 조회 불가',
                              style: Styles.label.merge(
                                TextStyle(
                                  fontFamily: CustomFonts.number.getFontFamily,
                                  color: MyColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        if (!_checkStateAndShowToast()) return;
                        if (!_checkBalanceIsNotNullAndShowToast()) return;
                        MyBottomSheet.showBottomSheet_90(
                            context: context,
                            child: ReceiveAddressScreen(id: widget.id));
                      },
                      borderRadius: BorderRadius.circular(8.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      minSize: 0,
                      color: MyColors.white,
                      child: SizedBox(
                        width: 35,
                        child: Center(
                          child: Text(
                            '받기',
                            style: Styles.caption.merge(
                              const TextStyle(
                                  color: MyColors.black,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    CupertinoButton(
                      onPressed: () {
                        if (_walletBaseItem.balance == null) {
                          CustomToast.showToast(
                              context: context, text: "잔액이 없습니다.");
                          return;
                        }
                        if (!_checkStateAndShowToast()) return;
                        if (!_checkBalanceIsNotNullAndShowToast()) return;
                        Navigator.pushNamed(context, '/send-address',
                            arguments: {'id': widget.id});
                      },
                      borderRadius: BorderRadius.circular(8.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      minSize: 0,
                      color: MyColors.primary,
                      child: SizedBox(
                        width: 35,
                        child: Center(
                          child: Text(
                            '보내기',
                            style: Styles.caption.merge(
                              const TextStyle(
                                  color: MyColors.black,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                children: [
                  Column(
                    children: [
                      Container(
                        width: MediaQuery.sizeOf(context).width,
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, bottom: 9),
                        decoration: const BoxDecoration(
                          color: MyColors.black,
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(255, 255, 255, 0.2),
                              offset: Offset(0, 3),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Visibility(
                          visible: _selectedListType == SelectedListType.UTXO &&
                              _utxoList.isNotEmpty,
                          maintainAnimation: true,
                          maintainState: true,
                          maintainSize: true,
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.only(
                                  top: 10,
                                ),
                                minSize: 0,
                                onPressed: () {
                                  setState(() {
                                    _scrollController
                                        .jumpTo(_scrollController.offset);
                                    if (_isFilterDropdownVisible ||
                                        _isScrolledFilterDropdownVisible) {
                                      _isScrolledFilterDropdownVisible = false;
                                    } else {
                                      _isScrolledFilterDropdownVisible = true;
                                    }
                                  });
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      key: _scrolledFilterDropdownButtonKey,
                                      _selectedFilter.text,
                                      style: Styles.caption2.merge(
                                        const TextStyle(
                                          color: MyColors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 5,
                                    ),
                                    SvgPicture.asset(
                                        'assets/svg/arrow-down.svg'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 16,
                        child: Container(),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MyColors.black,
                            border: Border.all(
                                color: MyColors.transparentWhite_50,
                                width: 0.5),
                            borderRadius: BorderRadius.circular(
                              16,
                            ),
                          ),
                          child: Text(
                            _selectedListType == SelectedListType.Transaction
                                ? '거래 내역'
                                : 'UTXO 목록', // TODO: 선택된 리스트 대입
                            style: Styles.caption2.merge(
                              const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: MyColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faucetTooltipWidget(BuildContext context) {
    return _faucetTooltipVisible
        ? Positioned(
            top: _faucetIconPosition.dy + _faucetIconSize.height - 10,
            right: MediaQuery.of(context).size.width -
                _faucetIconPosition.dx -
                _faucetIconSize.width +
                5,
            child: AnimatedOpacity(
              opacity: _faucetTipVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 1000),
              child: GestureDetector(
                onTap: _removeFaucetTooltip,
                child: ClipPath(
                  clipper: RightTriangleBubbleClipper(),
                  child: Container(
                    padding: const EdgeInsets.only(
                      top: 25,
                      left: 18,
                      right: 18,
                      bottom: 10,
                    ),
                    color: MyColors.skybule,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          faucetTip,
                          style: Styles.caption.merge(TextStyle(
                            height: 1.3,
                            fontFamily: CustomFonts.text.getFontFamily,
                            color: MyColors.darkgrey,
                          )),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        : Container();
  }

  void _removeFaucetTooltip() {
    // if (_overlayEntry != null) {
    //   _faucetTipVisible = false;
    //   _overlayEntry!.remove();
    //   _overlayEntry = null;
    // }
    setState(() {
      _faucetTipVisible = false;
      _faucetTooltipVisible = false;
    });
  }

  void _removeFilterDropdown() {
    setState(() {
      _isFilterDropdownVisible = false;
      _isScrolledFilterDropdownVisible = false;
    });
  }

  bool _checkStateAndShowToast() {
    var appState = Provider.of<AppStateModel>(context, listen: false);

    // 에러체크
    if (appState.isNetworkOn == false) {
      CustomToast.showWarningToast(
          context: context, text: ErrorCodes.networkError.message);
      return false;
    }

    if (appState.walletInitState == WalletInitState.processing) {
      CustomToast.showToast(
          context: context, text: "최신 데이터를 가져오는 중입니다. 잠시만 기다려주세요.");
      return false;
    }

    return true;
  }

  bool _checkBalanceIsNotNullAndShowToast() {
    if (_walletBaseItem.balance == null) {
      CustomToast.showToast(
          context: context, text: "화면을 아래로 당겨 최신 데이터를 가져와 주세요.");
      return false;
    }
    return true;
  }

  /// 거래 내역 리스트
  Widget _transactionListWidget() {
    return SliverSafeArea(
      minimum: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      sliver: _txList.isNotEmpty
          ? SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, index) {
                  return Column(
                    key: index == 0 ? _txSliverListKey : null,
                    children: [
                      TransactionRowItem(
                        tx: _txList[index],
                        currentUnit: _current,
                        id: widget.id,
                      ),
                      gapOfTxRowItems,
                      if (index == _txList.length - 1)
                        const SizedBox(
                          height: 80,
                        ),
                    ],
                  );
                },
                childCount: _txList.length,
              ),
            )
          : const SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(top: 100),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    '거래 내역이 없어요',
                    style: Styles.body1,
                  ),
                ),
              ),
            ),
    );
  }

  /// UTXO 목록
  Widget _utxoListWidget() {
    return SliverSafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 16),
      sliver: _utxoList.isNotEmpty
          ? SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) {
                    // 분리자
                    return const Divider(
                      height: 12,
                      color: Colors.transparent,
                    );
                  }

                  // 실제 아이템
                  final itemIndex = index ~/ 2; // 실제 아이템 인덱스
                  return ShrinkAnimationButton(
                    key: index == 0 ? _utxoSliverListKey : null,
                    defaultColor: Colors.transparent,
                    borderRadius: 20,
                    onPressed: () async {
                      final txHash = _utxoList[itemIndex].txHash;
                      await Navigator.pushNamed(
                        context,
                        '/utxo-detail',
                        arguments: {
                          'utxo': _utxoList[itemIndex],
                          'id': widget.id,
                        },
                      );

                      if (_model.isUpdateSelectedTagList) {
                        _model.setIsUpdateSelectedTagList(false);
                        for (var utxo in _utxoList) {
                          if (utxo.txHash == txHash) {
                            utxo.tags?.clear();
                            utxo.tags?.addAll(_model.selectedTagList);
                            setState(() {});
                            break;
                          }
                        }
                      }
                    },
                    child: UTXOItemCard(
                      utxo: _utxoList[itemIndex],
                    ),
                  );
                },
                childCount: _utxoList.length * 2 - 1, // 항목 개수 지정
              ),
            )
          : SliverFillRemaining(
              fillOverscroll: false,
              hasScrollBody: false,
              child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      _isUtxoListLoadComplete ? 'UTXO가 없어요' : 'UTXO를 확인하는 중이에요',
                      style: Styles.body1,
                      textAlign: TextAlign.center,
                    ),
                  )),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _removeFaucetTooltip();
        _removeFilterDropdown();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: MyColors.black,
            appBar: CustomAppBar.build(
              entireWidgetKey: _appBarKey,
              faucetIconKey: _faucetIconKey,
              backgroundColor: MyColors.black,
              title: TextUtils.ellipsisIfLonger(
                _walletBaseItem.name,
                maxLength: 15,
              ),
              context: context,
              hasRightIcon: true,
              onFaucetIconPressed: () async {
                _removeFaucetTooltip();
                if (!_checkStateAndShowToast()) return;
                if (!_checkBalanceIsNotNullAndShowToast()) return;
                await MyBottomSheet.showBottomSheet_50(
                    context: context,
                    child: FaucetRequestScreen(
                      onRequestSuccess: () {
                        Navigator.pop(context, true); // 성공 시 true 반환
                        // 1초 후에 이 지갑만 sync 요청
                        Future.delayed(const Duration(seconds: 1), () {
                          _model.initWallet(
                              targetId: widget.id, syncOthers: false);
                        });
                      },
                      walletBaseItem: _walletBaseItem,
                    ));
              },
              onTitlePressed: () {
                if (_walletBaseItem.walletType == WalletType.multiSignature) {
                  Navigator.pushNamed(context, '/wallet-multisig',
                      arguments: {'id': widget.id});
                } else {
                  Navigator.pushNamed(context, '/wallet-setting',
                      arguments: {'id': widget.id});
                }
              },
              showFaucetIcon: true,
            ),
            body: CustomScrollView(
                controller: _scrollController,
                semanticChildCount: _txList.isEmpty ? 1 : _txList.length,
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: () async {
                      _isPullToRefeshing = true;
                      try {
                        if (!_checkStateAndShowToast()) {
                          return;
                        }
                        _model.initWallet(targetId: widget.id);
                      } finally {
                        _isPullToRefeshing = false;
                      }
                    },
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      key: _topToggleButtonKey,
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Center(
                        child: SmallActionButton(
                          onPressed: () {
                            _toggleUnit();
                          },
                          height: 32,
                          width: 64,
                          child: Text(
                            _current == Unit.btc ? 'BTC' : 'sats',
                            style: Styles.label.merge(
                              TextStyle(
                                  fontFamily: CustomFonts.number.getFontFamily,
                                  color: MyColors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Selector<UpbitConnectModel, int?>(
                      selector: (context, model) => model.bitcoinPriceKrw,
                      builder: (context, bitcoinPriceKrw, child) {
                        return SliverToBoxAdapter(
                            child: BalanceAndButtons(
                          key: _topSelectorWidgetKey,
                          balance: _walletBaseItem.balance,
                          walletId: widget.id,
                          accountIndex: _selectedAccountIndex,
                          currentUnit: _current,
                          btcPriceInKrw: bitcoinPriceKrw,
                          checkPrerequisites: () {
                            return _checkStateAndShowToast() &&
                                _checkBalanceIsNotNullAndShowToast();
                          },
                        ));
                      }),
                  SliverToBoxAdapter(
                      child: Column(
                    key: _topHeaderWidgetKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 16.0, right: 16.0, bottom: 12.0, top: 30),
                        child: Selector<AppStateModel, WalletInitState>(
                            selector: (_, selectorModel) =>
                                selectorModel.walletInitState,
                            builder: (context, state, child) {
                              return Column(
                                children: [
                                  if (!_isPullToRefeshing &&
                                      state == WalletInitState.processing) ...{
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _listTypeSelectionRow(),
                                          Row(
                                            children: [
                                              const Text(
                                                '업데이트 중',
                                                style: TextStyle(
                                                  fontFamily: 'Pretendard',
                                                  color: MyColors.primary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle: FontStyle.normal,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              LottieBuilder.asset(
                                                'assets/files/status_loading.json',
                                                width: 20,
                                                height: 20,
                                              ),
                                            ],
                                          )
                                        ]),
                                  } else ...{
                                    Column(
                                      children: [
                                        _listTypeSelectionRow(),
                                      ],
                                    ),
                                  },
                                  if (_selectedListType ==
                                          SelectedListType.UTXO &&
                                      _utxoList.isNotEmpty) ...{
                                    const SizedBox(height: 8),
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
                                                _scrollController.jumpTo(
                                                    _scrollController.offset);
                                                if (_isFilterDropdownVisible ||
                                                    _isScrolledFilterDropdownVisible) {
                                                  _isFilterDropdownVisible =
                                                      false;
                                                } else {
                                                  _isFilterDropdownVisible =
                                                      true;
                                                }
                                              },
                                            );
                                          },
                                          minSize: 0,
                                          padding:
                                              const EdgeInsets.only(left: 8),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                key: _filterDropdownButtonKey,
                                                _selectedFilter.text,
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
                                  },
                                ],
                              );
                            }),
                      ),
                    ],
                  )),
                  _selectedListType == SelectedListType.Transaction
                      ? _transactionListWidget()
                      : _utxoListWidget(),
                  if ((_selectedListType == SelectedListType.Transaction &&
                      _txList.isNotEmpty)) ...{
                    SliverToBoxAdapter(
                      child: Container(
                        height: _positionedTopWidgetVisible
                            ? 0
                            : _txSliverListSize.height * _txList.length + 80 >
                                    MediaQuery.sizeOf(context).height -
                                        topPadding
                                ? 0
                                : MediaQuery.sizeOf(context).height -
                                    topPadding -
                                    (_txSliverListSize.height * _txList.length +
                                        80) -
                                    _appBarSize.height -
                                    kToolbarHeight +
                                    10,
                      ),
                    ),
                  },
                  if ((_selectedListType == SelectedListType.UTXO &&
                      _utxoList.isNotEmpty)) ...{
                    SliverToBoxAdapter(
                      child: Container(
                        height: _positionedTopWidgetVisible
                            ? 0
                            : _utxoSliverListSize.height * _utxoList.length +
                                        (12 * (_utxoList.length - 1)) >
                                    MediaQuery.sizeOf(context).height -
                                        topPadding
                                ? 0
                                : MediaQuery.sizeOf(context).height -
                                    topPadding -
                                    ((_utxoSliverListSize.height - 20) *
                                            _utxoList.length +
                                        (12 * (_utxoList.length - 1))) -
                                    _appBarSize.height -
                                    kToolbarHeight +
                                    10,
                      ),
                    ),
                  }
                ]),
          ),
          _afterScrolledWidget(),
          _faucetTooltipWidget(context),
          if (_isFilterDropdownVisible && _utxoList.isNotEmpty) ...{
            Positioned(
              top: _filterDropdownButtonPosition.dy +
                  _filterDropdownButtonSize.height +
                  8 -
                  _scrollController.offset,
              right: 16,
              child: _filterDropDownWidget(),
            ),
          },
          if (_isScrolledFilterDropdownVisible && _utxoList.isNotEmpty) ...{
            Positioned(
              top: _scrolledFilterDropdownButtonPosition.dy +
                  _scrolledFilterDropdownButtonSize.height +
                  8,
              right: 16,
              child: _filterDropDownWidget(),
            ),
          },
        ],
      ),
    );
  }

  getUtxoListWithHoldingAddress(
      List<UTXO> utxoEntities,
      WalletListItemBase walletBaseItem,
      String accountIndexField,
      String changeField,
      WalletType walletType) {
    List<model.UTXO> utxos = [];
    for (var element in utxoEntities) {
      Map<String, int> changeAndAccountIndex = getChangeAndAccountElements(
          element.derivationPath, walletType, accountIndexField, changeField);

      String ownedAddress = walletBaseItem.walletBase.getAddress(
          changeAndAccountIndex[accountIndexField]!,
          isChange: changeAndAccountIndex[changeField]! == 1);

      final txHashIndex = '${element.transactionHash}${element.index}';
      final tags = _model.loadUtxoTagListByTxHashIndex(widget.id, txHashIndex);

      utxos.add(model.UTXO(
        element.timestamp.toString(),
        element.blockHeight.toString(),
        element.amount,
        ownedAddress,
        element.derivationPath,
        element.transactionHash,
        element.index,
        tags: tags,
      ));
    }

    setState(() {
      _utxoList = utxos;
      _isUtxoListLoadComplete = true;
    });
  }
}

Map<String, int> getChangeAndAccountElements(
  String derivationPath,
  WalletType walletType,
  String accountIndexField,
  String changeField,
) {
  var pathElements = derivationPath.split('/');
  Map<String, int> result;

  switch (walletType) {
    // m / purpose' / coin_type' / account' / change / address_index
    case WalletType.singleSignature:
      result = {
        changeField: int.parse(pathElements[4]),
        accountIndexField: int.parse(pathElements[5])
      };
      break;
    // m / purpose' / coin_type' / account' / script_type' / change / address_index
    case WalletType.multiSignature:
      result = {
        changeField: int.parse(pathElements[5]),
        accountIndexField: int.parse(pathElements[6])
      };
      break;
    default:
      throw ArgumentError("wrong walletType: $walletType");
  }

  return result;
}

class BalanceAndButtons extends StatefulWidget {
  final int? balance;
  final int walletId;
  final int accountIndex;
  final Unit currentUnit;
  final int? btcPriceInKrw;
  final bool Function()? checkPrerequisites;

  const BalanceAndButtons({
    super.key,
    required this.balance,
    required this.walletId,
    required this.accountIndex,
    required this.currentUnit,
    required this.btcPriceInKrw,
    this.checkPrerequisites,
  });

  @override
  State<BalanceAndButtons> createState() => _BalanceAndButtonsState();
}

class _BalanceAndButtonsState extends State<BalanceAndButtons> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Text(
              widget.balance != null
                  ? (widget.currentUnit == Unit.btc
                      ? satoshiToBitcoinString(widget.balance!)
                      : addCommasToIntegerPart(widget.balance!.toDouble()))
                  : "잔액 조회 불가",
              style: Styles.h1Number
                  .merge(const TextStyle(color: MyColors.white))),
          if (widget.balance != null && widget.btcPriceInKrw != null)
            Text(
                '₩ ${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(widget.balance!, widget.btcPriceInKrw!).toDouble())}',
                style: Styles.subLabel.merge(TextStyle(
                    fontFamily: CustomFonts.number.getFontFamily,
                    color: MyColors.transparentWhite_70))),
          const SizedBox(height: 24.0),
          Row(
            children: [
              Expanded(
                  child: CupertinoButton(
                      onPressed: () {
                        if (widget.checkPrerequisites != null) {
                          if (!widget.checkPrerequisites!()) return;
                        }
                        // TODO: ReceiveAddressScreen에 widget.walletId 말고 다른 매개변수 고려해보기
                        MyBottomSheet.showBottomSheet_90(
                            context: context,
                            child: ReceiveAddressScreen(id: widget.walletId));
                      },
                      borderRadius: BorderRadius.circular(12.0),
                      padding: EdgeInsets.zero,
                      color: MyColors.white,
                      child: Text('받기',
                          style: Styles.label.merge(const TextStyle(
                              color: MyColors.black,
                              fontWeight: FontWeight.w600))))),
              const SizedBox(width: 12.0),
              Expanded(
                  child: CupertinoButton(
                      onPressed: () {
                        if (widget.balance == null) {
                          CustomToast.showToast(
                              context: context, text: "잔액이 없습니다.");
                          return;
                        }
                        if (widget.checkPrerequisites != null) {
                          if (!widget.checkPrerequisites!()) return;
                        }
                        Navigator.pushNamed(context, '/send-address',
                            arguments: {'id': widget.walletId});
                      },
                      borderRadius: BorderRadius.circular(12.0),
                      padding: EdgeInsets.zero,
                      color: MyColors.primary,
                      child: Text('보내기',
                          style: Styles.label.merge(const TextStyle(
                              color: MyColors.black,
                              fontWeight: FontWeight.w600))))),
            ],
          ),
        ],
      ),
    );
  }
}

class TransactionRowItem extends StatefulWidget {
  final Transfer tx;
  final Unit currentUnit;
  final int id;

  late final TransactionStatus? status;

  TransactionRowItem(
      {super.key,
      required this.tx,
      required this.currentUnit,
      required this.id}) {
    status = TransactionUtil.getStatus(tx);
  }

  @override
  State<TransactionRowItem> createState() => _TransactionRowItemState();
}

class _TransactionRowItemState extends State<TransactionRowItem> {
  Widget _getStatusWidget() {
    TextStyle fontStyle = Styles.body2.merge(
      const TextStyle(
        fontWeight: FontWeight.w500,
        height: 21 / 14,
      ),
    );
    switch (widget.status) {
      case TransactionStatus.received:
        return Row(
          children: [
            SvgPicture.asset(
              'assets/svg/tx-received.svg',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              '받기 완료',
              style: fontStyle,
            )
          ],
        );
      case TransactionStatus.receiving:
        return Row(
          children: [
            SvgPicture.asset(
              'assets/svg/tx-receiving.svg',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              '받는 중',
              style: fontStyle,
            )
          ],
        );
      case TransactionStatus.sent:
        return Row(
          children: [
            SvgPicture.asset(
              'assets/svg/tx-sent.svg',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              '보내기 완료',
              style: fontStyle,
            )
          ],
        );
      case TransactionStatus.sending:
        return Row(
          children: [
            SvgPicture.asset(
              'assets/svg/tx-sending.svg',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              '보내는 중',
              style: fontStyle,
            )
          ],
        );
      case TransactionStatus.self:
        return Row(
          children: [
            SvgPicture.asset(
              'assets/svg/tx-self.svg',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              '받기 완료',
              style: fontStyle,
            )
          ],
        );
      case TransactionStatus.selfsending:
        return Row(
          children: [
            SvgPicture.asset(
              'assets/svg/tx-self-sending.svg',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              '보내는 중',
              style: fontStyle,
            )
          ],
        );
      default:
        throw "[_TransactionRowItem] status: ${widget.status}";
    }
  }

  Widget _getAmountWidget() {
    switch (widget.status) {
      case TransactionStatus.receiving:
      case TransactionStatus.received:
        return Text(
          widget.currentUnit == Unit.btc
              ? '+${satoshiToBitcoinString(widget.tx.amount!)}'
              : '+${addCommasToIntegerPart(widget.tx.amount!.toDouble())}',
          style: Styles.body1Number.merge(
            const TextStyle(color: MyColors.white, height: 24 / 16),
          ),
        );
      case TransactionStatus.self:
      case TransactionStatus.selfsending:
      case TransactionStatus.sent:
      case TransactionStatus.sending:
        return Text(
          widget.currentUnit == Unit.btc
              ? satoshiToBitcoinString(widget.tx.amount!)
              : addCommasToIntegerPart(widget.tx.amount!.toDouble()),
          style: Styles.body1Number.merge(const TextStyle(
              color: MyColors.white, fontWeight: FontWeight.w500)),
        );
      default:
        // 기본 값으로 처리될 수 있도록 한 경우
        return const SizedBox(
          child: Text("상태 없음"),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String>? transactionTimeStamp = widget.tx.timestamp != null
        ? DateTimeUtil.formatTimeStamp(widget.tx.timestamp!.toLocal())
        : null;

    return ShrinkAnimationButton(
        defaultColor: MyColors.transparentWhite_06,
        onPressed: () {
          Navigator.pushNamed(context, '/transaction-detail', arguments: {
            'id': widget.id,
            'txHash': widget.tx.transactionHash
          });
        },
        borderRadius: MyBorder.defaultRadiusValue,
        child: Container(
          height: 84,
          padding: Paddings.widgetContainer,
          decoration: BoxDecoration(
              borderRadius: MyBorder.defaultRadius,
              color: MyColors.transparentWhite_06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    transactionTimeStamp != null ? transactionTimeStamp[0] : '',
                    style: Styles.caption,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Text(
                    '|',
                    style: Styles.caption.merge(
                      const TextStyle(
                        color: MyColors.transparentWhite_40,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Text(
                    transactionTimeStamp != null ? transactionTimeStamp[1] : '',
                    style: Styles.caption,
                  ),
                ],
              ),
              const SizedBox(
                height: 5.0,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [_getStatusWidget(), _getAmountWidget()],
              )
            ],
          ),
        ));
  }
}
