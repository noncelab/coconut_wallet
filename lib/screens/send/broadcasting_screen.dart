import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
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
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_tween_button.dart';
import 'package:coconut_wallet/widgets/card/send_transaction_flow_card.dart';
import 'package:coconut_wallet/widgets/dialog.dart';
import 'package:coconut_wallet/widgets/floating_widget.dart';
import 'package:coconut_wallet/widgets/overlays/network_error_tooltip.dart';
import 'package:coconut_wallet/widgets/send_amount_header.dart';
import 'package:coconut_wallet/widgets/send_output_detail_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

class BroadcastingScreen extends StatefulWidget {
  final int? signedTransactionDraftId;
  const BroadcastingScreen({super.key, this.signedTransactionDraftId});

  @override
  State<BroadcastingScreen> createState() => _BroadcastingScreenState();
}

class _BroadcastingScreenState extends State<BroadcastingScreen> {
  late BroadcastingViewModel _viewModel;
  late BitcoinUnit _currentUnit;

  String get confirmText => _currentUnit.displayBitcoinAmount(_viewModel.amount);

  String get estimatedFeeText =>
      _currentUnit.displayBitcoinAmount(_viewModel.fee, defaultWhenNull: t.calculation_failed);

  String get totalCostText =>
      _currentUnit.displayBitcoinAmount(_viewModel.totalAmount, defaultWhenNull: t.calculation_failed);

  String get unitText => _currentUnit.symbol;
  int? userMessageIndex; // 후원하기에서만 사용

  void _setOverlayLoading(bool value) {
    if (value) {
      context.loaderOverlay.show();
    } else {
      context.loaderOverlay.hide();
    }
  }

  void _onChangeUserMessage() {
    if (userMessageIndex == null) return;

    final int userMessagesLength = t.donation.user_messages.length;
    debugPrint('userMessageIndex: $userMessageIndex, userMessagesLength: $userMessagesLength');
    setState(() {
      userMessageIndex = (userMessageIndex! + 1) % userMessagesLength;
    });
  }

  void broadcast() async {
    if (context.loaderOverlay.visible) return;
    _setOverlayLoading(true);
    await Future.delayed(const Duration(seconds: 1));
    try {
      Result<String> result = await _viewModel.broadcast();
      _setOverlayLoading(false);

      if (result.isFailure) {
        vibrateMedium();
        if (!mounted) return;
        showAlertDialog(
          context: context,
          title: t.broadcasting_screen.error_popup_title,
          content: t.alert.error_send.broadcasting_failed(error: result.error.message),
        );
        return;
      }

      if (result.isSuccess) {
        vibrateLight();
        await _viewModel.updateTagsOfUsedUtxos();
        await _viewModel.deleteDraftsIfNeeded();

        if (!mounted) return;

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/broadcasting-complete', // 이동할 경로
          ModalRoute.withName(
            _viewModel.sendEntryPoint == SendEntryPoint.walletDetail
                ? "/wallet-detail" // '/wallet-detail' 경로를 남기고 그 외의 경로 제거, '/'는 HomeScreen 까지
                : "/",
          ),
          arguments: {
            'id': _viewModel.walletId!,
            'txHash': _viewModel.signedTx!.transactionHash,
            'isDonation': _viewModel.isSendingDonation,
          },
        );
      }
    } catch (e) {
      Logger.log(">>>>> broadcast error: $e");
      _setOverlayLoading(false);
      String message = t.alert.error_send.broadcasting_failed(error: e.toString());
      if (e.toString().contains('min relay fee not met')) {
        message = t.alert.error_send.insufficient_fee;
      }
      if (!mounted) return;
      showAlertDialog(context: context, content: message);
      vibrateMedium();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<ConnectivityProvider, WalletProvider, BroadcastingViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, walletProvider, viewModel) {
        if (viewModel!.isNetworkOn != connectivityProvider.isInternetOn) {
          viewModel.setIsNetworkOn(connectivityProvider.isInternetOn);
        }

        return viewModel;
      },
      child: Consumer<BroadcastingViewModel>(
        builder:
            (context, viewModel, child) => Scaffold(
              floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
              backgroundColor: CoconutColors.black,
              appBar: CoconutAppBar.build(
                title: viewModel.isSendingDonation ? t.donation.donate : t.broadcasting_screen.title,
                context: context,
              ),
              body: SafeArea(
                child: Stack(
                  children: [
                    viewModel.isSendingDonation
                        ? _buildDonationBroadcastInfo(viewModel.amount, viewModel.isInitDone, viewModel.isNetworkOn)
                        : _buildNormalBroadcastInfo(
                          viewModel,
                          viewModel.amount,
                          viewModel.fee,
                          viewModel.totalAmount,
                          viewModel.sendingAmountWhenAddressIsMyChange,
                          viewModel.isSendingToMyAddress,
                          viewModel.recipientAddresses,
                          viewModel.isNetworkOn,
                        ),
                    if (!viewModel.isSendingDonation)
                      if (viewModel.feeBumpingType == null && widget.signedTransactionDraftId == null) ...{
                        FixedBottomTweenButton(
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
                        ),
                      } else ...{
                        FixedBottomButton(
                          showGradient: false,
                          isActive: viewModel.isNetworkOn && viewModel.isInitDone,
                          onButtonClicked: () async {
                            _onBroadcastButtonClicked(viewModel);
                          },
                          text: t.broadcasting_screen.btn_submit,
                        ),
                      },
                  ],
                ),
              ),
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
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/transaction-draft',
              ModalRoute.withName("/"),
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
      CoconutToast.showWarningToast(context: context, text: ErrorCodes.networkError.message);
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

    if (_viewModel.isSendingDonation) {
      userMessageIndex = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((duration) async {
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
        showAlertDialog(context: context, content: t.alert.error_tx.not_parsed(error: e));
      }

      _setOverlayLoading(false);
    });
  }

  Widget _buildDonationBroadcastInfo(int? amount, bool isInitDone, bool isNetworkOn) {
    return Column(
      children: [
        if (!isNetworkOn) NetworkErrorTooltip(isNetworkOn: isNetworkOn),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _onChangeUserMessage();
                      },
                      child: Row(
                        children: [
                          Text(t.donation.user_messages[userMessageIndex!], style: CoconutTypography.heading3_21_Bold),
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: SvgPicture.asset('assets/svg/arrow-reload.svg', width: 20, height: 20),
                          ),
                        ],
                      ),
                    ),
                    CoconutLayout.spacing_100h,
                    Text(t.donation.user_messages_description_1, style: CoconutTypography.heading4_18_Bold),
                    CoconutLayout.spacing_100h,
                    Text(
                      t.donation.user_messages_description_2(amount: (amount ?? 0).toThousandsSeparatedString()),
                      style: CoconutTypography.heading4_18_Bold,
                    ),
                  ],
                ),
              ),
              CoconutLayout.spacing_200h,
              _buildThanksImage(),
              CoconutLayout.spacing_800h,
              CoconutButton(
                width: MediaQuery.sizeOf(context).width,
                onPressed: () {
                  if (isNetworkOn == false) {
                    CoconutToast.showWarningToast(context: context, text: ErrorCodes.networkError.message);
                    return;
                  }
                  if (isInitDone) {
                    broadcast();
                  }
                },
                // 버튼 보이지 않을 때: 수수료 조회에 실패, 잔액이 충분한 지갑이 없음
                // 비활성화 상태로 보일 때: 지갑 동기화 진행 중, 수수료 조회 중,
                // 활성화 상태로 보일 때: 모든 지갑 동기화 완료, 지갑별 수수료 조회 성공
                isActive: isNetworkOn && isInitDone,
                text: t.donation.donate_confirm,
                backgroundColor: CoconutColors.gray100,
                pressedBackgroundColor: CoconutColors.gray500,
                disabledBackgroundColor: CoconutColors.gray800,
                disabledForegroundColor: CoconutColors.gray700,
                height: 50,
                foregroundColor: CoconutColors.black,
                pressedTextColor: CoconutColors.black,
              ),
            ],
          ),
        ),
      ],
    );
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
      padding: const EdgeInsets.only(
        left: 10,
        right: 10,
        bottom: FixedBottomButton.fixedBottomButtonDefaultBottomPadding,
      ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (!isNetworkOn) NetworkErrorTooltip(isNetworkOn: isNetworkOn),
            CoconutLayout.spacing_1000h,
            Text(t.broadcasting_screen.description, style: Styles.h3, textAlign: TextAlign.center),
            CoconutLayout.spacing_400h,
            SendAmountHeader(
              amountText: confirmText,
              unitText: unitText,
              satoshiAmount: amount ?? 0,
              totalCostAmountText: totalCostText,
              onTap: _toggleUnit,
              topMargin: 0,
              fiatTextStyle: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray400),
            ),
            CoconutLayout.spacing_300h,
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _buildTransactionFlowCard(viewModel)),
            CoconutLayout.spacing_500h,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildOutputDetailCardSection(viewModel),
            ),
            if (isSendingToMyAddress) ...[
              const SizedBox(height: 20),
              Text(t.broadcasting_screen.self_sending, textAlign: TextAlign.center, style: Styles.caption),
            ],
            // FixedBottomButton 크기에 맞게 스크롤이 가능하도록 설정
            CoconutLayout.spacing_600h,
            const SizedBox(height: FixedBottomButton.fixedBottomButtonDefaultHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildThanksImage() {
    final String assetPath;
    int? delayMilliseconds;
    bool repeat = false;

    switch (userMessageIndex) {
      case 0:
        assetPath = 'assets/lottie/two-hands-making-heart.json';
        repeat = true;
        break;
      case 1:
        assetPath = 'assets/images/hand-with-laid-heart.png';
        repeat = true;
        break;
      case 2:
        assetPath = 'assets/lottie/giving-coin.json';
        delayMilliseconds = 1000;
        repeat = false;
        break;
      case 3:
        assetPath = 'assets/lottie/hand-with-floating-heart.json';
        repeat = true;
        break;
      case 4:
        assetPath = 'assets/lottie/tripple-hearts.json';
        repeat = true;
        break;
      case 5:
        assetPath = 'assets/lottie/giving-heart.json';
        delayMilliseconds = 1000;
        repeat = false;
        break;
      case 6:
        assetPath = 'assets/lottie/upside-down-hands.json';
        delayMilliseconds = 1000;
        repeat = false;
        break;
      default:
        assetPath = 'assets/lottie/two-hands-heart.json';
    }

    final Key lottieKey = ValueKey(userMessageIndex);
    if (userMessageIndex == 6) {
      return FloatingWidget(
        delayMilliseconds: delayMilliseconds,
        child: Stack(
          children: [
            ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    colors: [
                      CoconutColors.white.withValues(alpha: 0.1),
                      Colors.transparent,
                      CoconutColors.black.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
              blendMode: BlendMode.srcATop,
              child: Lottie.asset(
                'assets/lottie/spinning-heart.json',
                key: ValueKey(userMessageIndex! * 2),
                width: 200,
                height: 200,
                fit: BoxFit.fill,
                repeat: true,
              ),
            ),
            Lottie.asset(assetPath, key: lottieKey, width: 200, height: 200, fit: BoxFit.fill, repeat: repeat),
          ],
        ),
      );
    }
    return FloatingWidget(
      delayMilliseconds: delayMilliseconds,
      child:
          userMessageIndex == 1
              ? Image.asset(assetPath, width: 200, height: 200, fit: BoxFit.fill)
              : Lottie.asset(assetPath, key: lottieKey, width: 200, height: 200, fit: BoxFit.fill, repeat: repeat),
    );
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit == BitcoinUnit.btc ? BitcoinUnit.sats : BitcoinUnit.btc;
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

    return SendOutputDetailCard(items: uiItems);
  }
}
