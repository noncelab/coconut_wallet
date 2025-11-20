import 'package:coconut_wallet/enums/transaction_enums.dart';
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
    _unsignedTransactionDraftList = draft.where((draft) => draft.signedPsbtBase64Encoded == null).toList();
    _signedTransactionDraftList = draft.where((draft) => draft.signedPsbtBase64Encoded != null).toList();
    notifyListeners();
  }

  Future<RealmTransactionDraft?> getTransactionDraftById(int id) async {
    final draft = _transactionDraftRepository.getTransactionDraft(id);

    return draft;
  }
}
