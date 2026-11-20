import 'package:coconut_lib/coconut_lib.dart' as lib;
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/utxo.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:realm/realm.dart';

/// 선택된 UTXO의 상태를 나타내는 enum
enum SelectedUtxoExcludedStatus {
  used, // 일부 UTXO가 이미 사용됨
  locked, // 일부 UTXO가 잠금됨
}

typedef UtxoTagImportInfo = ({String tag, int? colorIndex});

const int _maxTagsPerUtxo = 5;

int _normalizeTagColorIndex(int colorIndex) {
  return WalletVisualStyleUtil.normalizePaletteIndex(colorIndex);
}

class UtxoRepository extends BaseRepository {
  UtxoRepository(super._realmManager);

  /// walletId로 RealmUtxoTag 목록을 쿼리하는 내부 메서드
  RealmResults<RealmUtxoTag> _queryUtxoTags(int walletId) {
    return realm.query<RealmUtxoTag>("walletId == '$walletId' SORT(createAt DESC)");
  }

  /// walletId 로 태그 목록 조회
  Result<List<UtxoTag>> getUtxoTags(int walletId) {
    return handleRealm<List<UtxoTag>>(() {
      return _queryUtxoTags(walletId).map(mapRealmUtxoTagToUtxoTag).toList();
    });
  }

  /// walletId 로 Realm 태그 목록 조회
  List<RealmUtxoTag> getRealmUtxoTags(int walletId) {
    return _queryUtxoTags(walletId).toList();
  }

  /// 동기화가 사용된 UTXO를 정리해도 전송 전에 선택한 태그를 원자적으로 승계한다.
  Future<Result<void>> applyInheritedTags(
    int walletId, {
    required List<String> sourceUtxoIds,
    required List<String> targetUtxoIds,
    required List<String> tagIds,
  }) async {
    return handleAsyncRealm(() async {
      final selectedTagIds = tagIds.toSet();
      final sourceIds = sourceUtxoIds.toSet();
      final targetIds = targetUtxoIds.toSet();

      await realm.writeAsync(() {
        if (selectedTagIds.length > _maxTagsPerUtxo) {
          throw ErrorCodes.withMessage(ErrorCodes.realmException, 'Too many inherited UTXO tags');
        }

        final tags = realm.query<RealmUtxoTag>(r'walletId == $0', [walletId]).toList();
        if (!tags.map((tag) => tag.id).toSet().containsAll(selectedTagIds)) {
          throw ErrorCodes.realmNotFound;
        }

        for (final targetId in targetIds) {
          final prospectiveTagCount =
              tags.where((tag) => selectedTagIds.contains(tag.id) || tag.utxoIdList.contains(targetId)).length;
          if (prospectiveTagCount > _maxTagsPerUtxo) {
            throw ErrorCodes.withMessage(ErrorCodes.realmException, 'Too many tags on an inherited UTXO');
          }
        }

        for (final tag in tags) {
          tag.utxoIdList.removeWhere(sourceIds.contains);
          if (selectedTagIds.contains(tag.id)) {
            for (final targetId in targetIds) {
              if (!tag.utxoIdList.contains(targetId)) {
                tag.utxoIdList.add(targetId);
              }
            }
          }
        }
      });
    });
  }

  /// walletId 로 조회된 태그 목록에서 utxoId($txHash$Index)를 포함하고 있는 태그 목록 조회
  Result<List<UtxoTag>> getUtxoTagsByTxHash(int walletId, String utxoId) {
    return handleRealm<List<UtxoTag>>(() {
      final tags = realm.query<RealmUtxoTag>("walletId == '$walletId' SORT(createAt DESC)");

      return tags.where((tag) => tag.utxoIdList.contains(utxoId)).map(mapRealmUtxoTagToUtxoTag).toList();
    });
  }

  /// 태그 추가
  Result<UtxoTag> createUtxoTag(String id, int walletId, String name, int colorIndex) {
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
  Result<bool> createTagAndUpdateTagsOfUtxo(
    int walletId,
    String utxoId,
    List<UtxoTag> newUtxoTags,
    List<String> selectedTagNames,
  ) {
    return handleRealm<bool>(() {
      realm.write(() {
        // 새로운 태그 추가
        final now = DateTime.now();
        for (var utxoTag in newUtxoTags) {
          final tag = RealmUtxoTag(utxoTag.id, walletId, utxoTag.name, utxoTag.colorIndex, now);
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
    });
  }

  /// utxo tag의 utxoIdList 변경
  /// - [walletId] 목록 검색
  /// - [utxoId] 업데이트할 Utxo Id
  /// - [selectedTagNames] 선택된 태그명 목록
  Result<bool> updateUtxoTagList(int walletId, String utxoId, List<String> selectedTagNames) {
    return handleRealm<bool>(() {
      realm.write(() {
        // 적용된 태그
        final tags = realm.query<RealmUtxoTag>(r'walletId == $0', [walletId]);
        for (var tag in tags) {
          final shouldHaveTag = selectedTagNames.contains(tag.name);
          final alreadyHasTag = tag.utxoIdList.contains(utxoId);

          if (shouldHaveTag && !alreadyHasTag) {
            // 태그가 있어야 하는데 없는 경우 - 추가
            tag.utxoIdList.add(utxoId);
          } else if (!shouldHaveTag && alreadyHasTag) {
            // 태그가 없어야 하는데 있는 경우 - 제거
            tag.utxoIdList.remove(utxoId);
          }
        }
      });

      return true;
    });
  }

  Future<Result<void>> addUtxoToTag(int walletId, String tagName, String utxoId, {int? colorIndex}) async {
    return handleAsyncRealm(() async {
      await realm.writeAsync(() {
        final existingTags = realm.query<RealmUtxoTag>(r'walletId == $0', [walletId]).toList();
        final attachedTagCount = existingTags.where((tag) => tag.utxoIdList.contains(utxoId)).length;
        var tag = existingTags.where((tag) => tag.name == tagName).firstOrNull;
        final isAlreadyAttached = tag?.utxoIdList.contains(utxoId) ?? false;

        if (!isAlreadyAttached && attachedTagCount >= _maxTagsPerUtxo) {
          return;
        }

        if (tag == null) {
          int newColorIndex;
          if (colorIndex != null) {
            newColorIndex = _normalizeTagColorIndex(colorIndex);
          } else {
            final usedColorIndexes = existingTags.map((t) => t.colorIndex).toSet();

            newColorIndex = 0;
            while (usedColorIndexes.contains(newColorIndex)) {
              newColorIndex++;
            }
          }

          tag = RealmUtxoTag(Uuid.v4().toString(), walletId, tagName, newColorIndex, DateTime.now());
          realm.add(tag);
        }

        if (colorIndex != null) {
          final normalizedColorIndex = _normalizeTagColorIndex(colorIndex);
          if (tag.colorIndex != normalizedColorIndex) {
            tag.colorIndex = normalizedColorIndex;
          }
        }

        if (!tag.utxoIdList.contains(utxoId)) {
          tag.utxoIdList.add(utxoId);
        }
      });
    });
  }

  Future<Result<void>> addUtxosToTags(int walletId, Map<String, Set<UtxoTagImportInfo>> utxoTags) async {
    if (utxoTags.isEmpty) return Result.success(null);

    return handleAsyncRealm(() async {
      await realm.writeAsync(() {
        final existingTags = realm.query<RealmUtxoTag>(r'walletId == $0', [walletId]).toList();
        final tagsByName = {for (final tag in existingTags) tag.name: tag};
        final usedColorIndexes = existingTags.map((tag) => tag.colorIndex).toSet();
        final attachedTagNamesByUtxoId = <String, Set<String>>{};
        for (final tag in existingTags) {
          for (final utxoId in tag.utxoIdList) {
            attachedTagNamesByUtxoId.putIfAbsent(utxoId, () => {}).add(tag.name);
          }
        }

        int nextAvailableColorIndex() {
          var colorIndex = 0;
          while (usedColorIndexes.contains(colorIndex)) {
            colorIndex++;
          }
          usedColorIndexes.add(colorIndex);
          return colorIndex;
        }

        for (final entry in utxoTags.entries) {
          final utxoId = entry.key;
          final attachedTagNames = attachedTagNamesByUtxoId.putIfAbsent(utxoId, () => {});

          for (final tagInfo in entry.value) {
            var tag = tagsByName[tagInfo.tag];
            final isAlreadyAttached = attachedTagNames.contains(tagInfo.tag);

            if (!isAlreadyAttached && attachedTagNames.length >= _maxTagsPerUtxo) {
              continue;
            }

            if (tag == null) {
              final colorIndex =
                  tagInfo.colorIndex == null ? nextAvailableColorIndex() : _normalizeTagColorIndex(tagInfo.colorIndex!);
              if (tagInfo.colorIndex != null) {
                usedColorIndexes.add(colorIndex);
              }

              tag = RealmUtxoTag(Uuid.v4().toString(), walletId, tagInfo.tag, colorIndex, DateTime.now());
              realm.add(tag);
              tagsByName[tagInfo.tag] = tag;
            }

            if (tagInfo.colorIndex != null) {
              final normalizedColorIndex = _normalizeTagColorIndex(tagInfo.colorIndex!);
              if (tag.colorIndex != normalizedColorIndex) {
                tag.colorIndex = normalizedColorIndex;
              }
            }

            if (!tag.utxoIdList.contains(utxoId)) {
              tag.utxoIdList.add(utxoId);
              attachedTagNames.add(tagInfo.tag);
            }
          }
        }
      });
    });
  }

  static const _revisionPrefix = 'UtxoRevision:';
  static const _spentRevisionPrefix = 'SpentUtxoRevision:';

  static void deleteWalletRevisionsInWrite(Realm realm, int walletId) {
    assert(realm.isInTransaction);
    realm.deleteMany(
      realm.query<RealmIntegerId>(r'key BEGINSWITH $0 OR key BEGINSWITH $1', [
        '$_revisionPrefix$walletId:',
        '$_spentRevisionPrefix$walletId:',
      ]),
    );
  }

  static int _stateVersion(Realm realm, RealmUtxo utxo) {
    return realm.find<RealmIntegerId>('$_revisionPrefix${utxo.id}')?.value ?? 0;
  }

  static int _advanceStateVersion(Realm realm, RealmUtxo utxo) {
    assert(realm.isInTransaction);
    final key = '$_revisionPrefix${utxo.id}';
    final counter = realm.find<RealmIntegerId>(key);
    if (counter == null) {
      return realm.add(RealmIntegerId(key, 1)).value;
    }
    return ++counter.value;
  }

  /// RPC 전에 복사한다. Realm 객체는 live이므로 상태 값 대신 변경 번호를 보관한다.
  Map<String, int> snapshotUtxoVersions(int walletId, {String? address}) {
    realm.refresh();
    final utxos = realm.query<RealmUtxo>(
      address == null
          ? r'walletId == $0 AND isDeleted == false'
          : r'walletId == $0 AND address == $1 AND isDeleted == false',
      address == null ? [walletId] : [walletId, address],
    );
    final versions = {for (final utxo in utxos) utxo.id: 0};
    // 사라진 CPFP 출력은 주소 행이 없어도, 조회가 시작됐을 때의 번호를 알아야 한다.
    final revisions = realm.query<RealmIntegerId>(r'key BEGINSWITH $0', ['$_revisionPrefix$walletId:']);
    for (final revision in revisions) {
      final id = revision.key.substring(_revisionPrefix.length);
      versions[id] = revision.value;
    }
    return versions;
  }

  void _setUtxoState(RealmUtxo utxo, String status, String? spentBy) {
    // 같은 값이어도 새 관찰이므로 그 전에 시작한 응답과 구별한다.
    utxo.status = status;
    utxo.spentByTransactionHash = spentBy;
    _advanceStateVersion(realm, utxo);
  }

  /// 모든 UTXO 추가. 조회 뒤 바뀐 행은 쓰기 잠금 안에서 제외한다.
  Future<Result<bool>> addAllUtxos(int walletId, List<UtxoState> utxos, {Map<String, int>? expectedVersions}) async {
    final versions = expectedVersions ?? snapshotUtxoVersions(walletId);
    return handleAsyncRealm<bool>(() async {
      await realm.writeAsync(() {
        // v9 개발 기기의 outpoint 전용 기본키를 정리한다.
        final legacyUtxos =
            realm
                .query<RealmUtxo>(r'walletId == $0 AND NOT (id BEGINSWITH $1)', [walletId, '$walletId:'])
                .where((utxo) => utxo.isDeleted || versions[utxo.id] == _stateVersion(realm, utxo))
                .toList();
        realm.deleteMany(legacyUtxos);
        for (final value in utxos) {
          final id = getRealmUtxoId(walletId, value.transactionHash, value.index);
          final existing = realm.find<RealmUtxo>(id);
          if (existing?.isDeleted == true) continue;
          final revision = realm.find<RealmIntegerId>('$_revisionPrefix$id');
          if ((revision?.value ?? (existing == null ? null : 0)) != versions[id]) continue;
          if (existing == null) {
            if (realm.find<RealmIntegerId>('$_spentRevisionPrefix$id') != null) continue;
            realm.add(mapUtxoToRealmUtxo(walletId, value));
            versions[id] = revision == null ? 0 : ++revision.value;
          } else {
            existing.blockHeight = value.blockHeight;
            existing.timestamp = value.timestamp;
            final status = utxoStatusToString(value.status);
            if (existing.status != status || existing.spentByTransactionHash != value.spentByTransactionHash) {
              _setUtxoState(existing, status, value.spentByTransactionHash);
            }
            versions[id] = _stateVersion(realm, existing);
          }
        }
      });
      return true;
    });
  }

  List<UtxoState> getUtxoStateList(int walletId) {
    realm.refresh();
    final realmUtxos = realm.query<RealmUtxo>(r'walletId == $0 AND isDeleted == false', [walletId]);
    return realmUtxos.map((e) => mapRealmToUtxoState(e)).toList();
  }

  // 특정 상태의 UTXO 목록만 조회
  List<UtxoState> getUtxosByStatus(int walletId, UtxoStatus status) {
    realm.refresh();
    final statusStr = utxoStatusToString(status);
    final realmUtxos = realm.query<RealmUtxo>(r'walletId == $0 AND status == $1 AND isDeleted == false', [
      walletId,
      statusStr,
    ]);
    return realmUtxos.map((e) => mapRealmToUtxoState(e)).toList();
  }

  /// 특정 UTXO 조회
  UtxoState? getUtxoState(int walletId, String utxoId, {bool includeDeleted = false}) {
    realm.refresh();
    final realmUtxo =
        realm.query<RealmUtxo>(
          includeDeleted ? r'walletId == $0 AND id == $1' : r'walletId == $0 AND id == $1 AND isDeleted == false',
          [walletId, '$walletId:$utxoId'],
        ).firstOrNull;

    if (realmUtxo == null) {
      return null;
    }

    return mapRealmToUtxoState(realmUtxo);
  }

  Future<Result<void>> toggleUtxoLockStatus(int walletId, String utxoId) async {
    return handleAsyncRealm(() async {
      await realm.writeAsync(() {
        final utxo = realm.find<RealmUtxo>('$walletId:$utxoId');
        if (utxo == null || utxo.isDeleted) return;
        if (utxo.status == utxoStatusToString(UtxoStatus.locked)) {
          _setUtxoState(utxo, utxoStatusToString(UtxoStatus.unspent), utxo.spentByTransactionHash);
        } else if (utxo.status == utxoStatusToString(UtxoStatus.unspent)) {
          _setUtxoState(utxo, utxoStatusToString(UtxoStatus.locked), utxo.spentByTransactionHash);
        }
      });
    });
  }

  Future<Result<void>> lockAllUtxos(int walletId, List<String> utxoIds) {
    return handleAsyncRealm(() => updateUtxoStatus(walletId, utxoIds, UtxoStatus.locked));
  }

  /// 재동기화 시작 전 호출. 잠금된 UTXO id 집합을 메모리로만 반환한다(Realm에 저장하지 않음).
  Set<String> snapshotLockedUtxoIds(int walletId) {
    return getUtxosByStatus(walletId, UtxoStatus.locked).map((u) => u.utxoId).toSet();
  }

  /// 재동기화 완료 후 호출. 스냅샷 중 새로 동기화된 상태가 unspent인 것만 다시 locked로 되돌린다.
  /// 이미 spent/incoming으로 바뀐 UTXO는 절대 강제로 잠그지 않는다.
  Future<void> restoreLockedUtxos(int walletId, Set<String> lockedUtxoIdsSnapshot) async {
    if (lockedUtxoIdsSnapshot.isEmpty) return;

    await updateUtxoStatus(walletId, lockedUtxoIdsSnapshot.toList(), UtxoStatus.locked);
  }

  /// 앱 업데이트 마이그레이션에서 보관한 잠금 설정을 최신 UTXO 동기화 결과에 적용한다.
  /// 잠금 복원이 확인된 항목만 제거하고, 미조회·미확정 항목은 다음 동기화를 위해 유지한다.
  Future<void> restorePendingUtxoLocks(int walletId) async {
    await realm.writeAsync(() {
      final pendingLocks = realm.query<RealmPendingUtxoLock>(r'walletId == $0', [walletId]).toList();
      for (final pendingLock in pendingLocks) {
        final utxo = realm.find<RealmUtxo>(pendingLock.id);
        if (utxo == null || utxo.walletId != walletId || utxo.isDeleted) continue;

        if (utxo.status == utxoStatusToString(UtxoStatus.unspent)) {
          _setUtxoState(utxo, utxoStatusToString(UtxoStatus.locked), utxo.spentByTransactionHash);
        }
        if (utxo.status == utxoStatusToString(UtxoStatus.locked)) {
          realm.delete(pendingLock);
        }
      }
    });
  }

  Future<void> updateUtxoStatus(int walletId, List<String> utxoList, UtxoStatus status) async {
    if (status != UtxoStatus.unspent && status != UtxoStatus.locked) {
      throw ArgumentError.value(status, 'status', 'Only user lock changes are supported');
    }
    final realmUtxoIds = utxoList.map((utxoId) => '$walletId:$utxoId').toList();
    await realm.writeAsync(() {
      final utxos = realm.query<RealmUtxo>(r'walletId == $0 AND id IN $1 AND isDeleted == false', [
        walletId,
        realmUtxoIds,
      ]);
      for (final utxo in utxos) {
        if (utxo.status == utxoStatusToString(UtxoStatus.unspent) ||
            utxo.status == utxoStatusToString(UtxoStatus.locked)) {
          _setUtxoState(utxo, utxoStatusToString(status), utxo.spentByTransactionHash);
        }
      }
    });
  }

  Future<void> deleteUtxoList(
    int walletId,
    List<String> utxoIds, {
    Map<String, int>? expectedVersions,
    bool confirmed = false,
  }) async {
    realm.refresh();
    final ids = utxoIds.map((outpoint) => '$walletId:$outpoint').toList();
    final hasCoin = realm.query<RealmUtxo>(r'id IN $0 AND isDeleted == false', [ids]).isNotEmpty;
    if (!hasCoin) {
      final revisions = ids.map((id) => '$_revisionPrefix$id').toList();
      if (!confirmed || realm.query<RealmIntegerId>(r'key IN $0', [revisions]).isEmpty) return;
    }
    final versions = confirmed ? null : expectedVersions ?? snapshotUtxoVersions(walletId);
    await realm.writeAsync(() {
      final deletedIds = <String>{};
      for (final outpoint in utxoIds) {
        final id = '$walletId:$outpoint';
        final utxo = realm.find<RealmUtxo>(id);
        if (utxo?.isDeleted == true) continue;
        final revision = realm.find<RealmIntegerId>('$_revisionPrefix$id');
        if (utxo == null) {
          // 사라진 CPFP 출력의 소비가 확정되면 나중의 조회로도 되살릴 수 없다.
          if (!confirmed || revision == null) continue;
          realm.add(RealmIntegerId('$_spentRevisionPrefix$id', revision.value + 1), update: true);
        } else {
          if (versions != null && versions[id] != (revision?.value ?? 0)) continue;
          utxo.isDeleted = true;
        }
        if (revision != null) realm.delete(revision);
        versions?.remove(id);
        final pendingLock = realm.find<RealmPendingUtxoLock>(id);
        if (pendingLock != null) realm.delete(pendingLock);
        deletedIds.add(outpoint);
      }
      if (deletedIds.isEmpty) return;
      for (final tag in realm.query<RealmUtxoTag>(r'walletId == $0', [walletId])) {
        tag.utxoIdList.removeWhere(deletedIds.contains);
      }
    });
  }

  /// CPFP 자식은 다시 나타날 수 있다. 태그와 잠금을 보존하고 삭제 전의 조회만 무효화한다.
  static void removeOrphanedCpfpOutputsInWrite(Realm realm, Iterable<RealmUtxo> utxos, Map<String, int> versions) {
    assert(realm.isInTransaction);
    for (final utxo in utxos.toList()) {
      if (utxo.isDeleted || versions[utxo.id] != _stateVersion(realm, utxo)) continue;
      versions[utxo.id] = _advanceStateVersion(realm, utxo);
      realm.delete(utxo);
    }
  }

  Future<void> deleteUtxosByReplacedTransactionHashSet(
    int walletId,
    Set<String> replacedTxHashSet, {
    Map<String, int>? expectedVersions,
  }) async {
    final versions = expectedVersions ?? snapshotUtxoVersions(walletId);
    final utxos = realm.query<RealmUtxo>(r'walletId == $0 AND transactionHash IN $1 AND isDeleted == false', [
      walletId,
      replacedTxHashSet,
    ]);
    await deleteUtxoList(
      walletId,
      utxos.map((u) => getUtxoId(u.transactionHash, u.index)).toList(),
      expectedVersions: versions,
    );
  }

  /// 더 최근의 다른 송금 예약 때문에 소비자를 반영하지 못한 입력이 있으면 false를 반환한다.
  Future<bool> markUtxoAsOutgoing(
    int walletId,
    lib.Transaction transaction, {
    Map<String, int>? expectedVersions,
  }) async {
    realm.refresh();
    final ids =
        transaction.inputs.map((input) => getRealmUtxoId(walletId, input.transactionHash, input.index)).toList();
    if (realm.query<RealmUtxo>(r'id IN $0 AND isDeleted == false', [ids]).isEmpty) return true;
    final versions = expectedVersions ?? snapshotUtxoVersions(walletId);
    return realm.writeAsync(() {
      var matched = true;
      for (final id in ids) {
        final utxo = realm.find<RealmUtxo>(id);
        if (utxo == null || utxo.isDeleted) continue;
        if (utxo.status == utxoStatusToString(UtxoStatus.outgoing) && versions[id] != _stateVersion(realm, utxo)) {
          if (utxo.spentByTransactionHash != transaction.transactionHash) matched = false;
          continue;
        }
        _setUtxoState(utxo, utxoStatusToString(UtxoStatus.outgoing), transaction.transactionHash);
        versions[id] = _stateVersion(realm, utxo);
      }
      return matched;
    });
  }

  /// 방금 전송한 확정 입력을 예약한다. 전송 도중 사용자 잠금이 먼저 반영되어도 예약이 우선한다.
  Future<void> markUnspentInputsAsOutgoing(int walletId, lib.Transaction transaction) async {
    await realm.writeAsync(() {
      for (final input in transaction.inputs) {
        final utxo = realm.find<RealmUtxo>(getRealmUtxoId(walletId, input.transactionHash, input.index));
        if (utxo == null || utxo.isDeleted) continue;
        if (utxo.status == utxoStatusToString(UtxoStatus.outgoing)) {
          _advanceStateVersion(realm, utxo); // 같은 화면 재시도·늦은 성공도 이전 조회로 풀리지 않게 예약을 갱신한다.
          continue;
        }
        if (utxo.status != utxoStatusToString(UtxoStatus.unspent) &&
            utxo.status != utxoStatusToString(UtxoStatus.locked)) {
          continue;
        }
        if (utxo.status == utxoStatusToString(UtxoStatus.locked)) {
          realm.add(
            RealmPendingUtxoLock(utxo.id, walletId, getUtxoId(input.transactionHash, input.index)),
            update: true,
          );
        }
        _setUtxoState(utxo, utxoStatusToString(UtxoStatus.outgoing), transaction.transactionHash);
      }
    });
  }

  Future<void> deleteUtxosByTransaction(int walletId, lib.Transaction transaction) async {
    final utxoIds = transaction.inputs.map((input) => getUtxoId(input.transactionHash, input.index)).toList();
    await deleteUtxoList(walletId, utxoIds, confirmed: true);
  }

  /// 선택된 UTXO의 상태를 확인하고 유효한 UTXO 목록과 제외된 상태를 반환
  /// - 사용 가능한 UTXO만 validUtxoList에 포함
  /// - 사용되었거나 잠긴 UTXO가 있으면 excludedStatus에 해당 상태 반환
  (List<UtxoState> validUtxoList, SelectedUtxoExcludedStatus? excludedStatus) getValidatedSelectedUtxoList(
    int walletId,
    List<String> selectedUtxoIds,
  ) {
    if (selectedUtxoIds.isEmpty) return ([], null);

    final utxoList = getUtxoStateList(walletId);

    final List<UtxoState> validatedList = [];
    final Set<String> foundIds = {};
    bool hasLocked = false;

    for (final utxo in utxoList) {
      if (selectedUtxoIds.contains(utxo.utxoId)) {
        if (utxo.status == UtxoStatus.outgoing) {
          continue;
        }

        if (utxo.status == UtxoStatus.locked) {
          hasLocked = true;
        } else {
          validatedList.add(utxo);
        }
        foundIds.add(utxo.utxoId);
      }
    }

    final bool hasUsed = foundIds.length < selectedUtxoIds.length;

    SelectedUtxoExcludedStatus? excludedStatus;
    if (hasUsed) {
      excludedStatus = SelectedUtxoExcludedStatus.used;
    } else if (hasLocked) {
      excludedStatus = SelectedUtxoExcludedStatus.locked;
    }

    return (validatedList, excludedStatus);
  }
}
