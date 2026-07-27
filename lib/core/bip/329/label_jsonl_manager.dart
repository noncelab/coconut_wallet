import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

    final directory = await getTemporaryDirectory();
    final fileName = 'coconut-labels-${DateTime.now().millisecondsSinceEpoch}.jsonl';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonlString);

    return XFile(file.path, name: fileName, mimeType: 'application/jsonl');
  }

  Future<XFile?> createLabelsJsonLFileForAllWallets(WalletProvider walletProvider) async {
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

    if (jsonLines.isEmpty) return null;

    return _createFileFromString(jsonLines.join('\n'));
  }

  Future<void> shareFile(XFile xFile) async {
    AppGuard.disablePrivacyScreen();
    try {
      await Share.shareXFiles([xFile], text: 'Coconut Wallet Labels');
    } finally {
      AppGuard.enablePrivacyScreen();
    }
  }

  Future<void> importLabelsFromJsonLFile(int walletId, WalletProvider walletProvider, String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ErrorCodes.withMessage(ErrorCodes.storageReadError, 'File not found: $filePath');
    }

    final currentWallet = walletProvider.getWalletById(walletId);
    final currentWalletOrigin = _getOriginFromDescriptor(currentWallet.descriptor);

    final lines = await file.readAsLines();

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final data = jsonDecode(line) as Map<String, dynamic>;
        final type = data['type'] as String?;
        final ref = data['ref'] as String?;
        final label = data['label'] as String?;
        final origin = data['origin'] as String?;

        if (type == null || ref == null || label == null || label.isEmpty) {
          debugPrint('Invalid or empty label in line: $line');
          continue;
        }

        if (origin != null && currentWalletOrigin != null && origin != currentWalletOrigin) {
          debugPrint('Skipping label from different origin: $line');
          continue;
        }

        if (type == 'tx') {
          if (walletProvider.getTransactionRecord(walletId, ref) == null) {
            continue;
          }
          await walletProvider.updateTransactionMemo(walletId, ref, label);
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

          final colorIndex = data['tag_color'] as int?;
          await walletProvider.addUtxoToTag(walletId, label, utxoId, colorIndex: colorIndex);

          final spendable = data['spendable'] as bool?;
          if (spendable == false) {
            await walletProvider.lockUtxo(walletId, utxoId);
          }
        }
      } catch (e, stackTrace) {
        debugPrint('Error processing line: $line');
        debugPrint('Error: $e');
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }

  Future<void> importLabelsForAllWallets(WalletProvider walletProvider, String filePath) async {
    final allWallets = walletProvider.walletItemList;

    for (final wallet in allWallets) {
      await importLabelsFromJsonLFile(wallet.id, walletProvider, filePath);
    }
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

  Future<XFile> _createFileFromString(String content) async {
    debugPrint('--- Exporting Labels as JSONL ---');
    debugPrint(content);
    debugPrint('---------------------------------');

    final directory = await getTemporaryDirectory();
    final fileName = 'coconut-labels-all-${DateTime.now().millisecondsSinceEpoch}.jsonl';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);
    return XFile(file.path, name: fileName, mimeType: 'application/jsonl');
  }

  List<String> _generateJsonLinesForWallet({
    required String descriptor,
    required List<dynamic> txMemos,
    required List<dynamic> utxoTags,
    required List<UtxoState> utxoStates,
  }) {
    final txMemosWithLabels = txMemos.where((memo) => memo.memo.isNotEmpty).toList();
    final origin = _getOriginFromDescriptor(descriptor);
    final utxoTagsWithLabels = utxoTags.where((tag) => tag.name.isNotEmpty && tag.utxoIdList.isNotEmpty).toList();

    if (txMemosWithLabels.isEmpty && utxoTagsWithLabels.isEmpty) {
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
}
