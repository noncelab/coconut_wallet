import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:flutter/material.dart';

class TransactionDraftViewModel extends ChangeNotifier {
  final TransactionDraftRepository _transactionDraftRepository;

  /// Wallet variables ---------------------------------------------------------
  List<TransactionDraft> _unsignedTransactionDraftList = [];
  List<TransactionDraft> _signedTransactionDraftList = [];
  bool _isInitialized = false;

  TransactionDraftViewModel(this._transactionDraftRepository);

  List<TransactionDraft> get signedTransactionDraftList => _signedTransactionDraftList;
  List<TransactionDraft> get unsignedTransactionDraftList => _unsignedTransactionDraftList;
  bool get isInitialized => _isInitialized;

  Future<void> initializeDraftList() async {
    _unsignedTransactionDraftList = _transactionDraftRepository.getAllUnsignedDrafts();
    _signedTransactionDraftList = await _transactionDraftRepository.getAllSignedDrafts();
    _isInitialized = true;

    notifyListeners();
  }
}
