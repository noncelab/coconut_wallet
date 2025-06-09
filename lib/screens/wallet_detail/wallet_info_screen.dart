import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_list_screen.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/widgets/card/information_item_card.dart';
import 'package:coconut_wallet/widgets/card/multisig_signer_card.dart';
import 'package:coconut_wallet/widgets/card/wallet_info_item_card.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/common/qrcode_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

class WalletInfoScreen extends StatefulWidget {
  final int id;
  final bool isMultisig;
  const WalletInfoScreen({super.key, required this.id, required this.isMultisig});

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
          return Stack(
            children: [
              GestureDetector(
                onTapDown: (details) => _removeTooltip(),
                child: Scaffold(
                  backgroundColor: CoconutColors.black,
                  appBar: CoconutAppBar.build(
                      title: t.wallet_info_screen.title(name: viewModel.walletName),
                      context: context),
                  body: SafeArea(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
                            child: WalletInfoItemCard(
                              id: widget.id,
                              walletItem: viewModel.walletItemBase,
                              onTooltipClicked: () {
                                _removeTooltip();

                                setState(() {
                                  _tooltipRemainingTime = kTooltipDuration;
                                });

                                _tooltipTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
                              onNameChanged: (updatedName) =>
                                  viewModel.updateWalletName(updatedName),
                            ),
                          ),
                          if (widget.isMultisig) ...{
                            Container(
                              margin: const EdgeInsets.only(top: 8, bottom: 32),
                              child: ListView.separated(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: viewModel.multisigTotalSignerCount,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  return MultisigSignerCard(
                                      index: index,
                                      signer: viewModel.getSigner(index),
                                      masterFingerprint:
                                          viewModel.getSignerMasterFingerprint(index));
                                },
                              ),
                            ),
                          } else ...{
                            CoconutLayout.spacing_800h
                          },
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(CoconutStyles.radius_400),
                              color: CoconutColors.gray800,
                            ),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                InformationItemCard(
                                  label: t.view_all_addresses,
                                  showIcon: true,
                                  onPressed: () {
                                    _removeTooltip();
                                    Navigator.pushNamed(context, '/address-list',
                                        arguments: {'id': widget.id});
                                  },
                                ),
                                Divider(color: CoconutColors.white.withOpacity(0.12), height: 1),
                                if (!widget.isMultisig) ...{
                                  InformationItemCard(
                                    label: t.wallet_info_screen.view_xpub,
                                    showIcon: true,
                                    onPressed: () async {
                                      _removeTooltip();
                                      if (viewModel.isSetPin) {
                                        await CommonBottomSheets.showBottomSheet_90(
                                          context: context,
                                          child: CustomLoadingOverlay(
                                            child: PinCheckScreen(
                                              onComplete: () {
                                                CommonBottomSheets.showBottomSheet_90(
                                                  context: context,
                                                  child: QrcodeBottomSheet(
                                                      qrData: viewModel.extendedPublicKey,
                                                      title: t.extended_public_key),
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      } else {
                                        CommonBottomSheets.showBottomSheet_90(
                                          context: context,
                                          child: QrcodeBottomSheet(
                                            qrData: viewModel.extendedPublicKey,
                                            title: t.extended_public_key,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  Divider(color: CoconutColors.white.withOpacity(0.12), height: 1),
                                },
                                InformationItemCard(
                                  label: t.tag_manage_label,
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
                                color: CoconutColors.white,
                              ),
                            ),
                          ),
                          Container(
                            decoration: defaultBoxDecoration,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                InformationItemCard(
                                  showIcon: true,
                                  label: t.delete_label,
                                  rightIcon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: CoconutColors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10)),
                                    child: SvgPicture.asset(
                                      'assets/svg/trash.svg',
                                      width: 16,
                                      colorFilter: const ColorFilter.mode(
                                        CoconutColors.hotPink,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  onPressed: () {
                                    _removeTooltip();
                                    CustomDialogs.showCustomAlertDialog(
                                      context,
                                      title: t.alert.wallet_delete.confirm_delete,
                                      message: t.alert.wallet_delete.confirm_delete_description,
                                      onConfirm: () async {
                                        if (viewModel.isSetPin) {
                                          await CommonBottomSheets.showBottomSheet_90(
                                            context: context,
                                            child: CustomLoadingOverlay(
                                              child: PinCheckScreen(
                                                onComplete: () async {
                                                  await _deleteWalletAndGoToWalletList(
                                                      context, viewModel);
                                                },
                                              ),
                                            ),
                                          );
                                        } else {
                                          await _deleteWalletAndGoToWalletList(context, viewModel);
                                        }
                                      },
                                      onCancel: () {
                                        Navigator.of(context).pop();
                                      },
                                      confirmButtonText: t.delete,
                                      confirmButtonColor: CoconutColors.hotPink,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: _tooltipTopPadding,
                right: MediaQuery.of(context).size.width -
                    _walletTooltipIconPosition.dx -
                    (_walletTooltipIconRenderBox == null
                        ? 0
                        : _walletTooltipIconRenderBox!.size.width) -
                    10,
                child: CoconutToolTip(
                  width: MediaQuery.sizeOf(context).width,
                  isBubbleClipperSideLeft: false,
                  tooltipType: CoconutTooltipType.placement,
                  richText: RichText(
                    text: TextSpan(
                      text: widget.isMultisig
                          ? t.tooltip.multisig_wallet(
                              total: viewModel.multisigTotalSignerCount,
                              count: viewModel.multisigRequiredSignerCount)
                          : t.tooltip.mfp +
                              (viewModel.isMfpPlaceholder
                                  ? '\n${t.wallet_info_screen.tooltip.mfp_placeholder_description}'
                                  : ''),
                      style: CoconutTypography.body3_12.setColor(CoconutColors.black).merge(
                            const TextStyle(
                              height: 1.3,
                            ),
                          ),
                    ),
                  ),
                  onTapRemove: _removeTooltip,
                  isPlacementTooltipVisible: _tooltipRemainingTime > 0,
                ),
              ),
            ],
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
      _setOverlayLoading(false);
    });
  }

  void _initializeTooltipPosition() {
    try {
      _walletTooltipIconRenderBox =
          _walletTooltipKey.currentContext?.findRenderObject() as RenderBox?;
      if (_walletTooltipIconRenderBox != null) {
        _walletTooltipIconPosition = _walletTooltipIconRenderBox!.localToGlobal(Offset.zero);
        _tooltipTopPadding =
            _walletTooltipIconPosition.dy + _walletTooltipIconRenderBox!.size.height;

        debugPrint('MediaQuery.paddingOf(context).top = ${MediaQuery.paddingOf(context).top}');
        debugPrint('kToolbarHeight = $kToolbarHeight');
        debugPrint(
            '_walletTooltipIconRenderBox!.size.height: ${_walletTooltipIconRenderBox!.size.height}');
        debugPrint('_tooltipTopPadding: $_tooltipTopPadding');
      }
    } catch (e) {
      debugPrint('Tooltip position initialization failed: $e');
      _walletTooltipIconPosition = Offset.zero;
    }
  }

  _removeTooltip() {
    if (_tooltipRemainingTime == 0) return;
    setState(() {
      _tooltipRemainingTime = 0;
    });
    _tooltipTimer?.cancel();
  }

  Future<void> _deleteWalletAndGoToWalletList(
      BuildContext context, WalletInfoViewModel viewModel) async {
    Navigator.of(context).pop();
    _setOverlayLoading(true);
    await viewModel.deleteWallet();
    _setOverlayLoading(false);
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (BuildContext context) => const WalletListScreen()),
          (route) => false);
    }
  }

  void _setOverlayLoading(bool value) {
    if (value) {
      context.loaderOverlay.show();
    } else {
      context.loaderOverlay.hide();
    }
  }
}
