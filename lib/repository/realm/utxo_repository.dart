import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/utxo.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:realm/realm.dart';

class UtxoRepository extends BaseRepository {
  UtxoRepository(super._realmManager);

  /// walletId 로 태그 목록 조회
  Result<List<UtxoTag>> getUtxoTags(int walletId) {
    return handleRealm<List<UtxoTag>>(
      () {
        final tags = realm
            .query<RealmUtxoTag>("walletId == '$walletId' SORT(createAt DESC)");

        return tags.map(mapRealmUtxoTagToUtxoTag).toList();
      },
    );
  }

  /// 사용된 UTXO의 태그 업데이트
  Future<Result<void>> updateTagsOfSpentUtxos(
      int walletId, List<String> usedUtxoIds, List<String> newUtxoIds) async {
    return handleAsyncRealm(
      () async {
        final tags = realm.query<RealmUtxoTag>("walletId == '$walletId'");

        await realm.writeAsync(() {
          for (int i = 0; i < tags.length; i++) {
            if (tags[i].utxoIdList.isEmpty) continue;

            int previousCount = tags[i].utxoIdList.length;

            tags[i].utxoIdList.removeWhere((utxoId) =>
                usedUtxoIds.any((targetUtxoId) => targetUtxoId == utxoId));

            if (newUtxoIds.isNotEmpty) {
              bool needToMove = previousCount > tags[i].utxoIdList.length;
              if (needToMove) {
                tags[i].utxoIdList.addAll(newUtxoIds);
              }
            }
          }
        });
      },
    );
  }

  /// walletId 로 조회된 태그 목록에서 utxoId($txHash$Index)를 포함하고 있는 태그 목록 조회
  Result<List<UtxoTag>> getUtxoTagsByTxHash(int walletId, String utxoId) {
    return handleRealm<List<UtxoTag>>(() {
      final tags = realm
          .all<RealmUtxoTag>()
          .query("walletId == '$walletId' SORT(createAt DESC)");

      return tags
          .where((tag) => tag.utxoIdList.contains(utxoId))
          .map(mapRealmUtxoTagToUtxoTag)
          .toList();
    });
  }

  /// 태그 추가
  Result<UtxoTag> createUtxoTag(
      String id, int walletId, String name, int colorIndex) {
    return handleRealm<UtxoTag>(() {
      final tag = RealmUtxoTag(id, walletId, name, colorIndex, DateTime.now());
      realm.write(() {
        realm.add(tag);
      });
      return mapRealmUtxoTagToUtxoTag(tag);
    });
  }

  /// id 로 조회된 태그의 속성 업데이트
  Result<UtxoTag> updateUtxoTag(String id, String name, int colorIndex) {
    return handleRealm<UtxoTag>(() {
      final tags = realm.query<RealmUtxoTag>("id == '$id'");

      if (tags.isEmpty) {
        throw ErrorCodes.realmNotFound;
      }

      final tag = tags.first;

      realm.write(() {
        tag.name = name;
        tag.colorIndex = colorIndex;
      });
      return mapRealmUtxoTagToUtxoTag(tag);
    });
  }

  /// id 로 조회된 태그 삭제
  Result<UtxoTag> deleteUtxoTag(String id) {
    return handleRealm<UtxoTag>(() {
      final tag = realm.find<RealmUtxoTag>(id);

      if (tag == null) {
        throw ErrorCodes.realmNotFound;
      }

      final removeTag = mapRealmUtxoTagToUtxoTag(tag);

      realm.write(() {
        realm.delete(tag);
      });

      return removeTag;
    });
  }

  /// utxoIdList 변경
  /// - [walletId] 목록 검색
  /// - [utxoId] Utxo Id
  /// - [newUtxoTags] 추가할 UtxoTag 목록
  /// - [selectedTagNames] 선택된 태그명 목록
  Result<bool> createTagAndUpdateTagsOfUtxo(int walletId, String utxoId,
      List<UtxoTag> newUtxoTags, List<String> selectedTagNames) {
    return handleRealm<bool>(
      () {
        realm.write(() {
          // 새로운 태그 추가
          final now = DateTime.now();
          for (var utxoTag in newUtxoTags) {
            final tag = RealmUtxoTag(
              utxoTag.id,
              walletId,
              utxoTag.name,
              utxoTag.colorIndex,
              now,
            );
            realm.add(tag);
          }

          // 태그 적용
          final tags = realm.query<RealmUtxoTag>("walletId == '$walletId'");
          for (var tag in tags) {
            if (selectedTagNames.contains(tag.name)) {
              // 태그 이름이 선택된 경우
              if (!tag.utxoIdList.contains(utxoId)) {
                // 해당 태그의 utxoIdList에 utxoId가 없는 경우
                tag.utxoIdList.add(utxoId);
              }
            } else {
              tag.utxoIdList.remove(utxoId);
            }
          }
        });

        return true;
      },
    );
  }

  /// 모든 UTXO 추가
  Result<bool> addAllUtxos(int walletId, List<UtxoState> utxos) {
    return handleRealm<bool>(() {
      final existingUtxos = realm.query<RealmUtxo>(
        r'walletId == $0',
        [walletId],
      );

      final existingUtxoMap = Map<String, RealmUtxo>.fromEntries(
        existingUtxos.map((realmUtxo) => MapEntry(realmUtxo.id, realmUtxo)),
      );

      final newUtxos = utxos
          .where((utxo) => !existingUtxoMap.containsKey(utxo.utxoId))
          .map((utxo) => mapUtxoToRealmUtxo(walletId, utxo))
          .toList();

      final toUpdateUtxos = utxos
          .where((utxo) => existingUtxoMap.containsKey(utxo.utxoId))
          .map((utxo) => mapUtxoToRealmUtxo(walletId, utxo))
          .toList();

      realm.write(() {
        for (final toUpdateUtxo in toUpdateUtxos) {
          final existingUtxo = existingUtxoMap[toUpdateUtxo.id];
          if (existingUtxo != null) {
            existingUtxo.blockHeight = toUpdateUtxo.blockHeight;
            existingUtxo.timestamp = toUpdateUtxo.timestamp;
            existingUtxo.status = toUpdateUtxo.status;
          }
        }
        realm.addAll<RealmUtxo>(newUtxos);
      });

      return true;
    });
  }

  // UTXO 상태를 "출금 중(outgoing)"으로 표시
  void markUtxoAsOutgoing(int walletId, String utxoId, String pendingTxHash) {
    final utxoToMark = realm.find<RealmUtxo>(utxoId);

    if (utxoToMark == null) return;

    realm.write(() {
      utxoToMark.status = utxoStatusToString(UtxoStatus.outgoing);
      utxoToMark.spentByTransactionHash = pendingTxHash;
    });
  }

  // RBF 가능한 UTXO 목록 조회
  List<UtxoState> getRbfEligibleUtxos(int walletId) {
    final rbfEligibleUtxos = realm.query<RealmUtxo>(
      r'walletId == $0 AND status == $1',
      [walletId, utxoStatusToString(UtxoStatus.outgoing)],
    );

    return rbfEligibleUtxos.map(mapRealmToUtxoState).toList();
  }

  // CPFP 가능한 UTXO 목록 조회 (확인되지 않은 트랜잭션의 출력)
  List<UtxoState> getCpfpEligibleUtxos(int walletId) {
    final cpfpEligibleUtxos = realm.query<RealmUtxo>(
      r'walletId == $0 AND status == $1 AND blockHeight == 0',
      [walletId, utxoStatusToString(UtxoStatus.incoming)],
    );

    return cpfpEligibleUtxos.map(mapRealmToUtxoState).toList();
  }

  List<UtxoState> getUtxoStateList(int walletId) {
    final realmUtxos = realm.query<RealmUtxo>(
      r'walletId == $0',
      [walletId],
    );
    return realmUtxos.map((e) => mapRealmToUtxoState(e)).toList();
  }

  // 특정 상태의 UTXO 목록만 조회
  List<UtxoState> getUtxosByStatus(int walletId, UtxoStatus status) {
    final statusStr = utxoStatusToString(status);
    final realmUtxos = realm.query<RealmUtxo>(
      r'walletId == $0 AND status == $1',
      [walletId, statusStr],
    );
    return realmUtxos.map((e) => mapRealmToUtxoState(e)).toList();
  }

  /// 특정 UTXO 조회
  UtxoState? getUtxoState(int walletId, String utxoId) {
    final realmUtxo = realm.query<RealmUtxo>(
      r'walletId == $0 AND id == $1',
      [walletId, utxoId],
    ).firstOrNull;

    if (realmUtxo == null) {
      return null;
    }

    return mapRealmToUtxoState(realmUtxo);
  }

  void deleteUtxo(int walletId, String utxoId) {
    final utxoToDelete = realm.query<RealmUtxo>(
      r'walletId == $0 AND id == $1',
      [walletId, utxoId],
    ).firstOrNull;

    if (utxoToDelete == null) return;

    realm.write(() {
      realm.delete(utxoToDelete);
    });
  }

  void deleteUtxoList(int walletId, List<String> utxoIds) {
    final utxosToDelete = realm.query<RealmUtxo>(
      r'walletId == $0 AND id IN $1',
      [walletId, utxoIds],
    );

    if (utxosToDelete.isEmpty) return;

    realm.write(() {
      realm.deleteMany(utxosToDelete);
    });
  }

  void deleteUtxosByReplacedTransactionHashSet(
      int walletId, Set<String> replacedTxHashSet) {
    final utxosToDelete = realm.query<RealmUtxo>(
      r'walletId == $0 AND transactionHash IN $1',
      [walletId, replacedTxHashSet],
    );

    if (utxosToDelete.isEmpty) return;

    realm.write(() {
      realm.deleteMany(utxosToDelete);
    });
  }
}
