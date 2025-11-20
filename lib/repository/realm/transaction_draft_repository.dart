import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart' as lib;
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
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
  required TransactionDraftStatus draftStatus,
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
    draftStatus: draftStatus.name,
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
  }) {
    final feeRate = feeRateText != null && feeRateText.isNotEmpty ? int.tryParse(feeRateText) : null;
    final recipientListJson = _recipientListToJson(recipientList);

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

      if (isRecipientListIdentical) {
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
    required TransactionDraftStatus draftStatus,
  }) async {
    // 동일한 draft가 이미 존재하는지 확인
    if (_isDuplicateDraft(
      walletId: walletId,
      recipientList: recipientList,
      feeRateText: feeRateText,
      isMaxMode: isMaxMode,
      isMultisig: isMultisig,
      isFeeSubtractedFromSendAmount: isFeeSubtractedFromSendAmount,
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
        draftStatus: draftStatus,
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
    TransactionDraftStatus? draftStatus,
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
        if (draftStatus != null) draft.draftStatus = draftStatus.name;
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

  /// draftStatus로 TransactionDraft 조회
  List<RealmTransactionDraft> getTransactionDraftsByStatus(TransactionDraftStatus status) {
    return realm.query<RealmTransactionDraft>('draftStatus == "${status.name}"').toList();
  }

  /// RealmTransactionDraft를 RecipientInfo 리스트와 함께 반환하는 헬퍼 클래스
  TransactionDraftData? getTransactionDraftData(int id) {
    final draft = getTransactionDraft(id);
    if (draft == null) return null;

    return TransactionDraftData(
      draft: draft,
      recipientList: _jsonToRecipientList(draft.recipientListJson.toList()),
      transaction: draft.transactionHex != null ? lib.Transaction.parse(draft.transactionHex!) : null,
      draftStatus:
          draft.draftStatus != null
              ? TransactionDraftStatusExtension.fromString(draft.draftStatus!)
              : TransactionDraftStatus.unsignedFromSendScreen,
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
  final TransactionDraftStatus draftStatus;

  TransactionDraftData({
    required this.draft,
    required this.recipientList,
    required this.transaction,
    required this.draftStatus,
  });
}
