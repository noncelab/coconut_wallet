import 'dart:io';

import 'package:coconut_wallet/core/bip/329/bip329_converter.dart';
import 'package:coconut_wallet/core/bip/329/bip329_record.dart';
import 'package:coconut_wallet/model/label/label_result.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/label_file_service.dart';
import 'package:flutter/foundation.dart';

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
    bool addMemoToExisting = false,
  }) async {
    final currentWallet = _walletProvider.getWalletById(walletId);
    final origin = Bip329Converter.getOriginFromDescriptor(currentWallet.descriptor);
    final lines = await _fileService.readFileLines(filePath);
    final records = _converter.decodeJsonLines(lines, targetOrigin: origin);

    final result = LabelImportResult(wallet: currentWallet);
    final lockedUtxoIds = <String>{};

    for (final record in records) {
      try {
        if (record.type == Bip329Type.tx) {
          final txHash = record.ref;
          final label = record.label;
          if (label == null || label.isEmpty) continue;

          final existingRecord = _walletProvider.getTransactionRecord(walletId, txHash);
          if (existingRecord == null) continue;

          if (addMemoToExisting && existingRecord.memo != null && existingRecord.memo!.isNotEmpty) {
            final newMemo = '${existingRecord.memo}\n$label';
            await _walletProvider.updateTransactionMemo(walletId, txHash, newMemo);
            result.txMemoCount++;
          } else {
            await _walletProvider.updateTransactionMemo(walletId, txHash, label);
            result.txMemoCount++;
          }
        } else if (record.type == Bip329Type.output) {
          final utxoId = Bip329Converter.parseRefToUtxoId(record.ref);
          if (utxoId == null) continue;

          if (_walletProvider.getUtxoState(walletId, utxoId) == null) {
            continue;
          }

          if (record.label != null && record.label!.isNotEmpty) {
            await _walletProvider.addUtxoToTag(walletId, record.label!, utxoId, colorIndex: record.tagColor);
            result.utxoTagCount++;
          }

          if (record.spendable == false) {
            if (!lockedUtxoIds.contains(utxoId)) {
              await _walletProvider.lockUtxo(walletId, utxoId);
              result.utxoLockCount++;
              lockedUtxoIds.add(utxoId);
            }
          }
        }
      } catch (e, stackTrace) {
        debugPrint('Error processing record: ${record.toJsonLine()} - $e');
        debugPrint('StackTrace: $stackTrace');
      }
    }

    return result;
  }

  /// Imports labels for a specific wallet and returns non-empty results.
  Future<List<LabelImportResult>> importLabelsForWallet(
    int walletId,
    String filePath, {
    bool addMemoToExisting = false,
  }) async {
    final result = await importLabelsFromJsonLFile(walletId, filePath, addMemoToExisting: addMemoToExisting);

    if (result.txMemoCount == 0 && result.utxoTagCount == 0 && result.utxoLockCount == 0) {
      return [];
    }
    return [result];
  }

  /// Imports labels for all wallets.
  Future<List<LabelImportResult>> importLabelsForAllWallets(String filePath, {bool addMemoToExisting = false}) async {
    final allWallets = _walletProvider.walletItemList;
    final List<LabelImportResult> results = [];

    for (final wallet in allWallets) {
      final singleWalletResult = await importLabelsFromJsonLFile(
        wallet.id,
        filePath,
        addMemoToExisting: addMemoToExisting,
      );
      if (singleWalletResult.txMemoCount > 0 ||
          singleWalletResult.utxoTagCount > 0 ||
          singleWalletResult.utxoLockCount > 0) {
        results.add(singleWalletResult);
      }
    }
    return results;
  }
}
