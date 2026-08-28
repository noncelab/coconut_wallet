import 'package:coconut_wallet/core/bip/329/bip329_record.dart';

class Bip329Converter {
  const Bip329Converter();

  static String normalizeOrigin(String origin) {
    return origin.replaceAllMapped(RegExp(r'(/|\b)(\d+)[hH]'), (match) => "${match.group(1)}${match.group(2)}'");
  }

  /// Extracts origin string from descriptor (e.g. `wpkh([mfp/path]...)` -> `wpkh([mfp/path])`).
  static String? getOriginFromDescriptor(String descriptor) {
    final mfpAndPathMatch = RegExp(r'\[([0-9a-fA-F]{8})/([m|M]?[^\]]+)\]').firstMatch(descriptor);
    if (mfpAndPathMatch == null) {
      return null;
    }

    final mfp = mfpAndPathMatch.group(1)!.toLowerCase();
    String path = mfpAndPathMatch.group(2)!;

    if (path.startsWith('m/')) {
      path = path.substring(2);
    }
    path = normalizeOrigin(path);

    final type = descriptor.split('(').first;
    final identifier = '[$mfp/$path]';

    return '$type($identifier)';
  }

  /// Converts `ref` formatted as `txid:vout` to Coconut `utxoId` (`txidvout`).
  static String? parseRefToUtxoId(String ref) {
    final parts = ref.split(':');
    return parts.length == 2 ? '${parts[0]}${parts[1]}' : null;
  }

  /// Converts Coconut `utxoId` (`txidvout` where txid is 64 hex chars) to `(txid, vout)`.
  static ({String txid, int vout})? parseUtxoId(String utxoId) {
    if (utxoId.length < 65) {
      return null;
    }
    final txid = utxoId.substring(0, 64);
    final voutString = utxoId.substring(64);
    final vout = int.tryParse(voutString);

    if (vout == null) return null;
    return (txid: txid, vout: vout);
  }

  /// Generates BIP-329 records for a wallet's memos, tags, and locked UTXOs.
  List<Bip329Record> generateRecordsForWallet({
    required String descriptor,
    required Iterable<({String txHash, String memo})> txMemos,
    required Iterable<({String name, List<String> utxoIds, int? colorIndex})> utxoTags,
    required Iterable<String> lockedUtxoIds,
  }) {
    final txMemosWithLabels = txMemos.where((memo) => memo.memo.isNotEmpty).toList();
    final origin = getOriginFromDescriptor(descriptor);
    final tagsWithLabels = utxoTags.where((tag) => tag.name.isNotEmpty && tag.utxoIds.isNotEmpty).toList();
    final lockedUtxoSet = lockedUtxoIds.toSet();

    if (txMemosWithLabels.isEmpty && tagsWithLabels.isEmpty && lockedUtxoSet.isEmpty) {
      return [];
    }

    final List<Bip329Record> records = [];

    // Transaction Memos
    for (final memo in txMemosWithLabels) {
      records.add(Bip329Record(type: Bip329Type.tx, ref: memo.txHash, label: memo.memo, origin: origin));
    }

    // UTXO Tags
    for (final tag in tagsWithLabels) {
      for (final utxoId in tag.utxoIds) {
        final parsedId = parseUtxoId(utxoId);
        if (parsedId == null) {
          continue;
        }

        final bool isSpendable = !lockedUtxoSet.contains(utxoId);

        records.add(
          Bip329Record(
            type: Bip329Type.output,
            ref: '${parsedId.txid}:${parsedId.vout}',
            label: tag.name,
            origin: origin,
            tagColor: tag.colorIndex,
            spendable: isSpendable ? null : false,
          ),
        );
      }
    }

    // Locked UTXOs without tags
    final taggedUtxoIds = tagsWithLabels.expand((tag) => tag.utxoIds).toSet();
    for (final utxoId in lockedUtxoSet) {
      if (taggedUtxoIds.contains(utxoId)) {
        continue;
      }

      final parsedId = parseUtxoId(utxoId);
      if (parsedId == null) {
        continue;
      }

      records.add(
        Bip329Record(
          type: Bip329Type.output,
          ref: '${parsedId.txid}:${parsedId.vout}',
          spendable: false,
          origin: origin,
        ),
      );
    }

    return records;
  }

  /// Encodes records to JSON Lines formatted string.
  String encodeToJsonL(List<Bip329Record> records) {
    return records.map((record) => record.toJsonLine()).join('\n');
  }

  /// Parses JSON Lines into list of BIP-329 records, optionally filtering by wallet origin.
  List<Bip329Record> decodeJsonLines(Iterable<String> lines, {String? targetOrigin}) {
    final List<Bip329Record> records = [];
    final normalizedTargetOrigin = targetOrigin != null ? normalizeOrigin(targetOrigin) : null;

    for (final line in lines) {
      final record = Bip329Record.tryParseLine(line);
      if (record == null) continue;

      if (record.origin != null && normalizedTargetOrigin != null) {
        final normalizedRecordOrigin = normalizeOrigin(record.origin!);
        if (normalizedRecordOrigin != normalizedTargetOrigin) {
          continue;
        }
      }

      records.add(record);
    }

    return records;
  }
}
