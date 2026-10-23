import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/bc_ur_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/composed_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/descriptor_qr_scan_data_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur/ur.dart';
import 'package:ur/ur_encoder.dart';

void main() {
  const descriptor =
      "wpkh([9b1441e4/84'/1'/0']tpubDDMbU29QrSafD2Ui4yGv31Xp3PPSMvudreoohYjR8xLTng7hbsjYwUTeRhiKULFqX16M5M8zZh9siw5i6RRyisc6LtWjr1FwBYTiZUGGYJN/<0;1>/*)";

  ComposedScanDataHandler createHandler() {
    return ComposedScanDataHandler([
      DescriptorQrScanDataHandler(),
      BcUrQrScanDataHandler(expectedUrType: const [UrType.cryptoAccount]),
    ]);
  }

  setUp(() {
    NetworkType.setNetworkType(NetworkType.regtest);
  });

  group('ComposedScanDataHandler reset', () {
    test('완료된 descriptor 결과와 진행 상태를 초기화한다', () {
      final handler = createHandler();
      expect(handler.validateFormat(descriptor), isTrue);
      expect(handler.joinData(descriptor), isTrue);
      expect(handler.isCompleted(), isTrue);
      expect(handler.progress, 1.0);
      expect(handler.result, descriptor);

      handler.reset();

      expect(handler.result, isNull);
      expect(handler.progress, 0.0);
      expect(handler.isCompleted(), isFalse);
      expect(handler.sequenceLength, isNull);
      expect(handler.validateFormat(descriptor), isTrue);
      expect(handler.joinData(descriptor), isTrue);
    });

    test('이전 handler 선택을 해제하고 잘못된 입력을 거절한다', () {
      final handler = createHandler();
      expect(handler.validateFormat(descriptor), isTrue);
      expect(handler.joinData(descriptor), isTrue);

      handler.reset();

      expect(handler.validateFormat('invalid-qr'), isFalse);
    });

    test('UR 스캔 도중 초기화하면 descriptor handler를 새로 선택한다', () {
      final handler = createHandler();
      final encoder = UREncoder(UR('crypto-account', Uint8List.fromList(List.generate(100, (index) => index))), 20);
      final part = encoder.nextPart();
      expect(handler.validateFormat(part), isTrue);
      expect(handler.joinData(part), isTrue);
      expect(handler.sequenceLength, greaterThan(1));
      expect(handler.isCompleted(), isFalse);

      handler.reset();

      expect(handler.validateFormat(descriptor), isTrue);
      expect(handler.joinData(descriptor), isTrue);
      expect(handler.isCompleted(), isTrue);
      expect(handler.result, descriptor);
    });
  });
}
