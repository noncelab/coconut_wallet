import 'dart:convert';

import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

/// 코코넛 볼트 - 지갑 내보내기 스캔용
class CoconutQrScanDataHandler implements IQrScanDataHandler {
  WatchOnlyWallet? _result;

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
