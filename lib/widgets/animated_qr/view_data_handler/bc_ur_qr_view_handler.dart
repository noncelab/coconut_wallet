import 'dart:convert';

import 'package:coconut_wallet/screens/send/unsigned_transaction_qr_screen.dart';
import 'package:coconut_wallet/utils/print_util.dart';
import 'package:ur/ur.dart';
import 'package:ur/ur_encoder.dart';
import 'package:ur/cbor_lite.dart';
import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/i_qr_view_data_handler.dart';

class BcUrQrViewHandler implements IQrViewDataHandler {
  final String _source;
  final QrScanDensity qrScanDensity;
  late String _urType;
  late UREncoder _urEncoder;

  BcUrQrViewHandler(this._source, this.qrScanDensity, Map<String, dynamic> data) {
    printLongString('--> source: $_source');
    assert(data['urType'] != null);
    assert(data['urType'] is String);
    _urType = (data['urType'] as String).toLowerCase();
    final input = base64Decode(_source);
    var cborEncoder = CBOREncoder();
    cborEncoder.encodeBytes(input);
    final ur = UR(_urType, cborEncoder.getBytes());
    // [Fast Mode] QR Code Ver 9 데이터 최대 크기(alphanumeric) 1840bits = 230bytes
    // 하지만 실제 QR 라이브러리 제한은 더 작을 수 있음 (에러: 1628 > 1248 bytes)
    // UR 헤더 길이: 약 20-30자 (시퀀스 정보 포함 시 더 길어질 수 있음)
    // 데이터: Bytewords.minimal로 인코딩(1바이트 -> 2자)
    // 안전한 값: (1248 - 30) / 2 = 609, 하지만 보수적으로 50으로 설정
    // 실제 테스트 결과 80에서도 에러 발생하므로 더 작게 조정 필요

    // [Normal Mode] QR Code Ver 7 데이터 최대 크기(alphanumeric) 1232bits = 154bytes
    // UR 헤더 길이: 약 20-30자
    // 데이터: Bytewords.minimal로 인코딩(1바이트 -> 2자)
    // 안전한 값: (1248 - 30) / 2 = 609, 하지만 보수적으로 30으로 설정

    // [Slow Mode] QR Code Ver 5 데이터 최대 크기(alphanumeric) 848bits = 106bytes
    // UR 헤더 길이: 약 20-30자
    // 데이터: Bytewords.minimal로 인코딩(1바이트 -> 2자)
    // 안전한 값: (106 - 30) / 2 = 38, 하지만 보수적으로 15로 설정

    // ver  최소 셀 수      |     데이터 최대 크기  (errorCorrectionLevel: Low 기준, bytes)
    // 1:   21 * 21       |          17
    // 2:   25 * 25       |          32
    // 3:   29 * 29       |          53
    // 4:   33 * 33       |          78
    // 5:   37 * 37       |          106
    // 6:   41 * 41       |          134
    // 7:   45 * 45       |          154
    // 8:   49 * 49       |          192
    // 9:   53 * 53       |          230
    // 10:  57 * 57       |          271
    // ...
    // 40: 177 * 177      |          2953

    printLongString('--> source: ${UREncoder.encode(ur)}');

    // QrInputTooLongException 방지를 위해 maxFragmentLen을 더 작게 설정
    // 실제 QR 라이브러리 제한(1248 bytes)을 고려하여 보수적으로 설정
    int maxFragmentLen =
        qrScanDensity == QrScanDensity.fast
            ? 50 // 80에서 50으로 감소 (안전 마진 확보)
            : qrScanDensity == QrScanDensity.normal
            ? 30 // 40에서 30으로 감소
            : 15; // 20에서 15로 감소

    _urEncoder = UREncoder(ur, maxFragmentLen);
  }

  @override
  String nextPart() {
    return _urEncoder.nextPart();
  }

  @override
  String get source => _source;
}
