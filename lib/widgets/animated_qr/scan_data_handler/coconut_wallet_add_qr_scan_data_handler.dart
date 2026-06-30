import 'dart:convert';

import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

/// 코코넛 볼트 - 지갑 내보내기 스캔용
class CoconutWalletAddQrScanDataHandler implements IQrScanDataHandler {
  WatchOnlyWallet? _result;

  @override
  bool isCompleted() {
    return _result != null;
  }

  @override
  bool joinData(String data) {
    try {
      Map<String, dynamic> jsonData = jsonDecode(data);
      final wallet = WatchOnlyWallet.fromJson(jsonData);
      if (wallet.isTaproot && !wallet.isSupportedTaprootConfiguration) {
        Logger.error('Unsupported Taproot configuration');
        return false;
      }
      _result = wallet;
      return true;
    } catch (e, stackTrace) {
      Logger.error(e.toString());
      Logger.error(stackTrace);
      return false;
    }
  }

  @override
  void reset() {
    _result = null;
  }

  @override
  dynamic get result => _result;

  @override
  double get progress => isCompleted() ? 1.0 : 0.0;

  @override
  bool validateFormat(String data) {
    try {
      jsonDecode(data);
      return true;
    } catch (e) {
      return false;
    }
  }
}
