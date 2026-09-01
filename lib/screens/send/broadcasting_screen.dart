import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/send/broadcasting_complete_screen.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_tween_button.dart';
import 'package:coconut_wallet/widgets/features/send/send_transaction_flow_card.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:coconut_wallet/widgets/common/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/widgets/common/overlays/error_tooltip.dart';
import 'package:coconut_wallet/widgets/features/send/send_amount_header.dart';
import 'package:coconut_wallet/widgets/features/send/send_output_detail_card.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

class BroadcastingScreen extends StatefulWidget {
  final int? signedTransactionDraftId;
  final bool animateHotWalletEntry;
  final int? initialAmount;
  final int? initialTotalAmount;
  const BroadcastingScreen({
    super.key,
    this.signedTransactionDraftId,
    this.animateHotWalletEntry = false,
    this.initialAmount,
    this.initialTotalAmount,
  });

  @override
  State<BroadcastingScreen> createState() => _BroadcastingScreenState();
}

enum _BroadcastAnimationOutcome { pending, succeeded, failed }

class _BroadcastingScreenState extends State<BroadcastingScreen> with SingleTickerProviderStateMixin {
  late BroadcastingViewModel _viewModel;
  late BitcoinUnit _currentUnit;
  late bool _showEntryChrome;
  late bool _showTransactionFlow;
  late bool _showOutputDetail;
  late bool _showBottomButton;
  late final AnimationController _broadcastLottieController;
  late final ScrollController _scrollController;
  final Completer<void> _broadcastLottieLoaded = Completer<void>();
  _BroadcastAnimationOutcome _broadcastAnimationOutcome = _BroadcastAnimationOutcome.pending;
  bool _isBroadcasting = false;
  bool _isPreparingBroadcast = false;
  bool _showBroadcastLottie = false;
  bool _isBroadcastCompletionPhase = false;
  bool _isOverlayLoading = false;

  int? get _displayAmount => _viewModel.amount ?? widget.initialAmount;

  int? get _displayTotalAmount => _viewModel.totalAmount ?? widget.initialTotalAmount;

  String get confirmText => _currentUnit.displayBitcoinAmount(_displayAmount);

  String get totalCostText =>
      _currentUnit.displayBitcoinAmount(_displayTotalAmount, defaultWhenNull: t.calculation_failed);

  String get unitText => _currentUnit.symbol;

  void _setOverlayLoading(bool value) {
    if (!mounted || _isOverlayLoading == value) return;
    setState(() => _isOverlayLoading = value);
  }

  Future<void> broadcast() async {
    if (_isBroadcasting || _isPreparingBroadcast || _isOverlayLoading) {
      return;
    }
    _isPreparingBroadcast = true;
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      await _scrollController.animateTo(0, duration: const Duration(milliseconds: 320), curve: Curves.easeInOutCubic);
    }
    if (!mounted) return;
    await _prepareBroadcastAnimation();
    if (!mounted) return;
    final lottieAnimation = _runBroadcastLottie();
    try {
      Result<String> result = await _viewModel.broadcast();

      if (result.isFailure) {
        _broadcastAnimationOutcome = _BroadcastAnimationOutcome.failed;
        await lottieAnimation;
        if (!mounted) return;
        _restoreAfterBroadcastFailure();
        vibrateMedium();
        String message = result.error.message;
        if (_viewModel.isTaprootScriptPathWallet && result.error.message.contains('non-final')) {
          message = t.alert.error_send.non_final_taproot_child;
        }
        if (!mounted) return;
        showInfoDialog(
          context,
          context.read<PreferenceProvider>().language,
          t.broadcasting_screen.error_popup_title,
          message,
        );
        return;
      }

      if (result.isSuccess) {
        await _viewModel.updateTagsOfUsedUtxos();
        await _viewModel.deleteDraftsIfNeeded();
        if (!mounted) return;
        _broadcastAnimationOutcome = _BroadcastAnimationOutcome.succeeded;
        await lottieAnimation;
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder<void>(
            settings: const RouteSettings(name: '/broadcasting-complete'),
            transitionDuration: const Duration(milliseconds: 280),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            pageBuilder:
                (_, animation, secondaryAnimation) => BroadcastingCompleteScreen(
                  id: _viewModel.walletId!,
                  txHash: _viewModel.signedTx!.transactionHash,
                  animateEntry: true,
                ),
            transitionsBuilder:
                (_, animation, secondaryAnimation, child) => FadeTransition(
                  opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                  child: child,
                ),
          ),
          switch (_viewModel.sendEntryPoint) {
            SendEntryPoint.renewalWalletDetail => ModalRoute.withName('/renewal-wallet-detail'),
            SendEntryPoint.walletDetail => ModalRoute.withName('/wallet-detail'),
            SendEntryPoint.home || null => (route) => route.isFirst,
          },
        );
      }
    } catch (e) {
      Logger.error(">>>>> broadcast error: $e");
      _broadcastAnimationOutcome = _BroadcastAnimationOutcome.failed;
      await lottieAnimation;
      if (!mounted) return;
      _restoreAfterBroadcastFailure();
      String message = e.toString();
      if (e.toString().contains('min relay fee not met')) {
        message = t.alert.error_send.insufficient_fee;
      }
      if (!mounted) return;
      showInfoDialog(
        context,
        context.read<PreferenceProvider>().language,
        t.broadcasting_screen.error_popup_title,
        message,
      );
      vibrateMedium();
    }
  }

  Future<void> _prepareBroadcastAnimation() async {
    setState(() {
      _isBroadcasting = true;
      _showEntryChrome = false;
      _showBottomButton = false;
      _broadcastAnimationOutcome = _BroadcastAnimationOutcome.pending;
      _isBroadcastCompletionPhase = false;
    });
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _showTransactionFlow = false);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _showOutputDetail = false);
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    setState(() => _showBroadcastLottie = true);
    await WidgetsBinding.instance.endOfFrame;
    await _broadcastLottieLoaded.future;
  }

  Future<void> _runBroadcastLottie() async {
    const pivot = 22 / 60;
    const pivotDuration = Duration(milliseconds: 733);
    _broadcastLottieController.value = 0;
    while (_broadcastAnimationOutcome == _BroadcastAnimationOutcome.pending) {
      await _broadcastLottieController.animateTo(pivot, duration: pivotDuration, curve: Curves.easeInOut);
      if (_broadcastAnimationOutcome != _BroadcastAnimationOutcome.pending) {
        break;
      }
      await _broadcastLottieController.animateBack(0, duration: pivotDuration, curve: Curves.easeInOut);
    }

    if (_broadcastAnimationOutcome == _BroadcastAnimationOutcome.succeeded) {
      if (mounted) {
        vibrateLight();
        setState(() => _isBroadcastCompletionPhase = true);
      }
      await _broadcastLottieController.animateTo(
        1,
        duration: Duration(milliseconds: ((1 - _broadcastLottieController.value) * 2000).round()),
        curve: Curves.linear,
      );
    } else {
      _broadcastLottieController.stop();
      _broadcastLottieController.value = 0;
    }
  }

  void _restoreAfterBroadcastFailure() {
    setState(() {
      _isBroadcasting = false;
      _showBroadcastLottie = false;
      _showEntryChrome = true;
      _showTransactionFlow = true;
      _showOutputDetail = true;
      _showBottomButton = true;
      _isBroadcastCompletionPhase = false;
      _isPreparingBroadcast = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _viewModel.isFromSignedDraft) {
          _viewModel.clearSendInfo();
        }
      },
      child: ChangeNotifierProxyProvider2<ConnectivityProvider, WalletProvider, BroadcastingViewModel>(
        create: (_) => _viewModel,
        update: (_, connectivityProvider, walletProvider, viewModel) {
          if (viewModel!.isNetworkOn != connectivityProvider.isInternetOn) {
            viewModel.setIsNetworkOn(connectivityProvider.isInternetOn);
          }

          return viewModel;
        },
        child: Consumer<BroadcastingViewModel>(
          builder: (context, viewModel, child) {
            final appBar = CoconutAppBar.build(title: t.broadcasting_screen.title, context: context);
            return Stack(
              children: [
                Scaffold(
                  floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
                  backgroundColor: context.coconutColors.background,
                  appBar: PreferredSize(
                    preferredSize: appBar.preferredSize,
                    child: AnimatedOpacity(
                      opacity: _showEntryChrome && !_isBroadcasting ? 1 : 0,
                      duration: const Duration(milliseconds: 280),
                      child: IgnorePointer(ignoring: !_showEntryChrome || _isBroadcasting, child: appBar),
                    ),
                  ),
                  body: SafeArea(
                    child: Stack(
                      children: [
                        _buildNormalBroadcastInfo(
                          viewModel,
                          viewModel.amount,
                          viewModel.fee,
                          viewModel.totalAmount,
                          viewModel.sendingAmountWhenAddressIsMyChange,
                          viewModel.isSendingToMyAddress,
                          viewModel.recipientAddresses,
                          viewModel.isNetworkOn,
                        ),
                        if (_isBroadcasting)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeInOutCubic,
                            top:
                                _isBroadcastCompletionPhase
                                    ? MediaQuery.sizeOf(context).height * 0.3 - appBar.preferredSize.height
                                    : (MediaQuery.sizeOf(context).height -
                                            MediaQuery.paddingOf(context).vertical -
                                            appBar.preferredSize.height -
                                            118) /
                                        2,
                            left: 0,
                            right: 0,
                            child: AnimatedOpacity(
                              opacity: _showBroadcastLottie ? 1 : 0,
                              duration: const Duration(milliseconds: 220),
                              child: Column(
                                children: [
                                  Lottie.asset(
                                    TransactionLottiePath.checkSpinning,
                                    controller: _broadcastLottieController,
                                    width: 70,
                                    height: 70,
                                    repeat: false,
                                    onLoaded: (composition) {
                                      _broadcastLottieController.duration = composition.duration;
                                      if (!_broadcastLottieLoaded.isCompleted) {
                                        _broadcastLottieLoaded.complete();
                                      }
                                    },
                                  ),
                                  CoconutLayout.spacing_400h,
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 280),
                                    layoutBuilder:
                                        (currentChild, previousChildren) => Stack(
                                          alignment: Alignment.center,
                                          children: [...previousChildren, if (currentChild != null) currentChild],
                                        ),
                                    transitionBuilder: (child, animation) {
                                      final isIncoming = child.key == ValueKey(_isBroadcastCompletionPhase);
                                      final curvedAnimation = CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                        reverseCurve: Curves.easeInCubic,
                                      );
                                      final slideAnimation = Tween<Offset>(
                                        begin: isIncoming ? const Offset(0, 0.3) : const Offset(0, -0.4),
                                        end: Offset.zero,
                                      ).animate(curvedAnimation);

                                      return FadeTransition(
                                        opacity: curvedAnimation,
                                        child: SlideTransition(position: slideAnimation, child: child),
                                      );
                                    },
                                    child: Text(
                                      _isBroadcastCompletionPhase
                                          ? t.broadcasting_complete_screen.complete
                                          : t.broadcasting_screen.requesting,
                                      key: ValueKey(_isBroadcastCompletionPhase),
                                      style: CoconutTypography.heading4_18_Bold.setColor(
                                        context.coconutColors.primaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (viewModel.feeBumpingType == null && widget.signedTransactionDraftId == null) ...{
                          _BroadcastEntryTransition(
                            visible: _showBottomButton,
                            child: FixedBottomTweenButton(
                              leftButtonRatio: 0.35,
                              leftButtonClicked: () async {
                                if (viewModel.isAlreadySaved) {
                                  CoconutToast.showToast(
                                    context: context,
                                    text: t.broadcasting_screen.toast.already_saved_draft,
                                    isVisibleIcon: true,
                                  );
                                  return;
                                }
                                try {
                                  final result = await viewModel.saveTransactionDraft();
                                  if (result.isSuccess) {
                                    _showTransactionDraftSavedDialog();
                                  } else {
                                    _showTransactionDraftSaveFailedDialog(result.error.message);
                                  }
                                } catch (e) {
                                  _showTransactionDraftSaveFailedDialog(e.toString());
                                }
                              },
                              rightButtonClicked: () async {
                                _onBroadcastButtonClicked(viewModel);
                              },
                              leftText: t.transaction_draft.save,
                              rightText: t.broadcasting_screen.btn_submit,
                              rightButtonBackgroundColor: context.coconutColors.primary,
                            ),
                          ),
                        } else ...{
                          _BroadcastEntryTransition(
                            visible: _showBottomButton,
                            child: FixedBottomButton(
                              isActive: viewModel.isNetworkOn && viewModel.isInitDone,
                              onButtonClicked: () async {
                                _onBroadcastButtonClicked(viewModel);
                              },
                              text: t.broadcasting_screen.btn_submit,
                              backgroundColor: context.coconutColors.primary,
                            ),
                          ),
                        },
                      ],
                    ),
                  ),
                ),
                if (_isOverlayLoading) const Positioned.fill(child: CoconutLoadingOverlay(applyFullScreen: true)),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showTransactionDraftSavedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.transaction_draft.dialog.transaction_draft_saved_broadcast_screen,
          description: t.transaction_draft.dialog.transaction_draft_saved_description_broadcast_screen,
          leftButtonText: t.transaction_draft.dialog.cancel,
          rightButtonText: t.transaction_draft.dialog.move,
          onTapRight: () {
            _viewModel.clearSendInfo();
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/transaction-draft',
              (route) => route.isFirst,
              arguments: {'isSignedTabActive': true},
            );
          },
          onTapLeft: () {
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showTransactionDraftSaveFailedDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.transaction_draft.dialog.transaction_draft_save_failed,
          description: errorMessage,
          rightButtonText: t.transaction_draft.dialog.confirm,
          onTapRight: () {
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _onBroadcastButtonClicked(BroadcastingViewModel viewModel) async {
    if (viewModel.isNetworkOn == false) {
      CoconutToast.showToast(
        context: context,
        isVisibleIcon: true,
        iconPath: CommonStateIconPath.triangleWarning,
        text: ErrorCodes.networkError.message,
        level: CoconutToastLevel.warning,
      );
      return;
    }
    if (viewModel.feeBumpingType != null && viewModel.hasTransactionConfirmed()) {
      await TransactionUtil.showTransactionConfirmedDialog(context);
      return;
    }
    if (viewModel.isInitDone) {
      broadcast();
    }
  }

  @override
  void initState() {
    super.initState();
    _showEntryChrome = !widget.animateHotWalletEntry;
    _showTransactionFlow = !widget.animateHotWalletEntry;
    _showOutputDetail = !widget.animateHotWalletEntry;
    _showBottomButton = !widget.animateHotWalletEntry;
    _broadcastLottieController = AnimationController(vsync: this);
    _scrollController = ScrollController();
    _currentUnit = context.read<PreferenceProvider>().currentUnit;
    _viewModel = BroadcastingViewModel(
      Provider.of<SendInfoProvider>(context, listen: false),
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<UtxoTagProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false).isInternetOn,
      Provider.of<NodeProvider>(context, listen: false),
      Provider.of<TransactionProvider>(context, listen: false),
      Provider.of<TransactionDraftRepository>(context, listen: false),
      Provider.of<UtxoRepository>(context, listen: false),
      widget.signedTransactionDraftId,
    );

    WidgetsBinding.instance.addPostFrameCallback((duration) async {
      if (widget.animateHotWalletEntry) {
        await Future.delayed(const Duration(milliseconds: 250));
        if (mounted) {
          setState(() {
            _showEntryChrome = true;
            _showTransactionFlow = true;
            _showOutputDetail = true;
            _showBottomButton = true;
          });
        }
      }
      _setOverlayLoading(true);

      try {
        final excludedUtxoStatus = await _viewModel.setTxInfo();
        if (excludedUtxoStatus != null && mounted) {
          final message =
              excludedUtxoStatus == SelectedUtxoExcludedStatus.used
                  ? t.transaction_draft.dialog.transaction_already_used_utxo_included
                  : t.transaction_draft.dialog.transaction_has_been_locked_utxo_included;
          showConfirmDialog(
            context,
            context.read<PreferenceProvider>().language,
            t.broadcasting_screen.dialog.send_unavailable,
            message,
            rightButtonText: t.delete,
            onTapRight: () async {
              Navigator.pop(context);
              _setOverlayLoading(true);
              await Future.delayed(const Duration(seconds: 1));
              try {
                await _viewModel.deleteSignedDraft();
              } catch (e) {
                if (!mounted) return;
                showInfoDialog(
                  context,
                  context.read<PreferenceProvider>().language,
                  t.transaction_draft.dialog.transaction_draft_delete_failed,
                  e.toString(),
                );
                _setOverlayLoading(false);
                return;
              }
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
          );
        }
      } catch (e) {
        vibrateMedium();
        if (!mounted) return;
        showInfoDialog(
          context,
          context.read<PreferenceProvider>().language,
          '',
          t.alert.error_tx.not_parsed(error: e),
          onTapButton: () => Navigator.pop(context),
        );
      }

      _setOverlayLoading(false);
    });
  }

  @override
  void dispose() {
    _broadcastLottieController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildNormalBroadcastInfo(
    BroadcastingViewModel viewModel,
    int? amount,
    int? fee,
    int? totalAmount,
    int? sendingAmountWhenAddressIsMyChange,
    bool isSendingToMyAddress,
    List<String> recipientAddresses,
    bool isNetworkOn,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: _isBroadcasting ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (!isNetworkOn) ErrorTooltip(isShown: !isNetworkOn, errorMessage: t.errors.network_error),
            CoconutLayout.spacing_1000h,
            AnimatedSlide(
              offset:
                  _isBroadcastCompletionPhase
                      ? const Offset(0, -0.35)
                      : _isBroadcasting
                      ? const Offset(0, -0.12)
                      : Offset.zero,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              child: AnimatedOpacity(
                opacity: _isBroadcastCompletionPhase ? 0 : 1,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: Column(
                  children: [
                    Text(
                      t.broadcasting_screen.description,
                      style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
                      textAlign: TextAlign.center,
                    ),
                    CoconutLayout.spacing_400h,
                    SendAmountHeader(
                      amountText: confirmText,
                      unit: _currentUnit,
                      satoshiAmount: amount ?? widget.initialAmount ?? 0,
                      totalCostAmountText: totalCostText,
                      onTap: _toggleUnit,
                      topMargin: 0,
                      fiatTextStyle: CoconutTypography.body2_14_Number.setColor(context.coconutColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ),
            CoconutLayout.spacing_300h,
            _BroadcastEntryTransition(visible: _showTransactionFlow, child: _buildTransactionFlowCard(viewModel)),
            CoconutLayout.spacing_500h,
            _BroadcastEntryTransition(visible: _showOutputDetail, child: _buildOutputDetailCardSection(viewModel)),
            if (isSendingToMyAddress) ...[
              const SizedBox(height: 20),
              Text(
                t.broadcasting_screen.self_sending,
                textAlign: TextAlign.center,
                style: CoconutTypography.caption_10_Number.setColor(context.coconutColors.secondaryText),
              ),
            ],
            CoconutLayout.spacing_500h,
            CoconutLayout.spacing_2500h,
          ],
        ),
      ),
    );
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit.next;
    });
  }

  Widget _buildTransactionFlowCard(BroadcastingViewModel viewModel) {
    final inputCount = viewModel.inputCount;
    final List<int?> inputAmounts = List<int?>.from(viewModel.inputAmounts);
    if (inputAmounts.length != inputCount) {
      inputAmounts
        ..clear()
        ..addAll(List<int?>.filled(inputCount, null));
    }

    return SendTransactionFlowCard(
      inputAmounts: inputAmounts,
      externalOutputAmounts: viewModel.externalOutputAmounts,
      changeOutputAmounts: viewModel.changeOutputAmounts,
      fee: viewModel.fee,
      currentUnit: _currentUnit,
    );
  }

  Widget _buildOutputDetailCardSection(BroadcastingViewModel viewModel) {
    final detailItems = viewModel.outputDetailItems;
    if (detailItems.isEmpty) {
      return const SizedBox.shrink();
    }

    int outputIndex = 0;
    final uiItems =
        detailItems.map((item) {
          if (!item.isChange) {
            outputIndex += 1;
          }
          return OutputDetailItem(
            label: item.isChange ? t.change : t.send_confirm_screen.flow_output_title(index: outputIndex),
            address: item.address,
            amountSats: item.amount,
            isChange: item.isChange,
          );
        }).toList();

    return SendOutputDetailCard(items: uiItems, currentUnit: _currentUnit);
  }
}

class _BroadcastEntryTransition extends StatelessWidget {
  const _BroadcastEntryTransition({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.12),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(opacity: visible ? 1 : 0, duration: const Duration(milliseconds: 240), child: child),
    ),
  );
}
