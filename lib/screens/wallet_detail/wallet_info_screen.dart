import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/card/information_item_card.dart';
import 'package:coconut_wallet/widgets/card/multisig_signer_card.dart';
import 'package:coconut_wallet/widgets/card/wallet_info_item_card.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/common/qrcode_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class WalletInfoScreen extends StatefulWidget {
  final int id;
  final bool isMultisig;
  const WalletInfoScreen(
      {super.key, required this.id, required this.isMultisig});

  @override
  State<WalletInfoScreen> createState() => _WalletInfoScreenState();
}

class _WalletInfoScreenState extends State<WalletInfoScreen> {
  final GlobalKey _walletTooltipKey = GlobalKey();
  static const int kTooltipDuration = 5;
  RenderBox? _walletTooltipIconRenderBox;
  Offset _walletTooltipIconPosition = Offset.zero;
  double _tooltipTopPadding = 0;
  Timer? _tooltipTimer;
  int _tooltipRemainingTime = 0;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WalletInfoViewModel>(
      create: (_) => WalletInfoViewModel(
        widget.id,
        Provider.of<AuthProvider>(_, listen: false),
        Provider.of<WalletProvider>(_, listen: false),
        widget.isMultisig,
      ),
      child: Consumer<WalletInfoViewModel>(
        builder: (_, viewModel, child) {
          return Scaffold(
            backgroundColor: MyColors.black,
            appBar: CoconutAppBar.build(
              context: context,
              title: t.wallet_info_screen.title(name: viewModel.walletName),
              hasRightIcon: false,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 20, left: 16, right: 16),
                          child: WalletInfoItemCard(
                            walletItem: viewModel.walletItemBase,
                            onTooltipClicked: () {
                              _removeTooltip();

                              setState(() {
                                _tooltipRemainingTime = kTooltipDuration;
                              });

                              _tooltipTimer = Timer.periodic(
                                  const Duration(seconds: 1), (timer) {
                                setState(() {
                                  if (_tooltipRemainingTime > 0) {
                                    _tooltipRemainingTime--;
                                  } else {
                                    _removeTooltip();
                                    timer.cancel();
                                  }
                                });
                              });
                            },
                            tooltipKey: _walletTooltipKey,
                          ),
                        ),
                        if (widget.isMultisig) ...{
                          Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 32),
                            child: ListView.separated(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: viewModel.multisigTotalSignerCount,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                return MultisigSignerCard(
                                    index: index,
                                    signer: viewModel.getSigner(index),
                                    masterFingerprint: viewModel
                                        .getSignerMasterFingerprint(index));
                              },
                            ),
                          ),
                        } else ...{
                          const SizedBox(height: 32),
                        },
                        Container(
                          decoration: BoxDecorations.boxDecoration,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              InformationItemCard(
                                label: t.view_all_addresses,
                                showIcon: true,
                                onPressed: () {
                                  if (viewModel.walletInitState ==
                                      WalletInitState.processing) {
                                    CustomToast.showToast(
                                      context: context,
                                      text: t.toast.fetching_onchain_data,
                                    );
                                    return;
                                  }
                                  _removeTooltip();
                                  Navigator.pushNamed(context, '/address-list',
                                      arguments: {'id': widget.id});
                                },
                              ),
                              const Divider(
                                  color: MyColors.transparentWhite_12,
                                  height: 1),
                              if (!widget.isMultisig) ...{
                                InformationItemCard(
                                  label: t.wallet_info_screen.view_xpub,
                                  showIcon: true,
                                  onPressed: () async {
                                    _removeTooltip();
                                    if (viewModel.isSetPin) {
                                      await CommonBottomSheets
                                          .showCustomBottomSheet(
                                        context: context,
                                        child: PinCheckScreen(
                                          onComplete: () {
                                            CommonBottomSheets
                                                .showCustomBottomSheet(
                                              context: context,
                                              child: QrcodeBottomSheet(
                                                qrData:
                                                    viewModel.extendedPublicKey,
                                                title: t.extended_public_key,
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    } else {
                                      CommonBottomSheets.showCustomBottomSheet(
                                        context: context,
                                        child: QrcodeBottomSheet(
                                          qrData: viewModel.extendedPublicKey,
                                          title: t.extended_public_key,
                                        ),
                                      );
                                    }
                                  },
                                ),
                                const Divider(
                                    color: MyColors.transparentWhite_12,
                                    height: 1),
                              },
                              InformationItemCard(
                                label: t.tag_manage,
                                showIcon: true,
                                onPressed: () {
                                  Navigator.pushNamed(context, '/utxo-tag',
                                      arguments: {'id': widget.id});
                                },
                              ),
                            ],
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 65,
                            height: 1,
                            margin: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1),
                              color: MyColors.white,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecorations.boxDecoration,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              InformationItemCard(
                                showIcon: true,
                                label: t.delete,
                                rightIcon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: MyColors.defaultBackground,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: SvgPicture.asset(
                                    'assets/svg/trash.svg',
                                    width: 16,
                                    colorFilter: const ColorFilter.mode(
                                      MyColors.warningRed,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                                onPressed: () {
                                  if (viewModel.walletInitState ==
                                      WalletInitState.processing) {
                                    CustomToast.showToast(
                                      context: context,
                                      text: t.toast.fetching_onchain_data,
                                    );
                                    return;
                                  }
                                  _removeTooltip();
                                  CustomDialogs.showCustomDialog(
                                    context,
                                    title: t.alert.wallet_delete.confirm_delete,
                                    description: t.alert.wallet_delete
                                        .confirm_delete_description,
                                    rightButtonColor: CoconutColors.red,
                                    rightButtonText: t.delete,
                                    onTapRight: () async {
                                      if (viewModel.isSetPin) {
                                        await CommonBottomSheets
                                            .showCustomBottomSheet(
                                          context: context,
                                          child: CustomLoadingOverlay(
                                            child: PinCheckScreen(
                                              onComplete: () async {
                                                await viewModel.deleteWallet();
                                                Navigator.popUntil(context,
                                                    (route) => route.isFirst);
                                              },
                                            ),
                                          ),
                                        );
                                      } else {
                                        await viewModel.deleteWallet();
                                        Navigator.popUntil(
                                            context, (route) => route.isFirst);
                                      }
                                    },
                                    onTapLeft: () {
                                      Navigator.of(context).pop();
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: _walletTooltipIconPosition.dy -
                          _tooltipTopPadding +
                          5,
                      right: MediaQuery.of(context).size.width -
                          _walletTooltipIconPosition.dx -
                          (_walletTooltipIconRenderBox == null
                              ? 0
                              : _walletTooltipIconRenderBox!.size.width) -
                          10,
                      child: CoconutToolTip(
                        tooltipType: CoconutTooltipType.placement,
                        width: MediaQuery.sizeOf(context).width,
                        backgroundColor: CoconutColors.white,
                        isBubbleClipperSideLeft: false,
                        isPlacementTooltipVisible: _tooltipRemainingTime > 0,
                        richText: RichText(
                          text: TextSpan(
                            text: widget.isMultisig
                                ? t.tooltip.multisig_wallet(
                                    total: viewModel.multisigTotalSignerCount,
                                    count:
                                        viewModel.multisigRequiredSignerCount)
                                : t.tooltip.mfp,
                            style: CoconutTypography.body3_12.setColor(
                              CoconutColors.black,
                            ),
                          ),
                        ),
                        onTapRemove: _removeTooltip,
                      ),
                    ),
                    // CustomTooltip(
                    //   top: _walletTooltipIconPosition.dy - _tooltipTopPadding,
                    //   right: MediaQuery.of(context).size.width -
                    //       _walletTooltipIconPosition.dx -
                    //       (_walletTooltipIconRenderBox == null
                    //           ? 0
                    //           : _walletTooltipIconRenderBox!.size.width) -
                    //       10,
                    //   text: widget.isMultisig
                    //       ? t.tooltip.multisig_wallet(
                    //           total: viewModel.multisigTotalSignerCount,
                    //           count: viewModel.multisigRequiredSignerCount)
                    //       : t.tooltip.mfp,
                    //   onTap: _removeTooltip,
                    //   topPadding: _tooltipTopPadding,
                    //   isVisible: _tooltipRemainingTime > 0,
                    // ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTooltipPosition();
    });
  }

  void _initializeTooltipPosition() {
    try {
      _walletTooltipIconRenderBox =
          _walletTooltipKey.currentContext?.findRenderObject() as RenderBox?;
      if (_walletTooltipIconRenderBox != null) {
        _walletTooltipIconPosition =
            _walletTooltipIconRenderBox!.localToGlobal(Offset.zero);
        _tooltipTopPadding =
            MediaQuery.paddingOf(context).top + kToolbarHeight - 8;
      }
    } catch (e) {
      debugPrint('Tooltip position initialization failed: $e');
      _walletTooltipIconPosition = Offset.zero;
    }
  }

  _removeTooltip() {
    setState(() {
      _tooltipRemainingTime = 0;
    });
    _tooltipTimer?.cancel();
  }
}
