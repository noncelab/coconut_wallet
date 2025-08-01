import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

abstract class IFragmentedQrScanDataHandler extends IQrScanDataHandler {
  int? get sequenceLength; // 필수
  bool validateSequenceLength(String data);
}
