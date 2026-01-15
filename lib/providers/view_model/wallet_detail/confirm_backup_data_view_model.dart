import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/coconut_wallet_add_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';
import 'package:flutter/material.dart';

class ConfirmBackupDataViewModel extends ChangeNotifier {
  late final IQrScanDataHandler _qrDataHandler;

  ConfirmBackupDataViewModel() {
    _qrDataHandler = CoconutQrScanDataHandler();
  }

  IQrScanDataHandler get qrDataHandler => _qrDataHandler;
}
