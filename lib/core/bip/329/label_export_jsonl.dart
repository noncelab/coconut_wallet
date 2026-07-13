import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LabelExportJsonL {
  Future<bool> exportLabelsAsJsonL(int walletId, WalletProvider walletProvider) async {
    final txMemos = walletProvider.getAllTransactionMemos(walletId);
    final utxoTags = walletProvider.getUtxoTags(walletId);
    final utxoStates = walletProvider.getUtxoList(walletId);

    final txMemosWithLabels = txMemos.where((memo) => memo.memo.isNotEmpty).toList();
    final utxoTagsWithLabels = utxoTags.where((tag) => tag.name.isNotEmpty && tag.utxoIdList.isNotEmpty).toList();

    if (txMemosWithLabels.isEmpty && utxoTagsWithLabels.isEmpty) {
      return false;
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
      return false;
    }

    final jsonlString = jsonLines.join('\n');

    debugPrint('--- Exporting Labels as JSONL ---');
    debugPrint(jsonlString);
    debugPrint('---------------------------------');

    final directory = await getTemporaryDirectory();
    final fileName = 'coconut-labels-${DateTime.now().millisecondsSinceEpoch}.jsonl';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonlString);

    final xFile = XFile(file.path, name: fileName, mimeType: 'application/jsonl');
    await Share.shareXFiles([xFile], text: 'Coconut Wallet Labels');
    return true;
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
