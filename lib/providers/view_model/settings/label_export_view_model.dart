import 'dart:io';
import 'dart:ui';

import 'package:coconut_wallet/core/bip/329/bip329_converter.dart';
import 'package:coconut_wallet/model/label/label_result.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/label_file_service.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class LabelExportViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;
  final LabelFileService _fileService;
  final Bip329Converter _converter;

  LabelExportViewModel({
    required WalletProvider walletProvider,
    LabelFileService fileService = const LabelFileService(),
    Bip329Converter converter = const Bip329Converter(),
  }) : _walletProvider = walletProvider,
       _fileService = fileService,
       _converter = converter;

  Future<List<File>> getImportableLabelFiles() async {
    return _fileService.getImportableLabelFiles();
  }

  /// Checks if a wallet has any exportable labels (transaction memos, utxo tags, or locked UTXOs).
  bool hasExportableLabelsForWallet(int walletId) {
    final wallet = _walletProvider.getWalletById(walletId);
    final txMemos = _walletProvider.getAllTransactionMemos(walletId);
    final utxoStates = _walletProvider.getUtxoList(walletId);
    final utxoTags = _walletProvider.getUtxoTags(walletId);

    final records = _converter.generateRecordsForWallet(
      descriptor: wallet.descriptor,
      txMemos: txMemos.map((m) => (txHash: m.transactionHash, memo: m.memo)),
      utxoTags: utxoTags.map((t) => (name: t.name, utxoIds: t.utxoIdList.toList(), colorIndex: t.colorIndex)),
      lockedUtxoIds: utxoStates.where((u) => u.status == UtxoStatus.locked).map((u) => u.utxoId),
    );

    return records.isNotEmpty;
  }

  /// Exports labels for a single wallet and saves to file. Returns XFile if labels exist.
  Future<XFile?> exportLabelsForWallet(int walletId) async {
    final wallet = _walletProvider.getWalletById(walletId);
    final txMemos = _walletProvider.getAllTransactionMemos(walletId);
    final utxoStates = _walletProvider.getUtxoList(walletId);
    final utxoTags = _walletProvider.getUtxoTags(walletId);

    final records = _converter.generateRecordsForWallet(
      descriptor: wallet.descriptor,
      txMemos: txMemos.map((m) => (txHash: m.transactionHash, memo: m.memo)),
      utxoTags: utxoTags.map((t) => (name: t.name, utxoIds: t.utxoIdList.toList(), colorIndex: t.colorIndex)),
      lockedUtxoIds: utxoStates.where((u) => u.status == UtxoStatus.locked).map((u) => u.utxoId),
    );

    if (records.isEmpty) {
      return null;
    }

    final jsonLString = _converter.encodeToJsonL(records);
    return _fileService.saveLabelFile(jsonLString);
  }

  /// Exports labels for multiple wallets and returns single XFile.
  Future<LabelExportResult> exportLabelsForWallets(List<int> walletIds) async {
    final List<String> allJsonLines = [];

    for (final walletId in walletIds) {
      final wallet = _walletProvider.getWalletById(walletId);
      final txMemos = _walletProvider.getAllTransactionMemos(walletId);
      final utxoStates = _walletProvider.getUtxoList(walletId);
      final utxoTags = _walletProvider.getUtxoTags(walletId);

      final records = _converter.generateRecordsForWallet(
        descriptor: wallet.descriptor,
        txMemos: txMemos.map((m) => (txHash: m.transactionHash, memo: m.memo)),
        utxoTags: utxoTags.map((t) => (name: t.name, utxoIds: t.utxoIdList.toList(), colorIndex: t.colorIndex)),
        lockedUtxoIds: utxoStates.where((u) => u.status == UtxoStatus.locked).map((u) => u.utxoId),
      );

      if (records.isNotEmpty) {
        allJsonLines.add(_converter.encodeToJsonL(records));
      }
    }

    if (allJsonLines.isEmpty) {
      return LabelExportResult(xFile: null);
    }

    final xFile = await _fileService.saveLabelFile(allJsonLines.join('\n'));
    return LabelExportResult(xFile: xFile);
  }

  /// Exports labels for all wallets.
  Future<LabelExportResult> exportLabelsForAllWallets() async {
    final allWalletIds = _walletProvider.walletItemList.map((w) => w.id).toList();
    return exportLabelsForWallets(allWalletIds);
  }

  /// Builds export summary results for selected wallets.
  List<LabelExportResult> buildExportResults(List<int> walletIds, XFile xFile) {
    final List<LabelExportResult> exportResults = [];

    for (final walletId in walletIds) {
      final wallet = _walletProvider.getWalletById(walletId);
      exportResults.add(
        LabelExportResult(
          xFile: xFile,
          wallet: wallet,
          txMemoCount: _walletProvider.getAllTransactionMemos(walletId).where((m) => m.memo.isNotEmpty).length,
          utxoTagCount: _walletProvider.getUtxoTags(walletId).fold(0, (sum, tag) => sum + tag.utxoIdList.length),
          utxoLockCount: _walletProvider.getUtxoList(walletId).where((u) => u.status == UtxoStatus.locked).length,
        ),
      );
    }

    return exportResults;
  }

  Future<void> shareFiles(List<File> files, {Rect? sharePositionOrigin}) async {
    final xFiles = files.map((file) => _fileService.createXFileFromFile(file)).toList();
    await _fileService.shareFiles(xFiles, sharePositionOrigin: sharePositionOrigin);
  }

  Future<void> shareFile(XFile file, {Rect? sharePositionOrigin}) async {
    await _fileService.shareFile(file, sharePositionOrigin: sharePositionOrigin);
  }

  Future<void> deleteFiles(List<File> files) async {
    await _fileService.deleteFiles(files);
  }
}
