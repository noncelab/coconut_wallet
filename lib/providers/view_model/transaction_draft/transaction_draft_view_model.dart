import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:flutter/material.dart';

class TransactionDraftViewModel extends ChangeNotifier {
  final TransactionDraftRepository _transactionDraftRepository;

  /// Wallet variables ---------------------------------------------------------
  List<RealmTransactionDraft> _unsignedTransactionDraftList = [];
  List<RealmTransactionDraft> _signedTransactionDraftList = [];

  TransactionDraftViewModel(this._transactionDraftRepository, int id);

  List<RealmTransactionDraft> get signedTransactionDraftList => _signedTransactionDraftList;
  List<RealmTransactionDraft> get unsignedTransactionDraftList => _unsignedTransactionDraftList;

  Future<void> initializeDraftList() async {
    final draft = _transactionDraftRepository.getAllTransactionDrafts();

    // createdAt 기준 최신순으로 정렬
    final sortedDrafts =
        draft.toList()..sort((a, b) {
          final aCreatedAt = a.createdAt;
          final bCreatedAt = b.createdAt;
          if (aCreatedAt == null && bCreatedAt == null) return 0;
          if (aCreatedAt == null) return 1; // null은 뒤로
          if (bCreatedAt == null) return -1; // null은 뒤로
          return bCreatedAt.compareTo(aCreatedAt); // 최신순 (내림차순)
        });

    _unsignedTransactionDraftList = sortedDrafts.where((draft) => draft.signedPsbtBase64Encoded == null).toList();
    _signedTransactionDraftList = sortedDrafts.where((draft) => draft.signedPsbtBase64Encoded != null).toList();
    notifyListeners();
  }

  Future<RealmTransactionDraft?> getTransactionDraftById(int id) async {
    final draft = _transactionDraftRepository.getTransactionDraft(id);

    return draft;
  }
}
