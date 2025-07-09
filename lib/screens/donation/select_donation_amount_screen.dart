import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class SelectDonationAmountScreen extends StatefulWidget {
  final int walletListLength;
  const SelectDonationAmountScreen({
    super.key,
    required this.walletListLength,
  });

  @override
  State<SelectDonationAmountScreen> createState() => _SelectDonationAmountScreenState();
}

class _SelectDonationAmountScreenState extends State<SelectDonationAmountScreen> with RouteAware {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  DonationSelectedType donationSelectedType = DonationSelectedType.none;

  final donationCoffeeValue = 5000; // 커피 한잔 후원금
  final donationLateMealValue = 10000; // 야근 식대 후원금
  final donationMaintenanceValue = 50000; // 유지 보수비 후원금

  static const kDonationLightningMaxValue = 500000000;

  int? customDonateValue;

  bool isDustErrorTextVisible = false;
  bool isOverDonationMaxValue = false;

  bool isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 다음화면에서 돌아왔을 때 textField에 autoFocusing 되는 현상 방지
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CoconutAppBar.build(
        title: t.donation.donate,
        context: context,
        backgroundColor: CoconutColors.black,
        isBottom: true,
      ),
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _hideKeyboard();
          if (donationSelectedType == DonationSelectedType.custom && customDonateValue == null) {
            setState(() {
              donationSelectedType = DonationSelectedType.none;
            });
          }
          if (handleDustThreshold()) return;
        },
        child: Selector<ConnectivityProvider, bool>(
          selector: (_, provider) => provider.isNetworkOn ?? false,
          builder: (context, isNetworkOn, _) {
            return Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    width: MediaQuery.sizeOf(context).width,
                    height: MediaQuery.of(context).viewInsets.bottom > 0
                        ? MediaQuery.sizeOf(context).height -
                            kToolbarHeight -
                            MediaQuery.paddingOf(context).top +
                            100
                        : MediaQuery.sizeOf(context).height -
                            kToolbarHeight -
                            MediaQuery.paddingOf(context).top -
                            30,
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 30,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                            child: Column(
                          children: [
                            Text(
                              t.donation.encourageSupportMessage,
                              style: CoconutTypography.body2_14_Bold,
                            ),
                            CoconutLayout.spacing_900h,
                            donationAmountCard(
                              DonationSelectedType.coffee,
                              t.donation.coffee,
                              amount: donationCoffeeValue,
                            ),
                            CoconutLayout.spacing_200h,
                            donationAmountCard(
                              DonationSelectedType.lateMeal,
                              t.donation.late_meal,
                              amount: donationLateMealValue,
                            ),
                            CoconutLayout.spacing_200h,
                            donationAmountCard(
                              DonationSelectedType.maintenance,
                              t.donation.maintenance,
                              amount: donationMaintenanceValue,
                            ),
                            CoconutLayout.spacing_200h,
                            donationAmountCard(
                              DonationSelectedType.custom,
                              t.donation.support_heart,
                              isEditable: true,
                            ),
                            if (isDustErrorTextVisible) ...[
                              CoconutLayout.spacing_200h,
                              Text(
                                t.donation.under_dust_error(dust: dustLimit),
                                style: CoconutTypography.body3_12.setColor(
                                  CoconutColors.warningText,
                                ),
                              ),
                            ],
                            if (isOverDonationMaxValue) ...[
                              CoconutLayout.spacing_200h,
                              Text(
                                t.donation.over_donation_max_value_error(
                                    value: kDonationLightningMaxValue),
                                style: CoconutTypography.body3_12.setColor(
                                  CoconutColors.warningText,
                                ),
                              ),
                            ],
                          ],
                        )),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: CoconutLayout.defaultPadding,
                  right: CoconutLayout.defaultPadding,
                  bottom: MediaQuery.of(context).viewInsets.bottom + Sizes.size30,
                  child: Row(
                    children: [
                      donateBottomButtonWidget(isNetworkOn, true),
                      CoconutLayout.spacing_200w,
                      donateBottomButtonWidget(isNetworkOn, false),
                    ],
                  ),
                ),
                if (isLoading)
                  Positioned(
                    top: 0,
                    bottom: MediaQuery.of(context).viewInsets.bottom + kToolbarHeight,
                    child: Container(
                        width: MediaQuery.sizeOf(context).width,
                        height: MediaQuery.sizeOf(context).height,
                        color: CoconutColors.black.withOpacity(0.3),
                        child: const Center(child: CoconutCircularIndicator())),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _hideKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
      _focusNode.unfocus();
      // Fallback for keyboard hide
      Future.delayed(const Duration(milliseconds: 50), () {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      });
    });
  }

  void goNextScreen(bool isNetworkOn, bool isOnchainDonation) async {
    setState(() {
      isLoading = true;
    });
    _hideKeyboard();

    if (isNetworkOn != true) {
      CoconutToast.showWarningToast(context: context, text: ErrorCodes.networkError.message);
      return;
    }

    int donateValue;
    switch (donationSelectedType) {
      case DonationSelectedType.coffee:
        {
          donateValue = donationCoffeeValue;
          break;
        }
      case DonationSelectedType.lateMeal:
        {
          donateValue = donationLateMealValue;
          break;
        }
      case DonationSelectedType.maintenance:
        {
          donateValue = donationMaintenanceValue;
          break;
        }
      case DonationSelectedType.custom:
        {
          if (customDonateValue == null) return;
          donateValue = customDonateValue!;
        }
      default:
        return;
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });

      if (isOnchainDonation) {
        Navigator.pushNamed(context, '/onchain-donation-info', arguments: {
          'donation-amount': donateValue,
        });
      } else {
        Navigator.pushNamed(context, '/lightning-donation-info',
            arguments: {'donation-amount': donateValue});
      }
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && !_scrollController.position.isScrollingNotifier.value) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Widget donateBottomButtonWidget(bool isNetworkOn, bool isOnchain) {
    return Expanded(
      child: CoconutButton(
        isActive: donationSelectedType != DonationSelectedType.none && !isLoading,
        foregroundColor: CoconutColors.black,
        pressedTextColor: CoconutColors.black,
        pressedBackgroundColor: CoconutColors.gray500,
        disabledBackgroundColor: CoconutColors.gray800,
        disabledForegroundColor: CoconutColors.gray700,
        onPressed: () {
          // 네트워크 체크
          if (!isNetworkOn) {
            CoconutToast.showWarningToast(context: context, text: ErrorCodes.networkError.message);
            return;
          }

          if (handleDustThreshold()) {
            scrollToBottom();
            return;
          }

          if (!isOnchain &&
              donationSelectedType == DonationSelectedType.custom &&
              ((customDonateValue != null && customDonateValue! > kDonationLightningMaxValue) ||
                  customDonateValue == null)) {
            setState(() {
              isOverDonationMaxValue = true;
            });
            return;
          }

          goNextScreen(isNetworkOn, isOnchain);
        },
        text: isOnchain ? t.donation.onchain : t.donation.lightning,
      ),
    );
  }

  bool handleDustThreshold() {
    if (donationSelectedType == DonationSelectedType.custom &&
        ((customDonateValue != null && customDonateValue! <= dustLimit) ||
            customDonateValue == null)) {
      setState(() {
        isDustErrorTextVisible = true;
      });
      return true;
    }
    return false;
  }

  Widget donationAmountCard(
    DonationSelectedType donationType,
    String donationTypeText, {
    int? amount,
    bool isEditable = false,
  }) {
    assert(isEditable || amount != null, 'isEditable=false일 때는 반드시 amount가 필요합니다.');

    return ShrinkAnimationButton(
      defaultColor: CoconutColors.black,
      onPressed: () {
        final hadFocus = _focusNode.hasFocus;
        final isCustom = donationType == DonationSelectedType.custom;
        if (!isCustom && hadFocus) _hideKeyboard();

        if (hadFocus) {
          if (isCustom && handleDustThreshold()) return;
        }

        setState(() {
          donationSelectedType = donationType;
          if (isDustErrorTextVisible) {
            isDustErrorTextVisible = false;
          } else if (isOverDonationMaxValue) {
            isOverDonationMaxValue = false;
          }
        });

        if (isCustom && !hadFocus) {
          _focusNode.requestFocus();
          Future.delayed(const Duration(milliseconds: 200)).then((_) {
            scrollToBottom();
          });
        }
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1, minHeight: 1),
        child: Container(
          width: MediaQuery.sizeOf(context).width,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            border: Border.all(
              color: donationSelectedType == donationType
                  ? CoconutColors.gray100
                  : CoconutColors.gray600,
            ),
            borderRadius: BorderRadius.circular(
              CoconutStyles.radius_250,
            ),
            color: Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                donationTypeText,
                style: CoconutTypography.body2_14_Bold,
              ),
              isEditable
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 150, maxWidth: 300),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 80, maxWidth: 80),
                              child: TextField(
                                controller: _controller,
                                autofocus: false,
                                onTap: () {
                                  donationSelectedType = DonationSelectedType.custom;
                                  setState(() {
                                    isDustErrorTextVisible = false;
                                    isOverDonationMaxValue = false;
                                  });
                                  _controller.selection = TextSelection.fromPosition(
                                    TextPosition(offset: _controller.text.length),
                                  );

                                  Future.delayed(const Duration(milliseconds: 200)).then((_) {
                                    scrollToBottom();
                                  });
                                },
                                onChanged: (input) {
                                  if (isDustErrorTextVisible) {
                                    setState(() {
                                      isDustErrorTextVisible = false;
                                    });
                                  }

                                  if (isOverDonationMaxValue) {
                                    setState(() {
                                      isOverDonationMaxValue = false;
                                    });
                                  }

                                  if (input.isEmpty) {
                                    customDonateValue = null;
                                    return;
                                  }

                                  customDonateValue = int.parse(input);
                                },
                                focusNode: _focusNode,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                textInputAction: TextInputAction.done,
                                onSubmitted: (value) {
                                  if (donationSelectedType == DonationSelectedType.custom &&
                                      customDonateValue != null &&
                                      customDonateValue! <= dustLimit) {
                                    setState(() {
                                      isDustErrorTextVisible = true;
                                    });
                                  }
                                },
                                textAlign: TextAlign.center,
                                style: CoconutTypography.body3_12.setColor(
                                  isDustErrorTextVisible || isOverDonationMaxValue
                                      ? CoconutColors.warningText
                                      : CoconutColors.gray100,
                                ),
                                decoration: InputDecoration(
                                  hintText: t.input_directly,
                                  hintStyle: CoconutTypography.body3_12.setColor(
                                    CoconutColors.gray600,
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: isDustErrorTextVisible || isOverDonationMaxValue
                                          ? CoconutColors.warningText
                                          : CoconutColors.gray600,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: CoconutColors.gray100,
                                      width: 1,
                                    ),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.only(bottom: 4),
                                ),
                                cursorColor: CoconutColors.gray100,
                              ),
                            ),
                          ),
                          CoconutLayout.spacing_50w,
                          Text(
                            t.sats,
                            style: CoconutTypography.body2_14_NumberBold.setColor(
                              CoconutColors.gray400,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        Text(
                          amount!.toThousandsSeparatedString(),
                          style: CoconutTypography.body2_14_NumberBold,
                        ),
                        CoconutLayout.spacing_100w,
                        Text(
                          t.sats,
                          style: CoconutTypography.body2_14_NumberBold.setColor(
                            CoconutColors.gray400,
                          ),
                        ),
                      ],
                    )
            ],
          ),
        ),
      ),
    );
  }
}

enum DonationSelectedType { coffee, lateMeal, maintenance, custom, none }
