import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/coconut_wallet_add_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';
import 'package:flutter/material.dart';

class ConfirmBackupDataViewModel extends ChangeNotifier {
  late final IQrScanDataHandler<WatchOnlyWallet> _qrDataHandler;

  ConfirmBackupDataViewModel() {
    _qrDataHandler = CoconutWalletAddQrScanDataHandler();
  }

  IQrScanDataHandler<WatchOnlyWallet> get qrDataHandler => _qrDataHandler;
}
