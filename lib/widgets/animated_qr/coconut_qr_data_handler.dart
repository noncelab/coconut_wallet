import 'dart:convert';

import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/i_coconut_qr_data_handler.dart';

/// 코코넛 볼트 - 지갑 내보내기 스캔용
class CoconutQRDataHandler implements ICoconutQrDataHandler {
  WatchOnlyWallet? _result;

  @override
  Future<void> initialize(Map<String, dynamic> data) async {}

  @override
  bool isCompleted() {
    return _result != null;
  }

  @override
  bool joinData(String data) {
    try {
      Map<String, dynamic> jsonData = jsonDecode(data);
      _result = WatchOnlyWallet.fromJson(jsonData);
      return true;
    } catch (e) {
      Logger.error(e.toString());
      return false;
    }
  }

  @override
  void reset() {
    _result = null;
  }

  @override
  dynamic get result => _result;
}
