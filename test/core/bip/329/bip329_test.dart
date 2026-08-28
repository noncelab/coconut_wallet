import 'package:coconut_wallet/core/bip/329/bip329_converter.dart';
import 'package:coconut_wallet/core/bip/329/bip329_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bip329Record', () {
    test('should correctly parse and serialize tx record', () {
      const line =
          '{"type":"tx","ref":"f91d0a8a78462bc5d4828b1507da6363e0da1641218c96749ebcf2abf00bec4d","label":"Coffee payment","origin":"wpkh([d34db33f/84\'/0\'/0\'])"}';
      final record = Bip329Record.tryParseLine(line);

      expect(record, isNotNull);
      expect(record!.type, equals(Bip329Type.tx));
      expect(record.ref, equals('f91d0a8a78462bc5d4828b1507da6363e0da1641218c96749ebcf2abf00bec4d'));
      expect(record.label, equals('Coffee payment'));
      expect(record.origin, equals("wpkh([d34db33f/84'/0'/0'])"));
      expect(record.spendable, isNull);
      expect(record.tagColor, isNull);
    });

    test('should correctly parse output record with spendable false and tag_color', () {
      const line =
          '{"type":"output","ref":"f91d0a8a78462bc5d4828b1507da6363e0da1641218c96749ebcf2abf00bec4d:0","label":"Savings","spendable":false,"tag_color":3}';
      final record = Bip329Record.tryParseLine(line);

      expect(record, isNotNull);
      expect(record!.type, equals(Bip329Type.output));
      expect(record.ref, equals('f91d0a8a78462bc5d4828b1507da6363e0da1641218c96749ebcf2abf00bec4d:0'));
      expect(record.label, equals('Savings'));
      expect(record.spendable, isFalse);
      expect(record.tagColor, equals(3));
    });

    test('should return null for invalid json or missing required fields', () {
      expect(Bip329Record.tryParseLine('invalid json'), isNull);
      expect(Bip329Record.tryParseLine('{"type":"unknown_type","ref":"abc"}'), isNull);
      expect(Bip329Record.tryParseLine('{"type":"tx"}'), isNull);
      expect(Bip329Record.tryParseLine(''), isNull);
    });
  });

  group('Bip329Converter', () {
    const converter = Bip329Converter();

    test('getOriginFromDescriptor extracts origin correctly', () {
      const descriptor =
          "wpkh([d34db33f/84h/0h/0h]xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrWCFJJeWJdP2oMmNVbxwh6QojwhpeFsgDzSX4wb5Er72jdLT/0/*)";
      final origin = Bip329Converter.getOriginFromDescriptor(descriptor);
      expect(origin, equals("wpkh([d34db33f/84'/0'/0'])"));
    });

    test('parseRefToUtxoId converts txid:vout to Coconut utxoId', () {
      const ref = 'f91d0a8a78462bc5d4828b1507da6363e0da1641218c96749ebcf2abf00bec4d:1';
      final utxoId = Bip329Converter.parseRefToUtxoId(ref);
      expect(utxoId, equals('f91d0a8a78462bc5d4828b1507da6363e0da1641218c96749ebcf2abf00bec4d1'));
    });

    test('parseUtxoId converts Coconut utxoId to txid and vout', () {
      const utxoId = 'f91d0a8a78462bc5d4828b1507da6363e0da1641218c96749ebcf2abf00bec4d0';
      final parsed = Bip329Converter.parseUtxoId(utxoId);
      expect(parsed, isNotNull);
      expect(parsed!.txid, equals('f91d0a8a78462bc5d4828b1507da6363e0da1641218c96749ebcf2abf00bec4d'));
      expect(parsed.vout, equals(0));
    });

    test('generateRecordsForWallet creates correct records', () {
      const descriptor =
          "wpkh([d34db33f/84h/0h/0h]xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrWCFJJeWJdP2oMmNVbxwh6QojwhpeFsgDzSX4wb5Er72jdLT/0/*)";
      const txHash = 'f91d0a8a78462bc5d4828b1507da6363e0da1641218c96749ebcf2abf00bec4d';
      const utxoId0 = '${txHash}0';
      const utxoId1 = '${txHash}1';

      final records = converter.generateRecordsForWallet(
        descriptor: descriptor,
        txMemos: [(txHash: txHash, memo: 'Salary')],
        utxoTags: [
          (name: 'Cold Storage', utxoIds: [utxoId0], colorIndex: 2),
        ],
        lockedUtxoIds: [utxoId0, utxoId1],
      );

      expect(records.length, equals(3));

      // 1. Tx memo
      expect(records[0].type, equals(Bip329Type.tx));
      expect(records[0].ref, equals(txHash));
      expect(records[0].label, equals('Salary'));
      expect(records[0].origin, equals("wpkh([d34db33f/84'/0'/0'])"));

      // 2. Tagged output (which is also locked)
      expect(records[1].type, equals(Bip329Type.output));
      expect(records[1].ref, equals('$txHash:0'));
      expect(records[1].label, equals('Cold Storage'));
      expect(records[1].tagColor, equals(2));
      expect(records[1].spendable, isFalse);

      // 3. Locked output without tag
      expect(records[2].type, equals(Bip329Type.output));
      expect(records[2].ref, equals('$txHash:1'));
      expect(records[2].label, isNull);
      expect(records[2].spendable, isFalse);
    });

    test('encodeToJsonL and decodeJsonLines roundtrip works properly', () {
      const descriptor = "wpkh([d34db33f/84h/0h/0h]xpub...)";
      const txHash = 'f91d0a8a78462bc5d4828b1507da6363e0da1641218c96749ebcf2abf00bec4d';

      final generated = converter.generateRecordsForWallet(
        descriptor: descriptor,
        txMemos: [(txHash: txHash, memo: 'Test Memo')],
        utxoTags: [],
        lockedUtxoIds: [],
      );

      final jsonL = converter.encodeToJsonL(generated);
      final decoded = converter.decodeJsonLines(jsonL.split('\n'), targetOrigin: "wpkh([d34db33f/84'/0'/0'])");

      expect(decoded.length, equals(1));
      expect(decoded.first.ref, equals(txHash));
      expect(decoded.first.label, equals('Test Memo'));
    });

    test('decodeJsonLines filters out records with different origin', () {
      final lines = [
        '{"type":"tx","ref":"tx1","label":"Memo 1","origin":"wpkh([11111111/84\'/0\'/0\'])"}',
        '{"type":"tx","ref":"tx2","label":"Memo 2","origin":"wpkh([22222222/84\'/0\'/0\'])"}',
        '{"type":"tx","ref":"tx3","label":"Memo 3"}', // no origin
      ];

      final filtered = converter.decodeJsonLines(lines, targetOrigin: "wpkh([11111111/84'/0'/0'])");

      expect(filtered.length, equals(2));
      expect(filtered.map((r) => r.ref).toList(), equals(['tx1', 'tx3']));
    });

    test('decodeJsonLines treats apostrophe, h, and H hardened origin markers as equivalent', () {
      final lines = [
        '{"type":"tx","ref":"apostrophe","label":"Memo 1","origin":"wpkh([11111111/84\'/0\'/0\'])"}',
        '{"type":"tx","ref":"lower-h","label":"Memo 2","origin":"wpkh([11111111/84h/0h/0h])"}',
        '{"type":"tx","ref":"upper-h","label":"Memo 3","origin":"wpkh([11111111/84H/0H/0H])"}',
        '{"type":"tx","ref":"mixed-h","label":"Memo 4","origin":"wpkh([11111111/84h/0H/0\'])"}',
        '{"type":"tx","ref":"other","label":"Memo 5","origin":"wpkh([22222222/84H/0H/0H])"}',
      ];

      final filtered = converter.decodeJsonLines(lines, targetOrigin: "wpkh([11111111/84'/0'/0'])");

      expect(filtered.map((r) => r.ref).toList(), equals(['apostrophe', 'lower-h', 'upper-h', 'mixed-h']));
    });

    test('decodeJsonLines handles large memo files without truncating labels', () {
      const origin = "wpkh([d45aa182/84'/1'/0'])";
      const recordCount = 10000;
      final longMemo = '긴 메모 '.padRight(256 * 1024, '가');

      final lines = List<String>.generate(recordCount, (index) {
        final txHash = index.toRadixString(16).padLeft(64, '0');
        final label = index == recordCount - 1 ? longMemo : 'memo-$index';
        return Bip329Record(type: Bip329Type.tx, ref: txHash, label: label, origin: origin).toJsonLine();
      });

      lines.add(
        const Bip329Record(
          type: Bip329Type.tx,
          ref: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          label: 'other wallet memo',
          origin: "wpkh([ffffffff/84'/1'/0'])",
        ).toJsonLine(),
      );
      lines.add('not-json');

      final decoded = converter.decodeJsonLines(lines, targetOrigin: origin);

      expect(decoded.length, equals(recordCount));
      expect(decoded.first.label, equals('memo-0'));
      expect(decoded.last.label, equals(longMemo));
      expect(decoded.last.label!.length, equals(longMemo.length));
    });
  });
}
