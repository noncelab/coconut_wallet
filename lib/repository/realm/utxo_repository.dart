import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/utxo.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:realm/realm.dart';

class UtxoRepository extends BaseRepository {
  UtxoRepository(super._realmManager);

  /// walletId 로 태그 목록 조회
  Result<List<UtxoTag>> getUtxoTags(int walletId) {
    final tags = realm
        .query<RealmUtxoTag>("walletId == '$walletId' SORT(createAt DESC)");

    return handleRealm<List<UtxoTag>>(
      () {
        return tags.map(mapRealmUtxoTagToUtxoTag).toList();
      },
    );
  }

  /// 사용된 UTXO의 태그 업데이트
  Future<Result<void>> updateTagsOfSpentUtxos(
      int walletId, List<String> usedUtxoIds, List<String> newUtxoIds) async {
    final tags = realm.query<RealmUtxoTag>("walletId == '$walletId'");

    return handleAsyncRealm(
      () async {
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
  Result<UtxoTag> addUtxoTag(
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

  /// walletId 로 조회된 태그 전체 삭제
  Result<bool> deleteAllUtxoTag(int walletId) {
    return handleRealm<bool>(() {
      final tags = realm.query<RealmUtxoTag>("walletId == '$walletId'");

      if (tags.isEmpty) {
        throw ErrorCodes.realmNotFound;
      }

      realm.deleteMany(tags);

      return true;
    });
  }

  /// utxoIdList 변경
  /// - [walletId] 목록 검색
  /// - [utxoId] Utxo Id
  /// - [addTags] 추가할 UtxoTag 목록
  /// - [selectedNames] 선택된 태그명 목록
  Result<bool> updateUtxoTagList(int walletId, String utxoId,
      List<UtxoTag> addTags, List<String> selectedNames) {
    return handleRealm<bool>(
      () {
        realm.write(() {
          // 새로운 태그 추가
          final now = DateTime.now();
          for (var utxoTag in addTags) {
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
            if (selectedNames.contains(tag.name)) {
              if (!tag.utxoIdList.contains(utxoId)) {
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
  void addAllUtxos(int walletId, List<UtxoState> utxos) {
    final existingUtxos = realm.query<RealmUtxo>(
      r'walletId == $0',
      [walletId],
    );

    final existingUtxoMap = Map<String, RealmUtxo>.fromEntries(
      existingUtxos.map((e) => MapEntry(e.id, e)),
    );

    final newUtxos = utxos
        .where((utxo) => !existingUtxoMap
            .containsKey(makeUtxoId(utxo.transactionHash, utxo.index)))
        .map((utxo) => mapUtxoToRealmUtxo(walletId, utxo))
        .toList();

    final toUpdateUtxos = utxos
        .where((utxo) => existingUtxoMap
            .containsKey(makeUtxoId(utxo.transactionHash, utxo.index)))
        .map((utxo) => mapUtxoToRealmUtxo(walletId, utxo))
        .toList();

    realm.write(() {
      for (final utxo in toUpdateUtxos) {
        final existingUtxo = existingUtxoMap[utxo.id];
        if (existingUtxo != null) {
          existingUtxo.timestamp = utxo.timestamp;
        }
      }
      realm.addAll<RealmUtxo>(newUtxos);
    });
  }

  /// UTXO 목록 조회
  List<UtxoState> getUtxoStateList(int walletId) {
    final realmUtxos = realm.query<RealmUtxo>(
      r'walletId == $0',
      [walletId],
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
}
