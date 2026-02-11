import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

TransactionDraft mapRealmTxDraftToTxDraft(RealmTransactionDraft realmDraft, String? signedPsbtBase64Encoded) {
  return TransactionDraft(
    id: realmDraft.id,
    walletId: realmDraft.walletId,
    feeRate: realmDraft.feeRate,
    isMaxMode: realmDraft.isMaxMode,
    isFeeSubtractedFromSendAmount: realmDraft.isFeeSubtractedFromSendAmount,
    recipients: RecipientDraft.fromJsonStringList(realmDraft.recipientJsons),
    createdAt: realmDraft.createdAt,
    bitcoinUnit: realmDraft.bitcoinUnit == null ? null : BitcoinUnit.getFromSymbol(realmDraft.bitcoinUnit!),
    selectedUtxoIds: realmDraft.selectedUtxoIds.map((utxoId) => utxoId).toList(),
    txWaitingForSign: realmDraft.txWaitingForSign,
    signedPsbtBase64Encoded: signedPsbtBase64Encoded,
  );
}

RealmTransactionDraft mapTxDraftToRealmTxDraft(TransactionDraft draft) {
  return RealmTransactionDraft(
    draft.id,
    draft.walletId,
    draft.createdAt,
    draft.feeRate,
    draft.isMaxMode,
    recipientJsons: RecipientDraft.toJsonList(draft.recipients),
    isFeeSubtractedFromSendAmount: draft.isFeeSubtractedFromSendAmount,
    bitcoinUnit: draft.bitcoinUnit?.symbol,
    selectedUtxoIds: draft.selectedUtxoIds,
    txWaitingForSign: draft.txWaitingForSign,
  );
}
