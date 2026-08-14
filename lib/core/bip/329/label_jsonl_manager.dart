import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

class LabelImportResult {
  final WalletItemBase? wallet;
  int txMemoCount = 0;
  int utxoTagCount = 0;
  int utxoLockCount = 0;

  LabelImportResult({this.wallet});
}

class LabelExportResult {
  final XFile? xFile;
  final WalletItemBase? wallet;
  final int txMemoCount;
  final int utxoTagCount;
  final int utxoLockCount;

  LabelExportResult({this.xFile, this.wallet, this.txMemoCount = 0, this.utxoTagCount = 0, this.utxoLockCount = 0});
}

class LabelJsonLManager {
  Future<XFile?> createLabelsJsonLFile(int walletId, WalletProvider walletProvider) async {
    final wallet = walletProvider.getWalletById(walletId);

    final txMemos = walletProvider.getAllTransactionMemos(walletId);
    final utxoStates = walletProvider.getUtxoList(walletId);
    final utxoTags = walletProvider.getUtxoTags(walletId);

    final jsonLines = _generateJsonLinesForWallet(
      descriptor: wallet.descriptor,
      txMemos: txMemos,
      utxoTags: utxoTags,
      utxoStates: utxoStates,
    );

    if (jsonLines.isEmpty) {
      return null;
    }

    final jsonlString = jsonLines.join('\n');

    debugPrint('--- Exporting Labels as JSONL ---');
    debugPrint(jsonlString);
    debugPrint('---------------------------------');

    final directory = await getApplicationDocumentsDirectory();
    const fileName = 'coconut-labels.jsonl';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonlString);

    return XFile(file.path, name: fileName, mimeType: 'application/jsonl');
  }

  Future<LabelExportResult> createLabelsJsonLFileForAllWallets(WalletProvider walletProvider) async {
    final allWallets = walletProvider.walletItemList;
    final List<String> jsonLines = [];

    for (final wallet in allWallets) {
      final walletId = wallet.id;
      jsonLines.addAll(
        _generateJsonLinesForWallet(
          descriptor: wallet.descriptor,
          txMemos: walletProvider.getAllTransactionMemos(walletId),
          utxoTags: walletProvider.getUtxoTags(walletId),
          utxoStates: walletProvider.getUtxoList(walletId),
        ),
      );
    }

    if (jsonLines.isEmpty) return LabelExportResult(xFile: null);

    return LabelExportResult(xFile: await _createFileFromString(jsonLines.join('\n')));
  }

  Future<LabelExportResult> createLabelsJsonLFileForWallets(List<int> walletIds, WalletProvider walletProvider) async {
    final List<String> jsonLines = [];

    for (final walletId in walletIds) {
      final wallet = walletProvider.getWalletById(walletId);

      jsonLines.addAll(
        _generateJsonLinesForWallet(
          descriptor: wallet.descriptor,
          txMemos: walletProvider.getAllTransactionMemos(walletId),
          utxoTags: walletProvider.getUtxoTags(walletId),
          utxoStates: walletProvider.getUtxoList(walletId),
        ),
      );
    }

    if (jsonLines.isEmpty) return LabelExportResult(xFile: null);

    return LabelExportResult(xFile: await _createFileFromString(jsonLines.join('\n')));
  }

  Future<void> shareFile(XFile xFile, {Rect? sharePositionOrigin}) async {
    AppGuard.disablePrivacyScreen();
    try {
      await Share.shareXFiles([xFile], text: 'Coconut Wallet Labels', sharePositionOrigin: sharePositionOrigin);
    } finally {
      AppGuard.enablePrivacyScreen();
    }
  }

  Future<void> shareFiles(List<XFile> xFiles, {Rect? sharePositionOrigin}) async {
    if (xFiles.isEmpty) return;
    AppGuard.disablePrivacyScreen();
    try {
      await Share.shareXFiles(xFiles, text: 'Coconut Wallet Labels', sharePositionOrigin: sharePositionOrigin);
    } finally {
      AppGuard.enablePrivacyScreen();
    }
  }

  XFile createXFileFromFile(File file) {
    return XFile(file.path, name: p.basename(file.path), mimeType: 'application/jsonl');
  }

  Future<LabelImportResult> importLabelsFromJsonLFile(
    int walletId,
    WalletProvider walletProvider,
    String filePath, {
    bool addMemoToExisting = false,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ErrorCodes.withMessage(ErrorCodes.storageReadError, 'File not found: $filePath');
    }

    final result = LabelImportResult(wallet: walletProvider.getWalletById(walletId));

    final currentWallet = walletProvider.getWalletById(walletId);
    final currentWalletOrigin = _getOriginFromDescriptor(currentWallet.descriptor);

    final lines = await file.readAsLines();
    final lockedUtxoIds = <String>{};

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final data = jsonDecode(line) as Map<String, dynamic>;
        final type = data['type'] as String?;
        final ref = data['ref'] as String?;
        final label = data['label'] as String?;
        final origin = data['origin'] as String?;

        if (type == null || ref == null) {
          debugPrint('Invalid or empty label in line: $line');
          continue;
        }

        if (origin != null && currentWalletOrigin != null && origin != currentWalletOrigin) {
          debugPrint('Skipping label from different origin: $line');
          continue;
        }

        if (type == 'tx') {
          final existingRecord = walletProvider.getTransactionRecord(walletId, ref);
          if (existingRecord == null) {
            continue;
          }
          if (label == null || label.isEmpty) {
            debugPrint('Invalid or empty label for tx in line: $line');
            continue;
          }
          if (addMemoToExisting && existingRecord.memo!.isNotEmpty) {
            final newMemo = '${existingRecord.memo}\n$label';
            await walletProvider.updateTransactionMemo(walletId, ref, newMemo);
            result.txMemoCount++;
            continue;
          }
          await walletProvider.updateTransactionMemo(walletId, ref, label);
          result.txMemoCount++;
        } else if (type == 'output') {
          final parsedId = _parseRefToUtxoId(ref);
          if (parsedId == null) {
            debugPrint('Could not parse output ref: $ref');
            continue;
          }

          final utxoId = parsedId;
          if (walletProvider.getUtxoState(walletId, utxoId) == null) {
            continue;
          }

          if (label != null && label.isNotEmpty) {
            int? colorIndex = data['tag_color'] as int?;
            // 색상 추가 시 수정
            if (colorIndex != null && (colorIndex < 0 || colorIndex > 11)) {
              colorIndex = null;
            }

            await walletProvider.addUtxoToTag(walletId, label, utxoId, colorIndex: colorIndex);
            result.utxoTagCount++;
          }

          final spendable = data['spendable'] as bool?;
          if (spendable == false) {
            if (!lockedUtxoIds.contains(utxoId)) {
              await walletProvider.lockUtxo(walletId, utxoId);
              result.utxoLockCount++;
              lockedUtxoIds.add(utxoId);
            }
          }
        }
      } catch (e, stackTrace) {
        debugPrint('Error processing line: $line');
        debugPrint('Error: $e');
        debugPrint('StackTrace: $stackTrace');
      }
    }
    return result;
  }

  Future<List<LabelImportResult>> importLabelsForAllWallets(
    WalletProvider walletProvider,
    String filePath, {
    bool addMemoToExisting = false,
  }) async {
    final allWallets = walletProvider.walletItemList;
    final List<LabelImportResult> results = [];

    for (final wallet in allWallets) {
      final singleWalletResult = await importLabelsFromJsonLFile(
        wallet.id,
        walletProvider,
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

  Future<List<LabelImportResult>> importLabelsForWallet(
    int walletId,
    WalletProvider walletProvider,
    String filePath, {
    bool addMemoToExisting = false,
  }) async {
    final result = await importLabelsFromJsonLFile(
      walletId,
      walletProvider,
      filePath,
      addMemoToExisting: addMemoToExisting,
    );

    if (result.txMemoCount == 0 && result.utxoTagCount == 0 && result.utxoLockCount == 0) {
      return [];
    }
    return [result];
  }

  String? _parseRefToUtxoId(String ref) {
    final parts = ref.split(':');
    return parts.length == 2 ? '${parts[0]}${parts[1]}' : null;
  }

  ({String txid, int vout})? _parseUtxoId(String utxoId) {
    if (utxoId.length < 65) {
      return null;
    }
    final txid = utxoId.substring(0, 64);
    final voutString = utxoId.substring(64);
    final vout = int.tryParse(voutString);

    if (vout == null) return null;
    return (txid: txid, vout: vout);
  }

  Future<XFile?> _createFileFromString(String content) async {
    debugPrint('--- Exporting Labels as JSONL ---');
    debugPrint(content);
    debugPrint('---------------------------------');

    final directory = await getApplicationDocumentsDirectory();
    const baseName = 'coconut-labels';
    const extension = '.jsonl';
    String fileName = '$baseName$extension';
    String filePath = p.join(directory.path, fileName);
    int counter = 1;

    while (await File(filePath).exists()) {
      fileName = '$baseName ($counter)$extension';
      filePath = p.join(directory.path, fileName);
      counter++;
    }

    final file = File(filePath);
    await file.writeAsString(content);
    return XFile(file.path, name: fileName, mimeType: 'application/jsonl');
  }

  List<String> _generateJsonLinesForWallet({
    required String descriptor,
    required List<RealmTransactionMemo> txMemos,
    required List<UtxoState> utxoStates,
    required List<RealmUtxoTag> utxoTags,
  }) {
    final txMemosWithLabels = txMemos.where((memo) => memo.memo.isNotEmpty).toList();
    final origin = _getOriginFromDescriptor(descriptor);
    final utxoTagsWithLabels = utxoTags.where((tag) => tag.name.isNotEmpty && tag.utxoIdList.isNotEmpty).toList();
    final lockedUtxos = utxoStates.where((utxo) => utxo.status == UtxoStatus.locked).toList();

    if (txMemosWithLabels.isEmpty && utxoTagsWithLabels.isEmpty && lockedUtxos.isEmpty) {
      return [];
    }

    final List<String> jsonLines = [];
    final utxoStateMap = {for (var utxo in utxoStates) utxo.utxoId: utxo};

    // Transaction Memos
    for (final memo in txMemosWithLabels) {
      final data = {"type": "tx", "ref": memo.transactionHash, "label": memo.memo, "origin": origin};
      jsonLines.add(jsonEncode(data));
    }

    // Utxo Tags
    for (final tag in utxoTagsWithLabels) {
      for (final utxoId in tag.utxoIdList) {
        final parsedId = _parseUtxoId(utxoId);
        if (parsedId == null) {
          debugPrint('Could not parse utxoId: $utxoId');
          continue;
        }

        final utxoState = utxoStateMap[utxoId];
        final bool isSpendable = utxoState?.status != UtxoStatus.locked;

        final Map<String, dynamic> data = {
          "type": "output",
          "ref": "${parsedId.txid}:${parsedId.vout}",
          "label": tag.name,
          "origin": origin,
          // Coconut
          "tag_color": tag.colorIndex,
        };

        if (!isSpendable) {
          data['spendable'] = false;
        }
        jsonLines.add(jsonEncode(data));
      }
    }

    // Locked Utxos
    final taggedUtxoIds = utxoTagsWithLabels.expand((tag) => tag.utxoIdList).toSet();
    for (final utxo in lockedUtxos) {
      // Skip UTXOs that already have tags as they were processed above
      if (taggedUtxoIds.contains(utxo.utxoId)) {
        continue;
      }

      final parsedId = _parseUtxoId(utxo.utxoId);
      if (parsedId == null) {
        debugPrint('Could not parse utxoId: ${utxo.utxoId}');
        continue;
      }

      final Map<String, dynamic> data = {
        "type": "output",
        "ref": "${parsedId.txid}:${parsedId.vout}",
        "spendable": false,
        "origin": origin,
      };
      jsonLines.add(jsonEncode(data));
    }

    return jsonLines;
  }

  String? _getOriginFromDescriptor(String descriptor) {
    final mfpAndPathMatch = RegExp(r'\[([0-9a-fA-F]{8})/([m|M]?[^\]]+)\]').firstMatch(descriptor);
    if (mfpAndPathMatch == null) {
      return null;
    }

    final mfp = mfpAndPathMatch.group(1)!.toLowerCase();
    String path = mfpAndPathMatch.group(2)!;

    if (path.startsWith('m/')) {
      path = path.substring(2);
    }
    path = path.replaceAll("h", "'");

    final type = descriptor.split('(').first;
    final identifier = '[$mfp/$path]';

    return '$type($identifier)';
  }

  Future<List<File>> getImportableLabelFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files =
          directory.listSync().whereType<File>().where((file) {
            return file.path.toLowerCase().endsWith('.jsonl');
          }).toList();

      // Sort by modification date, newest first
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (e) {
      return [];
    }
  }

  Future<File?> pickAndSaveExternalLabelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return null;
      }

      final pickedFile = result.files.single;
      final filePath = pickedFile.path!;
      final fileName = pickedFile.name;

      if (!fileName.toLowerCase().endsWith('.jsonl') && !filePath.toLowerCase().endsWith('.jsonl')) {
        throw ErrorCodes.withMessage(ErrorCodes.storageReadError, 'Invalid file type');
      }

      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final directory = await getApplicationDocumentsDirectory();
      final baseName = p.basenameWithoutExtension(fileName);
      const extension = '.jsonl';
      String targetFileName = '$baseName$extension';
      String targetPath = p.join(directory.path, targetFileName);
      int counter = 1;

      while (await File(targetPath).exists()) {
        targetFileName = '$baseName ($counter)$extension';
        targetPath = p.join(directory.path, targetFileName);
        counter++;
      }

      return await sourceFile.copy(targetPath);
    } catch (e) {
      debugPrint('Error picking or saving external label file: $e');
      rethrow;
    }
  }
}
