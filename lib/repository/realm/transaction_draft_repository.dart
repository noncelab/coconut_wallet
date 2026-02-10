import 'package:coconut_wallet/constants/secure_keys.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/transaction_draft.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:realm/realm.dart';

class TransactionDraftRepository extends BaseRepository {
  final SecureStorageRepository _secureStorage = SecureStorageRepository();

  TransactionDraftRepository(super._realmManager);

  Future<Result<TransactionDraft>> saveUnsignedDraft({
    required int walletId,
    required double feeRate,
    required bool isMaxMode,
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

  /// walletId로 Unsigned TransactionDraft 조회
  List<TransactionDraft> getUnsignedTransactionDraftsByWalletId(int walletId) {
    return realm
        .query<RealmTransactionDraft>('walletId == $walletId AND feeRate != nil SORT(createdAt DESC)')
        .map((draft) => mapRealmTxDraftToTxDraft(draft, null))
        .toList();
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

  /// 특정 지갑의 모든 Draft 삭제 (Realm + SecureStorage)
  Future<void> deleteAllByWalletId(int walletId) async {
    final drafts = realm.query<RealmTransactionDraft>('walletId == $walletId');

    // signed draft의 SecureStorage 데이터 삭제
    for (final draft in drafts) {
      if (_isSignedDraft(draft)) {
        await _secureStorage.delete(key: _getSignedTransactionStorageKey(draft.id));
      }
    }

    // Realm 레코드 삭제
    if (drafts.isNotEmpty) {
      await realm.writeAsync(() {
        realm.deleteMany(drafts);
      });
    }
  }

  Future<Result<void>> deleteOne(int draftId) async {
    return handleAsyncRealm<void>(() async {
      final draft = realm.find<RealmTransactionDraft>(draftId);
      if (draft == null) {
        throw StateError('Transaction draft not found: $draftId');
      }

      final isSigned = _isSignedDraft(draft);

      realm.write(() {
        realm.delete(draft);
      });

      if (isSigned) {
        await _secureStorage.delete(key: _getSignedTransactionStorageKey(draftId));
      }
    });
  }
}
