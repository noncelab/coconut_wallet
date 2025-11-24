import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart' as lib;
import 'package:coconut_wallet/constants/secure_keys.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/view_model/send/refactor/send_view_model.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/utils/result.dart';

/// 선택된 UTXO의 상태를 나타내는 enum
enum SelectedUtxoStatus {
  unused, // 모든 UTXO가 사용 가능
  used, // 일부 UTXO가 이미 사용됨
  locked, // 일부 UTXO가 잠금됨
}

/// RecipientInfo 리스트를 JSON 문자열 리스트로 변환
List<String> _recipientListToJson(List<RecipientInfo> recipients) {
  return recipients.map((recipient) {
    return jsonEncode({
      'address': recipient.address,
      'amount': recipient.amount,
      'addressError': recipient.addressError.name,
      'minimumAmountError': recipient.minimumAmountError.name,
    });
  }).toList();
}

/// JSON 문자열 리스트를 RecipientInfo 리스트로 변환
List<RecipientInfo> _jsonToRecipientList(List<String> recipientListJson) {
  return recipientListJson.map((jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return RecipientInfo(
      address: json['address'] as String? ?? '',
      amount: json['amount'] as String? ?? '',
      addressError: _parseAddressError(json['addressError'] as String?),
      minimumAmountError: _parseAmountError(json['minimumAmountError'] as String?),
    );
  }).toList();
}

AddressError _parseAddressError(String? value) {
  if (value == null) return AddressError.none;
  return AddressError.values.firstWhere((e) => e.name == value, orElse: () => AddressError.none);
}

AmountError _parseAmountError(String? value) {
  if (value == null) return AmountError.none;
  return AmountError.values.firstWhere((e) => e.name == value, orElse: () => AmountError.none);
}

/// UtxoState 리스트를 JSON 문자열 리스트로 변환
List<String> _utxoListToJson(List<UtxoState> utxoList) {
  return utxoList.map((utxo) {
    return jsonEncode({
      'transactionHash': utxo.transactionHash,
      'index': utxo.index,
      'amount': utxo.amount,
      'derivationPath': utxo.derivationPath,
      'blockHeight': utxo.blockHeight,
      'to': utxo.to,
      'timestamp': utxo.timestamp.toIso8601String(),
      'tags':
          utxo.tags
              ?.map(
                (tag) => {
                  'id': tag.id,
                  'walletId': tag.walletId,
                  'name': tag.name,
                  'colorIndex': tag.colorIndex,
                  'utxoIdList': tag.utxoIdList,
                },
              )
              .toList(),
      'status': utxo.status.name,
      'spentByTransactionHash': utxo.spentByTransactionHash,
    });
  }).toList();
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

/// SendViewModel 데이터를 RealmTransactionDraft로 변환
RealmTransactionDraft _mapToRealmTransactionDraft({
  required int id,
  required int walletId,
  required List<RecipientInfo> recipientList,
  required String? feeRateText,
  required bool isMaxMode,
  required bool isMultisig,
  required bool isFeeSubtractedFromSendAmount,
  lib.Transaction? transaction,
  String? txWaitingForSign,
  String? signedPsbtBase64Encoded,
  required String currentUnit,
  List<UtxoState>? selectedUtxoList,
  int? totalAmount,
}) {
  final feeRate = feeRateText != null && feeRateText.isNotEmpty ? double.tryParse(feeRateText) : null;
  final transactionHex = transaction?.serialize();

  return RealmTransactionDraft(
    id,
    walletId,
    feeRate: feeRate,
    isMaxMode: isMaxMode,
    isMultisig: isMultisig,
    isFeeSubtractedFromSendAmount: isFeeSubtractedFromSendAmount,
    transactionHex: transactionHex,
    txWaitingForSign: txWaitingForSign,
    signedPsbtBase64Encoded: signedPsbtBase64Encoded,
    recipientListJson: _recipientListToJson(recipientList),
    createdAt: DateTime.now(),
    currentUnit: currentUnit,
    selectedUtxoListJson: selectedUtxoList != null ? _utxoListToJson(selectedUtxoList) : const [],
    totalAmount: totalAmount,
  );
}

class TransactionDraftRepository extends BaseRepository {
  final UtxoRepository _utxoRepository;
  final SecureStorageRepository _secureStorage = SecureStorageRepository();

  TransactionDraftRepository(super._realmManager, this._utxoRepository);

  /// Unsigned TransactionDraft 저장
  Future<Result<RealmTransactionDraft>> saveUnsignedTransactionDraft({
    required int walletId,
    List<RecipientInfo>? recipientList,
    required String? feeRateText,
    required bool isMaxMode,
    required bool isMultisig,
    bool? isFeeSubtractedFromSendAmount,
    lib.Transaction? transaction,
    String? txWaitingForSign,
    String? signedPsbtBase64Encoded,
    required String currentUnit,
    List<UtxoState>? selectedUtxoList,
    int? totalAmount,
  }) async {
    // SignedTransactionDraft인 경우 SecureStorage에만 저장
    if (signedPsbtBase64Encoded != null && signedPsbtBase64Encoded.isNotEmpty) {
      return await _saveSignedTransactionDraftToSecureStorage(
        walletId: walletId,
        recipientList: recipientList ?? [],
        feeRateText: feeRateText,
        isMaxMode: isMaxMode,
        isMultisig: isMultisig,
        isFeeSubtractedFromSendAmount: isFeeSubtractedFromSendAmount ?? false,
        transaction: transaction,
        txWaitingForSign: txWaitingForSign,
        signedPsbtBase64Encoded: signedPsbtBase64Encoded,
        currentUnit: currentUnit,
        selectedUtxoList: selectedUtxoList,
        totalAmount: totalAmount,
      );
    }

    // UnsignedTransactionDraft는 Realm에 저장
    return handleAsyncRealm<RealmTransactionDraft>(() async {
      final lastId = getLastId(realm, (RealmTransactionDraft).toString());
      final newId = lastId + 1;

      final draft = _mapToRealmTransactionDraft(
        id: newId,
        walletId: walletId,
        recipientList: recipientList ?? [],
        feeRateText: feeRateText,
        isMaxMode: isMaxMode,
        isMultisig: isMultisig,
        isFeeSubtractedFromSendAmount: isFeeSubtractedFromSendAmount ?? false,
        transaction: transaction,
        txWaitingForSign: txWaitingForSign,
        signedPsbtBase64Encoded: null, // Unsigned는 null
        currentUnit: currentUnit,
        selectedUtxoList: selectedUtxoList,
        totalAmount: totalAmount,
      );

      await realm.writeAsync(() {
        realm.add(draft);
      });

      saveLastId(realm, (RealmTransactionDraft).toString(), newId);

      return draft;
    });
  }

  /// TransactionDraft 업데이트
  Future<Result<RealmTransactionDraft>> updateUnsignedTransactionDraft({
    required int id,
    int? walletId,
    List<RecipientInfo>? recipientList,
    String? feeRateText,
    bool? isMaxMode,
    bool? isMultisig,
    bool? isFeeSubtractedFromSendAmount,
    lib.Transaction? transaction,
    String? txWaitingForSign,
    String? signedPsbtBase64Encoded,
    String? currentUnit,
    List<UtxoState>? selectedUtxoList,
  }) async {
    return handleAsyncRealm<RealmTransactionDraft>(() async {
      final draft = realm.find<RealmTransactionDraft>(id);
      if (draft == null) {
        throw StateError('[updateTransactionDraft] Draft not found: $id');
      }

      await realm.writeAsync(() {
        if (walletId != null) draft.walletId = walletId;
        if (feeRateText != null) {
          draft.feeRate = feeRateText.isNotEmpty ? double.tryParse(feeRateText) : null;
        }
        if (isMaxMode != null) draft.isMaxMode = isMaxMode;
        if (isMultisig != null) draft.isMultisig = isMultisig;
        if (isFeeSubtractedFromSendAmount != null) draft.isFeeSubtractedFromSendAmount = isFeeSubtractedFromSendAmount;
        if (transaction != null) draft.transactionHex = transaction.serialize();
        if (txWaitingForSign != null) draft.txWaitingForSign = txWaitingForSign;
        if (signedPsbtBase64Encoded != null) draft.signedPsbtBase64Encoded = signedPsbtBase64Encoded;
        if (recipientList != null) {
          draft.recipientListJson.clear();
          draft.recipientListJson.addAll(_recipientListToJson(recipientList));
        }
        if (currentUnit != null) draft.currentUnit = currentUnit;
        if (selectedUtxoList != null) {
          draft.selectedUtxoListJson.clear();
          draft.selectedUtxoListJson.addAll(_utxoListToJson(selectedUtxoList));
        }
      });

      return draft;
    });
  }

  /// Unsigned TransactionDraft 조회 (ID로)
  RealmTransactionDraft? getUnsignedTransactionDraft(int id) {
    return realm.find<RealmTransactionDraft>(id);
  }

  /// 모든 Unsigned TransactionDraft 조회
  List<RealmTransactionDraft> getAllUnsignedTransactionDrafts() {
    return realm.all<RealmTransactionDraft>().toList();
  }

  /// walletId로 Unsigned TransactionDraft 조회
  List<RealmTransactionDraft> getUnsignedTransactionDraftsByWalletId(int walletId) {
    return realm.query<RealmTransactionDraft>('walletId == $walletId').toList();
  }

  /// RealmTransactionDraft를 RecipientInfo 리스트와 함께 반환하는 헬퍼 클래스
  TransactionDraftData? getUnsignedTransactionDraftData(int id) {
    final draft = getUnsignedTransactionDraft(id);
    if (draft == null) return null;

    return TransactionDraftData(
      draft: draft,
      recipientList: _jsonToRecipientList(draft.recipientListJson.toList()),
      transaction: draft.transactionHex != null ? lib.Transaction.parse(draft.transactionHex!) : null,
    );
  }

  /// Signed TransactionDraft 삭제
  Future<Result<void>> deleteTransactionDraft(int id) async {
    return await deleteSignedTransactionDraft(id);
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

  /// 모든 TransactionDraft 삭제
  Future<Result<void>> deleteAllUnsignedTransactionDrafts() async {
    return handleAsyncRealm<void>(() async {
      await realm.writeAsync(() {
        realm.deleteAll<RealmTransactionDraft>();
      });
    });
  }

  /// 선택된 UTXO의 상태 확인 (unused, used, locked)
  SelectedUtxoStatus getSelectedUtxoStatus(int walletId, List<String> selectedUtxoListJson) {
    if (selectedUtxoListJson.isEmpty) return SelectedUtxoStatus.unused;

    final utxoList = _utxoRepository.getUtxoStateList(walletId);
    final selectedUtxoIds = _jsonToUtxoList(selectedUtxoListJson).map((utxo) => utxo.utxoId).toList();

    bool hasUsed = false;
    bool hasLocked = false;

    for (final utxo in utxoList) {
      if (selectedUtxoIds.contains(utxo.utxoId)) {
        if (utxo.status == UtxoStatus.locked) {
          hasLocked = true;
        } else if (utxo.status != UtxoStatus.unspent) {
          hasUsed = true;
        }
      }
    }

    if (hasUsed) return SelectedUtxoStatus.used;
    if (hasLocked) return SelectedUtxoStatus.locked;
    return SelectedUtxoStatus.unused;
  }

  /// SignedTransactionDraft를 SecureStorage에 저장
  Future<Result<RealmTransactionDraft>> _saveSignedTransactionDraftToSecureStorage({
    required int walletId,
    required List<RecipientInfo> recipientList,
    required String? feeRateText,
    required bool isMaxMode,
    required bool isMultisig,
    required bool isFeeSubtractedFromSendAmount,
    lib.Transaction? transaction,
    String? txWaitingForSign,
    required String signedPsbtBase64Encoded,
    required String currentUnit,
    List<UtxoState>? selectedUtxoList,
    int? totalAmount,
  }) async {
    try {
      // ID 생성 (Realm의 lastId를 사용하되, Signed는 별도로 관리)
      final lastId = getLastId(realm, (RealmTransactionDraft).toString());
      final newId = lastId + 1;

      final draft = _mapToRealmTransactionDraft(
        id: newId,
        walletId: walletId,
        recipientList: recipientList,
        feeRateText: feeRateText,
        isMaxMode: isMaxMode,
        isMultisig: isMultisig,
        isFeeSubtractedFromSendAmount: isFeeSubtractedFromSendAmount,
        transaction: transaction,
        txWaitingForSign: txWaitingForSign,
        signedPsbtBase64Encoded: signedPsbtBase64Encoded,
        currentUnit: currentUnit,
        selectedUtxoList: selectedUtxoList,
        totalAmount: totalAmount,
      );

      final key = '$kSecureStorageSignedTransactionDraftPrefix$newId';
      final jsonData = jsonEncode({
        'id': draft.id,
        'walletId': draft.walletId,
        'feeRate': draft.feeRate,
        'isMaxMode': draft.isMaxMode,
        'isMultisig': draft.isMultisig,
        'isFeeSubtractedFromSendAmount': draft.isFeeSubtractedFromSendAmount,
        'transactionHex': draft.transactionHex,
        'txWaitingForSign': draft.txWaitingForSign,
        'signedPsbtBase64Encoded': draft.signedPsbtBase64Encoded,
        'recipientListJson': draft.recipientListJson.toList(),
        'createdAt': draft.createdAt?.toIso8601String(),
        'currentUnit': draft.currentUnit,
        'selectedUtxoListJson': draft.selectedUtxoListJson.toList(),
        'totalAmount': draft.totalAmount,
      });
      await _secureStorage.write(key: key, value: jsonData);

      // ID를 업데이트하여 다음 SignedTransactionDraft가 다른 ID를 사용하도록 함
      saveLastId(realm, (RealmTransactionDraft).toString(), newId);

      return Result<RealmTransactionDraft>.success(draft);
    } catch (e) {
      return Result<RealmTransactionDraft>.failure(
        AppError('SAVE_SIGNED_DRAFT_ERROR', 'Failed to save signed transaction draft: $e'),
      );
    }
  }

  /// SecureStorage에서 SignedTransactionDraft 조회
  Future<RealmTransactionDraft?> _getSignedTransactionDraftFromSecureStorage(int id) async {
    final key = '$kSecureStorageSignedTransactionDraftPrefix$id';
    try {
      final jsonString = await _secureStorage.read(key: key);
      if (jsonString == null) return null;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return RealmTransactionDraft(
        json['id'] as int,
        json['walletId'] as int,
        feeRate: json['feeRate'] as double?,
        isMaxMode: json['isMaxMode'] as bool?,
        isMultisig: json['isMultisig'] as bool?,
        isFeeSubtractedFromSendAmount: json['isFeeSubtractedFromSendAmount'] as bool?,
        transactionHex: json['transactionHex'] as String?,
        txWaitingForSign: json['txWaitingForSign'] as String?,
        signedPsbtBase64Encoded: json['signedPsbtBase64Encoded'] as String?,
        recipientListJson: (json['recipientListJson'] as List<dynamic>).map((e) => e as String).toList(),
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
        currentUnit: json['currentUnit'] as String?,
        selectedUtxoListJson: (json['selectedUtxoListJson'] as List<dynamic>).map((e) => e as String).toList(),
        totalAmount: json['totalAmount'] as int?,
      );
    } catch (e) {
      return null;
    }
  }

  /// 모든 SignedTransactionDraft 조회
  Future<List<RealmTransactionDraft>> getAllSignedTransactionDrafts() async {
    final allKeys = await _secureStorage.getAllKeys();
    final signedDraftKeys = allKeys.where((key) => key.startsWith(kSecureStorageSignedTransactionDraftPrefix)).toList();

    final drafts = <RealmTransactionDraft>[];
    for (final key in signedDraftKeys) {
      final idString = key.replaceFirst(kSecureStorageSignedTransactionDraftPrefix, '');
      final id = int.tryParse(idString);
      if (id != null) {
        final draft = await _getSignedTransactionDraftFromSecureStorage(id);
        if (draft != null) {
          drafts.add(draft);
        }
      }
    }

    return drafts;
  }

  /// SignedTransactionDraft 삭제
  Future<Result<void>> deleteSignedTransactionDraft(int id) async {
    try {
      final key = '$kSecureStorageSignedTransactionDraftPrefix$id';
      await _secureStorage.delete(key: key);
      return Result<void>.success(null);
    } catch (e) {
      return Result<void>.failure(
        AppError('DELETE_SIGNED_DRAFT_ERROR', 'Failed to delete signed transaction draft: $e'),
      );
    }
  }

  /// 모든 TransactionDraft 조회 (Unsigned + Signed)
  Future<List<RealmTransactionDraft>> getAllTransactionDrafts() async {
    final unsignedDrafts = getAllUnsignedTransactionDrafts();
    final signedDrafts = await getAllSignedTransactionDrafts();

    final allDrafts = [...unsignedDrafts, ...signedDrafts];

    // createdAt 기준 최신순으로 정렬
    allDrafts.sort((a, b) {
      final aCreatedAt = a.createdAt;
      final bCreatedAt = b.createdAt;
      if (aCreatedAt == null && bCreatedAt == null) return 0;
      if (aCreatedAt == null) return 1;
      if (bCreatedAt == null) return -1;
      return bCreatedAt.compareTo(aCreatedAt);
    });

    return allDrafts;
  }
}

/// TransactionDraft와 변환된 데이터를 함께 담는 클래스
class TransactionDraftData {
  final RealmTransactionDraft draft;
  final List<RecipientInfo> recipientList;
  final lib.Transaction? transaction;

  TransactionDraftData({required this.draft, required this.recipientList, required this.transaction});
}
