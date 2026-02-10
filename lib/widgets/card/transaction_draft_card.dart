import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/icon/wallet_icon_small.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class TransactionDraftCard extends StatefulWidget {
  final TransactionDraft transactionDraft;
  final bool? isSwiped;
  final void Function(bool isSwiped)? onSwipeChanged;
  final VoidCallback? onDelete;
  final bool isSelectable;
  final bool isSelected;
  final VoidCallback? onTap;

  const TransactionDraftCard({
    super.key,
    required this.transactionDraft,
    this.isSwiped,
    this.onSwipeChanged,
    this.onDelete,
    this.isSelectable = false,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<TransactionDraftCard> createState() => _TransactionDraftCardState();
}

class _TransactionDraftCardState extends State<TransactionDraftCard> with SingleTickerProviderStateMixin {
  late double _dragOffset;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isAnimating = false;
  VoidCallback? _pendingOnComplete;
  final double _deleteThreshold = 0.2; // 20% 이상 스와이프 시 삭제

  @override
  void initState() {
    super.initState();
    _dragOffset = 0;
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _animation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TransactionDraftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSwiped != widget.isSwiped) {
      if (widget.isSwiped != null && !widget.isSwiped!) {
        _animateToOriginalPosition();
      }
    }
  }

  void _animateToOriginalPosition() {
    _isAnimating = true;
    _pendingOnComplete = null;

    // 기존 리스너 제거
    _animation.removeListener(_animationListener);
    _animationController.stop();
    _animationController.reset();

    _animation = Tween<double>(
      begin: _dragOffset,
      end: 0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _animation.addListener(_animationListener);
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _animation.removeListener(_animationListener);
        _isAnimating = false;
      }
    });
    _animationController.forward();
  }

  void _animateToDeletePosition({VoidCallback? onComplete}) {
    final screenWidth = MediaQuery.of(context).size.width;

    _isAnimating = true;
    _pendingOnComplete = onComplete;

    // 기존 리스너 제거
    _animation.removeListener(_animationListener);
    _animationController.stop();
    _animationController.reset();

    _animation = Tween<double>(
      begin: _dragOffset,
      end: -screenWidth,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _animation.addListener(_animationListener);
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animation.removeListener(_animationListener);
        _isAnimating = false;
        final callback = _pendingOnComplete;
        _pendingOnComplete = null; // 콜백 무효화
        callback?.call();
      }
    });
    _animationController.forward();
  }

  void _animationListener() {
    if (mounted) {
      setState(() {
        _dragOffset = _animation.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final walletId = widget.transactionDraft.walletId;
    // recipientListJson에서 amount 합산 (BTC 단위)
    final int totalAmountSats = widget.transactionDraft.recipients.fold<int>(0, (sum, recipient) {
      return sum + recipient.amount;
    });
    final feeRate = widget.transactionDraft.feeRate;
    final isMaxMode = widget.transactionDraft.isMaxMode;
    final recipients = widget.transactionDraft.recipients;
    final createdAt = widget.transactionDraft.createdAt;
    final formattedCreatedAt = DateTimeUtil.formatTimestamp(createdAt.toLocal());

    String walletName;
    int iconIndex;
    int colorIndex;
    WalletImportSource walletImportSource;
    List<MultisigSigner>? signers;
    try {
      final wallet = context.read<WalletProvider>().getWalletById(walletId);
      walletName = wallet.name;
      iconIndex = wallet.iconIndex;
      colorIndex = wallet.colorIndex;
      walletImportSource = wallet.walletImportSource;
      if (wallet.walletType == WalletType.multiSignature) {
        signers = (wallet as MultisigWalletListItem).signers;
      }
    } catch (e) {
      // 삭제된 지갑인 경우
      walletName = t.transaction_draft.deleted_wallet;
      iconIndex = 0;
      colorIndex = 0;
      walletImportSource = WalletImportSource.coconutVault;
      signers = null;
    }

    return SizedBox(
      width: screenWidth - 32,
      child: ShrinkAnimationButton(
        borderRadius: 12,
        onPressed: () async {
          if (_dragOffset != 0) {
            // 스와이프된 상태면 닫기
            widget.onSwipeChanged?.call(false);
          } else {
            if (widget.onTap != null) {
              widget.onTap!.call();
            } else {
              // 임시 저장 트랜잭션 화면에서 카드를 눌렀을 때 -> 화면 이동
              await Navigator.pushNamed(
                context,
                '/send',
                arguments: {
                  'walletId': null,
                  'sendEntryPoint': SendEntryPoint.home,
                  'transactionDraft': widget.transactionDraft,
                },
              );
            }
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // 빨간색 배경 (시각적 피드백용)
              if (widget.onDelete != null)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: CoconutColors.hotPink,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/svg/trash.svg',
                          width: 24,
                          colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                        ),
                      ],
                    ),
                  ),
                ),
              GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (widget.onSwipeChanged == null || _isAnimating) return;
                  if (details.delta.dx < 0) {
                    // 왼쪽으로 드래그
                    setState(() {
                      _dragOffset = (_dragOffset + details.delta.dx).clamp(-screenWidth, 0);
                    });
                  } else if (details.delta.dx > 0 && _dragOffset < 0) {
                    // 오른쪽으로 드래그 (복원)
                    setState(() {
                      _dragOffset = (_dragOffset + details.delta.dx).clamp(-screenWidth, 0);
                    });
                  }
                },
                onHorizontalDragEnd: (details) {
                  if (widget.onSwipeChanged == null || _isAnimating) return;

                  final deleteThresholdPx = screenWidth * _deleteThreshold;

                  if (_dragOffset.abs() >= deleteThresholdPx) {
                    // 20% 이상 스와이프되면 100% 왼쪽으로 이동 후 삭제 다이얼로그 호출
                    widget.onSwipeChanged?.call(true); // 스와이프 중 상태로 설정
                    _animateToDeletePosition(
                      onComplete: () {
                        widget.onDelete?.call();
                      },
                    );
                  } else {
                    // 20% 미만이면 원래 위치로 복귀
                    widget.onSwipeChanged?.call(false);
                    _animateToOriginalPosition();
                  }
                },
                child: Transform.translate(
                  offset: Offset(_dragOffset, 0),
                  child: Container(
                    decoration: BoxDecoration(color: CoconutColors.gray800, borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: Sizes.size24, vertical: Sizes.size16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTimestampAndMax(formattedCreatedAt, isMaxMode ?? false),
                        CoconutLayout.spacing_200h,
                        _buildWalletNameAmount(
                          walletImportSource,
                          walletName,
                          totalAmountSats,
                          iconIndex,
                          colorIndex,
                          signers,
                          context.read<PreferenceProvider>().currentUnit,
                        ),
                        CoconutLayout.spacing_200h,
                        _buildRecipientAddress(recipients),
                        CoconutLayout.spacing_200h,
                        _buildFeeRate(feeRate ?? 0),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.isSelectable && widget.isSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CoconutColors.gray350, width: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimestampAndMax(List<String> transactionTimeStamp, bool isMaxMode) {
    if (transactionTimeStamp.isEmpty) {
      return const SizedBox.shrink();
    }
    final textStyle = CoconutTypography.body3_12_Number.setColor(CoconutColors.gray400);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(transactionTimeStamp[0], style: textStyle),
        CoconutLayout.spacing_200w,
        Container(width: 1, height: 10, color: CoconutColors.gray600),
        CoconutLayout.spacing_200w,
        Text(transactionTimeStamp[1], style: textStyle),
        if (isMaxMode) ...[const Spacer(), Text(t.transaction_draft.max, style: textStyle)],
      ],
    );
  }

  Widget _buildWalletNameAmount(
    WalletImportSource walletImportSource,
    String walletName,
    int amountSats,
    int iconIndex,
    int colorIndex,
    List<MultisigSigner>? signers,
    BitcoinUnit currentUnit,
  ) {
    String amountString = currentUnit.displayBitcoinAmount(amountSats, withUnit: true);
    if (amountString != '0 BTC') {
      amountString = '- $amountString';
    } else {
      amountString = '';
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              WalletIconSmall(
                walletImportSource: walletImportSource,
                iconIndex: iconIndex,
                colorIndex: colorIndex,
                gradientColors: signers != null ? ColorUtil.getGradientColors(signers) : null,
              ),
              CoconutLayout.spacing_150w,
              Expanded(
                child: Text(
                  walletName,
                  style: CoconutTypography.body2_14.setColor(CoconutColors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        CoconutLayout.spacing_200w,
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(amountString, style: CoconutTypography.body1_16_Number.setColor(CoconutColors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientAddress(List<RecipientDraft> recipientListJson) {
    if (recipientListJson.isEmpty) {
      return const SizedBox.shrink();
    }

    bool isBatchTransaction = recipientListJson.length > 1;
    final firstRecipientAddress = recipientListJson[0].address;
    return isBatchTransaction
        ? Text(
          t.transaction_draft.recipient_batch_address(
            address: firstRecipientAddress,
            count: recipientListJson.length - 1,
          ),
          style: CoconutTypography.body3_12.setColor(CoconutColors.white),
        )
        : Text(firstRecipientAddress, style: CoconutTypography.body3_12.setColor(CoconutColors.white));
  }

  Widget _buildFeeRate(double feeRate) {
    return Row(
      children: [
        Text(t.transaction_draft.fee_rate, style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
        CoconutLayout.spacing_100w,
        Text(feeRate.toString(), style: CoconutTypography.body3_12.setColor(CoconutColors.white)),
        CoconutLayout.spacing_100w,
        Text(t.transaction_draft.sats_per_vbyte, style: CoconutTypography.body3_12.setColor(CoconutColors.white)),
      ],
    );
  }
}
