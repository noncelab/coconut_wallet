import 'dart:convert';

import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/print_util.dart';
import 'package:ur/ur.dart';
import 'package:ur/ur_encoder.dart';
import 'package:ur/cbor_lite.dart';
import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/i_qr_view_data_handler.dart';

class BcUrQrViewHandler implements IQrViewDataHandler {
  final String _source;
  late String _urType;
  late UREncoder _urEncoder;

  BcUrQrViewHandler(this._source, Map<String, dynamic> data) {
    printLongString('--> source: $_source');
    assert(data['urType'] != null);
    assert(data['urType'] is String);
    _urType = (data['urType'] as String).toLowerCase();
    final input = base64Decode(_source);
    var cborEncoder = CBOREncoder();
    cborEncoder.encodeBytes(input);
    final ur = UR(_urType, cborEncoder.getBytes());
    // QR Code Ver 9 데이터 최대 크기(alphanumeric) 1856bits = 232bytes
    // UR 헤더 길이: 약 20자
    // 데이터: Bytewords.minimal로 인코딩(1바이트 -> 2자)
    // 232 = 20 + (maxFragmentLen * 2)
    // maxFragmentLen = (232 - 20) / 2 = 106
    // 하지만 106으로 설정 시 QrInputTooLongException: Input too long 에러가 발생하여 80으로 줄임
    _urEncoder = UREncoder(ur, 80);
  }

  @override
  String nextPart() {
    return _urEncoder.nextPart();
  }

  @override
  String get source => _source;
}
