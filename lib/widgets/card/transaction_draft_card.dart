import 'dart:convert';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/icon/wallet_icon_small.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:realm/realm.dart';

class TransactionDraftCard extends StatefulWidget {
  final RealmTransactionDraft transactionDraft;
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
  final double _swipeThreshold = 0.2; // 20% 스와이프
  late AnimationController _animationController;
  late Animation<double> _animation;

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
      if (widget.isSwiped != null && widget.isSwiped!) {
        _animateToSwipedPosition();
      } else {
        _animateToOriginalPosition();
      }
    }
  }

  void _animateToSwipedPosition() {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset = -screenWidth * _swipeThreshold;

    // 기존 리스너 제거
    _animation.removeListener(_animationListener);
    _animationController.stop();
    _animationController.reset();

    _animation = Tween<double>(
      begin: _dragOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _animation.addListener(_animationListener);
    _animationController.forward();
  }

  void _animateToOriginalPosition() {
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
    final totalAmount = widget.transactionDraft.recipientListJson.fold<double>(0.0, (sum, jsonString) {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final amountStr = json['amount'] as String? ?? '0';
      final amount = double.tryParse(amountStr) ?? 0.0;
      return sum + amount;
    });
    final currentUnit = widget.transactionDraft.currentUnit;
    // BTC를 사토시로 변환
    final totalAmountSats = currentUnit == t.btc ? UnitUtil.convertBitcoinToSatoshi(totalAmount) : totalAmount.toInt();
    final totalAmountForSignedTransaction = widget.transactionDraft.totalAmount;
    final feeRate = widget.transactionDraft.feeRate;
    final isMaxMode = widget.transactionDraft.isMaxMode;
    final isMultisig = widget.transactionDraft.isMultisig;
    final isFeeSubtractedFromSendAmount = widget.transactionDraft.isFeeSubtractedFromSendAmount;
    final transactionHex = widget.transactionDraft.transactionHex;
    final txWaitingForSign = widget.transactionDraft.txWaitingForSign;
    final signedPsbtBase64Encoded = widget.transactionDraft.signedPsbtBase64Encoded;
    final recipientListJson = widget.transactionDraft.recipientListJson;
    final createdAt = widget.transactionDraft.createdAt;
    final formattedCreatedAt = createdAt != null ? DateTimeUtil.formatTimestamp(createdAt.toLocal()) : <String>[];

    final selectedUtxoListJson = widget.transactionDraft.selectedUtxoListJson;
    final formattedSelectedUtxoList =
        selectedUtxoListJson.map((jsonString) {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          return UtxoState(
            transactionHash: json['transactionHash'] as String,
            index: json['index'] as int,
            amount: json['amount'] as int,
            derivationPath: json['derivationPath'] as String,
            blockHeight: json['blockHeight'] as int,
            to: json['to'] as String,
            timestamp: DateTime.parse(json['timestamp'] as String),
          );
        }).toList();

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
              // 삭제 버튼
              if (widget.onDelete != null)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: CoconutColors.gray800,
                      borderRadius: BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: screenWidth * _swipeThreshold + 20,
                        height: double.infinity,
                        child: GestureDetector(
                          onTap: widget.onDelete,
                          child: Container(
                            decoration: const BoxDecoration(color: CoconutColors.hotPink),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CoconutLayout.spacing_500w,
                                SvgPicture.asset(
                                  'assets/svg/trash.svg',
                                  width: 24,
                                  colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (widget.onSwipeChanged == null) return;
                  if (details.delta.dx < 0) {
                    // 왼쪽으로 드래그
                    setState(() {
                      _dragOffset = (_dragOffset + details.delta.dx).clamp(-screenWidth * _swipeThreshold, 0);
                    });
                  } else if (details.delta.dx > 0 && _dragOffset < 0) {
                    // 오른쪽으로 드래그 (복원)
                    setState(() {
                      _dragOffset = (_dragOffset + details.delta.dx).clamp(-screenWidth * _swipeThreshold, 0);
                    });
                  }
                },
                onHorizontalDragEnd: (details) {
                  if (widget.onSwipeChanged == null) return;
                  final threshold = screenWidth * _swipeThreshold;
                  if (_dragOffset.abs() >= threshold * 0.5) {
                    // 50% 이상 스와이프되면 완전히 열기
                    widget.onSwipeChanged?.call(true);
                    _animateToSwipedPosition();
                  } else {
                    // 그렇지 않으면 닫기
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
                        _buildTimestamp(formattedCreatedAt),
                        CoconutLayout.spacing_200h,
                        _buildWalletNameAmount(
                          walletImportSource,
                          walletName,
                          totalAmountForSignedTransaction,
                          totalAmountSats,
                          iconIndex,
                          colorIndex,
                          signers,
                          context.read<PreferenceProvider>().currentUnit,
                          isMaxMode ?? false,
                        ),
                        CoconutLayout.spacing_200h,
                        _buildRecipientAddress(recipientListJson),
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

  Widget _buildTimestamp(List<String> transactionTimeStamp) {
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
      ],
    );
  }

  Widget _buildWalletNameAmount(
    WalletImportSource walletImportSource,
    String walletName,
    int? totalAmountForSignedTransaction,
    int amountSats,
    int iconIndex,
    int colorIndex,
    List<MultisigSigner>? signers,
    BitcoinUnit currentUnit,
    bool isMaxMode,
  ) {
    String amountString = currentUnit.displayBitcoinAmount(
      totalAmountForSignedTransaction ?? amountSats,
      withUnit: true,
    );
    if (amountString != '0 BTC') {
      amountString = '- $amountString';
    } else {
      amountString = '';
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            WalletIconSmall(
              walletImportSource: walletImportSource,
              iconIndex: iconIndex,
              colorIndex: colorIndex,
              gradientColors: signers != null ? ColorUtil.getGradientColors(signers) : null,
            ),
            CoconutLayout.spacing_150w,
            Text(walletName, style: CoconutTypography.body2_14.setColor(CoconutColors.white)),
          ],
        ),
        CoconutLayout.spacing_200w,
        Text(
          isMaxMode ? t.transaction_draft.max : amountString,
          style: CoconutTypography.body1_16_Number.setColor(CoconutColors.white),
        ),
      ],
    );
  }

  Widget _buildRecipientAddress(RealmList<String> recipientListJson) {
    if (recipientListJson.isEmpty) {
      return const SizedBox.shrink();
    }

    bool isBatchTransaction = recipientListJson.length > 1;
    final firstRecipientAddress = jsonDecode(recipientListJson[0])['address'] as String;
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
