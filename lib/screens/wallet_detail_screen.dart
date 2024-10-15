import 'dart:async';
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:coconut_wallet/model/app_error.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/model/wallet_list_item.dart';
import 'package:coconut_wallet/screens/faucet_request_screen.dart';
import 'package:coconut_wallet/screens/receive_address_screen.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/serialization_extensions.dart';
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

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  static const SizedBox gapOfTxRowItems = SizedBox(
    height: 8,
  );
  final GlobalKey _faucetIconKey = GlobalKey();
  int _selectedAccountIndex = 0;
  Unit _current = Unit.btc;
  List<Transfer> _txList = [];
  bool _isPullToRefeshing = false;
  late WalletListItem _walletListItem;
  String faucetTip = '테스트용 비트코인으로 마음껏 테스트 해보세요';
  late RenderBox _faucetRenderBox;
  late Size _faucetIconSize;
  late Offset _faucetIconPosition;
  bool _faucetTipVisible = false;
  bool _faucetTooltipVisible = false;

  late AppStateModel _model;
  late WalletInitState _prevWalletInitState;
  late int? _prevTxCount;
  late bool _prevIsLatestTxBlockHeightZero;

  final SharedPrefs _sharedPrefs = SharedPrefs();

  @override
  void initState() {
    super.initState();
    _model = Provider.of<AppStateModel>(context, listen: false);
    _prevWalletInitState = _model.walletInitState;
    _walletListItem = _model.getWalletById(widget.id);
    _prevTxCount = _walletListItem.txCount;
    _prevIsLatestTxBlockHeightZero = _walletListItem.isLatestTxBlockHeightZero;

    List<Transfer>? newTxList = loadTxListFromSharedPref();
    if (newTxList != null) {
      _txList = newTxList;
    }

    _model.addListener(_stateListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      if (_walletListItem.balance == 0 && faucetHistory.count < 3) {
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
    _model.removeListener(_stateListener);
    super.dispose();
  }

  void _stateListener() {
    // _prevWalletInitState != WalletInitState.finished 조건 걸어주지 않으면 삭제 시 getWalletById 과정에서 에러 발생
    if (_prevWalletInitState != WalletInitState.finished &&
        _model.walletInitState == WalletInitState.finished) {
      _walletListItem = _model.getWalletById(widget.id);

      Logger.log(
          '>>>>>> prevTxCount: $_prevTxCount, wallet.txCount: ${_walletListItem.txCount}');
      Logger.log(
          '>>>>>> prevIsZero: $_prevIsLatestTxBlockHeightZero, wallet.isZero: ${_walletListItem.isLatestTxBlockHeightZero}');

      /// _walletListItem의 txCount, isLatestTxBlockHeightZero가 변경되었을 때만 트랜잭션 목록 업데이트
      if (_prevTxCount != _walletListItem.txCount ||
          _prevIsLatestTxBlockHeightZero !=
              _walletListItem.isLatestTxBlockHeightZero) {
        List<Transfer>? newTxList = loadTxListFromSharedPref();
        if (newTxList != null) {
          _txList = newTxList;
          setState(() {});
        }
      }
      _prevTxCount = _walletListItem.txCount;
      _prevIsLatestTxBlockHeightZero =
          _walletListItem.isLatestTxBlockHeightZero;
    }
    _prevWalletInitState = _model.walletInitState;
  }

  List<Transfer>? loadTxListFromSharedPref() {
    final String? txListString = _sharedPrefs.getTxList(widget.id);
    if (txListString == null || txListString.isEmpty) {
      return null;
    }

    List<dynamic> jsonList = jsonDecode(txListString);
    return TransferListDeserialization.fromJsonList(jsonList);
  }

  void _toggleUnit() {
    setState(() {
      _current = _current == Unit.btc ? Unit.sats : Unit.btc;
    });
  }

  void changeSelectedAccount(int index) {
    setState(() => _selectedAccountIndex = index);
  }

  Widget _faucetTooltipWidget(BuildContext context) {
    return _faucetTooltipVisible
        ? Positioned(
            top: _faucetIconPosition.dy + _faucetIconSize.height - 10,
            right: MediaQuery.of(context).size.width -
                _faucetIconPosition.dx -
                _faucetIconSize.width -
                15,
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
    if (_walletListItem.balance == null) {
      CustomToast.showToast(
          context: context, text: "화면을 아래로 당겨 최신 데이터를 가져와 주세요.");
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _removeFaucetTooltip();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: MyColors.black,
            appBar: CustomAppBar.build(
              faucetIconKey: _faucetIconKey,
              title: _walletListItem.name,
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
                      walletListItem: _walletListItem,
                    ));
              },
              onRightIconPressed: () {
                Navigator.pushNamed(context, '/wallet-setting',
                    arguments: {'id': widget.id});
              },
              showFaucetIcon: true,
            ),
            body: CustomScrollView(
                //controller: _scrollController,
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
                  // Unit 전환 버튼
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Center(
                          child: SmallActionButton(
                              onPressed: _toggleUnit,
                              height: 32,
                              width: 64,
                              child: Text(_current == Unit.btc ? 'BTC' : 'sats',
                                  style: Styles.label.merge(TextStyle(
                                      fontFamily:
                                          CustomFonts.number.getFontFamily,
                                      color: MyColors.white))))),
                    ),
                  ),
                  Selector<UpbitConnectModel, int?>(
                      selector: (context, model) => model.bitcoinPriceKrw,
                      builder: (context, bitcoinPriceKrw, child) {
                        return SliverToBoxAdapter(
                            child: BalanceAndButtons(
                          balance: _walletListItem.balance,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(
                              left: 16.0, right: 16.0, bottom: 12.0, top: 30),
                          child: Selector<AppStateModel, WalletInitState>(
                              selector: (_, selectorModel) =>
                                  selectorModel.walletInitState,
                              builder: (context, state, child) {
                                if (!_isPullToRefeshing &&
                                    state == WalletInitState.processing) {
                                  return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('거래 내역', style: Styles.h3),
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
                                      ]);
                                } else {
                                  return const Text('거래 내역', style: Styles.h3);
                                }
                              })),
                    ],
                  )),
                  SliverSafeArea(
                      minimum: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 10),
                      sliver: _txList.isNotEmpty
                          ? SliverList(
                              delegate:
                                  SliverChildBuilderDelegate((ctx, index) {
                              return Column(children: [
                                TransactionRowItem(
                                    tx: _txList[index],
                                    currentUnit: _current,
                                    id: widget.id),
                                gapOfTxRowItems,
                                if (index == _txList.length - 1)
                                  const SizedBox(
                                    height: 80,
                                  )
                              ]);
                            }, childCount: _txList.length))
                          : const SliverFillRemaining(
                              fillOverscroll: false,
                              hasScrollBody: false,
                              child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child:
                                        Text('거래 내역이 없어요', style: Styles.body1),
                                  )),
                            )),
                ]),
          ),
          _faucetTooltipWidget(context),
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
                      borderRadius: BorderRadius.circular(15.0),
                      padding: EdgeInsets.zero,
                      color: MyColors.white,
                      child: Text('받기',
                          style: Styles.label.merge(const TextStyle(
                              color: MyColors.black,
                              fontWeight: FontWeight.w600))))),
              const SizedBox(width: 8.0),
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
                      borderRadius: BorderRadius.circular(15.0),
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
    switch (widget.status) {
      case TransactionStatus.received:
        return Row(
          children: [
            SvgPicture.asset('assets/svg/tx-received.svg'),
            const SizedBox(width: 5),
            const Text(
              '받기 완료',
              style: Styles.body1,
            )
          ],
        );
      case TransactionStatus.receiving:
        return Row(
          children: [
            SvgPicture.asset('assets/svg/tx-receiving.svg', width: 24),
            const SizedBox(width: 5),
            const Text(
              '받는 중',
              style: Styles.body1,
            )
          ],
        );
      case TransactionStatus.sent:
        return Row(
          children: [
            SvgPicture.asset('assets/svg/tx-sent.svg', width: 24),
            const SizedBox(width: 5),
            const Text(
              '보내기 완료',
              style: Styles.body1,
            )
          ],
        );
      case TransactionStatus.sending:
        return Row(
          children: [
            SvgPicture.asset('assets/svg/tx-sending.svg', width: 24),
            const SizedBox(width: 5),
            const Text(
              '보내는 중',
              style: Styles.body1,
            )
          ],
        );
      case TransactionStatus.self:
        return Row(
          children: [
            SvgPicture.asset('assets/svg/tx-self.svg', width: 24),
            const SizedBox(width: 5),
            const Text(
              '받기 완료',
              style: Styles.body1,
            )
          ],
        );
      case TransactionStatus.selfsending:
        return Row(
          children: [
            SvgPicture.asset('assets/svg/tx-self-sending.svg', width: 24),
            const SizedBox(width: 5),
            const Text(
              '보내는 중',
              style: Styles.body1,
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
          style: Styles.body1Number.merge(const TextStyle(
              color: MyColors.white, fontWeight: FontWeight.w500)),
        );
      case TransactionStatus.self:
      case TransactionStatus.selfsending:
      case TransactionStatus.sent:
      case TransactionStatus.sending:
        return Text(
          widget.currentUnit == Unit.btc
              ? '-${satoshiToBitcoinString(widget.tx.amount!)}'
              : '-${addCommasToIntegerPart(widget.tx.amount!.toDouble())}',
          style: Styles.body1Number.merge(const TextStyle(
              color: MyColors.primary, fontWeight: FontWeight.w500)),
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
        ? DateTimeUtil.formatTimeStamp(widget.tx.timestamp!)
        : null;
    return ShrinkAnimationButton(
        defaultColor: MyColors.transparentWhite_06,
        onPressed: () {
          Navigator.pushNamed(context, '/transaction-detail',
              arguments: {'id': widget.id, 'tx': widget.tx});
        },
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
              Text(
                transactionTimeStamp != null
                    ? '${transactionTimeStamp[0]} | ${transactionTimeStamp[1]}'
                    : '',
                style: Styles.caption,
              ),
              const SizedBox(
                height: 4.0,
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
