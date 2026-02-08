import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/refactor/send_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart'
    show TransactionDraftRepository, SelectedUtxoExcludedStatus;
import 'package:coconut_wallet/screens/send/refactor/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/screens/send/refactor/select_wallet_with_options_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_list_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/dashed_border_painter.dart';
import 'package:coconut_wallet/utils/text_field_filter_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/utils/wallet_util.dart';
import 'package:coconut_wallet/widgets/body/address_qr_scanner_body.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/card/transaction_draft_card.dart';
import 'package:coconut_wallet/widgets/dialog.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/ripple_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tuple/tuple.dart';

part 'send_screen_draft.dart';

class SendScreen extends StatefulWidget {
  final int? walletId;
  final SendEntryPoint sendEntryPoint;
  final int? transactionDraftId;

  const SendScreen({super.key, this.walletId, required this.sendEntryPoint, this.transactionDraftId});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey _viewMoreButtonKey = GlobalKey();
  final GlobalKey _addressInputFieldKey = GlobalKey();
  double _addressInputFieldBottomDy = 0; // 주소 입력창의 하단 Position.dy

  bool _isDropdownMenuVisible = false;

  final Color keyboardToolbarGray = const Color(0xFF2E2E2E);
  final Color feeRateFieldGray = const Color(0xFF2B2B2B);
  // 스크롤 범위 연산에 사용하는 값들
  final double kCoconutAppbarHeight = 60;
  final double kPageViewHeight = 225;
  final double kAddressBoardPosition = 185;
  final double kTooltipHeight = 43;
  final double kTooltipPadding = 5;
  final double kAmountHeight = 34;
  final double kFeeBoardBottomPadding = 12;
  double get addressBoardHeight => walletAddressListHeight + 100;
  double get walletAddressListHeight => _viewModel.orderedRegisteredWallets.length >= 2 ? 100 : 48;
  double get keyboardHeight => MediaQuery.of(context).viewInsets.bottom;
  double get feeBoardHeight => _viewModel.isMaxMode ? 100 : 154;

  late final SendViewModel _viewModel;
  final _recipientPageController = PageController();
  int _focusedPageIndex = 0;

  final ScrollController _screenScrollController = ScrollController();
  final ScrollController _addressListScrollController = ScrollController();

  final List<TextEditingController> _addressControllerList = [];
  final List<FocusNode> _addressFocusNodeList = [];
  final List<VoidCallback> _addressTextListenerList = [];

  final TextEditingController _feeRateController = TextEditingController();
  final FocusNode _feeRateFocusNode = FocusNode();

  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  // 배치 트랜잭션 드래그 가이드
  late bool hasSeenAddRecipientCard;
  bool _isLeftDragGuideViewVisible = false;

  MobileScannerController? _qrViewController;
  bool _isQrDataHandling = false;
  String _previousAmountText = "";

  bool get _hasKeyboard => _amountFocusNode.hasFocus || _feeRateFocusNode.hasFocus || _isAddressFocused;

  bool get _isAddressFocused => _addressFocusNodeList.any((e) => e.hasFocus);

  String get incomingBalanceTooltipText => t.tooltip.amount_to_be_sent(
    bitcoin: _viewModel.currentUnit.displayBitcoinAmount(_viewModel.incomingBalance),
    unit: _viewModel.currentUnit.symbol,
  );

  double _previousKeyboardHeight = 0;

  @override
  void initState() {
    super.initState();
    _addAddressField();
    _viewModel = SendViewModel(
      context.read<WalletProvider>(),
      context.read<SendInfoProvider>(),
      context.read<PreferenceProvider>(),
      context.read<TransactionDraftRepository>(),
      context.read<ConnectivityProvider>().isNetworkOn,
      _onAmountTextUpdate,
      _onFeeRateTextUpdate,
      _onRecipientPageDeleted,
      widget.walletId,
      widget.sendEntryPoint,
      widget.transactionDraftId,
    );
    if (widget.transactionDraftId != null) {
      _syncAddressControllersWithRecipientList();
    }

    _amountFocusNode.addListener(
      () => setState(() {
        if (!_amountFocusNode.hasFocus) {
          _viewModel.validateAllFieldsOnFocusLost();
        }
        if (_isDropdownMenuVisible) {
          _setDropdownMenuVisiblility(false);
        }
      }),
    );
    _feeRateFocusNode.addListener(
      () => setState(() {
        _amountController.text = _removeTrailingDot(_amountController.text);
      }),
    );
    _amountController.addListener(_amountTextListener);
    _recipientPageController.addListener(_recipientPageListener);

    // 수신자 카드를 보기 전까지 Bounce 애니메이션을 처리한다.
    hasSeenAddRecipientCard = context.read<PreferenceProvider>().hasSeenAddRecipientCard;
    if (!hasSeenAddRecipientCard) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 300));
        // _startBounce();
        if (!mounted) return;
        setState(() {
          _isLeftDragGuideViewVisible = true;
        });
      });
    }

    // MFP 없는 지갑이 선택된 경우 Toast 메시지 출력 하기
    if (isWalletWithoutMfp(_viewModel.selectedWalletItem)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CoconutToast.showToast(
          isVisibleIcon: true,
          context: context,
          text: t.wallet_detail_screen.toast.no_mfp_wallet_cant_send,
        );
      });
    } else if (_viewModel.incomingBalance > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        String amountText = _viewModel.currentUnit.displayBitcoinAmount(_viewModel.incomingBalance, withUnit: false);
        CoconutToast.showToast(
          isVisibleIcon: true,
          context: context,
          seconds: 5,
          text: t.tooltip.amount_to_be_sent(bitcoin: amountText, unit: _viewModel.currentUnit.symbol),
        );
      });
    }

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previousKeyboardHeight = MediaQuery.of(context).viewInsets.bottom;
      final addressInputFieldRect = _addressInputFieldKey.currentContext?.findRenderObject() as RenderBox;
      setState(() {
        _addressInputFieldBottomDy =
            addressInputFieldRect.localToGlobal(Offset.zero).dy +
            addressInputFieldRect.size.height -
            MediaQuery.of(context).padding.top -
            kToolbarHeight;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _recipientPageController.dispose();
    _feeRateController.dispose();
    _feeRateFocusNode.dispose();
    _amountController.dispose();
    _amountFocusNode.dispose();

    for (var focusNode in _addressFocusNodeList) {
      focusNode.dispose();
    }
    for (var controller in _addressControllerList) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentKeyboardHeight = MediaQuery.of(context).viewInsets.bottom;

      if (_previousKeyboardHeight > 0 && currentKeyboardHeight == 0) {
        _clearFocusOnKeyboardDismiss();
      }

      _previousKeyboardHeight = currentKeyboardHeight;
    });
  }

  void _clearFocusOnKeyboardDismiss() {
    _amountFocusNode.unfocus();
    _feeRateFocusNode.unfocus();

    for (var focusNode in _addressFocusNodeList) {
      focusNode.unfocus();
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {});
  }

  void _setDropdownMenuVisiblility(bool isVisible) {
    if (isVisible) {
      _feeRateController.text = _removeTrailingDot(_feeRateController.text);
      _amountController.text = _removeTrailingDot(_amountController.text);
      FocusManager.instance.primaryFocus?.unfocus();

      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isDropdownMenuVisible = true;
          });
        }
      });
    } else {
      if (_isDropdownMenuVisible != isVisible) {
        setState(() {
          _isDropdownMenuVisible = false;
        });
      }
    }
  }

  bool _validateEnteredAddresses() {
    // 임시저장 가능한지 확인하기 위한 함수
    for (var address in _addressControllerList) {
      if (address.text.isEmpty || !_viewModel.validateAddress(address.text, _addressControllerList.indexOf(address))) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // usableHeight: height - safeArea - toolbar
    final usableHeight =
        MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom -
        kCoconutAppbarHeight;

    return ChangeNotifierProxyProvider2<ConnectivityProvider, WalletProvider, SendViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, walletProvider, previous) {
        if (connectivityProvider.isNetworkOn != previous?.isNetworkOn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            previous?.setIsNetworkOn(connectivityProvider.isNetworkOn);
          });
        }
        return previous ?? _viewModel;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        appBar: _buildAppBar(context),
        body: GestureDetector(
          onTap: _clearFocus,
          behavior: HitTestBehavior.translucent,
          child: SizedBox(
            height: usableHeight,
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _screenScrollController,
                  child: Selector<SendViewModel, bool>(
                    selector: (_, viewModel) => viewModel.showAddressBoard,
                    builder: (context, data, child) {
                      return SizedBox(height: _getScrollableHeight(usableHeight), child: child);
                    },
                    child: Stack(
                      children: [
                        _buildInvisibleAmountField(),
                        _buildCounter(context),
                        _buildPageView(context),
                        _buildBoard(context),
                        if (_amountFocusNode.hasFocus || _feeRateFocusNode.hasFocus) _buildKeyboardToolbar(context),
                      ],
                    ),
                  ),
                ),
                _buildFinalButton(context),
                Selector<SendViewModel, Tuple3<bool, bool?, bool>>(
                  selector: (_, vm) => Tuple3(vm.isSaved, vm.hasDrafts, vm.canGoNext),
                  builder: (context, data, child) {
                    return _buildDropdownMenu(isSaved: data.item1, hasDrafts: data.item2, canGoNext: data.item3);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownMenu({required bool isSaved, required bool? hasDrafts, required bool canGoNext}) {
    if (!_isDropdownMenuVisible) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      right: 20,
      child: CoconutPulldownMenu(
        shadowColor: CoconutColors.gray800,
        dividerColor: CoconutColors.gray800,
        entries: [
          if (isSaved) ...[
            CoconutPulldownMenuItem(title: t.transaction_draft.save_new, isDisabled: !canGoNext), // 새로 저장
            CoconutPulldownMenuItem(title: t.transaction_draft.update, isDisabled: !canGoNext), // 변경 사항 저장
          ] else ...[
            CoconutPulldownMenuItem(
              title: t.transaction_draft.save,
              isDisabled: hasDrafts == null || !canGoNext,
            ), // 임시 저장
          ],
          if (hasDrafts == true) CoconutPulldownMenuItem(title: t.transaction_draft.load),
        ],
        onSelected: ((index, selectedText) async {
          _setDropdownMenuVisiblility(false);
          if (selectedText == t.transaction_draft.save || selectedText == t.transaction_draft.save_new) {
            await _onSaveNewDraft();
          } else if (selectedText == t.transaction_draft.update) {
            await _onUpdateDraft();
          } else if (selectedText == t.transaction_draft.load) {
            await _onLoadDraft();
          }
        }),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
      height: kCoconutAppbarHeight,
      customTitle: Selector<SendViewModel, Tuple5<WalletListItemBase?, bool, int, int, BitcoinUnit>>(
        selector:
            (_, viewModel) => Tuple5(
              viewModel.selectedWalletItem,
              viewModel.isUtxoSelectionAuto,
              viewModel.selectedUtxoAmountSum,
              viewModel.selectedUtxoListLength,
              viewModel.currentUnit,
            ),
        builder: (context, data, child) {
          final selectedWalletItem = data.item1;
          final isUtxoSelectionAuto = data.item2;
          final selectedUtxoListLength = data.item4;
          final currentUnit = data.item5;

          // null 이거나, 대표지갑이 mfp가 없고 mfp 있는 지갑이 0개일 때
          if (_viewModel.isSelectedWalletNull ||
              (isWalletWithoutMfp(_viewModel.selectedWalletItem) &&
                  !hasMfpWallet(_viewModel.orderedRegisteredWallets))) {
            return Container(
              color: Colors.transparent,
              width: 50,
              child: Text(
                textAlign: TextAlign.center,
                '-',
                style: CoconutTypography.body1_16.setColor(CoconutColors.white),
              ),
            );
          }

          String amountText = currentUnit.displayBitcoinAmount(_viewModel.balance, withUnit: true);
          if (!isUtxoSelectionAuto && selectedUtxoListLength > 0) {
            amountText += t.send_screen.n_utxos(count: selectedUtxoListLength);
          }

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isWalletWithoutMfp(_viewModel.selectedWalletItem)
                              ? '-'
                              : (selectedWalletItem!.name.length > 10
                                  ? '${selectedWalletItem.name.substring(0, 10)}...'
                                  : selectedWalletItem.name),
                          style: CoconutTypography.body1_16.setColor(CoconutColors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        CoconutLayout.spacing_50w,
                        const Icon(Icons.keyboard_arrow_down_sharp, color: CoconutColors.white, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isWalletWithoutMfp(_viewModel.selectedWalletItem) && !isUtxoSelectionAuto)
                Text(amountText, style: CoconutTypography.body3_12_NumberBold.setColor(CoconutColors.white)),
            ],
          );
        },
      ),
      onTitlePressed: () {
        // 지갑이 적어도 1개 이상 있어야 하며, MFP를 가진 지갑이 존재하는 경우에 출력한다. (존재하지 않는 경우 지갑 선택, UTXO 옵션처리를 할 필요가 없음)
        if (!_viewModel.isSelectedWalletNull && hasMfpWallet(_viewModel.orderedRegisteredWallets)) {
          _onAppBarTitlePressed();
        }
      },
      context: context,
      isBottom: true,
      actionButtonList: [
        SizedBox(
          height: 40,
          width: 40,
          child: IconButton(
            icon: SvgPicture.asset('assets/svg/kebab.svg'),
            onPressed: () {
              if (_isDropdownMenuVisible) {
                _setDropdownMenuVisiblility(false);
              } else {
                _setDropdownMenuVisiblility(true);
              }
            },
            color: CoconutColors.white,
          ),
        ),
      ],
      onBackPressed: () {
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildInvisibleAmountField() {
    return SizedBox(
      width: 0,
      height: 0,
      child: TextField(
        controller: _amountController,
        focusNode: _amountFocusNode,
        showCursor: false,
        enableInteractiveSelection: false,
        onEditingComplete: () {
          _amountController.text = _removeTrailingDot(_amountController.text);
          FocusScope.of(context).unfocus();
        },
        keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), SingleDotInputFormatter()],
      ),
    );
  }

  Widget _buildFinalButton(BuildContext context) {
    return Selector<SendViewModel, Tuple4<String, bool, bool, int?>>(
      selector:
          (_, viewModel) => Tuple4(
            viewModel.finalErrorMessage,
            viewModel.isReadyToSend,
            viewModel.isFeeRateLowerThanMin,
            viewModel.unintendedDustFee,
          ),
      builder: (context, data, child) {
        final finalErrorMessage = data.item1; // error
        final isReadyToSend = data.item2;
        final isFeeRateLowerThanMin = data.item3; // warning
        final unintendedDustFee = data.item4; // info

        final finalButtonMessages = [];

        /// errorMessage가 있으면 errorMessage만 표기
        /// isFeeRateLowerThanMin, unintendedDustFee중에서는 있는 것을 모두 표시
        if (_viewModel.finalErrorMessage.isNotEmpty) {
          finalButtonMessages.add(
            FinalButtonMessage(textColor: CoconutColors.hotPink, message: _viewModel.finalErrorMessage),
          );
        } else {
          if (isFeeRateLowerThanMin) {
            finalButtonMessages.add(
              FinalButtonMessage(
                textColor: CoconutColors.yellow,
                message: t.toast.min_fee(minimum: _viewModel.minimumFeeRate ?? 0),
              ),
            );
          }
          if (unintendedDustFee != null) {
            finalButtonMessages.add(
              FinalButtonMessage(
                textColor: CoconutColors.white,
                message: t.send_screen.unintended_dust_fee(unintendedDustFee: unintendedDustFee.toString()),
              ),
            );
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            ...finalButtonMessages.asMap().entries.map(
              (entry) => Positioned(
                bottom:
                    FixedBottomButton.fixedBottomButtonDefaultBottomPadding +
                    FixedBottomButton.fixedBottomButtonDefaultHeight +
                    12 +
                    ((finalButtonMessages.length - 1 - entry.key) * 20),
                child: Text(entry.value.message, style: CoconutTypography.body3_12.setColor(entry.value.textColor)),
              ),
            ),
            FixedBottomButton(
              showGradient: false,
              isVisibleAboveKeyboard: false,
              onButtonClicked: () {
                FocusScope.of(context).unfocus();
                if (isWalletWithoutMfp(_viewModel.selectedWalletItem)) return;
                if (mounted) {
                  _viewModel.saveSendInfo();
                  Navigator.pushNamed(context, '/send-confirm', arguments: {"currentUnit": _viewModel.currentUnit});
                }
              },
              isActive:
                  !isWalletWithoutMfp(_viewModel.selectedWalletItem) && isReadyToSend && finalErrorMessage.isEmpty,
              text: t.complete,
              backgroundColor: CoconutColors.gray100,
              pressedBackgroundColor: CoconutColors.gray500,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeeItem(String imagePath, double? sats, bool isFetching) {
    final child = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: CoconutColors.gray700),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            imagePath,
            height: 12,
            colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
          ),
          CoconutLayout.spacing_150w,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              "${sats ?? "-"} ${t.send_screen.fee_rate_suffix}",
              style: CoconutTypography.body2_14.setColor(CoconutColors.white),
            ),
          ),
        ],
      ),
    );

    return Expanded(
      child: RippleEffect(
        borderRadius: 8,
        onTap: () {
          if (isFetching) return;
          _feeRateController.text = sats.toString();
          _clearFocus();
        },
        child:
            !isFetching
                ? child
                : Shimmer.fromColors(
                  baseColor: CoconutColors.white.withOpacity(0.2),
                  highlightColor: CoconutColors.white.withOpacity(0.6),
                  child: child,
                ),
      ),
    );
  }

  Widget _buildKeyboardToolbar(BuildContext context) {
    return Positioned(
      bottom: keyboardHeight,
      child: GestureDetector(
        onTap: () {}, // ignore
        child: Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          color: keyboardToolbarGray,
          child:
              _amountFocusNode.hasFocus ? _buildAmountKeyboardToolbar(context) : _buildFeeRateKeyboardToolbar(context),
        ),
      ),
    );
  }

  Widget _buildAmountKeyboardToolbar(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        GestureDetector(
          onTap: _viewModel.toggleUnit,
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Selector<SendViewModel, BitcoinUnit>(
              selector: (_, viewModel) => viewModel.currentUnit,
              builder: (context, data, child) {
                return Row(
                  children: [
                    SvgPicture.asset(
                      'assets/svg/check.svg',
                      colorFilter: ColorFilter.mode(
                        _viewModel.isBtcUnit ? CoconutColors.white : CoconutColors.gray700,
                        BlendMode.srcIn,
                      ),
                      width: 10,
                      height: 10,
                    ),
                    CoconutLayout.spacing_200w,
                    Text(t.send_screen.use_btc_unit, style: CoconutTypography.body2_14.setColor(CoconutColors.white)),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeeRateKeyboardToolbar(BuildContext context) {
    return Selector<SendViewModel, Tuple2<RecommendedFeeFetchStatus, bool>>(
      selector: (_, viewModel) => Tuple2(viewModel.recommendedFeeFetchStatus, viewModel.isNetworkOn),
      builder: (context, data, child) {
        final recommendedFeeFetchStatus = data.item1;
        final isNetworkOn = data.item2;

        if (isNetworkOn && recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _viewModel.refreshRecommendedFees();
          });
        }

        final isFailed = recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed;
        final isFetching = recommendedFeeFetchStatus == RecommendedFeeFetchStatus.fetching;

        return Row(
          children: [
            if (isFailed) ...[
              SvgPicture.asset(
                'assets/svg/triangle-warning.svg',
                colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                width: 20,
              ),
              CoconutLayout.spacing_200w,
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.send_screen.recommended_fee_unavailable,
                    style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                  ),
                  Text(
                    t.send_screen.recommended_fee_unavailable_description,
                    style: CoconutTypography.body3_12.setColor(CoconutColors.gray300),
                  ),
                ],
              ),
            ] else ...[
              _buildFeeItem('assets/svg/fee-rate/low.svg', _viewModel.feeInfos[2].satsPerVb, isFetching),
              CoconutLayout.spacing_150w,
              _buildFeeItem('assets/svg/fee-rate/medium.svg', _viewModel.feeInfos[1].satsPerVb, isFetching),
              CoconutLayout.spacing_150w,
              _buildFeeItem('assets/svg/fee-rate/high.svg', _viewModel.feeInfos[0].satsPerVb, isFetching),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBottomTooltips(BuildContext context) {
    return Selector<SendViewModel, Tuple3<bool, int, String>>(
      selector: (_, viewModel) => Tuple3(viewModel.isMaxMode, _viewModel.recipientList.length, viewModel.amountSumText),
      builder: (context, data, child) {
        return Column(
          children: [
            CoconutLayout.spacing_300h,
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child:
                  _viewModel.isBatchMode
                      ? Padding(
                        key: const ValueKey('batch_tooltip'),
                        padding: EdgeInsets.only(bottom: kTooltipPadding),
                        child: _buildTooltip(
                          iconPath: 'assets/svg/receipt.svg',
                          text: t.send_screen.tooltip_text(
                            count: _viewModel.recipientList.length,
                            amount: _viewModel.amountSumText,
                          ),
                        ),
                      )
                      : const SizedBox.shrink(key: ValueKey('batch_empty')),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child:
                  _viewModel.isMaxMode
                      ? _buildTooltip(
                        key: const ValueKey('max_tooltip'),
                        iconPath: 'assets/svg/broom.svg',
                        text: t.send_screen.tooltip_max_mode_text,
                      )
                      : const SizedBox.shrink(key: ValueKey('max_empty')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTooltip({required String iconPath, required String text, Key? key}) {
    return SizedBox(
      child: CoconutToolTip(
        key: key,
        backgroundColor: CoconutColors.gray800,
        borderColor: CoconutColors.gray800,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        icon: Transform.translate(
          offset: const Offset(0, 3),
          child: SvgPicture.asset(
            iconPath,
            colorFilter: const ColorFilter.mode(CoconutColors.gray300, BlendMode.srcIn),
          ),
        ),
        tooltipType: CoconutTooltipType.fixed,
        richText: RichText(
          text: TextSpan(text: text, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray300)),
        ),
      ),
    );
  }

  Widget _buildFeeBoard(BuildContext context) {
    return Column(
      children: [
        Selector<SendViewModel, Tuple5<bool, int?, int, bool, bool>>(
          selector:
              (_, viewModel) => Tuple5(
                viewModel.showFeeBoard,
                viewModel.estimatedFeeInSats,
                viewModel.balance,
                viewModel.isMaxMode,
                viewModel.isFeeSubtractedFromSendAmount,
              ),
          builder: (context, data, child) {
            if (!_viewModel.showFeeBoard) return const SizedBox();
            return Container(
              padding: const EdgeInsets.only(left: 16, right: 14, top: 12, bottom: 20),
              decoration: BoxDecoration(
                border: Border.all(color: CoconutColors.gray700, width: 1),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: Column(
                children: [
                  child!,
                  CoconutLayout.spacing_200h,
                  Row(
                    children: [
                      _buildFeeRowLabel(t.send_screen.estimated_fee),
                      CoconutLayout.spacing_200w,
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            "${_viewModel.estimatedFeeInSats ?? '-'} sats",
                            style: CoconutTypography.body2_14_NumberBold.setColor(
                              _viewModel.isEstimatedFeeGreaterThanBalance ? CoconutColors.hotPink : CoconutColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_viewModel.isMaxMode) _buildFeeSubtractedFromSendAmount(),
                ],
              ),
            );
          },
          child: _buildFeeRateRow(),
        ),
        _buildBottomTooltips(context),
      ],
    );
  }

  Widget _buildFeeSubtractedFromSendAmount() {
    return Column(
      children: [
        CoconutLayout.spacing_400h,
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFeeRowLabel(t.send_screen.fee_subtracted_from_send_amount),
                  FittedBox(
                    child: Text(
                      _viewModel.isFeeSubtractedFromSendAmount
                          ? t.send_screen.fee_subtracted_from_send_amount_enabled_description
                          : t.send_screen.fee_subtracted_from_send_amount_disabled_description,
                      style: CoconutTypography.body3_12.setColor(CoconutColors.gray500),
                      maxLines: 2, // en - right overflow 방지
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
            CoconutLayout.spacing_200w,
            CoconutSwitch(
              scale: 0.7,
              isOn: _viewModel.isFeeSubtractedFromSendAmount,
              activeColor: CoconutColors.gray100,
              trackColor: CoconutColors.gray600,
              thumbColor: CoconutColors.gray800,
              onChanged: (isOn) => _viewModel.setIsFeeSubtractedFromSendAmount(isOn),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeeRateRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: _buildFeeRowLabel(t.send_screen.fee_rate)),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: IntrinsicWidth(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: CoconutTextField(
                  textInputType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                  textInputFormatter: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  enableInteractiveSelection: false,
                  textAlign: TextAlign.end,
                  controller: _feeRateController,
                  focusNode: _feeRateFocusNode,
                  backgroundColor: feeRateFieldGray,
                  onEditingComplete: () {
                    _feeRateController.text = _removeTrailingDot(_feeRateController.text);
                    FocusScope.of(context).unfocus();
                  },
                  height: 30,
                  padding: const EdgeInsets.only(left: 12, right: 2),
                  onChanged: (text) {
                    if (text == "-") return;
                    String formattedText = filterNumericInput(text, integerPlaces: 8, decimalPlaces: 2);
                    double? parsedFeeRate = double.tryParse(formattedText);

                    if ((formattedText != '0' && formattedText != '0.' && formattedText != '0.0') &&
                        (parsedFeeRate != null && parsedFeeRate < 0.1)) {
                      Fluttertoast.showToast(
                        msg: t.send_screen.fee_rate_too_low,
                        backgroundColor: CoconutColors.gray700,
                        toastLength: Toast.LENGTH_SHORT,
                      );
                      _feeRateController.text = '0.';
                      return;
                    }
                    _feeRateController.text = formattedText;
                    _viewModel.setFeeRateText(formattedText);
                  },
                  maxLines: 1,
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 14,
                  activeColor: CoconutColors.white,
                  fontWeight: FontWeight.bold,
                  borderRadius: 8,
                  suffix: Container(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      t.send_screen.fee_rate_suffix,
                      style: CoconutTypography.body2_14_NumberBold.setColor(CoconutColors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeeRowLabel(String label) {
    return Text(label, style: CoconutTypography.body2_14.setColor(CoconutColors.gray300));
  }

  Widget _buildPageView(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (_isLeftDragGuideViewVisible) {
          setState(() {
            _isLeftDragGuideViewVisible = false;
          });
        }
      },
      onPointerMove: (_) {
        if (_isLeftDragGuideViewVisible) {
          setState(() {
            _isLeftDragGuideViewVisible = false;
          });
        }
      },
      child: Stack(
        children: [
          SizedBox(
            height: kPageViewHeight,
            width: MediaQuery.of(context).size.width,
            child: Selector<SendViewModel, Tuple2<int, bool>>(
              selector: (_, viewModel) => Tuple2(viewModel.recipientList.length, viewModel.isMaxMode),
              builder: (context, data, child) {
                final recipientListLength = data.item1;
                final isMaxMode = data.item2;
                return PageView.builder(
                  controller: _recipientPageController,
                  onPageChanged: (index) {
                    // 수신자 추가 카드 확인 여부 업데이트
                    if (index == _viewModel.addRecipientCardIndex && !hasSeenAddRecipientCard) {
                      hasSeenAddRecipientCard = true;
                      context.read<PreferenceProvider>().setHasSeenAddRecipientCard();
                    }

                    _viewModel.setCurrentPage(index);
                  },
                  // isMaxMode: 수신자 추가 버튼 안보임
                  itemCount: recipientListLength + (!isMaxMode ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == recipientListLength) {
                      return _buildAddRecipientCard();
                    }
                    return _buildRecipientPage(context, index);
                  },
                );
              },
            ),
          ),
          AnimatedOpacity(
            opacity: _isLeftDragGuideViewVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                height: kPageViewHeight,
                width: MediaQuery.of(context).size.width,
                color: CoconutColors.black.withValues(alpha: 0.6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset('assets/lottie/swipe-left.json', width: 60, height: 60),
                    CoconutLayout.spacing_200h,
                    Text(
                      t.send_screen.swipe_to_add_address,
                      style: CoconutTypography.body2_14.setColor(CoconutColors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRecipientCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 25),
      child: ShrinkAnimationButton(
        defaultColor: CoconutColors.black,
        onPressed: () {
          _viewModel.addRecipient();
          _amountController.text = '';
          _addAddressField();
          _setDropdownMenuVisiblility(false);
        },
        child: CustomPaint(
          painter: DashedBorderPainter(dashSpace: 4.0, dashWidth: 4.0, color: CoconutColors.gray600),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/svg/plus.svg'),
              CoconutLayout.spacing_100w,
              Text(t.send_screen.add_recipient, style: CoconutTypography.body2_14.setColor(CoconutColors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientPage(BuildContext context, int index) {
    return Stack(
      children: [
        // Amount Touch Event Panel
        GestureDetector(
          onTap: () {
            // keyboard > amount request focus
            if (_hasKeyboard) {
              _clearFocus();
              return;
            }
            if (_viewModel.isAmountDisabled) return;
            _amountFocusNode.requestFocus();
          },
          child: Container(
            color: Colors.transparent,
            width: MediaQuery.of(context).size.width,
            height: kAmountHeight + Sizes.size80,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
          child: Column(
            children: [
              Selector<SendViewModel, Tuple7<BitcoinUnit, String, bool, bool, bool, bool, int?>>(
                selector:
                    (_, viewModel) => Tuple7(
                      viewModel.currentUnit,
                      viewModel.recipientList[index].amount,
                      viewModel.isMaxMode,
                      viewModel.isTotalSendAmountExceedsBalance,
                      viewModel.isLastAmountInsufficient,
                      viewModel.recipientList[index].minimumAmountError.isError,
                      viewModel.estimatedFeeInSats,
                    ),
                builder: (context, data, child) {
                  String amountText = data.item2;
                  final isMinimumAmount = data.item6;
                  final hasInsufficientBalanceErrorOfLastRecipient = data.item5 && index == _viewModel.lastIndex;

                  Color amountTextColor;
                  if (_viewModel.isTotalSendAmountExceedsBalance ||
                      isMinimumAmount ||
                      hasInsufficientBalanceErrorOfLastRecipient) {
                    amountTextColor = CoconutColors.hotPink;
                  } else if (_viewModel.isMaxModeLastIndex(index)) {
                    amountTextColor = CoconutColors.gray600;
                  } else if (amountText.isEmpty) {
                    amountTextColor = MyColors.transparentWhite_20;
                  } else {
                    amountTextColor = CoconutColors.white;
                  }

                  final isEnglishOrSpanish =
                      context.read<PreferenceProvider>().isEnglish || context.read<PreferenceProvider>().isSpanish;
                  final maxButtonBaseText = t.send_screen.input_maximum_amount;
                  final maxButtonText =
                      _viewModel.isMaxMode
                          ? (!isEnglishOrSpanish ? '$maxButtonBaseText ${t.cancel}' : '${t.cancel} $maxButtonBaseText')
                          : maxButtonBaseText;

                  return Column(
                    children: [
                      IgnorePointer(
                        child: SizedBox(
                          height: kAmountHeight,
                          child: FittedBox(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              text:
                                  _viewModel.isAmountInsufficient(index)
                                      ? TextSpan(
                                        text: t.send_screen.max_mode_insufficient_balance,
                                        style: CoconutTypography.heading3_21_Bold.setColor(CoconutColors.hotPink),
                                      )
                                      : TextSpan(
                                        text: '${amountText.isEmpty ? 0 : amountText.toThousandsSeparatedString()} ',
                                        style: CoconutTypography.heading2_28_NumberBold.setColor(amountTextColor),
                                        children: [
                                          TextSpan(
                                            text: _viewModel.currentUnit.symbol,
                                            style: CoconutTypography.heading4_18_Number,
                                          ),
                                        ],
                                      ),
                            ),
                          ),
                        ),
                      ),
                      CoconutLayout.spacing_200h,
                      IgnorePointer(
                        ignoring: index != _viewModel.lastIndex,
                        child: Opacity(
                          opacity: index == _viewModel.lastIndex ? 1.0 : 0.0,
                          child: ShrinkAnimationButton(
                            onPressed: () {
                              _viewModel.setMaxMode(!_viewModel.isMaxMode);
                              _clearFocus();
                            },
                            defaultColor: MyColors.grey,
                            pressedColor: MyColors.grey.withOpacity(0.8),
                            borderRadius: 4.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    'assets/svg/broom.svg',
                                    colorFilter: ColorFilter.mode(
                                      CoconutColors.white.withOpacity(_viewModel.isMaxMode ? 1.0 : 0.3),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  CoconutLayout.spacing_100w,
                                  Text(
                                    maxButtonText,
                                    style: Styles.caption.merge(
                                      TextStyle(color: CoconutColors.white, fontFamily: CustomFonts.text.getFontFamily),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              CoconutLayout.spacing_500h,
              Selector<SendViewModel, Tuple2<String, AddressError>>(
                selector:
                    (_, viewModel) =>
                        Tuple2(viewModel.recipientList[index].address, viewModel.recipientList[index].addressError),
                builder: (context, data, child) {
                  final isAddressError = data.item2.isError;
                  final controller = _addressControllerList[index];
                  return CoconutTextField(
                    key: index == 0 ? _addressInputFieldKey : null,
                    controller: _addressControllerList[index],
                    focusNode: _addressFocusNodeList[index],
                    backgroundColor: CoconutColors.black,
                    height: 52,
                    padding: const EdgeInsets.only(left: 16, right: 0),
                    onChanged: (text) {},
                    maxLines: 1,
                    suffix: IconButton(
                      iconSize: 14,
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        _setDropdownMenuVisiblility(false);
                        if (controller.text.isEmpty) {
                          await _showAddressScanner(index);
                        } else {
                          controller.clear();
                        }
                        _viewModel.validateAllFieldsOnFocusLost();
                      },
                      icon:
                          controller.text.isEmpty
                              ? SvgPicture.asset('assets/svg/scan.svg')
                              : SvgPicture.asset(
                                'assets/svg/text-field-clear.svg',
                                colorFilter: ColorFilter.mode(
                                  isAddressError ? CoconutColors.hotPink : CoconutColors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                    ),
                    placeholderText: t.send_screen.address_placeholder,
                    isError: isAddressError,
                  );
                },
              ),
              CoconutLayout.spacing_100h,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Selector<SendViewModel, int>(
                      selector: (_, viewModel) => viewModel.recipientList.length,
                      builder: (context, data, child) {
                        if (!_viewModel.isBatchMode) return const SizedBox();
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: CoconutUnderlinedButton(
                            text: t.send_screen.delete,
                            onTap: () {
                              _deleteAddressField(_viewModel.currentIndex);
                              _viewModel.deleteRecipient();
                              _setDropdownMenuVisiblility(false);
                            },
                            textStyle: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                            padding: EdgeInsets.zero,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCounter(BuildContext context) {
    return Selector<SendViewModel, Tuple2<int, int>>(
      selector: (_, viewModel) => Tuple2(viewModel.currentIndex, viewModel.recipientList.length),
      builder: (context, data, child) {
        final currentIndex = data.item1;
        final recipientListLength = data.item2;
        if (recipientListLength == 1 || currentIndex >= recipientListLength) {
          return const SizedBox();
        }
        return Positioned(
          right: 16,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: CoconutColors.gray800),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("${currentIndex + 1} ", style: CoconutTypography.body3_12.setColor(CoconutColors.white)),
                Text("/ $recipientListLength", style: CoconutTypography.body3_12.setColor(CoconutColors.gray600)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddressRow(int index, String address, String walletName, String derivationPath) {
    return ShrinkAnimationButton(
      onPressed: () {
        final currentIndex = _viewModel.currentIndex;
        if (currentIndex < _addressControllerList.length) {
          // 리스너를 제거하여 notifyListeners 호출 방지
          _addressControllerList[currentIndex].removeListener(_addressTextListenerList[currentIndex]);
          _addressControllerList[currentIndex].text = address;
          // 리스너는 빌드 완료 후 다시 추가
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted && currentIndex < _addressControllerList.length) {
              _addressControllerList[currentIndex].addListener(_addressTextListenerList[currentIndex]);
              // ViewModel에 직접 설정 (이미 텍스트가 같으면 notifyListeners 호출 안 함)
              _viewModel.setAddressText(address, currentIndex);
            }
          });
        }
        _viewModel.markWalletAddressForUpdate(index);
        vibrateLight();

        // _clearFocus는 한 프레임 더 지연
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _clearFocus();
          }
        });
      },
      defaultColor: Colors.transparent,
      pressedColor: CoconutColors.gray800,
      borderRadius: 12.0,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.only(left: 14, right: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoconutLayout.spacing_100h,
              Text(
                shortenAddress(address, head: 10),
                style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white),
              ),
              Text("$walletName • $derivationPath", style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
              CoconutLayout.spacing_100h,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressBoard(BuildContext context) {
    return SizedBox(
      height: addressBoardHeight + (_viewModel.orderedRegisteredWallets.length <= 2 ? 0 : 30),
      child: Column(
        children: [
          CoconutLayout.spacing_50h,
          Expanded(
            child: GestureDetector(
              onTap: () => {}, // ignore
              child: Container(
                decoration: BoxDecoration(
                  color: CoconutColors.black,
                  border: Border.all(color: CoconutColors.gray700, width: 1),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 14, top: 14),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 20),
                        child: Row(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                t.send_screen.my_address,
                                style: CoconutTypography.body3_12_Bold.setColor(CoconutColors.white),
                              ),
                            ),
                            const Spacer(),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: CoconutUnderlinedButton(
                                text: t.close,
                                onTap: () => _viewModel.setShowAddressBoard(false),
                                textStyle: CoconutTypography.body3_12,
                                padding: const EdgeInsets.only(right: 14, left: 24),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildWalletAddressList(),
                    CoconutLayout.spacing_200h,
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 14, bottom: 14),
                          child: CoconutUnderlinedButton(
                            key: _viewMoreButtonKey,
                            text: t.view_more,
                            onTap: () {
                              _clearFocus();
                              if (_viewModel.orderedRegisteredWallets.length == 1) {
                                _showAddressListBottomSheet(_viewModel.orderedRegisteredWallets[0].id);
                                return;
                              }
                              CommonBottomSheets.showDraggableBottomSheet(
                                context: context,
                                childBuilder:
                                    (scrollController) => SelectWalletBottomSheet(
                                      showOnlyMfpWallets: false,
                                      scrollController: scrollController,
                                      currentUnit: _viewModel.currentUnit,
                                      walletId: _viewModel.selectedWalletId,
                                      onWalletChanged: (id) {
                                        Navigator.pop(context);
                                        _showAddressListBottomSheet(id);
                                      },
                                    ),
                              );
                            },
                            textStyle: CoconutTypography.body3_12,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletAddressList() {
    if (_viewModel.orderedRegisteredWallets.length <= 2) {
      return Column(
        children: [
          CoconutLayout.spacing_200h,
          SizedBox(
            height: walletAddressListHeight,
            child: ListView.builder(
              controller: _addressListScrollController,
              itemCount: _viewModel.orderedRegisteredWallets.length,
              itemBuilder: (BuildContext context, int index) {
                final walletAddressInfo = _viewModel.registeredWalletAddressMap.entries.toList()[index].value;
                return Column(
                  children: [
                    _buildAddressRow(
                      index,
                      walletAddressInfo.walletAddress.address,
                      walletAddressInfo.name,
                      walletAddressInfo.walletAddress.derivationPath,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }
    return Stack(
      children: [
        Column(
          children: [
            CoconutLayout.spacing_200h,
            SizedBox(
              height: walletAddressListHeight + 30,
              child: Scrollbar(
                controller: _addressListScrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _addressListScrollController,
                  itemCount: _viewModel.orderedRegisteredWallets.length,
                  itemBuilder: (BuildContext context, int index) {
                    final walletAddressInfo = _viewModel.registeredWalletAddressMap.entries.toList()[index].value;
                    return Column(
                      children: [
                        if (index == 0) CoconutLayout.spacing_200h,
                        _buildAddressRow(
                          index,
                          walletAddressInfo.walletAddress.address,
                          walletAddressInfo.name,
                          walletAddressInfo.walletAddress.derivationPath,
                        ),
                        if (index == _viewModel.orderedRegisteredWallets.length - 1) CoconutLayout.spacing_200h,
                      ],
                    );
                  },
                ),
              ),
            ),
            CoconutLayout.spacing_200h,
          ],
        ),
        Positioned(
          left: 0,
          right: 4,
          top: 0,
          child: IgnorePointer(
            ignoring: true,
            child: Container(
              height: 30,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [CoconutColors.black, Colors.transparent],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 4,
          bottom: 0,
          child: IgnorePointer(
            ignoring: true,
            child: Container(
              height: 30,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, CoconutColors.black],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoard(BuildContext context) {
    return Selector<SendViewModel, bool>(
      selector: (_, viewModel) => viewModel.showAddressBoard,
      builder: (context, data, child) {
        return Positioned(
          left: 16,
          right: 16,
          top: !_viewModel.showAddressBoard ? kPageViewHeight : _addressInputFieldBottomDy,
          child: !_viewModel.showAddressBoard ? _buildFeeBoard(context) : _buildAddressBoard(context),
        );
      },
    );
  }

  double _getScrollableHeight(double usableHeight) {
    double scrollbarHeight = usableHeight;
    if (_viewModel.showAddressBoard) {
      // AddressBoard와 키보드간 간격만큼 스크롤 범위를 조정한다.
      final addressBoardBottomPos = kAddressBoardPosition + addressBoardHeight;

      // 사용 가능 높이에 키보드 높이와 보드의 바텀 위치를 빼서 스크롤 가능 범위를 구한다.
      final keyboardGap = usableHeight - keyboardHeight - addressBoardBottomPos;
      if (keyboardGap < 0) scrollbarHeight += -keyboardGap + CoconutLayout.defaultPadding;
    } else if (_viewModel.showFeeBoard && _isAddressFocused) {
      // FeeBoard와 키보드간 간격만큼 스크롤 범위를 조정한다.
      double bottomPos = kPageViewHeight + feeBoardHeight;
      int tooltipCount = 0;
      if (_viewModel.isBatchMode) ++tooltipCount;
      if (_viewModel.isMaxMode) ++tooltipCount;

      // 수수료 보드와 툴팁 사이 패딩
      if (tooltipCount > 0) bottomPos += kFeeBoardBottomPadding;
      // 툴팁 개수에 따른 패딩 계산
      if (tooltipCount > 1) bottomPos += kTooltipPadding * (tooltipCount - 1);
      // 툴팁 개수에 따른 높이 계산
      bottomPos += tooltipCount * kTooltipHeight;

      final keyboardGap = usableHeight - keyboardHeight - bottomPos;
      if (keyboardGap < 0) scrollbarHeight += -keyboardGap + CoconutLayout.defaultPadding;
    }

    // amount, fee는 스크롤 허용하지 않음
    return scrollbarHeight;
  }

  void _onAppBarTitlePressed() {
    _clearFocus();
    CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      heightRatio: 0.4,
      child: SelectWalletWithOptionsBottomSheet(
        currentUnit: _viewModel.currentUnit,
        selectedWalletId: _viewModel.selectedWalletId,
        onWalletInfoUpdated: _viewModel.onWalletInfoUpdated,
        isUtxoSelectionAuto: _viewModel.isUtxoSelectionAuto,
        selectedUtxoList: _viewModel.selectedUtxoList,
      ),
    );
  }

  void _showAddressListBottomSheet(int walletId) {
    CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      heightRatio: 0.9,
      child: AddressListScreen(id: walletId, isFullScreen: false),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    final codes = capture.barcodes;
    if (codes.isEmpty) return;

    final barcode = codes.first;
    if (barcode.rawValue == null) return;

    final scanData = barcode.rawValue;

    if (_isQrDataHandling || scanData == null || scanData.isEmpty) {
      return;
    }

    _isQrDataHandling = true;

    final validationResult = _viewModel.validateScannedAddress(scanData);
    if (mounted) {
      if (validationResult == null) {
        Navigator.pop(context, scanData);
      } else {
        CoconutToast.showToast(isVisibleIcon: true, context: context, text: validationResult.message);
      }

      _isQrDataHandling = false;
    }
  }

  Future<void> _showAddressScanner(int index) async {
    final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
    final String? scannedData = await CommonBottomSheets.showBottomSheet_100(
      context: context,
      child: Builder(
        builder:
            (sheetContext) => Scaffold(
              backgroundColor: CoconutColors.black,
              appBar: CoconutAppBar.build(
                title: t.send,
                context: sheetContext,
                actionButtonList: [
                  IconButton(
                    icon: SvgPicture.asset('assets/svg/arrow-reload.svg', width: 20, height: 20),
                    color: CoconutColors.white,
                    onPressed: () {
                      _qrViewController?.switchCamera();
                    },
                  ),
                ],
                onBackPressed: () {
                  _clearQrScanController();
                  Navigator.of(sheetContext).pop<String>('');
                },
              ),
              body: AddressQrScannerBody(
                qrKey: qrKey,
                onDetect: _onDetect,
                setMobileScannerController: (controller) {
                  _qrViewController = controller;
                },
              ),
            ),
      ),
    );

    if (scannedData != null) {
      if (scannedData.startsWith('bitcoin:')) {
        final bip21Data = parseBip21Uri(scannedData);
        _addressControllerList[index].text = bip21Data.address;
        _viewModel.setAddressText(bip21Data.address, index);

        if (bip21Data.amount != null) {
          final amountText =
              _viewModel.isBtcUnit
                  ? BalanceFormatUtil.formatSatoshiToReadableBitcoin(bip21Data.amount!)
                  : bip21Data.amount!.toString();
          _amountController.text = amountText;
          _viewModel.setAmountText(bip21Data.amount!, index);
        }
      } else {
        final normalized = normalizeAddress(scannedData);
        _addressControllerList[index].text = normalized;
        _viewModel.setAddressText(normalized, index);
      }
    }
    _clearQrScanController();
  }

  void _clearQrScanController() {
    // dispose는 MobileScanner에서 함 (or error occurred)
    //_qrViewController?.dispose();
    _qrViewController = null;
  }

  void _recipientPageListener() {
    final page = _recipientPageController.page;

    // 페이지가 완전히 변경되었고 이전에 Address 필드에 포커싱이 있었다면, 새로운 페이지의 Address 필드를 포커싱한다.
    if (page == page!.roundToDouble() && page != _focusedPageIndex) {
      _focusedPageIndex = page.toInt();

      if (_isAddressFocused && _focusedPageIndex < _viewModel.recipientList.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _addressFocusNodeList[_focusedPageIndex].requestFocus();
          _addressControllerList[_focusedPageIndex].selection = TextSelection.fromPosition(
            TextPosition(offset: _addressControllerList[_focusedPageIndex].text.length),
          );
        });
      }
    }
  }

  void _onRecipientPageDeleted(int page) {
    // PageController가 아직 attach되지 않았으면 (PageView가 빌드되지 않았으면) 실행하지 않음
    if (!_recipientPageController.hasClients) return;
    if (_recipientPageController.page == page) return;
    _recipientPageController.animateToPage(page, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
  }

  void _onFeeRateTextUpdate(String text) {
    _feeRateController.text = text;
  }

  void _onAmountTextUpdate(String text) {
    // 단위변환시 문자열 길이가 달라지므로 viewModel text와 길이를 맞춘다.
    _previousAmountText = text;
    _amountController.text = text;
  }

  void _amountTextListener() {
    // 최대 금액 보내기 모드인 경우에는 무시
    if (_viewModel.isAmountDisabled) {
      if (_amountController.text != _previousAmountText) {
        _amountController.text = _previousAmountText;
      }
      return;
    }

    // 문자가 입력된 경우와 삭제된 경우를 인식한다.
    String currentText = _amountController.text;
    if (currentText.length > _previousAmountText.length) {
      String lastInserted = currentText.substring(_previousAmountText.length);
      _viewModel.onKeyTap(lastInserted);
    } else if (currentText.length < _previousAmountText.length) {
      _viewModel.onKeyTap('<');
      // 삭제 버튼을 꾹 누른 경우에 대한 처리
      if (currentText.isEmpty) {
        _viewModel.clearAmountText();
      }
    }

    _previousAmountText = currentText;
  }

  void _addAddressField() {
    final controller = TextEditingController();
    final index = _addressControllerList.length;
    addressTextListener() => _viewModel.setAddressText(controller.text, index);

    controller.addListener(addressTextListener);
    _addressTextListenerList.add(addressTextListener);
    _addressControllerList.add(controller);

    final focusNode = FocusNode();
    focusNode.addListener(
      () => setState(() {
        _feeRateController.text = _removeTrailingDot(_feeRateController.text);
        _amountController.text = _removeTrailingDot(_amountController.text);

        final shouldShowBoard = focusNode.hasFocus && _viewModel.selectedWalletItem != null;
        _viewModel.setShowAddressBoard(shouldShowBoard);
        if (!focusNode.hasFocus) {
          _viewModel.validateAllFieldsOnFocusLost();
        } else {
          Future.delayed(const Duration(milliseconds: 1000), () {
            final viewMoreButtonRect = _viewMoreButtonKey.currentContext?.findRenderObject() as RenderBox;
            final viewMoreButtonPosition = viewMoreButtonRect.localToGlobal(Offset.zero);
            final viewMoreButtonHeight = viewMoreButtonRect.size.height;
            final viewMoreButtonBottom = viewMoreButtonPosition.dy + viewMoreButtonHeight;
            bool isViewMoreButtonVisible =
                viewMoreButtonBottom < MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom;
            if (!isViewMoreButtonVisible) {
              _screenScrollController.animateTo(
                _screenScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        }
        if (_isDropdownMenuVisible) {
          _setDropdownMenuVisiblility(false);
        }
        Future.delayed(const Duration(milliseconds: 1000), () {
          final viewMoreButtonRect = _viewMoreButtonKey.currentContext?.findRenderObject() as RenderBox;
          final viewMoreButtonPosition = viewMoreButtonRect.localToGlobal(Offset.zero);
          final viewMoreButtonHeight = viewMoreButtonRect.size.height;
          final viewMoreButtonBottom = viewMoreButtonPosition.dy + viewMoreButtonHeight;
          bool isViewMoreButtonVisible =
              viewMoreButtonBottom < MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom;
          if (!isViewMoreButtonVisible) {
            _screenScrollController.animateTo(
              _screenScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }),
    );
    _addressFocusNodeList.add(focusNode);
  }

  void _deleteAddressField(int index) {
    _addressControllerList[index].dispose();
    _addressFocusNodeList[index].dispose();

    _addressControllerList.removeAt(index);
    _addressFocusNodeList.removeAt(index);
    _addressTextListenerList.removeAt(index);
    _rebindAddressTextListeners(index);
  }

  void _rebindAddressTextListeners(int index) {
    for (int i = index; i < _addressTextListenerList.length; ++i) {
      final controller = _addressControllerList[i];
      newAddressTextListener() => _viewModel.setAddressText(controller.text, i);
      controller.removeListener(_addressTextListenerList[i]);
      controller.addListener(newAddressTextListener);
      _addressTextListenerList[i] = newAddressTextListener;
    }
  }

  void _clearFocus() {
    _feeRateController.text = _removeTrailingDot(_feeRateController.text);
    _amountController.text = _removeTrailingDot(_amountController.text);
    FocusManager.instance.primaryFocus?.unfocus();

    // setState 변경은 빌드 완료 후 실행
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_isLeftDragGuideViewVisible || _isDropdownMenuVisible) {
        setState(() {
          _isLeftDragGuideViewVisible = false;
          _isDropdownMenuVisible = false;
        });
      }
    });
  }

  /// 텍스트 끝의 소수점을 제거하는 함수
  String _removeTrailingDot(String text) {
    if (text.endsWith('.')) {
      return text.substring(0, text.length - 1);
    }
    return text;
  }

  /// recipientList와 _addressControllerList 동기화
  void _syncAddressControllersWithRecipientList() {
    final recipientListLength = _viewModel.recipientList.length;
    final currentControllerLength = _addressControllerList.length;

    // recipientList의 길이에 맞춰 _addressControllerList 조정
    if (recipientListLength > currentControllerLength) {
      // 부족한 만큼 추가
      for (int i = currentControllerLength; i < recipientListLength; i++) {
        _addAddressField();
      }
    } else if (recipientListLength < currentControllerLength) {
      // 초과하는 만큼 삭제
      for (int i = currentControllerLength - 1; i >= recipientListLength; i--) {
        _deleteAddressField(i);
      }
    }

    // 각 컨트롤러의 텍스트를 recipientList의 address로 업데이트
    // 리스너를 모두 제거한 후 텍스트를 설정하고, 나중에 다시 추가
    for (int i = 0; i < recipientListLength; i++) {
      if (i < _addressControllerList.length) {
        _addressControllerList[i].removeListener(_addressTextListenerList[i]);
      }
    }

    for (int i = 0; i < recipientListLength; i++) {
      if (i < _addressControllerList.length) {
        final address = _viewModel.recipientList[i].address;
        if (_addressControllerList[i].text != address) {
          _addressControllerList[i].text = address;
        }
      }
    }

    // 모든 리스너를 다시 추가 (빌드 완료 후)
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (int i = 0; i < recipientListLength && i < _addressControllerList.length; i++) {
        _addressControllerList[i].addListener(_addressTextListenerList[i]);
      }
    });

    // REFACTOR: amountController listener 설정도 addPostFrameCallback 내부에서 해야하는건 아닌지 확인
    // amount 컨트롤러도 업데이트
    if (recipientListLength > 0) {
      final currentIndex = _viewModel.currentIndex;
      if (currentIndex < recipientListLength) {
        final amount = _viewModel.recipientList[currentIndex].amount;
        if (_amountController.text != amount) {
          _amountController.removeListener(_amountTextListener);
          _amountController.text = amount;
          _previousAmountText = amount;
          _amountController.addListener(_amountTextListener);
        }
      }
    }
  }
}

class SingleDotInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    // 소수점이 2개 이상이면 입력 취소
    if ('.'.allMatches(text).length > 1) return oldValue;

    return newValue;
  }
}

class FinalButtonMessage {
  final Color textColor;
  final String message;

  FinalButtonMessage({required this.textColor, required this.message});
}

enum RecommendedFeeFetchStatus { fetching, succeed, failed }
