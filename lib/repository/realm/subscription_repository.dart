import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

class SubscriptionRepository extends BaseRepository {
  SubscriptionRepository(super._realmManager);

  /// 스크립트 상태 업데이트 또는 생성
  /// [scriptPubKey] 스크립트 공개키
  /// [status] 새로운 상태 해시
  /// [walletId] 지갑 ID
  Result<RealmScriptStatus> updateScriptStatus(
    String scriptPubKey,
    String status,
    int walletId,
  ) {
    return handleRealm(() {
      final now = DateTime.now();
      final existingStatus = realm.find<RealmScriptStatus>(scriptPubKey);

      if (existingStatus != null) {
        realm.write(() {
          existingStatus.status = status;
          existingStatus.timestamp = now;
        });
        return existingStatus;
      } else {
        final newStatus = RealmScriptStatus(scriptPubKey, status, walletId, now);
        realm.write(() {
          realm.add(newStatus);
        });
        return newStatus;
      }
    });
  }

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
  Result<void> batchUpdateScriptStatuses(
    int walletId,
    List<ScriptStatus> fetchedStatuses,
    Map<String, RealmScriptStatus> existingStatusMap,
  ) {
    return handleRealm(() {
      final now = DateTime.now();
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

      realm.write(() {
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

  /// 모든 스크립트 상태를 맵으로 가져오기 { scriptPubKey: scriptStatus }
  Map<String, RealmScriptStatus> getScriptStatusMap(int walletId) {
    final scriptStatuses = realm.query<RealmScriptStatus>(
      r'walletId == $0',
      [walletId],
    );
    return {
      for (final status in scriptStatuses) status.scriptPubKey: status,
    };
  }
}
