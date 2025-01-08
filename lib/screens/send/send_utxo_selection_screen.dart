import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/currency_code.dart';
import 'package:coconut_wallet/model/app_error.dart';
import 'package:coconut_wallet/model/data/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/data/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/data/wallet_type.dart';
import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/model/fee_info.dart';
import 'package:coconut_wallet/model/send_info.dart';
import 'package:coconut_wallet/model/utxo_tag.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/screens/send/utxo_selection/fee_selection_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/cconut_wallet_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/recommended_fee_util.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/bottom_sheet.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/custom_dropdown.dart';
import 'package:coconut_wallet/widgets/custom_tag_chip.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

enum RecommendedFeeFetchStatus { fetching, succeed, failed }

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
  late WalletBase _walletBase;
  late WalletFeature _walletFeature;
  late WalletType _walletType;
  late UpbitConnectModel _upbitConnectModel;
  late final ScrollController _scrollController;

  late List<UTXO> _confirmedUtxoList;
  late List<UTXO> _selectedUtxoList;
  // 선택된 태그
  String _selectedUtxoTagName = '전체';
  // txHashIndex - 태그 목록
  late final Map<String, List<UtxoTag>> _utxoTagMap = {};

  final GlobalKey _filterDropdownButtonKey = GlobalKey();
  final GlobalKey _scrolledFilterDropdownButtonKey = GlobalKey();
  final bool _positionedTopWidgetVisible = false; // 스크롤시 상단에 붙어있는 위젯
  bool _isFilterDropdownVisible = false; // 필터 드롭다운(확장형)
  bool _isScrolledFilterDropdownVisible = false; // 필터 드롭다운(축소형)
  late Offset _filterDropdownButtonPosition;
  late Offset _scrolledFilterDropdownButtonPosition;

  final GlobalKey _headerTopContainerKey = GlobalKey();
  Size _headerTopContainerSize = const Size(0, 0);
  bool _afterScrolledHeaderContainerVisible = false;

  late double _totalUtxoAmountWidgetPaddingLeft;
  late double _totalUtxoAmountWidgetPaddingRight;
  late double _totalUtxoAmountWidgetPaddingTop;
  late double _totalUtxoAmountWidgetPaddingBottom;

  late int _confirmedBalance;
  late bool _isMaxMode;
  late int? _requiredSignature;
  late int? _totalSigner;

  RecommendedFeeFetchStatus _recommendedFeeFetchStatus =
      RecommendedFeeFetchStatus.fetching;
  TransactionFeeLevel? _selectedLevel = TransactionFeeLevel.halfhour;
  RecommendedFee? recommendedFees;
  bool get _customFeeSelected => _selectedLevel == null;

  FeeInfo? _customFeeInfo;
  int? _estimatedFee = 0;
  List<FeeInfoWithLevel> feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];

  FeeInfoWithLevel? get _selectedFeeInfoWithLevel => _selectedLevel == null
      ? null
      : feeInfos.firstWhere((feeInfo) => feeInfo.level == _selectedLevel);

  int? get _satsPerVb =>
      _selectedFeeInfoWithLevel?.satsPerVb ?? _customFeeInfo?.satsPerVb;

  int? get _change {
    if (_recommendedFeeFetchStatus == RecommendedFeeFetchStatus.fetching) {
      return null;
    }

    if (_recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed &&
        _customFeeInfo == null) {
      return null;
    }

    var change = _transaction.getChangeAmount(_walletBase.addressBook);
    if (change != 0) return change;
    if (_estimatedFee == null) return null;
    // utxo가 모자랄 때도 change = 0으로 반환되기 때문에 진짜 잔돈이 0인지 아닌지 확인이 필요
    return _isSelectedUtxoEnough() ? change : null;
  }

  int get sendAmount {
    return _isMaxMode
        ? UnitUtil.bitcoinToSatoshi(
              widget.sendInfo.amount,
            ) -
            (_estimatedFee ?? 0)
        : UnitUtil.bitcoinToSatoshi(
            widget.sendInfo.amount,
          );
  }

  UtxoOrderEnum _selectedFilter = UtxoOrderEnum.byAmountDesc;

  late Transaction _transaction;

  _addDisplayUtxoList() {
    _utxoTagMap.clear();
    for (var element in _confirmedUtxoList) {
      final tags =
          _model.loadUtxoTagListByTxHashIndex(widget.id, element.utxoId);
      _utxoTagMap[element.utxoId] = tags;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _model = Provider.of<AppStateModel>(context, listen: false);

    _upbitConnectModel = Provider.of<UpbitConnectModel>(context, listen: false);

    _scrollController = ScrollController();

    _walletBaseItem = _model.getWalletById(widget.id);
    _walletFeature = getWalletFeatureByWalletType(_walletBaseItem);
    _walletType = _walletBaseItem.walletType;

    _requiredSignature = _walletBaseItem.walletType == WalletType.multiSignature
        ? (_walletBaseItem as MultisigWalletListItem).requiredSignatureCount
        : null;
    _totalSigner = _walletBaseItem.walletType == WalletType.multiSignature
        ? (_walletBaseItem as MultisigWalletListItem).signers.length
        : null;

    if (_model.walletInitState == WalletInitState.finished) {
      _confirmedUtxoList = _getAllConfirmedUtxoList(_walletFeature);
      _selectedUtxoList = [];
      UTXO.sortUTXO(_confirmedUtxoList, _selectedFilter);
      _addDisplayUtxoList();
    } else {
      _confirmedUtxoList = _selectedUtxoList = [];
    }

    if (_walletType == WalletType.multiSignature) {
      final multisigListItem = _walletBaseItem as MultisigWalletListItem;
      _walletBase = multisigListItem.walletBase;

      final multisigWallet = _walletBase as MultisignatureWallet;
      _confirmedBalance = multisigWallet.getBalance();
    } else {
      final singlesigListItem = _walletBaseItem as SinglesigWalletListItem;
      _walletBase = singlesigListItem.walletBase;

      final singlesigWallet = _walletBase as SingleSignatureWallet;
      _confirmedBalance = singlesigWallet.getBalance();
    }

    _isMaxMode =
        _confirmedBalance == UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount);

    _transaction = createTransaction(_isMaxMode, 1, _walletBase);
    syncSelectedUtxosWithTransaction();

    _totalUtxoAmountWidgetPaddingLeft = _totalUtxoAmountWidgetPaddingRight =
        _totalUtxoAmountWidgetPaddingTop = 24;
    _totalUtxoAmountWidgetPaddingBottom = 20;

    _scrollController.addListener(() {
      double threshold = _headerTopContainerSize.height + 20;
      double offset = _scrollController.offset;
      if (_isFilterDropdownVisible || _isScrolledFilterDropdownVisible) {
        _removeFilterDropdown();
      }
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
      // if (_scrollController.position.extentAfter < 100) {
      //   /// 페이징
      //   _loadMoreData();
      // }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _model.initUtxoTagScreenTagData(widget.id);

      RenderBox filterDropdownButtonRenderBox =
          _filterDropdownButtonKey.currentContext?.findRenderObject()
              as RenderBox;
      RenderBox scrolledFilterDropdownButtonRenderBox =
          _scrolledFilterDropdownButtonKey.currentContext?.findRenderObject()
              as RenderBox;
      _filterDropdownButtonPosition =
          filterDropdownButtonRenderBox.localToGlobal(Offset.zero);
      _scrolledFilterDropdownButtonPosition =
          scrolledFilterDropdownButtonRenderBox.localToGlobal(Offset.zero);

      RenderBox headerTopContainerRenderBox =
          _headerTopContainerKey.currentContext?.findRenderObject()
              as RenderBox;
      _headerTopContainerSize = headerTopContainerRenderBox.size;

      await _setRecommendedFees();
      if (_recommendedFeeFetchStatus == RecommendedFeeFetchStatus.succeed) {
        _updateFeeRate(_satsPerVb!);
      }
    });
  }

  Transaction createTransaction(
      bool isMaxMode, int feeRate, WalletBase walletBase) {
    if (isMaxMode) {
      return Transaction.forSweep(widget.sendInfo.address, feeRate, walletBase);
    }

    return Transaction.forPayment(widget.sendInfo.address,
        UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount), feeRate, walletBase);
  }

  int _estimateFee(int feeRate) {
    return _transaction.estimateFee(feeRate, _walletBase.addressType,
        requiredSignature: _requiredSignature, totalSinger: _totalSigner);
  }

  void _updateFeeRate(int satsPerVb) {
    _transaction.updateFeeRate(satsPerVb, _walletBase,
        requiredSignature: _requiredSignature, totalSinger: _totalSigner);
  }

  void syncSelectedUtxosWithTransaction() {
    var inputs = _transaction.inputs;
    List<UTXO> result = [];
    for (int i = 0; i < inputs.length; i++) {
      result.add(_confirmedUtxoList.firstWhere((utxo) =>
          utxo.transactionHash == inputs[i].transactionHash &&
          utxo.index == inputs[i].index));
    }
    setState(() {
      _selectedUtxoList = result;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initFeeInfo(FeeInfo feeInfo, int estimatedFee) {
    feeInfo.estimatedFee = estimatedFee;
    feeInfo.fiatValue = _upbitConnectModel.bitcoinPriceKrw != null
        ? FiatUtil.calculateFiatAmount(
            estimatedFee, _upbitConnectModel.bitcoinPriceKrw!)
        : null;

    if (feeInfo is FeeInfoWithLevel && feeInfo.level == _selectedLevel) {
      _estimatedFee = estimatedFee;
      return;
    }
  }

  Future<void> _setRecommendedFees() async {
    var recommendedFees = await fetchRecommendedFees(_model);
    if (recommendedFees == null) {
      setState(() {
        _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.failed;
      });
      return;
    }

    feeInfos[0].satsPerVb = recommendedFees.fastestFee;
    feeInfos[1].satsPerVb = recommendedFees.halfHourFee;
    feeInfos[2].satsPerVb = recommendedFees.hourFee;

    for (var feeInfo in feeInfos) {
      try {
        int estimatedFee = _estimateFee(feeInfo.satsPerVb!);
        setState(() {
          _initFeeInfo(feeInfo, estimatedFee);
        });
      } catch (error) {
        setState(() {
          _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.failed;
        });
        // 수수료 조회 실패 알림
        WidgetsBinding.instance.addPostFrameCallback((duration) {
          CustomToast.showWarningToast(
              context: context,
              text: ErrorCodes.withMessage(
                      ErrorCodes.feeEstimationError, error.toString())
                  .message);
        });
        return;
      }
    }
    setState(() {
      _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.succeed;
    });
  }

  /// UTXO 선택 상태를 토글하는 함수
  void _toggleSelection(UTXO utxo) {
    _removeFilterDropdown();
    setState(() {
      if (_selectedUtxoList.contains(utxo)) {
        if (!_isMaxMode) {
          _transaction.removeInputWithUtxo(utxo, _satsPerVb!, _walletBase,
              requiredSignature: _requiredSignature, totalSinger: _totalSigner);
        }

        // 모두 선택 시 List.from 으로 전체 리스트, 필터 리스트 구분 될 때
        // 라이브러리 UTXO에 copyWith 구현 필요함
        final keyToRemove = '${utxo.transactionHash}_${utxo.index}';
        _selectedUtxoList = _selectedUtxoList
            .fold<Map<String, UTXO>>({}, (map, utxo) {
              final key = '${utxo.transactionHash}_${utxo.index}';
              if (key != keyToRemove) {
                // 제거할 키가 아니면 추가
                map[key] = utxo;
              }
              return map;
            })
            .values
            .toList();

        if (_isSelectedUtxoEnough()) {
          _estimatedFee = _estimateFee(_satsPerVb!);
        }
      } else {
        if (!_isMaxMode) {
          _transaction.addInputWithUtxo(utxo, _satsPerVb!, _walletBase,
              requiredSignature: _requiredSignature, totalSinger: _totalSigner);
          _estimatedFee = _estimateFee(_satsPerVb!);
        }
        _selectedUtxoList.add(utxo);
      }
    });
  }

  void selectAll() {
    _removeFilterDropdown();
    setState(() {
      if (_selectedUtxoTagName != '전체') {
        final filteredList = _confirmedUtxoList.where((utxo) {
          return _utxoTagMap[utxo.utxoId]
                  ?.any((e) => e.name == _selectedUtxoTagName) ??
              false;
        }).toList();
        _selectedUtxoList = List.from(filteredList);
      } else {
        _selectedUtxoList = List.from(_confirmedUtxoList);
      }
    });

    if (!_isMaxMode) {
      _transaction = Transaction.fromUtxoList(
          _selectedUtxoList,
          widget.sendInfo.address,
          UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount),
          _satsPerVb!,
          _walletBase);
      _estimatedFee = _estimateFee(_satsPerVb!);
    }
  }

  void deselectAll() {
    _removeFilterDropdown();
    setState(() {
      _selectedUtxoList = [];
    });
    if (!_isMaxMode) {
      _transaction = Transaction.fromUtxoList([],
          widget.sendInfo.address,
          UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount),
          _satsPerVb!,
          _walletBase);
    }
  }

  bool _isSelectedUtxoEnough() {
    if (_selectedUtxoList.isEmpty) return false;

    if (_isMaxMode) {
      return _calculateTotalAmountOfUtxoList(_selectedUtxoList) ==
          _calculateTotalAmountOfUtxoList(_confirmedUtxoList);
    }

    if (_estimatedFee == null) {
      throw StateError("EstimatedFee has not been calculated yet");
    }

    return _calculateTotalAmountOfUtxoList(_selectedUtxoList) >=
        UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount) +
            (_estimatedFee ?? 0);
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
        UTXO.sortUTXO(_confirmedUtxoList, orderEnum);
        _addDisplayUtxoList();
      });
    }
  }

  List<UTXO> _getAllConfirmedUtxoList(WalletFeature wallet) {
    return wallet.walletStatus!.utxoList
        .where((utxo) => utxo.blockHeight != 0)
        .toList();
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
          '큰 금액순',
          '작은 금액순',
          '최신순',
          '오래된 순',
        ],
        dividerColor: Colors.black,
        onTapButton: (index) {
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
          setState(() {
            _isFilterDropdownVisible = _isScrolledFilterDropdownVisible = false;
          });
        },
      ),
    );
  }

  Widget _totalUtxoAmountWidget(Widget textKeyWidget,
      {bool isAfterScrolled = false}) {
    return Column(
      children: [
        Container(
          width: MediaQuery.sizeOf(context).width,
          decoration: BoxDecoration(
            color: _recommendedFeeFetchStatus ==
                        RecommendedFeeFetchStatus.succeed &&
                    _estimatedFee != null &&
                    _selectedUtxoList.isNotEmpty
                ? _isSelectedUtxoEnough()
                    ? MyColors.transparentWhite_10
                    : MyColors.transparentRed
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
                      color: _selectedUtxoList.isEmpty
                          ? MyColors.white
                          : _recommendedFeeFetchStatus ==
                                      RecommendedFeeFetchStatus.succeed &&
                                  _estimatedFee != null
                              ? _isSelectedUtxoEnough()
                                  ? MyColors.white
                                  : MyColors.warningRed
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
                          color: _recommendedFeeFetchStatus ==
                                      RecommendedFeeFetchStatus.succeed &&
                                  _estimatedFee != null
                              ? _isSelectedUtxoEnough()
                                  ? MyColors.transparentWhite_70
                                  : MyColors.transparentWarningRed
                              : MyColors.transparentWhite_70),
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
                            color: _recommendedFeeFetchStatus ==
                                        RecommendedFeeFetchStatus.succeed &&
                                    _estimatedFee != null &&
                                    _selectedUtxoList.isNotEmpty
                                ? _isSelectedUtxoEnough()
                                    ? MyColors.white
                                    : MyColors.warningRed
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
                  visible: _recommendedFeeFetchStatus ==
                          RecommendedFeeFetchStatus.failed ||
                      (_selectedUtxoList.isEmpty ||
                          _getSelectedUtxoTotalSatoshi() <
                              UnitUtil.bitcoinToSatoshi(
                                  widget.sendInfo.amount)),
                  maintainSize: true,
                  maintainState: true,
                  maintainAnimation: true,
                  child: _recommendedFeeFetchStatus ==
                              RecommendedFeeFetchStatus.failed &&
                          !_customFeeSelected
                      ? Text(
                          '추천 수수료를 조회하지 못했어요.\n\'변경\'버튼을 눌러서 수수료를 직접 입력해 주세요.',
                          style: Styles.warning.merge(
                            const TextStyle(
                              height: 16 / 12,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        )
                      : _selectedUtxoList.isEmpty
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
                              _estimatedFee != null && _isSelectedUtxoEnough()
                                  ? ''
                                  : 'UTXO 합계가 모자라요',
                              style: Styles.warning.merge(
                                const TextStyle(
                                  height: 16 / 12,
                                ),
                              ),
                            ),
                )
              : Container(),
        ),
        Visibility(
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          maintainSemantics: false,
          maintainInteractivity: false,
          visible: !_positionedTopWidgetVisible,
          child: Row(children: [
            CupertinoButton(
              onPressed: () {
                setState(
                  () {
                    if (isAfterScrolled
                        ? _isScrolledFilterDropdownVisible
                        : _isFilterDropdownVisible) {
                      _removeFilterDropdown();
                    } else {
                      _scrollController.jumpTo(_scrollController.offset);

                      if (isAfterScrolled) {
                        _isScrolledFilterDropdownVisible = true;
                      } else {
                        _isFilterDropdownVisible = true;
                      }
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
                    text: '모두 해제',
                    onTap: () {
                      _removeFilterDropdown();
                      deselectAll();
                    },
                  ),
                  SvgPicture.asset('assets/svg/row-divider.svg'),
                  CustomUnderlinedButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    text: '모두 선택',
                    onTap: () async {
                      _removeFilterDropdown();
                      selectAll();
                    },
                  )
                ],
              ),
            )
          ]),
        ),
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

  int _calculateTotalAmountOfUtxoList(List<UTXO> utxos) {
    return utxos.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
  }

  String _getCurrentFilter() {
    if (_selectedFilter == UtxoOrderEnum.byTimestampDesc) {
      return '최신순';
    } else if (_selectedFilter == UtxoOrderEnum.byTimestampAsc) {
      return '오래된 순';
    } else if (_selectedFilter == UtxoOrderEnum.byAmountDesc) {
      return '큰 금액순';
    } else {
      return '작은 금액순';
    }
  }

  void _onFeeRateChanged(Map<String, dynamic> feeSelectionResult) {
    setState(() {
      _estimatedFee =
          (feeSelectionResult[FeeSelectionScreen.feeInfoField] as FeeInfo)
              .estimatedFee;
      _selectedLevel =
          feeSelectionResult[FeeSelectionScreen.selectedOptionField];
    });
    _customFeeInfo =
        feeSelectionResult[FeeSelectionScreen.selectedOptionField] == null
            ? (feeSelectionResult[FeeSelectionScreen.feeInfoField] as FeeInfo)
            : null;

    var satsPerVb = _customFeeInfo?.satsPerVb! ??
        feeInfos
            .firstWhere((feeInfo) => feeInfo.level == _selectedLevel)
            .satsPerVb!;
    _updateFeeRate(satsPerVb);
  }

  goNext() {
    _removeFilterDropdown();
    if (_model.isNetworkOn != true) {
      CustomToast.showWarningToast(
          context: context, text: ErrorCodes.networkError.message);
      return;
    }

    List<String> usedUtxoIds = _selectedUtxoList.map((e) => e.utxoId).toList();

    bool isIncludeTag = usedUtxoIds
        .any((txHashIndex) => _utxoTagMap[txHashIndex]?.isNotEmpty == true);

    if (isIncludeTag) {
      CustomDialogs.showCustomAlertDialog(
        context,
        title: '태그 적용',
        message: '기존 UTXO의 태그를 새 UTXO에도 적용하시겠어요?',
        onConfirm: () {
          Navigator.of(context).pop();
          _model.recordUsedUtxoIdListWhenSend(usedUtxoIds);
          _model.allowTagToMove();
          _moveToSendConfirm();
        },
        onCancel: () {
          Navigator.of(context).pop();
          _model.recordUsedUtxoIdListWhenSend(usedUtxoIds);
          _moveToSendConfirm();
        },
        confirmButtonText: '적용하기',
        confirmButtonColor: MyColors.primary,
        cancelButtonText: '아니오',
      );
    } else {
      _moveToSendConfirm();
    }
  }

  _moveToSendConfirm() {
    Navigator.pushNamed(context, '/send-confirm', arguments: {
      'id': widget.id,
      'fullSendInfo': FullSendInfo(
          address: widget.sendInfo.address,
          amount: UnitUtil.satoshiToBitcoin(sendAmount),
          satsPerVb: _satsPerVb!,
          estimatedFee: _estimatedFee!,
          isMaxMode: _isMaxMode,
          transaction: _transaction)
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _removeFilterDropdown();
      },
      child: Scaffold(
        appBar: CustomAppBar.buildWithNext(
            backgroundColor: MyColors.black,
            title: 'UTXO 고르기',
            context: context,
            nextButtonTitle: '완료',
            isActive: (_model.isNetworkOn ?? false) &&
                        (_recommendedFeeFetchStatus ==
                                RecommendedFeeFetchStatus.succeed &&
                            _estimatedFee != null) ||
                    (_recommendedFeeFetchStatus ==
                            RecommendedFeeFetchStatus.failed &&
                        _estimatedFee != null &&
                        _customFeeSelected)
                ? _change != null
                : false,
            onNextPressed: goNext),
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
                                  const Spacer(),
                                  Visibility(
                                    visible: _isMaxMode,
                                    child: Container(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      margin: const EdgeInsets.only(
                                          right: 4, bottom: 16),
                                      height: 24,
                                      width: 34,
                                      decoration: BoxDecoration(
                                        color: MyColors.defaultBackground,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '최대',
                                          style: Styles.caption2.copyWith(
                                            color: MyColors.white,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${satoshiToBitcoinString(sendAmount).normalizeToFullCharacters()} BTC',
                                        style: Styles.body2Number,
                                      ),
                                      Selector<UpbitConnectModel, int?>(
                                        selector: (context, model) =>
                                            model.bitcoinPriceKrw,
                                        builder:
                                            (context, bitcoinPriceKrw, child) {
                                          return Text(
                                            bitcoinPriceKrw != null
                                                ? '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount), bitcoinPriceKrw).toDouble())} ${CurrencyCode.KRW.code}'
                                                : '',
                                            style: Styles.balance2,
                                          );
                                        },
                                      )
                                    ],
                                  ),
                                ],
                              ),
                              _divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '수수료',
                                    style: _recommendedFeeFetchStatus ==
                                                RecommendedFeeFetchStatus
                                                    .failed &&
                                            !_customFeeSelected
                                        ? Styles.body2Bold.merge(
                                            const TextStyle(
                                              color:
                                                  MyColors.transparentWhite_40,
                                            ),
                                          )
                                        : Styles.body2Bold,
                                  ),
                                  CustomUnderlinedButton(
                                      text: '변경',
                                      isEnable: _recommendedFeeFetchStatus !=
                                          RecommendedFeeFetchStatus.fetching,
                                      onTap: () async {
                                        Result<int, CoconutError>?
                                            minimumFeeRate = await _model
                                                .getMinimumNetworkFeeRate();
                                        Map<String, dynamic>?
                                            feeSelectionResult =
                                            await MyBottomSheet
                                                .showBottomSheet_90(
                                          context: context,
                                          child: FeeSelectionScreen(
                                              feeInfos: feeInfos,
                                              selectedFeeLevel: _selectedLevel,
                                              networkMinimumFeeRate:
                                                  minimumFeeRate?.value,
                                              customFeeInfo: _customFeeInfo,
                                              isRecommendedFeeFetchSuccess:
                                                  _recommendedFeeFetchStatus ==
                                                      RecommendedFeeFetchStatus
                                                          .succeed,
                                              estimateFee: _estimateFee),
                                        );
                                        if (feeSelectionResult != null) {
                                          _onFeeRateChanged(feeSelectionResult);
                                        }
                                      }),
                                  Expanded(
                                      child: _recommendedFeeFetchStatus ==
                                                  RecommendedFeeFetchStatus
                                                      .failed &&
                                              !_customFeeSelected
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '- ',
                                                  style: Styles.body2Bold.merge(
                                                      const TextStyle(
                                                          color: MyColors
                                                              .transparentWhite_40)),
                                                ),
                                                Text(
                                                  'BTC',
                                                  style:
                                                      Styles.body2Number.merge(
                                                    const TextStyle(
                                                      color: MyColors
                                                          .transparentWhite_40,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : _recommendedFeeFetchStatus ==
                                                      RecommendedFeeFetchStatus
                                                          .succeed ||
                                                  _customFeeSelected
                                              ? Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '${satoshiToBitcoinString(_estimatedFee ?? 0).toString()} BTC',
                                                      style: Styles.body2Number,
                                                    ),
                                                    if (_satsPerVb != null) ...{
                                                      Text(
                                                        '${_selectedLevel?.expectedTime ?? ''} ($_satsPerVb sats/vb)',
                                                        style: Styles.caption,
                                                      ),
                                                    },
                                                  ],
                                                )
                                              : const Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    SizedBox(
                                                      width: 15,
                                                      height: 15,
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: MyColors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  ],
                                                )),
                                ],
                              ),
                              _divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '잔돈',
                                    style: _change != null
                                        ? Styles.body2Bold
                                        : Styles.body2Bold.merge(
                                            const TextStyle(
                                              color:
                                                  MyColors.transparentWhite_40,
                                            ),
                                          ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _change != null
                                              ? '${satoshiToBitcoinString(_change!)} BTC'
                                              : '- BTC',
                                          style: _change != null
                                              ? Styles.body2Number
                                              : Styles.body2Number
                                                  .merge(const TextStyle(
                                                  color: MyColors
                                                      .transparentWhite_40,
                                                )),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _totalUtxoAmountWidget(
                          Text(
                            key: _filterDropdownButtonKey,
                            _getCurrentFilter(),
                            style: Styles.caption2.merge(
                              const TextStyle(
                                color: MyColors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          isAfterScrolled: false,
                        ),
                      ],
                    ),
                  ),
                  Visibility(
                    visible: _model.utxoTagList.isNotEmpty,
                    child: Container(
                      margin: const EdgeInsets.only(left: 16, bottom: 12),
                      child: CustomTagHorizontalSelector(
                        tags: _model.utxoTagList.map((e) => e.name).toList(),
                        onSelectedTag: (tagName) {
                          _selectedUtxoTagName = tagName;
                          deselectAll();
                        },
                      ),
                    ),
                  ),
                  ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(
                          top: 0, bottom: 30, left: 16, right: 16),
                      itemCount: _confirmedUtxoList.length + 1,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 0),
                      itemBuilder: (context, index) {
                        if (index < _confirmedUtxoList.length) {
                          final utxo = _confirmedUtxoList[index];
                          final isContainedTagName = _utxoTagMap[utxo.utxoId]
                                  ?.any(
                                      (e) => e.name == _selectedUtxoTagName) ??
                              false;

                          if (_selectedUtxoTagName != '전체' &&
                              !isContainedTagName) {
                            return const SizedBox();
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: UtxoSelectableCard(
                              key: ValueKey(utxo.transactionHash),
                              utxo: utxo,
                              isSelected: _selectedUtxoList
                                  .contains(_confirmedUtxoList[index]),
                              utxoTags: _utxoTagMap[utxo.utxoId],
                              onSelected: _toggleSelection,
                            ),
                          );
                        } else {
                          return const SizedBox();
                        }
                      }),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_afterScrolledHeaderContainerVisible,
                child: Opacity(
                  opacity: _afterScrolledHeaderContainerVisible ? 1 : 0,
                  child: Container(
                    color: MyColors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child: _totalUtxoAmountWidget(
                      Text(
                        key: _scrolledFilterDropdownButtonKey,
                        _getCurrentFilter(),
                        style: Styles.caption2.merge(
                          const TextStyle(
                            color: MyColors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      isAfterScrolled: true,
                    ),
                  ),
                ),
              ),
            ),
            if (_isFilterDropdownVisible && _confirmedUtxoList.isNotEmpty) ...{
              Positioned(
                top: _filterDropdownButtonPosition.dy -
                    _scrollController.offset -
                    MediaQuery.of(context).padding.top -
                    20,
                left: 16,
                child: _filterDropDownWidget(),
              ),
            },
            if (_isScrolledFilterDropdownVisible &&
                _confirmedUtxoList.isNotEmpty) ...{
              Positioned(
                top: _scrolledFilterDropdownButtonPosition.dy -
                    MediaQuery.of(context).padding.top -
                    65,
                left: 16,
                child: _filterDropDownWidget(),
              ),
            }
          ],
        ),
      ),
    );
  }
}

class UtxoSelectableCard extends StatefulWidget {
  final UTXO utxo;
  final bool isSelected;
  final List<UtxoTag>? utxoTags;
  final Function(UTXO) onSelected;

  const UtxoSelectableCard({
    super.key,
    required this.utxo,
    required this.isSelected,
    required this.onSelected,
    this.utxoTags,
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
    dateString = DateTimeUtil.formatDatetime(widget.utxo.timestamp.toString())
        .split('|');
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
                ),
                Visibility(
                  visible: widget.utxoTags?.isNotEmpty == true,
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: List.generate(
                        widget.utxoTags?.length ?? 0,
                        (index) => IntrinsicWidth(
                          child: CustomTagChip(
                            tag: widget.utxoTags?[index].name ?? '',
                            colorIndex: widget.utxoTags?[index].colorIndex ?? 0,
                            type: CustomTagChipType.fix,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SvgPicture.asset(
              'assets/svg/circle-check.svg',
              colorFilter: ColorFilter.mode(
                  widget.isSelected
                      ? MyColors.primary
                      : MyColors.transparentWhite_40,
                  BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }
}
