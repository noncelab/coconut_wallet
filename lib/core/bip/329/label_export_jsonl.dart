import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LabelExportJsonL {
  Future<bool> exportMemosAsJsonL(int walletId, WalletProvider walletProvider) async {
    final txMemos = walletProvider.getAllTransactionMemos(walletId);
    if (txMemos.isEmpty) {
      return false;
    }

    final txMemosWithLabels = txMemos.where((memo) => memo.memo.isNotEmpty).toList();

    if (txMemosWithLabels.isEmpty) {
      return false;
    }

    final jsonlString = txMemosWithLabels
        .map((memo) {
          final data = {"type": "tx", "ref": memo.transactionHash, "label": memo.memo};
          return jsonEncode(data);
        })
        .join('\n');

    debugPrint('--- Exporting Memos as JSONL ---');
    debugPrint(jsonlString);
    debugPrint('---------------------------------');

    final directory = await getTemporaryDirectory();
    final fileName = 'coconut-memos-${DateTime.now().millisecondsSinceEpoch}.jsonl';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonlString);

    final xFile = XFile(file.path, name: fileName, mimeType: 'application/jsonl');
    await Share.shareXFiles([xFile], text: 'Transaction Memos');
    return true;
  }
}
