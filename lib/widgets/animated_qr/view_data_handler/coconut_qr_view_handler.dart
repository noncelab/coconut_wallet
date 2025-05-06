import 'package:coconut_wallet/widgets/animated_qr/animated_qr_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/i_qr_view_data_handler.dart';

class CoconutQrViewHandler implements IQrViewDataHandler {
  final String _source;
  late List<String> splitedData;
  int _dataIndex = 0;

  CoconutQrViewHandler(this._source) {
    splitedData = AnimatedQRDataHandler.splitData(_source);
  }

  @override
  String nextPart() {
    return splitedData[_dataIndex++ % splitedData.length];
  }

  @override
  String get source => _source;
}
