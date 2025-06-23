import 'dart:convert';

import 'package:coconut_wallet/utils/print_util.dart';
import 'package:ur/ur.dart';
import 'package:ur/ur_encoder.dart';
import 'package:ur/cbor_lite.dart';
import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/i_qr_view_data_handler.dart';

class BcUrQrViewHandler implements IQrViewDataHandler {
  final String _source;
  final bool isFastMode;
  late String _urType;
  late UREncoder _urEncoder;

  BcUrQrViewHandler(this._source, this.isFastMode, Map<String, dynamic> data) {
    printLongString('--> source: $_source');
    assert(data['urType'] != null);
    assert(data['urType'] is String);
    _urType = (data['urType'] as String).toLowerCase();
    final input = base64Decode(_source);
    var cborEncoder = CBOREncoder();
    cborEncoder.encodeBytes(input);
    final ur = UR(_urType, cborEncoder.getBytes());
    // [Fast Mode] QR Code Ver 9 데이터 최대 크기(alphanumeric) 1856bits = 232bytes
    // UR 헤더 길이: 약 20자
    // 데이터: Bytewords.minimal로 인코딩(1바이트 -> 2자)
    // 232 = 20 + (maxFragmentLen * 2)
    // maxFragmentLen = (232 - 20) / 2 = 106
    // 하지만 106으로 설정 시 QrInputTooLongException: Input too long 에러가 발생하여 80으로 줄임

    // [Regular Mode] QR Code Ver 7 데이터 최대 크기(alphanumeric) 1248bits = 154bytes
    // UR 헤더 길이: 약 20자
    // 데이터: Bytewords.minimal로 인코딩(1바이트 -> 2자)
    // 154 = 20 + (maxFragmentLen * 2)
    // maxFragmentLen = (154 - 20) / 2 = 67

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

    _urEncoder = UREncoder(ur, isFastMode ? 85 : 40);
  }

  @override
  String nextPart() {
    return _urEncoder.nextPart();
  }

  @override
  String get source => _source;
}
