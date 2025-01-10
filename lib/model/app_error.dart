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

  static const AppError storageReadError =
      AppError('1001', '저장소에서 데이터를 불러오는데 실패했습니다.');
  static const AppError storageWriteError =
      AppError('1002', '저장소에 데이터를 저장하는데 실패했습니다.');
  static const AppError networkError =
      AppError('1003', '네트워크에 연결할 수 없어요. 연결 상태를 확인해 주세요.');
  static const AppError nodeConnectionError =
      AppError('1004', '비트코인 노드와 연결하는데 실패했습니다.');
  static const AppError fetchWalletError =
      AppError('1005', '지갑을 가져오는데 실패했습니다.');
  static const AppError walletSyncFailedError =
      AppError('1006', '지갑 정보 불러오기 실패');
  static const AppError fetchBalanceError = AppError('1007', '잔액 조회를 실패했습니다.');
  static const AppError fetchTransferListError =
      AppError('1008', '트랜잭션 목록 조회를 실패했습니다.');
  static const AppError fetchTransactionsError =
      AppError('1009', '거래 내역을 가져오는데 실패했습니다.');
  static const AppError databasePathError =
      AppError('1010', 'DB 경로를 찾을 수 없습니다.');

  static const AppError feeEstimationError =
      AppError('1100', "수수료 계산을 실패했습니다.");

  static const AppError realmUnknown = AppError('1201', '알 수 없는 오류가 발생했습니다.');
  static const AppError realmNotFound = AppError('1202', '데이터를 찾을 수 없습니다.');
  static const AppError realmException =
      AppError('1202', 'Realm 작업 중 오류가 발생했습니다.');
}
