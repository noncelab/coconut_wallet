import 'dart:convert';

import 'package:coconut_wallet/constants/secure_keys.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/providers/view_model/send/refactor/send_view_model.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/transaction_draft.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:realm/realm.dart';

/// 선택된 UTXO의 상태를 나타내는 enum
enum SelectedUtxoExcludedStatus {
  used, // 일부 UTXO가 이미 사용됨
  locked, // 일부 UTXO가 잠금됨
}

/// JSON 문자열 리스트를 UtxoState 리스트로 변환
List<UtxoState> _jsonToUtxoList(List<String> utxoListJson) {
  return utxoListJson.map((jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final tagsJson = json['tags'] as List<dynamic>?;
    final tags =
        tagsJson?.map((tagJson) {
          return UtxoTag(
            id: tagJson['id'] as String,
            walletId: tagJson['walletId'] as int,
            name: tagJson['name'] as String,
            colorIndex: tagJson['colorIndex'] as int,
            utxoIdList: (tagJson['utxoIdList'] as List<dynamic>?)?.map((e) => e as String).toList(),
          );
        }).toList();

    final statusString = json['status'] as String? ?? 'unspent';
    final status = UtxoStatus.values.firstWhere((s) => s.name == statusString, orElse: () => UtxoStatus.unspent);

    return UtxoState(
      transactionHash: json['transactionHash'] as String,
      index: json['index'] as int,
      amount: json['amount'] as int,
      derivationPath: json['derivationPath'] as String,
      blockHeight: json['blockHeight'] as int,
      to: json['to'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      tags: tags,
      status: status,
      spentByTransactionHash: json['spentByTransactionHash'] as String?,
    );
  }).toList();
}

class TransactionDraftRepository extends BaseRepository {
  final UtxoRepository _utxoRepository;
  final SecureStorageRepository _secureStorage = SecureStorageRepository();

  TransactionDraftRepository(super._realmManager, this._utxoRepository);

  Future<Result<TransactionDraft>> saveUnsignedDraft({
    required int walletId,
    required double feeRate,
    required bool isMaxMode,
    //required bool isMultisig, // TODO: 필요?
    required bool isFeeSubtractedFromSendAmount,
    required List<RecipientDraft> recipients,
    required BitcoinUnit bitcoinUnit,
    List<String>? selectedUtxoIds,
  }) {
    return handleAsyncRealm<TransactionDraft>(() async {
      final lastId = getLastId(realm, (RealmTransactionDraft).toString());
      final newId = lastId + 1;

      final txDraft = TransactionDraft(
        id: newId,
        walletId: walletId,
        recipients: recipients,
        createdAt: DateTime.now(),
        feeRate: feeRate,
        isMaxMode: isMaxMode,
        isFeeSubtractedFromSendAmount: isFeeSubtractedFromSendAmount,
        bitcoinUnit: bitcoinUnit,
        selectedUtxoIds: selectedUtxoIds ?? [],
      );

      final realmDraft = mapTxDraftToRealmTxDraft(txDraft);

      realm.write(() {
        realm.add(realmDraft);
      });

      saveLastId(realm, (RealmTransactionDraft).toString(), newId);

      return txDraft;
    });
  }

  Future<Result<TransactionDraft>> updateUnsignedDraft({
    required int draftId,
    required double feeRate,
    required bool isMaxMode,
    //required bool isMultisig, // TODO: 필요?
    required bool isFeeSubtractedFromSendAmount,
    required List<RecipientDraft> recipients,
    required BitcoinUnit bitcoinUnit,
    List<String>? selectedUtxoIds,
  }) {
    return handleAsyncRealm<TransactionDraft>(() async {
      final draft = realm.find<RealmTransactionDraft>(draftId);
      if (draft == null) {
        throw StateError('No draft found with id $draftId');
      }

      final txDraft = TransactionDraft(
        id: draftId,
        walletId: draft.walletId,
        recipients: recipients,
        createdAt: draft.createdAt,
        feeRate: feeRate,
        isMaxMode: isMaxMode,
        isFeeSubtractedFromSendAmount: isFeeSubtractedFromSendAmount,
        bitcoinUnit: bitcoinUnit,
        selectedUtxoIds: selectedUtxoIds ?? [],
      );

      realm.write(() {
        draft
          ..feeRate = feeRate
          ..isMaxMode = isMaxMode
          ..isFeeSubtractedFromSendAmount = isFeeSubtractedFromSendAmount
          ..recipientJsons.clear()
          ..recipientJsons.addAll(RecipientDraft.toJsonList(recipients))
          ..bitcoinUnit = bitcoinUnit.symbol
          ..selectedUtxoIds.clear()
          ..selectedUtxoIds.addAll(selectedUtxoIds ?? []);
      });

      return txDraft;
    });
  }

  Future<Result<TransactionDraft>> saveSignedDraft({
    required int walletId,
    required List<RecipientDraft> recipients,
    required double feeRate,
    required bool isMaxMode,
    required String txWaitingForSign,
    required String signedPsbtBase64Encoded,
  }) {
    return handleAsyncRealm<TransactionDraft>(() async {
      final lastId = getLastId(realm, (RealmTransactionDraft).toString());
      final newId = lastId + 1;

      // signed tx는 secure storage에 저장
      final signedTxKey = _getSignedTransactionStorageKey(newId);
      await _secureStorage.write(key: signedTxKey, value: signedPsbtBase64Encoded);

      final txDraft = TransactionDraft(
        id: newId,
        walletId: walletId,
        recipients: recipients,
        feeRate: feeRate,
        isMaxMode: isMaxMode,
        txWaitingForSign: txWaitingForSign,
        createdAt: DateTime.now(),
      );
      final realmDraft = mapTxDraftToRealmTxDraft(txDraft);

      realm.write(() {
        realm.add(realmDraft);
      });

      saveLastId(realm, (RealmTransactionDraft).toString(), newId);

      return txDraft;
    });
  }

  String _getSignedTransactionStorageKey(int draftId) {
    return '${SecureStorageKeys.kSignedTransactionDraftPrefix}$draftId';
  }

  Future<String?> _getSignedPsbtBase64(int draftId) async {
    return await _secureStorage.read(key: _getSignedTransactionStorageKey(draftId));
  }

  /// signed draft ID로만 요청한다고 가정하고 구현했습니다.
  Future<Result<TransactionDraft>> getSignedDraft(int draftId) async {
    final draft = realm.find<RealmTransactionDraft>(draftId);
    assert(draft != null);
    assert(_isSignedDraft(draft!));

    final signedPsbtBase64Encoded = await _getSignedPsbtBase64(draftId);
    assert(signedPsbtBase64Encoded != null);

    return Result.success(mapRealmTxDraftToTxDraft(draft!, signedPsbtBase64Encoded!));
  }

  bool _isSignedDraft(RealmTransactionDraft draft) {
    final hasRequired = draft.txWaitingForSign != null;
    final noHaveUnsignedDraftRequired =
        //draft.recipientJsons.isEmpty &&
        //draft.feeRate == null &&
        //draft.isMaxMode == null &&
        draft.isFeeSubtractedFromSendAmount == null && draft.bitcoinUnit == null && draft.selectedUtxoIds.isEmpty;

    return hasRequired && noHaveUnsignedDraftRequired;
  }

  /// ------------------------------------------------------------------------------------
  ///
  /// Unsigned TransactionDraft 조회 (ID로)
  TransactionDraft? getUnsignedTransactionDraft(int id) {
    final draft = realm.find<RealmTransactionDraft>(id);
    if (draft == null) return null;
    return mapRealmTxDraftToTxDraft(draft, null);
  }

  List<TransactionDraft> getAllUnsignedDrafts() {
    return realm
        .all<RealmTransactionDraft>()
        .query('txWaitingForSign == null SORT(id DESC)')
        .map((draft) => mapRealmTxDraftToTxDraft(draft, null))
        .toList();
  }

  Future<List<TransactionDraft>> getAllSignedDrafts() async {
    final realmDrafts = realm.all<RealmTransactionDraft>().query('txWaitingForSign != null SORT(id DESC)');
    List<TransactionDraft> drafts = [];
    for (final draft in realmDrafts) {
      final signedPsbtBase64Encoded = await _getSignedPsbtBase64(draft.id);
      assert(signedPsbtBase64Encoded != null);
      drafts.add(mapRealmTxDraftToTxDraft(draft, signedPsbtBase64Encoded!));
    }

    return drafts;
  }

  TransactionDraft getSignedDraftWithoutPsbt(int draftId) {
    final realmDraft = realm.find<RealmTransactionDraft>(draftId);
    if (realmDraft == null) {
      throw StateError('[getSignedDraftWithoutPsbt] TransactionDraft not found');
    }
    final draft = mapRealmTxDraftToTxDraft(realmDraft, null);
    if (!draft.isSigned) {
      throw StateError('[getSignedDraftWithoutPsbt] TransactionDraft is not signed');
    }
    return draft;
  }

  /// walletId로 Unsigned TransactionDraft 조회
  List<TransactionDraft> getUnsignedTransactionDraftsByWalletId(int walletId) {
    return realm
        .query<RealmTransactionDraft>('walletId == $walletId AND feeRate != nil SORT(createdAt DESC)')
        .map((draft) => mapRealmTxDraftToTxDraft(draft, null))
        .toList();
  }

  /// Signed TransactionDraft 삭제
  Future<Result<void>> deleteTransactionDraft(int id) async {
    return await deleteSignedDraft(id);
  }

  /// Unsigned TransactionDraft 삭제
  Future<Result<void>> deleteUnsignedTransactionDraft(int id) async {
    return handleAsyncRealm<void>(() async {
      final draft = realm.find<RealmTransactionDraft>(id);
      if (draft == null) {
        throw StateError('[deleteTransactionDraft] Draft not found: $id');
      }

      await realm.writeAsync(() {
        realm.delete(draft);
      });
    });
  }

  /// 선택된 UTXO의 상태를 확인하고 유효한 UTXO 목록과 제외된 상태를 반환
  /// - 사용 가능한 UTXO만 validUtxoList에 포함
  /// - 사용되었거나 잠긴 UTXO가 있으면 excludedStatus에 해당 상태 반환
  (List<UtxoState> validUtxoList, SelectedUtxoExcludedStatus? excludedStatus) getValidatedSelectedUtxoList(
    int walletId,
    List<String> selectedUtxoIds,
  ) {
    if (selectedUtxoIds.isEmpty) return ([], null);

    final utxoList = _utxoRepository.getUtxoStateList(walletId);

    final List<UtxoState> validatedList = [];
    final Set<String> foundIds = {};
    bool hasLocked = false;

    for (final utxo in utxoList) {
      if (selectedUtxoIds.contains(utxo.utxoId)) {
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

  /// SignedTransactionDraft를 SecureStorage에 저장
  // Future<Result<RealmTransactionDraft>> _saveSignedTransactionDraftToSecureStorage({
  //   required int walletId,
  //   required List<RecipientInfo> recipientList,
  //   required String? feeRateText,
  //   required bool isMaxMode,
  //   required bool isMultisig,
  //   required bool isFeeSubtractedFromSendAmount,
  //   lib.Transaction? transaction,
  //   String? txWaitingForSign,
  //   required String signedPsbtBase64Encoded,
  //   required String currentUnit,
  //   List<UtxoState>? selectedUtxoList,
  //   int? totalAmount,
  // }) async {
  //   try {
  //     // ID 생성 (Realm의 lastId를 사용하되, Signed는 별도로 관리)
  //     final lastId = getLastId(realm, (RealmTransactionDraft).toString());
  //     final newId = lastId + 1;

  //     final draft = _mapToRealmTransactionDraft(
  //       id: newId,
  //       walletId: walletId,
  //       recipientList: recipientList,
  //       feeRateText: feeRateText,
  //       isMaxMode: isMaxMode,
  //       isMultisig: isMultisig,
  //       isFeeSubtractedFromSendAmount: isFeeSubtractedFromSendAmount,
  //       transaction: transaction,
  //       txWaitingForSign: txWaitingForSign,
  //       signedPsbtBase64Encoded: signedPsbtBase64Encoded,
  //       currentUnit: currentUnit,
  //       selectedUtxoList: selectedUtxoList,
  //       totalAmount: totalAmount,
  //     );

  //     final key = '$kSecureStorageSignedTransactionDraftPrefix$newId';
  //     final jsonData = jsonEncode({
  //       'id': draft.id,
  //       'walletId': draft.walletId,
  //       'feeRate': draft.feeRate,
  //       'isMaxMode': draft.isMaxMode,
  //       'isMultisig': draft.isMultisig,
  //       'isFeeSubtractedFromSendAmount': draft.isFeeSubtractedFromSendAmount,
  //       'transactionHex': draft.transactionHex,
  //       'txWaitingForSign': draft.txWaitingForSign,
  //       'signedPsbtBase64Encoded': draft.signedPsbtBase64Encoded,
  //       'recipientListJson': draft.recipientJsons.toList(),
  //       'createdAt': draft.createdAt?.toIso8601String(),
  //       'currentUnit': draft.currentUnit,
  //       'selectedUtxoListJson': draft.selectedUtxoIds.toList(),
  //       'totalAmount': draft.totalAmount,
  //     });
  //     await _secureStorage.write(key: key, value: jsonData);

  //     // ID를 업데이트하여 다음 SignedTransactionDraft가 다른 ID를 사용하도록 함
  //     saveLastId(realm, (RealmTransactionDraft).toString(), newId);

  //     return Result<RealmTransactionDraft>.success(draft);
  //   } catch (e) {
  //     return Result<RealmTransactionDraft>.failure(
  //       AppError('SAVE_SIGNED_DRAFT_ERROR', 'Failed to save signed transaction draft: $e'),
  //     );
  //   }
  // }

  /// SecureStorage에서 SignedTransactionDraft 조회
  // Future<RealmTransactionDraft?> _getSignedTransactionDraftFromSecureStorage(int id) async {
  //   final key = '$kSecureStorageSignedTransactionDraftPrefix$id';
  //   try {
  //     final jsonString = await _secureStorage.read(key: key);
  //     if (jsonString == null) return null;

  //     final json = jsonDecode(jsonString) as Map<String, dynamic>;
  //     return RealmTransactionDraft(
  //       json['id'] as int,
  //       json['walletId'] as int,
  //       feeRate: json['feeRate'] as double?,
  //       isMaxMode: json['isMaxMode'] as bool?,
  //       isMultisig: json['isMultisig'] as bool?,
  //       isFeeSubtractedFromSendAmount: json['isFeeSubtractedFromSendAmount'] as bool?,
  //       transactionHex: json['transactionHex'] as String?,
  //       txWaitingForSign: json['txWaitingForSign'] as String?,
  //       signedPsbtBase64Encoded: json['signedPsbtBase64Encoded'] as String?,
  //       recipientJsons: (json['recipientListJson'] as List<dynamic>).map((e) => e as String).toList(),
  //       createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
  //       currentUnit: json['currentUnit'] as String?,
  //       selectedUtxoIds: (json['selectedUtxoListJson'] as List<dynamic>).map((e) => e as String).toList(),
  //       totalAmount: json['totalAmount'] as int?,
  //     );
  //   } catch (e) {
  //     return null;
  //   }
  // }

  /// 모든 SignedTransactionDraft 조회
  // Future<List<RealmTransactionDraft>> getAllSignedTransactionDrafts() async {
  //   final allKeys = await _secureStorage.getAllKeys();
  //   final signedDraftKeys = allKeys.where((key) => key.startsWith(kSecureStorageSignedTransactionDraftPrefix)).toList();

  //   final drafts = <RealmTransactionDraft>[];
  //   for (final key in signedDraftKeys) {
  //     final idString = key.replaceFirst(kSecureStorageSignedTransactionDraftPrefix, '');
  //     final id = int.tryParse(idString);
  //     if (id != null) {
  //       final draft = await _getSignedTransactionDraftFromSecureStorage(id);
  //       if (draft != null) {
  //         drafts.add(draft);
  //       }
  //     }
  //   }

  //   return drafts;
  // }

  /// SignedTransactionDraft 삭제
  Future<Result<void>> deleteSignedDraft(int draftId) async {
    return handleAsyncRealm<void>(() async {
      final draft = realm.find<RealmTransactionDraft>(draftId);
      if (draft == null) {
        throw StateError('Transaction draft not found: $draftId');
      }
      assert(_isSignedDraft(draft));

      realm.write(() {
        realm.delete(draft);
      });

      await _secureStorage.delete(key: _getSignedTransactionStorageKey(draftId));
    });
  }

  Future<Result<void>> deleteOne(int draftId) async {
    return handleAsyncRealm<void>(() async {
      final draft = realm.find<RealmTransactionDraft>(draftId);
      if (draft == null) {
        throw StateError('Transaction draft not found: $draftId');
      }

      realm.write(() {
        realm.delete(draft);
      });

      if (_isSignedDraft(draft)) {
        await _secureStorage.delete(key: _getSignedTransactionStorageKey(draftId));
      }
    });
  }
}

/// TransactionDraft와 변환된 데이터를 함께 담는 클래스
class TransactionDraftData {
  final RealmTransactionDraft draft;
  final List<RecipientInfo> recipientList;

  TransactionDraftData({required this.draft, required this.recipientList});
}
