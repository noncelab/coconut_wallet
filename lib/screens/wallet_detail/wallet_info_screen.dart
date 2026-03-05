import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/widgets/button/button_group.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:coconut_wallet/widgets/card/multisig_signer_card.dart';
import 'package:coconut_wallet/widgets/card/wallet_info_item_card.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/dialog.dart';
import 'package:coconut_wallet/screens/common/qr_with_copy_text_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

const String kEntryPointWalletList = '/wallet-list';
const String kEntryPointWalletHome = '/wallet-home';

class WalletInfoScreen extends StatefulWidget {
  final int id;
  final bool isMultisig;
  final String entryPoint;
  const WalletInfoScreen({super.key, required this.id, required this.isMultisig, required this.entryPoint});

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
      create:
          (_) => WalletInfoViewModel(
            widget.id,
            Provider.of<AuthProvider>(context, listen: false),
            Provider.of<WalletProvider>(context, listen: false),
            Provider.of<NodeProvider>(context, listen: false),
            widget.isMultisig,
          ),
      child: Consumer<WalletInfoViewModel>(
        builder: (innerContext, viewModel, child) {
          return Stack(
            children: [
              GestureDetector(
                onTapDown: (details) => _removeTooltip(),
                child: Scaffold(
                  backgroundColor: CoconutColors.black,
                  appBar: CoconutAppBar.build(title: '', context: context),
                  body: SafeArea(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
                            child: WalletInfoItemCard(
                              id: widget.id,
                              walletItem: viewModel.walletItemBase,
                              onTooltipClicked: () {
                                // 이미 툴팁이 보이고 있는 상태라면 토글
                                if (_tooltipRemainingTime > 0) {
                                  _removeTooltip();

                                  return;
                                }
                                _removeTooltip();

                                Future.delayed(const Duration(milliseconds: 50), () {
                                  setState(() {
                                    _tooltipRemainingTime = kTooltipDuration;
                                  });

                                  _tooltipTimer?.cancel();
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
                                });
                              },
                              tooltipKey: _walletTooltipKey,
                              onNameChanged: (updatedName) => viewModel.updateWalletName(updatedName),
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
                                    masterFingerprint: viewModel.getSignerMasterFingerprint(index),
                                    derivationPath: viewModel.getSignerBsms(index).derivationPath,
                                  );
                                },
                              ),
                            ),
                          } else ...{
                            CoconutLayout.spacing_800h,
                          },
                          _WalletInfoStatsSection(
                            walletId: widget.id,
                            transactionCount: viewModel.transactionCount,
                            utxoCount: viewModel.utxoCount,
                            balanceSats: viewModel.walletBalance.total,
                            currentUnit: context.read<PreferenceProvider>().currentUnit,
                            targetSats: viewModel.targetSats,
                            onEditTargetTap: () => _showTargetSettingBottomSheet(context, viewModel),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ButtonGroup(
                              buttons: [
                                SingleButton(
                                  enableShrinkAnim: true,
                                  title: t.view_all_addresses,
                                  onPressed: () {
                                    _removeTooltip();
                                    Navigator.pushNamed(context, '/address-list', arguments: {'id': widget.id});
                                  },
                                ),
                                if (!widget.isMultisig) ...{
                                  SingleButton(
                                    enableShrinkAnim: true,
                                    title: t.wallet_info_screen.view_xpub,
                                    onPressed: () async {
                                      _removeTooltip();
                                      _handleAuthFlow(
                                        onComplete: () {
                                          _showExtendedBottomSheet(viewModel.extendedPublicKey);
                                        },
                                      );
                                    },
                                  ),
                                },
                                if (widget.isMultisig) ...{
                                  SingleButton(
                                    enableShrinkAnim: true,
                                    title: t.wallet_info_screen.view_wallet_backup_data,
                                    onPressed: () {
                                      _removeTooltip();

                                      Navigator.pushNamed(
                                        context,
                                        '/wallet-backup-data',
                                        arguments: {'id': widget.id, 'walletName': viewModel.walletName},
                                      );
                                    },
                                  ),
                                },
                                SingleButton(
                                  enableShrinkAnim: true,
                                  title: t.tag_manage_label,
                                  onPressed: () {
                                    _removeTooltip();
                                    Navigator.pushNamed(context, '/utxo-tag', arguments: {'id': widget.id});
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SingleButton(
                              enableShrinkAnim: true,
                              title: t.delete_label,
                              rightElement: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: CoconutColors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SvgPicture.asset(
                                  'assets/svg/trash.svg',
                                  width: 16,
                                  colorFilter: const ColorFilter.mode(CoconutColors.hotPink, BlendMode.srcIn),
                                ),
                              ),
                              onPressed: () {
                                _removeTooltip();
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return CoconutPopup(
                                      languageCode: context.read<PreferenceProvider>().language,
                                      title: t.alert.wallet_delete.confirm_delete,
                                      description: t.alert.wallet_delete.confirm_delete_description,
                                      onTapRight: () {
                                        _handleAuthFlow(
                                          onComplete: () async {
                                            await _deleteWalletAndGoToEntryPoint(context, viewModel);
                                          },
                                        );
                                      },
                                      onTapLeft: () {
                                        Navigator.of(context).pop();
                                      },
                                      rightButtonText: t.delete,
                                      rightButtonColor: CoconutColors.hotPink,
                                      leftButtonText: t.cancel,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          CoconutLayout.spacing_2500h,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: _tooltipTopPadding,
                right:
                    MediaQuery.of(context).size.width -
                    _walletTooltipIconPosition.dx -
                    (_walletTooltipIconRenderBox == null ? 0 : _walletTooltipIconRenderBox!.size.width) -
                    10,
                child: CoconutToolTip(
                  width: MediaQuery.sizeOf(context).width,
                  isBubbleClipperSideLeft: false,
                  tooltipType: CoconutTooltipType.placement,
                  richText: RichText(
                    text: TextSpan(
                      text:
                          widget.isMultisig
                              ? t.tooltip.multisig_wallet(
                                total: viewModel.multisigTotalSignerCount,
                                count: viewModel.multisigRequiredSignerCount,
                              )
                              : t.tooltip.mfp +
                                  (viewModel.isMfpPlaceholder
                                      ? '\n${t.wallet_info_screen.tooltip.mfp_placeholder_description}'
                                      : ''),
                      style: CoconutTypography.body3_12
                          .setColor(CoconutColors.black)
                          .merge(const TextStyle(height: 1.3)),
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
      _walletTooltipIconRenderBox = _walletTooltipKey.currentContext?.findRenderObject() as RenderBox?;
      if (_walletTooltipIconRenderBox != null) {
        _walletTooltipIconPosition = _walletTooltipIconRenderBox!.localToGlobal(Offset.zero);
        _tooltipTopPadding = _walletTooltipIconPosition.dy + _walletTooltipIconRenderBox!.size.height;

        // debugPrint('MediaQuery.paddingOf(context).top = ${MediaQuery.paddingOf(context).top}');
        // debugPrint('kToolbarHeight = $kToolbarHeight');
        // debugPrint(
        //     '_walletTooltipIconRenderBox!.size.height: ${_walletTooltipIconRenderBox!.size.height}');
        // debugPrint('_tooltipTopPadding: $_tooltipTopPadding');
      }
    } catch (e) {
      // debugPrint('Tooltip position initialization failed: $e');
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

  void _showTargetSettingBottomSheet(BuildContext context, WalletInfoViewModel viewModel) {
    final btcString = viewModel.targetSats != null ? _satsToBtcInputString(viewModel.targetSats!) : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _TargetQuantitySettingBottomSheet(
            initialBtcString: btcString,
            onComplete: (text) {
              final btc = double.tryParse(text);
              if (btc == null || btc <= 0) {
                if (text.isNotEmpty) {
                  CoconutToast.showWarningToast(context: context, text: t.wallet_info_screen.target_set_invalid);
                }
                return false;
              }
              if (btc > 21_000_000) {
                CoconutToast.showWarningToast(context: context, text: t.wallet_info_screen.target_set_max_exceeded);
                return false;
              }
              final sats = UnitUtil.convertBitcoinToSatoshi(btc);
              if (sats > 0) {
                viewModel.setTargetSats(sats);
                return true;
              }
              CoconutToast.showWarningToast(context: context, text: t.wallet_info_screen.target_set_invalid);
              return false;
            },
          ),
    );
  }

  static String _satsToBtcInputString(int sats) {
    final btc = sats / 100000000.0;
    return btc.toStringAsFixed(8).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _deleteWalletAndGoToEntryPoint(BuildContext context, WalletInfoViewModel viewModel) async {
    Navigator.of(context).pop();

    final navigator = Navigator.of(context);
    final languageCode = context.read<PreferenceProvider>().language;

    _setOverlayLoading(true);

    try {
      await viewModel.deleteWallet();

      _setOverlayLoading(false);

      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        if (widget.entryPoint == kEntryPointWalletHome) {
          navigator.pushNamedAndRemoveUntil('/', (route) => false);
        } else {
          navigator.pushNamedAndRemoveUntil(kEntryPointWalletList, (route) => route.isFirst);
        }
      }
    } catch (e) {
      debugPrint('Delete wallet failed: $e');
      _setOverlayLoading(false);
      if (mounted) {
        await showInfoDialog(context, languageCode, t.wallet_info_screen.error.delete, e.toString());
      }
    }
  }

  void _setOverlayLoading(bool value) {
    if (!mounted) return;
    if (value) {
      context.loaderOverlay.show();
    } else {
      context.loaderOverlay.hide();
    }
  }

  Future<void> _handleAuthFlow({required VoidCallback onComplete}) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthEnabled) {
      onComplete();
      return;
    }

    if (await authProvider.isBiometricsAuthValid()) {
      onComplete();
      return;
    }

    if (!mounted) return;
    await CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      heightRatio: 0.9,
      child: CustomLoadingOverlay(child: PinCheckScreen(onComplete: onComplete)),
    );
  }

  void _showExtendedBottomSheet(String extendedPublicKey) {
    CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      heightRatio: 0.9,
      child: QrWithCopyTextScreen(qrData: extendedPublicKey, title: t.extended_public_key, showPulldownMenu: false),
    );
  }
}

/// 트랜잭션 수, UTXO 수, 목표 수량 통계 카드
class _WalletInfoStatsSection extends StatelessWidget {
  final int walletId;
  final int transactionCount;
  final int utxoCount;
  final int balanceSats;
  final BitcoinUnit currentUnit;
  final int? targetSats;
  final VoidCallback onEditTargetTap;

  const _WalletInfoStatsSection({
    required this.walletId,
    required this.transactionCount,
    required this.utxoCount,
    required this.balanceSats,
    required this.currentUnit,
    this.targetSats,
    required this.onEditTargetTap,
  });

  static const int _maxBtcSats = 2100000000000000; // 21M BTC

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(label: t.wallet_info_screen.transaction, value: '$transactionCount')),
              const SizedBox(width: 12),
              Expanded(
                child: ShrinkAnimationButton(
                  defaultColor: CoconutColors.gray800,
                  pressedColor: CoconutColors.gray750,
                  borderRadius: 24,
                  onPressed: () {
                    Navigator.pushNamed(context, '/utxo-overview', arguments: {'id': walletId});
                  },
                  child: _StatCard(label: t.wallet_info_screen.utxo, value: '$utxoCount', transparentBackground: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ShrinkAnimationButton(
            defaultColor: CoconutColors.gray800,
            pressedColor: CoconutColors.gray750,
            borderRadius: 24,
            onPressed: onEditTargetTap,
            child: _TargetQuantityCard(
              balanceSats: balanceSats,
              currentUnit: currentUnit,
              targetSats: targetSats,
              maxSats: _maxBtcSats,
              transparentBackground: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool transparentBackground;

  const _StatCard({required this.label, required this.value, this.transparentBackground = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: transparentBackground ? Colors.transparent : CoconutColors.gray800,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray500)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(value, style: CoconutTypography.heading3_21_NumberBold.setColor(CoconutColors.white)),
          ),
        ],
      ),
    );
  }
}

class _TargetQuantityCard extends StatelessWidget {
  final int balanceSats;
  final BitcoinUnit currentUnit;
  final int? targetSats;
  final int maxSats;
  final bool transparentBackground;

  const _TargetQuantityCard({
    required this.balanceSats,
    required this.currentUnit,
    this.targetSats,
    required this.maxSats,
    this.transparentBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTarget = targetSats ?? maxSats;
    final progress = effectiveTarget > 0 ? (balanceSats / effectiveTarget).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: transparentBackground ? Colors.transparent : CoconutColors.gray800,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t.wallet_info_screen.target_quantity,
                style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray500),
              ),
              const SizedBox(width: 4),
              SvgPicture.asset(
                'assets/svg/edit-outlined.svg',
                width: 12,
                height: 12,
                colorFilter: const ColorFilter.mode(CoconutColors.gray500, BlendMode.srcIn),
              ),
            ],
          ),
          const SizedBox(height: 8),
          targetSats == null
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stay humble, stack sats!',
                    style: CoconutTypography.heading4_18_NumberBold.setColor(CoconutColors.gray500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.wallet_info_screen.target_not_set_secondary,
                    style: CoconutTypography.body3_12.setColor(CoconutColors.gray600),
                  ),
                ],
              )
              : _buildTargetProgressText(
                percent: percent,
                amountText: currentUnit.displayBitcoinAmount(effectiveTarget, withUnit: false),
                unitSymbol: currentUnit.symbol,
                isPrefixUnit: currentUnit.isPrefixSymbol,
              ),
          if (targetSats != null) ...[
            SizedBox(
              width: double.infinity,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: CoconutColors.white,
                  inactiveTrackColor: CoconutColors.gray600,
                  thumbColor: CoconutColors.white,
                  overlayColor: CoconutColors.white.withValues(alpha: 0.2),
                  overlayShape: const _VerticalPaddingOverlayShape(),
                  trackHeight: 6,
                  trackShape: const _FullWidthSliderTrackShape(),
                  thumbShape: const _ElongatedSliderThumbShape(),
                ),
                child: IgnorePointer(child: Slider(value: progress, onChanged: (_) {})),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetProgressText({
    required String percent,
    required String amountText,
    required String unitSymbol,
    required bool isPrefixUnit,
  }) {
    final whiteStyle = CoconutTypography.heading3_21_Number.setColor(CoconutColors.white);
    final grayStyle = CoconutTypography.body1_16_Number.setColor(CoconutColors.gray400);

    return RichText(
      text: TextSpan(
        style: whiteStyle,
        children: [
          TextSpan(text: percent, style: whiteStyle),
          TextSpan(text: '%', style: grayStyle),
          TextSpan(text: ' / ', style: whiteStyle),
          if (isPrefixUnit) ...[
            TextSpan(text: '$unitSymbol ', style: grayStyle),
            TextSpan(text: amountText, style: whiteStyle),
          ] else ...[
            TextSpan(text: amountText, style: whiteStyle),
            TextSpan(text: ' $unitSymbol', style: grayStyle),
          ],
        ],
      ),
    );
  }
}

class _VerticalPaddingOverlayShape extends SliderComponentShape {
  const _VerticalPaddingOverlayShape();

  static const double _verticalPadding = 12;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(_ElongatedSliderThumbShape.thumbWidth, _ElongatedSliderThumbShape.thumbHeight + _verticalPadding * 2);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final paint =
        Paint()
          ..color = (sliderTheme.overlayColor ?? sliderTheme.thumbColor ?? CoconutColors.white).withValues(
            alpha: 0.12 * activationAnimation.value,
          );
    final size = getPreferredSize(true, isDiscrete);
    final rect = Rect.fromCenter(center: center, width: size.width, height: size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)), paint);
  }
}

class _FullWidthSliderTrackShape extends RoundedRectSliderTrackShape {
  const _FullWidthSliderTrackShape();

  static const double _verticalPadding = 8;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4;
    final trackLeft = offset.dx;
    final effectiveHeight = parentBox.size.height - _verticalPadding * 2;
    final trackTop = offset.dy + _verticalPadding + (effectiveHeight - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

class _ElongatedSliderThumbShape extends SliderComponentShape {
  const _ElongatedSliderThumbShape();

  static const double thumbWidth = 27;
  static const double thumbHeight = 12;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(thumbWidth, thumbHeight);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    const rect = Rect.fromLTWH(0, 0, thumbWidth, thumbHeight);
    final paint =
        Paint()
          ..color = sliderTheme.thumbColor ?? CoconutColors.white
          ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(center.dx - thumbWidth / 2, center.dy - thumbHeight / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(thumbHeight / 2)), paint);
    canvas.restore();
  }
}

class _TargetQuantitySettingBottomSheet extends StatefulWidget {
  final String initialBtcString;
  final bool Function(String text) onComplete;

  const _TargetQuantitySettingBottomSheet({required this.initialBtcString, required this.onComplete});

  @override
  State<_TargetQuantitySettingBottomSheet> createState() => _TargetQuantitySettingBottomSheetState();
}

class _TargetQuantitySettingBottomSheetState extends State<_TargetQuantitySettingBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.text = widget.initialBtcString;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
      if (widget.initialBtcString.trim().isNotEmpty) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isValueChanged {
    final text = _controller.text.trim();
    return text.isNotEmpty && text != widget.initialBtcString.trim();
  }

  void _handleComplete() {
    FocusScope.of(context).unfocus();
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onComplete(text);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CoconutBottomSheet(
        useIntrinsicHeight: true,
        appBar: CoconutAppBar.buildWithNext(
          title: t.wallet_info_screen.target_set_title,
          context: context,
          onBackPressed: () => Navigator.pop(context),
          onNextPressed: _handleComplete,
          nextButtonTitle: t.done,
          isBottom: true,
          isActive: _isValueChanged,
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 30),
            child: CoconutTextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: (_) => setState(() {}),
              textInputType: const TextInputType.numberWithOptions(decimal: true),
              textInputFormatter: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), _SingleDotInputFormatter()],
              placeholderText: t.wallet_info_screen.target_set_placeholder,
              backgroundColor: CoconutColors.white.withValues(alpha: 0.15),
              errorColor: CoconutColors.hotPink,
              placeholderColor: CoconutColors.gray700,
              activeColor: CoconutColors.white,
              cursorColor: CoconutColors.white,
              maxLength: 17,
              isLengthVisible: false,
              maxLines: 1,
            ),
          ),
        );
      },
    );
  }
}

class _SingleDotInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if ('.'.allMatches(newValue.text).length > 1) return oldValue;
    return newValue;
  }
}
