import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:flutter/material.dart';

class TransactionDraftViewModel extends ChangeNotifier {
  final TransactionDraftRepository _transactionDraftRepository;

  /// Wallet variables ---------------------------------------------------------
  List<RealmTransactionDraft> _unsignedTransactionDraftList = [];
  List<RealmTransactionDraft> _signedTransactionDraftList = [];
  bool _isInitialized = false;

  TransactionDraftViewModel(this._transactionDraftRepository);

  List<RealmTransactionDraft> get signedTransactionDraftList => _signedTransactionDraftList;
  List<RealmTransactionDraft> get unsignedTransactionDraftList => _unsignedTransactionDraftList;
  bool get isInitialized => _isInitialized;

  Future<void> initializeDraftList() async {
    final allDrafts = await _transactionDraftRepository.getAllTransactionDrafts();

    // createdAt 기준 최신순으로 정렬 (이미 getAllTransactionDrafts에서 정렬됨)
    _unsignedTransactionDraftList = allDrafts.where((draft) => draft.signedPsbtBase64Encoded == null).toList();
    _signedTransactionDraftList = allDrafts.where((draft) => draft.signedPsbtBase64Encoded != null).toList();
    _isInitialized = true;

    notifyListeners();
  }
}
