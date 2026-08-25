import 'dart:io';

import 'package:coconut_wallet/core/bip/329/bip329_converter.dart';
import 'package:coconut_wallet/core/bip/329/bip329_record.dart';
import 'package:coconut_wallet/model/label/label_result.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/label_file_service.dart';
import 'package:flutter/foundation.dart';

typedef UtxoTagInfo = ({String tag, int? colorIndex});

class LabelImportViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;
  final LabelFileService _fileService;
  final Bip329Converter _converter;

  LabelImportViewModel({
    required WalletProvider walletProvider,
    LabelFileService fileService = const LabelFileService(),
    Bip329Converter converter = const Bip329Converter(),
  }) : _walletProvider = walletProvider,
       _fileService = fileService,
       _converter = converter;

  Future<List<File>> getImportableLabelFiles() async {
    return _fileService.getImportableLabelFiles();
  }

  Future<File?> pickAndSaveExternalLabelFile() async {
    return _fileService.pickAndSaveExternalLabelFile();
  }

  Future<void> deleteFile(File file) async {
    await _fileService.deleteFile(file);
  }

  /// Imports labels from file for a single wallet.
  Future<LabelImportResult> importLabelsFromJsonLFile(
    int walletId,
    String filePath, {
    bool overwriteMemo = false,
  }) async {
    final currentWallet = _walletProvider.getWalletById(walletId);
    final origin = Bip329Converter.getOriginFromDescriptor(currentWallet.descriptor);
    final lines = await _fileService.readFileLines(filePath);
    final records = _converter.decodeJsonLines(lines, targetOrigin: origin);

    final result = LabelImportResult(wallet: currentWallet);
    final Map<String, String> txMemos = {};
    final Map<String, List<UtxoTagInfo>> utxoTags = {};
    final Set<String> utxoIdsToLock = {};

    for (final record in records) {
      _processRecord(
        walletId: walletId,
        record: record,
        overwriteMemo: overwriteMemo,
        txMemos: txMemos,
        utxoTags: utxoTags,
        utxoIdsToLock: utxoIdsToLock,
        result: result,
      );
    }

    // Provider / DB Batch Updates
    if (txMemos.isNotEmpty) {
      await _walletProvider.updateTransactionMemos(walletId, txMemos);
    }

    if (utxoTags.isNotEmpty) {
      final List<Future<void>> tagFutures = [];
      for (final entry in utxoTags.entries) {
        for (final tagInfo in entry.value) {
          tagFutures.add(
            _walletProvider.addUtxoToTag(walletId, tagInfo.tag, entry.key, colorIndex: tagInfo.colorIndex),
          );
        }
      }
      await Future.wait(tagFutures);
    }

    if (utxoIdsToLock.isNotEmpty) {
      await _walletProvider.lockUtxos(walletId, utxoIdsToLock.toList());
      result.utxoLockCount = utxoIdsToLock.length;
    }

    return result;
  }

  void _processRecord({
    required int walletId,
    required Bip329Record record,
    required bool overwriteMemo,
    required Map<String, String> txMemos,
    required Map<String, List<UtxoTagInfo>> utxoTags,
    required Set<String> utxoIdsToLock,
    required LabelImportResult result,
  }) {
    if (record.type == Bip329Type.tx) {
      final txHash = record.ref;
      final label = record.label;
      if (label == null || label.isEmpty) return;

      final existingRecord = _walletProvider.getTransactionRecord(walletId, txHash);
      if (existingRecord == null) return;

      final bool hasExistingMemo = existingRecord.memo != null && existingRecord.memo!.isNotEmpty;
      final String finalMemo = (!overwriteMemo && hasExistingMemo) ? '${existingRecord.memo}\n$label' : label;

      txMemos[txHash] = finalMemo;
      result.txMemoCount++;
    } else if (record.type == Bip329Type.output) {
      final utxoId = Bip329Converter.parseRefToUtxoId(record.ref);
      if (utxoId == null || _walletProvider.getUtxoState(walletId, utxoId) == null) {
        return;
      }

      if (record.label != null && record.label!.isNotEmpty) {
        utxoTags.putIfAbsent(utxoId, () => []).add((tag: record.label!, colorIndex: record.tagColor));
        result.utxoTagCount++;
      }

      if (record.spendable == false) {
        utxoIdsToLock.add(utxoId);
      }
    }
  }

  /// Imports labels for a specific wallet and returns non-empty results.
  Future<List<LabelImportResult>> importLabelsForWallet(
    int walletId,
    String filePath, {
    bool overwriteMemo = false,
  }) async {
    final result = await importLabelsFromJsonLFile(walletId, filePath, overwriteMemo: overwriteMemo);

    if (result.txMemoCount == 0 && result.utxoTagCount == 0 && result.utxoLockCount == 0) {
      return [];
    }
    return [result];
  }

  /// Imports labels for all wallets.
  Future<List<LabelImportResult>> importLabelsForAllWallets(String filePath, {bool overwriteMemo = false}) async {
    final allWallets = _walletProvider.walletItemList;
    final List<LabelImportResult> results = [];

    for (final wallet in allWallets) {
      final singleWalletResult = await importLabelsFromJsonLFile(wallet.id, filePath, overwriteMemo: overwriteMemo);
      if (singleWalletResult.txMemoCount > 0 ||
          singleWalletResult.utxoTagCount > 0 ||
          singleWalletResult.utxoLockCount > 0) {
        results.add(singleWalletResult);
      }
    }
    return results;
  }
}
