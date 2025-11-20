import 'dart:convert';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/icon/wallet_icon_small.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:realm/realm.dart';

class TransactionDraftCard extends StatelessWidget {
  final RealmTransactionDraft transactionDraft;
  const TransactionDraftCard({super.key, required this.transactionDraft});

  @override
  Widget build(BuildContext context) {
    final walletId = transactionDraft.walletId;
    // recipientListJson에서 amount 합산 (BTC 단위)
    final totalAmount = transactionDraft.recipientListJson.fold<double>(0.0, (sum, jsonString) {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final amountStr = json['amount'] as String? ?? '0';
      final amount = double.tryParse(amountStr) ?? 0.0;
      return sum + amount;
    });
    final currentUnit = transactionDraft.currentUnit;
    // BTC를 사토시로 변환
    final totalAmountSats = currentUnit == t.btc ? UnitUtil.convertBitcoinToSatoshi(totalAmount) : totalAmount.toInt();
    final feeRate = transactionDraft.feeRate;
    final isMaxMode = transactionDraft.isMaxMode;
    final isMultisig = transactionDraft.isMultisig;
    final isFeeSubtractedFromSendAmount = transactionDraft.isFeeSubtractedFromSendAmount;
    final transactionHex = transactionDraft.transactionHex;
    final txWaitingForSign = transactionDraft.txWaitingForSign;
    final signedPsbtBase64Encoded = transactionDraft.signedPsbtBase64Encoded;
    final recipientListJson = transactionDraft.recipientListJson;
    final createdAt = transactionDraft.createdAt;
    final formattedCreatedAt = DateTimeUtil.formatTimestamp(createdAt!.toLocal());

    final selectedUtxoListJson = transactionDraft.selectedUtxoListJson;
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

    debugPrint('formattedSelectedUtxoList: $formattedSelectedUtxoList');
    debugPrint('formattedCreatedAt: $formattedCreatedAt');
    debugPrint('totalAmountSats: $totalAmountSats');
    debugPrint('feeRate: $feeRate');
    debugPrint('isMaxMode: $isMaxMode');
    debugPrint('isMultisig: $isMultisig');
    debugPrint('isFeeSubtractedFromSendAmount: $isFeeSubtractedFromSendAmount');
    debugPrint('transactionHex: $transactionHex');
    debugPrint('txWaitingForSign: $txWaitingForSign');
    debugPrint('signedPsbtBase64Encoded: $signedPsbtBase64Encoded');
    debugPrint('recipientListJson: $recipientListJson');
    debugPrint('selectedUtxoListJson: $selectedUtxoListJson');
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

    return ShrinkAnimationButton(
      onPressed: () {
        debugPrint('TransactionDraftCard onPressed');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sizes.size24, vertical: Sizes.size16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimestamp(formattedCreatedAt),
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
            _buildRecipientAddress(recipientListJson),
            CoconutLayout.spacing_200h,
            _buildFeeRate(feeRate ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestamp(List<String> transactionTimeStamp) {
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
        Text(amountString, style: CoconutTypography.body1_16_Number.setColor(CoconutColors.white)),
      ],
    );
  }

  Widget _buildRecipientAddress(RealmList<String> recipientListJson) {
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

  Widget _buildFeeRate(int feeRate) {
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
