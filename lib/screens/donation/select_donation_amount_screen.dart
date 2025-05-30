import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class SelectDonationAmountScreen extends StatefulWidget {
  const SelectDonationAmountScreen({
    super.key,
  });

  @override
  State<SelectDonationAmountScreen> createState() => _SelectDonationAmountScreenState();
}

class _SelectDonationAmountScreenState extends State<SelectDonationAmountScreen> with RouteAware {
  final GlobalKey _bottomButtonRowKey = GlobalKey();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  DonationSelectedType donationSelectedType = DonationSelectedType.none;

  final donationCoffeeValue = 5000; // 커피 한잔 후원금
  final donationLateMealValue = 10000; // 야근 식대 후원금
  final donationMaintenanceValue = 50000; // 유지 보수비 후원금
  final int dust = 546; // segwit dust

  int? customDonateValue;

  bool isDustErrorTextVisible = false;

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
          FocusScope.of(context).unfocus();
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
                    height: MediaQuery.sizeOf(context).height -
                        kToolbarHeight -
                        MediaQuery.paddingOf(context).top,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Expanded(
                            child: Column(
                          children: [
                            CoconutLayout.spacing_800h,
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
                                t.donation.under_dust_error(dust: dust),
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
                    key: _bottomButtonRowKey,
                    children: [
                      donateBottomButtonWidget(isNetworkOn, true),
                      CoconutLayout.spacing_200w,
                      donateBottomButtonWidget(isNetworkOn, false),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void goNextScreen(bool isNetworkOn, bool isOnchainDonation) {
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

    Navigator.pushNamed(
        context, isOnchainDonation ? '/onchain-donation-info' : '/lightning-donation-info',
        arguments: {'donation-amount': donateValue});
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
        isActive: donationSelectedType != DonationSelectedType.none,
        foregroundColor: CoconutColors.black,
        pressedTextColor: CoconutColors.black,
        pressedBackgroundColor: CoconutColors.gray500,
        disabledBackgroundColor: CoconutColors.gray800,
        disabledForegroundColor: CoconutColors.gray700,
        onPressed: () {
          FocusScope.of(context).unfocus();

          // 네트워크 체크
          if (!isNetworkOn) {
            CoconutToast.showWarningToast(context: context, text: ErrorCodes.networkError.message);
            return;
          }

          if (handleDustThreshold()) return;

          goNextScreen(isNetworkOn, isOnchain);
        },
        text: isOnchain ? t.donation.onchain : t.donation.lightning,
      ),
    );
  }

  bool handleDustThreshold() {
    if (donationSelectedType == DonationSelectedType.custom &&
        customDonateValue != null &&
        customDonateValue! <= dust) {
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

        if (hadFocus) {
          FocusScope.of(context).unfocus();
          if (isCustom && handleDustThreshold()) return;
        }

        setState(() {
          donationSelectedType = donationType;
          if (isDustErrorTextVisible) {
            isDustErrorTextVisible = false;
          }
        });

        if (isCustom && !hadFocus) {
          scrollToBottom();
          _focusNode.requestFocus();
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
                                  scrollToBottom();
                                  donationSelectedType = DonationSelectedType.custom;
                                  setState(() {
                                    isDustErrorTextVisible = false;
                                  });
                                  _controller.selection = TextSelection.fromPosition(
                                    TextPosition(offset: _controller.text.length),
                                  );
                                },
                                onChanged: (input) {
                                  if (isDustErrorTextVisible) {
                                    setState(() {
                                      isDustErrorTextVisible = false;
                                    });
                                  }

                                  if (input.isEmpty) {
                                    customDonateValue = null;
                                    return;
                                  }

                                  customDonateValue = int.parse(input);
                                },
                                focusNode: donationSelectedType == DonationSelectedType.custom
                                    ? _focusNode
                                    : null,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                textInputAction: TextInputAction.done,
                                textAlign: TextAlign.center,
                                style: CoconutTypography.body3_12.setColor(
                                  isDustErrorTextVisible
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
                                      color: isDustErrorTextVisible
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
                          addCommasToIntegerPart(
                            amount!.toDouble(),
                          ),
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
