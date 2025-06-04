import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

class SubscriptionRepository extends BaseRepository {
  SubscriptionRepository(super._realmManager);

  /// 지갑의 모든 스크립트 상태 조회
  /// [walletId] 지갑 ID
  Result<List<RealmScriptStatus>> getAllScriptStatuses(int walletId) {
    return handleRealm(() {
      final scriptStatuses = realm.query<RealmScriptStatus>(
        r'walletId == $0 SORT(timestamp DESC)',
        [walletId],
      );
      return scriptStatuses.toList();
    });
  }

  /// 여러 스크립트 상태 일괄 업데이트
  /// [subscribeResponse] 구독 응답
  /// [walletId] 지갑 ID
  Future<Result<void>> updateScriptStatusList(
    int walletId,
    List<ScriptStatus> fetchedStatuses,
  ) async {
    return handleAsyncRealm(() async {
      await deleteScriptStatusIfWalletDeleted(walletId);
      final now = DateTime.now();
      final existingStatusMap = getExistingScriptStatusMap(fetchedStatuses);
      final (:toAddStatuses, :toUpdateStatuses) = _prepareScriptStatusList(
        fetchedStatuses: fetchedStatuses,
        existingStatusMap: existingStatusMap,
        walletId: walletId,
        now: now,
      );

      if (toAddStatuses.isEmpty && toUpdateStatuses.isEmpty) {
        Logger.log('업데이트 필요 없음');
        return;
      }

      await realm.writeAsync(() {
        final wallet = realm.find<RealmWalletBase>(walletId);
        if (wallet == null) {
          return;
        }

        // 기존 상태 업데이트
        for (final update in toUpdateStatuses) {
          final existingStatus = existingStatusMap[update.scriptPubKey];

          if (existingStatus != null && update.status != null) {
            existingStatus.status = update.status!;
            existingStatus.timestamp = now;
          }
        }

        // 새로운 상태 일괄 추가
        realm.addAll<RealmScriptStatus>(toAddStatuses);
      });
    });
  }

  /// 스크립트 상태 업데이트 준비
  /// 업데이트가 필요한 상태와 새로 생성할 상태를 분리하여 반환
  ({List<RealmScriptStatus> toAddStatuses, List<ScriptStatus> toUpdateStatuses})
      _prepareScriptStatusList({
    required List<ScriptStatus> fetchedStatuses,
    required Map<String, RealmScriptStatus> existingStatusMap,
    required int walletId,
    required DateTime now,
  }) {
    final toAddStatuses = <RealmScriptStatus>[];
    final toUpdateStatuses = <ScriptStatus>[];

    for (final fetchedStatus in fetchedStatuses) {
      final existingStatus = existingStatusMap[fetchedStatus.scriptPubKey];

      // 기존 상태가 없고 업데이트된 상태가 있는 경우 새로 생성
      if (existingStatus == null && fetchedStatus.status != null) {
        toAddStatuses.add(RealmScriptStatus(
          fetchedStatus.scriptPubKey,
          fetchedStatus.status!,
          walletId,
          now,
        ));
      }

      if (existingStatus != null &&
          fetchedStatus.status != null &&
          existingStatus.status != fetchedStatus.status) {
        toUpdateStatuses.add(fetchedStatus);
      }
    }

    return (
      toAddStatuses: toAddStatuses,
      toUpdateStatuses: toUpdateStatuses,
    );
  }

  List<ScriptStatus> getUpdatedScriptStatuses(
    List<ScriptStatus> fetchedScriptStatuses,
    int walletId,
  ) {
    final updatedScriptStatuses = <ScriptStatus>[];
    final existingScriptStatusMap = getExistingScriptStatusMap(fetchedScriptStatuses);

    for (final status in fetchedScriptStatuses) {
      final existingStatus = existingScriptStatusMap[status.scriptPubKey];

      if (status.status != existingStatus?.status) {
        updatedScriptStatuses.add(status);
      }
    }

    return updatedScriptStatuses;
  }

  Map<String, RealmScriptStatus> getExistingScriptStatusMap(List<ScriptStatus> scriptStatuses) {
    final scriptPubKeyList = scriptStatuses.map((e) => e.scriptPubKey).toList();
    // scriptPubKey 목록에 해당하는 기존 스크립트 상태 조회
    final existingScriptStatuses = realm.query<RealmScriptStatus>(
      r'scriptPubKey IN $0',
      [scriptPubKeyList],
    ).toList();

    return {
      for (final status in existingScriptStatuses) status.scriptPubKey: status,
    };
  }

  /// 지갑이 삭제된 경우 해당 지갑의 scriptStatus를 삭제합니다.
  Future<void> deleteScriptStatusIfWalletDeleted(int walletId) async {
    try {
      // 지갑이 존재하는지 확인
      final wallet = realm.query<RealmWalletBase>(
        r'id == $0',
        [walletId],
      ).firstOrNull;

      // 지갑이 삭제된 경우
      if (wallet == null) {
        // 해당 지갑의 모든 scriptStatus 삭제
        final scriptStatuses = realm.query<RealmScriptStatus>(
          r'walletId == $0',
          [walletId],
        );

        await realm.writeAsync(() {
          realm.deleteMany<RealmScriptStatus>(scriptStatuses);
        });

        Logger.log('Deleted scriptStatuses for deleted wallet: $walletId');
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to delete scriptStatuses for wallet $walletId: $e');
      Logger.error('Stack trace: $stackTrace');
    }
  }
}
