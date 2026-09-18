import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_edit_bottom_sheet.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:coconut_wallet/utils/wallet_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/tooltip_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_icon.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

import 'dart:math' as math;

import 'package:flutter_svg/svg.dart';

class WalletInfoItemCard extends StatefulWidget {
  final int id;
  final WalletItemBase walletItem;
  final VoidCallback onTooltipClicked;
  final GlobalKey tooltipKey;
  final Function(String) onNameChanged;
  final Function() onShowMfpInputBottomSheet;

  /// 탭루트 지갑에서 현재 선택된 서명 방식이 key path(부모 키)인지 여부.
  /// 그라디언트 방향(부모: 보라→파랑, 자식: 파랑→보라)을 결정하는 데 쓰인다.
  final bool taprootKeyPathSelected;
  const WalletInfoItemCard({
    super.key,
    required this.id,
    required this.walletItem,
    required this.onTooltipClicked,
    required this.tooltipKey,
    required this.onNameChanged,
    required this.onShowMfpInputBottomSheet,
    this.taprootKeyPathSelected = true,
  });

  @override
  State<WalletInfoItemCard> createState() => _WalletInfoItemCardState();
}

class _WalletInfoItemCardState extends State<WalletInfoItemCard> {
  List<MultisigSigner>? signers;
  late int colorIndex;
  late int iconIndex;
  late String rightText;
  late String rightSubText;
  late String nameText;
  late WalletItemBase walletItem;
  WalletImportSource? walletImportSource;

  bool isItemTapped = false; // ui (edit 아이콘)
  bool isCustomAccount = false;

  bool _isWithoutMfp() =>
      walletItem is SinglesigWalletItem &&
      (isWalletWithoutMfp(walletItem) ||
          (walletItem.walletBase as SingleSignatureWallet).keyStore.masterFingerprint ==
              WalletAddService.masterFingerprintPlaceholder);

  bool _isExtendedPublicKey() {
    return walletImportSource == WalletImportSource.extendedPublicKey;
  }

  int _getAccountIndex(String derivationPath) {
    try {
      final segments = derivationPath.split('/');
      if (segments.length > 3) {
        return int.parse(segments[3].replaceAll("'", ""));
      }
    } catch (e) {
      return 0;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _updateFromWalletItem();
  }

  @override
  void didUpdateWidget(covariant WalletInfoItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletItem != widget.walletItem) {
      _updateFromWalletItem();
    }
  }

  void _updateFromWalletItem() {
    walletItem = widget.walletItem;
    signers = null;
    if (walletItem is MultisigWalletItem) {
      /// 멀티 시그
      MultisigWalletItem multiWallet = walletItem as MultisigWalletItem;
      signers = multiWallet.signers;
      colorIndex = multiWallet.colorIndex;
      iconIndex = multiWallet.iconIndex;
      rightText = '';
      rightSubText = '${multiWallet.requiredSignatureCount}/${multiWallet.signers.length}';
      walletImportSource = widget.walletItem.walletImportSource;
      isCustomAccount = false;
    } else if (walletItem is TaprootWalletItem) {
      /// 탭루트
      final taprootWallet = walletItem.walletBase as TaprootWallet;
      colorIndex = widget.walletItem.colorIndex;
      iconIndex = widget.walletItem.iconIndex;
      rightText = _formatCreatedAtInVault((widget.walletItem as TaprootWalletItem).createdAtInVault);
      rightSubText = taprootWallet.derivationPath;
      walletImportSource = widget.walletItem.walletImportSource;
      isCustomAccount = _getAccountIndex(taprootWallet.derivationPath) != 0;
    } else {
      /// 싱글 시그
      final singlesigWallet = walletItem.walletBase as SingleSignatureWallet;
      colorIndex = widget.walletItem.colorIndex;
      iconIndex = widget.walletItem.iconIndex;
      rightText = singlesigWallet.keyStore.masterFingerprint;
      rightSubText = singlesigWallet.derivationPath;
      walletImportSource = widget.walletItem.walletImportSource;

      isCustomAccount = _getAccountIndex(singlesigWallet.derivationPath) != 0;
    }
    nameText = walletItem.name;
  }

  String _formatCreatedAtInVault(DateTime? createdAtInVault) {
    if (createdAtInVault == null) {
      return '';
    }

    final localDateTime = createdAtInVault.toLocal();
    final year = (localDateTime.year % 100).toString().padLeft(2, '0');
    final month = localDateTime.month.toString().padLeft(2, '0');
    final day = localDateTime.day.toString().padLeft(2, '0');
    final hour = localDateTime.hour.toString().padLeft(2, '0');
    final minute = localDateTime.minute.toString().padLeft(2, '0');

    return '$year.$month.$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final taprootStyle =
        widget.walletItem is TaprootWalletItem ? TaprootCardStyle.fromKeyPath(widget.taprootKeyPathSelected) : null;
    final List<Color>? gradientColors =
        signers != null
            ? WalletVisualStyleUtil.getGradientColors(signers!, lighten: true)
            : taprootStyle?.iconGradientColors;
    final bool hasGradient = gradientColors != null;
    final bool isMfpDisplayed =
        walletItem is! TaprootWalletItem &&
        walletItem is! MultisigWalletItem &&
        !_isWithoutMfp() &&
        !_isExtendedPublicKey();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24), // defaultRadius로 통일하면 border 넓이가 균일해보이지 않음
        border: hasGradient ? null : Border.all(color: context.coconutColors.border, width: 1),
        gradient:
            hasGradient
                ? LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  transform: const GradientRotation(math.pi / 10),
                )
                : null,
      ),
      child: Container(
        margin: hasGradient ? const EdgeInsets.all(1) : null,
        padding: const EdgeInsets.all(20),
        decoration:
            hasGradient
                ? BoxDecoration(
                  color: context.coconutColors.surface,
                  borderRadius: BorderRadius.circular(23), // defaultRadius로 통일하면 border 넓이가 균일해보이지 않음
                )
                : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 아이콘
            // TODO: 만약 멀티시그의 외부지갑도 지원하게 된다면 이 부분 수정해야합니다.
            Expanded(
              child: GestureDetector(
                onTapDown: (details) {
                  setState(() {
                    isItemTapped = true;
                  });
                },
                onTapCancel: () {
                  setState(() {
                    isItemTapped = false;
                  });
                },
                onTap: () {
                  setState(() {
                    isItemTapped = false;
                  });
                  _onTap(context, walletImportSource);
                },
                child: Row(
                  children: [
                    _buildIcon(),

                    CoconutLayout.spacing_200w,
                    // 이름
                    Expanded(
                      child: Text(
                        nameText,
                        style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            CoconutLayout.spacing_200w,
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rightText.isNotEmpty)
                  Row(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: TooltipButton(
                                textStyle: (walletItem is TaprootWalletItem
                                        ? CoconutTypography.body3_12_Bold
                                        : isMfpDisplayed
                                        ? CoconutTypography.body2_14_NumberBold
                                        : CoconutTypography.body3_12_NumberBold)
                                    .setColor(context.coconutColors.primaryText),
                                isSelected: false,
                                text: rightText.replaceAllMapped(
                                  RegExp(r'[a-z]+'),
                                  (match) => match.group(0)!.toUpperCase(),
                                ),
                                iconKey: _isWithoutMfp() || _isExtendedPublicKey() ? null : widget.tooltipKey,
                                containerMargin: EdgeInsets.zero,
                                containerPadding: EdgeInsets.zero,
                                iconMargin: const EdgeInsets.only(left: 4),
                                onTap:
                                    _isWithoutMfp() || _isExtendedPublicKey() ? _onMfpEditTap : widget.onTooltipClicked,
                                pressedTextStyle:
                                    _isWithoutMfp() || _isExtendedPublicKey()
                                        ? CoconutTypography.body2_14_NumberBold.setColor(
                                          context.coconutColors.mutedText,
                                        )
                                        : null,
                                defaultIconBuilder:
                                    _isWithoutMfp() || _isExtendedPublicKey()
                                        ? (isPressed) => SvgPicture.asset(
                                          CommonActionIconPath.editOutlined,
                                          width: 14,
                                          colorFilter: ColorFilter.mode(
                                            isPressed
                                                ? context.coconutColors.mutedText
                                                : context.coconutColors.iconSecondary,
                                            BlendMode.srcIn,
                                          ),
                                        )
                                        : (isPressed) => Icon(
                                          Icons.info_outline_rounded,
                                          color:
                                              isPressed
                                                  ? context.coconutColors.mutedText
                                                  : context.coconutColors.iconSecondary,
                                          size: 18,
                                        ),
                                extraIcons:
                                    _isWithoutMfp() || _isExtendedPublicKey()
                                        ? [
                                          TooltipIconAction(
                                            key: widget.tooltipKey,
                                            icon: Icon(
                                              Icons.info_outline_rounded,
                                              color: context.coconutColors.iconSecondary,
                                              size: 18,
                                            ),
                                            onTap: widget.onTooltipClicked,
                                            margin: const EdgeInsets.only(left: 4),
                                          ),
                                        ]
                                        : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          rightSubText,
                          style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context, WalletImportSource? walletImportSource) {
    final bool isExternalWallet = walletImportSource != null && walletImportSource != WalletImportSource.coconutVault;

    if (!isExternalWallet && !isCustomAccount) {
      return;
    }

    CommonBottomSheets.showBottomSheet_100(
      context: context,
      screenName: AnalyticsScreenNames.walletInfoEditSheet,
      isDismissible: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      child: WalletInfoEditBottomSheet(
        id: widget.id,
        walletImportSource: walletImportSource ?? WalletImportSource.coconutVault,
        isCustomAccount: isCustomAccount,
      ),
    ).then((result) {
      if (result != null) {
        var ellipsisName = result.length > 10 ? '${result.substring(0, 7)}...' : result;
        setState(() {
          nameText = ellipsisName;
        });
        widget.onNameChanged(ellipsisName);
      }
    });
  }

  void _onMfpEditTap() {
    widget.onShowMfpInputBottomSheet();
  }

  Widget _buildIcon() {
    final colors = context.coconutColors;
    final bool isExternalWallet = walletImportSource != null && walletImportSource != WalletImportSource.coconutVault;
    final bool shouldShowEditIcon = isExternalWallet || isCustomAccount;
    final pressedIconBackgroundSubtle = Color.alphaBlend(
      colors.surfacePressOverlay.withValues(alpha: colors.surfacePressOverlayOpacity),
      colors.iconBackgroundSubtle,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        WalletIcon(
          walletImportSource: walletImportSource ?? WalletImportSource.coconutVault,
          colorIndex: colorIndex,
          iconIndex: iconIndex,
          isInnerWallet: !isExternalWallet,
        ),
        if (shouldShowEditIcon)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: isItemTapped ? pressedIconBackgroundSubtle : colors.iconBackgroundSubtle,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: colors.shadowDefault, offset: const Offset(1, 1), blurRadius: 6, spreadRadius: 0),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(3.3),
                decoration: BoxDecoration(
                  color: isItemTapped ? pressedIconBackgroundSubtle : colors.iconBackgroundSubtle,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  CommonActionIconPath.editOutlined,
                  width: 10,
                  colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
