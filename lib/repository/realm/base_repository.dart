import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:realm/realm.dart';

class BaseRepository {
  final RealmManager _realmManager;

  Realm get realm => _realmManager.realm;

  BaseRepository(this._realmManager);

  /// 공통 에러 핸들링
  Result<T> handleRealm<T>(T Function() operation) {
    try {
      return Result.success(operation());
    } catch (e) {
      return handleError<T>(e);
    }
  }

  /// 비동기 공통 에러 핸들링
  Future<Result<T>> handleAsyncRealm<T>(Future<T> Function() operation) async {
    try {
      return Result.success(await operation());
    } catch (e) {
      return handleError(e);
    }
  }

  /// 에러 처리
  Result<T> handleError<T>(dynamic e) {
    if (e is AppError) {
      return Result<T>.failure(e);
    }

    if (e is RealmException) {
      return Result<T>.failure(ErrorCodes.withMessage(ErrorCodes.realmException, e.message));
    }

    return Result<T>.failure(ErrorCodes.withMessage(ErrorCodes.realmUnknown, e.toString()));
  }
}
