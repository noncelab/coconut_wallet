import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LabelJsonLManager {
  Future<XFile?> createLabelsJsonLFile(int walletId, WalletProvider walletProvider) async {
    final txMemos = walletProvider.getAllTransactionMemos(walletId);
    final utxoTags = walletProvider.getUtxoTags(walletId);
    final utxoStates = walletProvider.getUtxoList(walletId);

    final txMemosWithLabels = txMemos.where((memo) => memo.memo.isNotEmpty).toList();
    final utxoTagsWithLabels = utxoTags.where((tag) => tag.name.isNotEmpty && tag.utxoIdList.isNotEmpty).toList();

    if (txMemosWithLabels.isEmpty && utxoTagsWithLabels.isEmpty) {
      return null;
    }

    final List<String> jsonLines = [];

    final utxoStateMap = {for (var utxo in utxoStates) utxo.utxoId: utxo};

    // 거래 메모
    for (final memo in txMemosWithLabels) {
      final data = {"type": "tx", "ref": memo.transactionHash, "label": memo.memo};
      jsonLines.add(jsonEncode(data));
    }

    // UTXO 태그
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
        };
        if (!isSpendable) {
          data['spendable'] = false;
        }
        jsonLines.add(jsonEncode(data));
      }
    }

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

  Future<void> shareFile(XFile xFile) async {
    await Share.shareXFiles([xFile], text: 'Coconut Wallet Labels');
  }

  Future<void> importLabelsFromJsonLFile(int walletId, WalletProvider walletProvider, String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ErrorCodes.withMessage(ErrorCodes.storageReadError, 'File not found: $filePath');
    }

    final lines = await file.readAsLines();

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final data = jsonDecode(line) as Map<String, dynamic>;
        final type = data['type'] as String?;
        final ref = data['ref'] as String?;
        final label = data['label'] as String?;

        if (type == null || ref == null || label == null || label.isEmpty) {
          debugPrint('Invalid or empty label in line: $line');
          continue;
        }

        if (type == 'tx') {
          await walletProvider.updateTransactionMemo(walletId, ref, label);
        } else if (type == 'output') {
          final parsedId = _parseRefToUtxoId(ref);
          if (parsedId == null) {
            debugPrint('Could not parse output ref: $ref');
            continue;
          }

          final utxoId = parsedId;
          await walletProvider.addUtxoToTag(walletId, label, utxoId);

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
}
