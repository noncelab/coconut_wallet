import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart' as lib;
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/view_model/send/refactor/send_view_model.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/utils/result.dart';

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
}) {
  final feeRate = feeRateText != null && feeRateText.isNotEmpty ? int.tryParse(feeRateText) : null;
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
  );
}

class TransactionDraftRepository extends BaseRepository {
  TransactionDraftRepository(super._realmManager);

  /// 동일한 TransactionDraft가 이미 존재하는지 확인
  bool _isDuplicateDraft({
    required int walletId,
    required List<RecipientInfo> recipientList,
    required String? feeRateText,
    required bool isMaxMode,
    required bool isMultisig,
    required bool isFeeSubtractedFromSendAmount,
    List<UtxoState>? selectedUtxoList,
  }) {
    final feeRate = feeRateText != null && feeRateText.isNotEmpty ? int.tryParse(feeRateText) : null;
    final recipientListJson = _recipientListToJson(recipientList);
    final selectedUtxoListJson = selectedUtxoList != null ? _utxoListToJson(selectedUtxoList) : const <String>[];

    // walletId로 필터링
    final drafts = realm.query<RealmTransactionDraft>('walletId == $walletId').toList();

    for (final draft in drafts) {
      // feeRate 비교
      if (draft.feeRate != feeRate) continue;

      // isMaxMode 비교
      if (draft.isMaxMode != isMaxMode) continue;

      // isMultisig 비교
      if (draft.isMultisig != isMultisig) continue;

      // 수신자 부담 비교
      if (draft.isFeeSubtractedFromSendAmount != isFeeSubtractedFromSendAmount) continue;

      // recipientListJson 비교 (순서와 개수 모두 일치해야 함)
      if (draft.recipientListJson.length != recipientListJson.length) continue;

      final draftRecipientJsonList = draft.recipientListJson.toList();
      bool isRecipientListIdentical = true;
      for (int i = 0; i < recipientListJson.length; i++) {
        if (draftRecipientJsonList[i] != recipientListJson[i]) {
          isRecipientListIdentical = false;
          break;
        }
      }

      if (!isRecipientListIdentical) continue;

      // selectedUtxoListJson 비교 (순서와 개수 모두 일치해야 함)
      final draftSelectedUtxoListJson = draft.selectedUtxoListJson.toList();
      if (draftSelectedUtxoListJson.length != selectedUtxoListJson.length) continue;

      bool isSelectedUtxoListIdentical = true;
      for (int i = 0; i < selectedUtxoListJson.length; i++) {
        if (draftSelectedUtxoListJson[i] != selectedUtxoListJson[i]) {
          isSelectedUtxoListIdentical = false;
          break;
        }
      }

      if (isSelectedUtxoListIdentical) {
        return true;
      }
    }

    return false;
  }

  /// TransactionDraft 저장
  Future<Result<RealmTransactionDraft>> saveTransactionDraft({
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
  }) async {
    // 동일한 draft가 이미 존재하는지 확인
    if (_isDuplicateDraft(
      walletId: walletId,
      recipientList: recipientList,
      feeRateText: feeRateText,
      isMaxMode: isMaxMode,
      isMultisig: isMultisig,
      isFeeSubtractedFromSendAmount: isFeeSubtractedFromSendAmount,
      selectedUtxoList: selectedUtxoList,
    )) {
      return Result<RealmTransactionDraft>.failure(ErrorCodes.transactionDraftAlreadyExists);
    }

    return handleAsyncRealm<RealmTransactionDraft>(() async {
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
      );

      await realm.writeAsync(() {
        realm.add(draft);
      });

      saveLastId(realm, (RealmTransactionDraft).toString(), newId);

      return draft;
    });
  }

  /// TransactionDraft 업데이트
  Future<Result<RealmTransactionDraft>> updateTransactionDraft({
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
          draft.feeRate = feeRateText.isNotEmpty ? int.tryParse(feeRateText) : null;
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

  /// TransactionDraft 조회 (ID로)
  RealmTransactionDraft? getTransactionDraft(int id) {
    return realm.find<RealmTransactionDraft>(id);
  }

  /// 모든 TransactionDraft 조회
  List<RealmTransactionDraft> getAllTransactionDrafts() {
    return realm.all<RealmTransactionDraft>().toList();
  }

  /// walletId로 TransactionDraft 조회
  List<RealmTransactionDraft> getTransactionDraftsByWalletId(int walletId) {
    return realm.query<RealmTransactionDraft>('walletId == $walletId').toList();
  }

  /// RealmTransactionDraft를 RecipientInfo 리스트와 함께 반환하는 헬퍼 클래스
  TransactionDraftData? getTransactionDraftData(int id) {
    final draft = getTransactionDraft(id);
    if (draft == null) return null;

    return TransactionDraftData(
      draft: draft,
      recipientList: _jsonToRecipientList(draft.recipientListJson.toList()),
      transaction: draft.transactionHex != null ? lib.Transaction.parse(draft.transactionHex!) : null,
    );
  }

  /// TransactionDraft 삭제
  Future<Result<void>> deleteTransactionDraft(int id) async {
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
  Future<Result<void>> deleteAllTransactionDrafts() async {
    return handleAsyncRealm<void>(() async {
      await realm.writeAsync(() {
        realm.deleteAll<RealmTransactionDraft>();
      });
    });
  }
}

/// TransactionDraft와 변환된 데이터를 함께 담는 클래스
class TransactionDraftData {
  final RealmTransactionDraft draft;
  final List<RecipientInfo> recipientList;
  final lib.Transaction? transaction;

  TransactionDraftData({required this.draft, required this.recipientList, required this.transaction});
}
