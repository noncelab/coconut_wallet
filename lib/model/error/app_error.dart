import 'package:coconut_wallet/localization/strings.g.dart';

class AppError {
  final String code;
  final String message;

  const AppError(this.code, this.message);

  @override
  String toString() => 'Error Code: $code, Error Message: $message';
}

class ErrorCodes {
  static AppError withMessage(AppError error, String addedMessage) {
    return AppError(error.code, '${error.message}: $addedMessage');
  }

  static AppError storageReadError = AppError('1001', t.errors.storage_read_error);
  static AppError storageWriteError = AppError('1002', t.errors.storage_write_error);
  static AppError networkError = AppError('1003', t.errors.network_error);
  static AppError nodeConnectionError = AppError('1004', t.errors.node_connection_error);
  static AppError fetchWalletError = AppError('1005', t.errors.fetch_wallet_error);
  static AppError walletSyncFailedError = AppError('1006', t.errors.wallet_sync_failed_error);
  static AppError fetchBalanceError = AppError('1007', t.errors.fetch_balance_error);
  static AppError fetchTransactionListError = AppError('1008', t.errors.fetch_transaction_list_error);
  static AppError fetchTransactionsError = AppError('1009', t.errors.fetch_transactions_error);
  static AppError databasePathError = AppError('1010', t.errors.database_path_error);
  static AppError feeEstimationError = AppError('1100', t.errors.fee_estimation_error);
  static AppError realmUnknown = AppError('1201', t.errors.realm_unknown);
  static AppError realmNotFound = AppError('1202', t.errors.realm_not_found);
  static AppError realmException = AppError('1203', t.errors.realm_exception);
  static AppError nodeUnknown = AppError('1300', t.errors.node_unknown);
  static AppError nodeIsolateError = AppError('1301', t.errors.node_unknown);
  static AppError broadcastError = AppError('1302', t.errors.broadcast_error);
  static AppError broadcastErrorWithMessage(String message) => ErrorCodes.withMessage(broadcastError, message);
  static AppError invalidTransactionDraftId = AppError('1400', t.errors.transaction_draft.invalid_id);
  static AppError transactionDraftAlreadyExists = AppError(
    '1401',
    t.transaction_draft.dialog.transaction_draft_already_exists,
  );
}
