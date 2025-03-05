import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/script_status.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
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
        final newStatus =
            RealmScriptStatus(scriptPubKey, status, walletId, now);
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
    List<ScriptStatus> scriptStatuses,
    int walletId,
  ) {
    return handleRealm(() {
      final existingStatusMap = _getExistingScriptStatusMap(
        walletId: walletId,
        scriptPubKeys: scriptStatuses.map((e) => e.scriptPubKey).toList(),
      );

      final now = DateTime.now();
      // 추가/변경된 스크립트 상태 전체
      final updatedStatuses = <ScriptStatus>[];
      final newStatuses = _prepareToAddScriptStatusList(
        updates: scriptStatuses,
        existingStatusMap: existingStatusMap,
        walletId: walletId,
        now: now,
        updatedStatuses: updatedStatuses,
      );

      if (newStatuses.isEmpty && updatedStatuses.isEmpty) {
        return;
      }

      realm.write(() {
        // 기존 상태 업데이트
        for (final update in scriptStatuses) {
          final existingStatus = existingStatusMap[update.scriptPubKey];

          if (existingStatus != null && update.status != null) {
            existingStatus.status = update.status!;
            existingStatus.timestamp = now;
            updatedStatuses.add(update);
          }
        }

        // 새로운 상태 일괄 추가
        realm.addAll<RealmScriptStatus>(newStatuses);
      });
    });
  }

  /// 스크립트 상태 업데이트 준비
  /// 업데이트가 필요한 상태와 새로 생성할 상태를 분리하여 반환
  List<RealmScriptStatus> _prepareToAddScriptStatusList({
    required List<ScriptStatus> updates,
    required Map<String, RealmScriptStatus> existingStatusMap,
    required int walletId,
    required DateTime now,
    required List<ScriptStatus> updatedStatuses,
  }) {
    final newStatuses = <RealmScriptStatus>[];

    for (final update in updates) {
      final existingStatus = existingStatusMap[update.scriptPubKey];

      // 기존 상태가 없고 업데이트된 상태가 있는 경우 새로 생성
      if (existingStatus == null && update.status != null) {
        newStatuses.add(RealmScriptStatus(
          update.scriptPubKey,
          update.status!,
          walletId,
          now,
        ));

        updatedStatuses.add(update);
      }
    }

    return newStatuses;
  }

  /// 기존 스크립트 상태 맵 가져오기
  Map<String, RealmScriptStatus> _getExistingScriptStatusMap({
    required int walletId,
    required List<String> scriptPubKeys,
  }) {
    final scriptResults = realm.query<RealmScriptStatus>(
      r'walletId == $0 AND scriptPubKey IN $1',
      [walletId, scriptPubKeys],
    );

    return {
      for (final status in scriptResults) status.scriptPubKey: status,
    };
  }

  /// 모든 스크립트 상태를 맵으로 가져오기
  Map<String, UnaddressedScriptStatus> getScriptStatusMap(int walletId) {
    final scriptStatuses = realm.query<RealmScriptStatus>(
      r'walletId == $0',
      [walletId],
    );
    return {
      for (final status in scriptStatuses)
        status.scriptPubKey: mapRealmToUnaddressedScriptStatus(status),
    };
  }
}
