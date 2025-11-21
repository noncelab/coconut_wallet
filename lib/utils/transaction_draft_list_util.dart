import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';

/// Transaction draft 리스트를 가져와서 최신순으로 정렬하여 반환
List<RealmTransactionDraft> getSortedUnsignedTransactionDrafts(TransactionDraftRepository repository) {
  final allDrafts = repository.getAllTransactionDrafts();
  final unsignedDrafts = allDrafts.where((draft) => draft.signedPsbtBase64Encoded == null).toList();
  final sortedDrafts = unsignedDrafts.toList()..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  return sortedDrafts;
}
