import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/bc_ur_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/descriptor_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_fragmented_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

/// TODO: 우선 seedsigner 지갑 추가가 안되는 문제부터 해결합니다.
/// 추후 필요 시 다른 qr scan handler도 추가합니다.
class ComposedScanDataHandler implements IFragmentedQrScanDataHandler {
  //final List<UrType>? expectedUrType;
  final BcUrQrScanDataHandler _bcUrQrScanDataHandler;
  final DescriptorQrScanDataHandler _descriptorQrScanDataHandler;
  IQrScanDataHandler? _selected;

  ComposedScanDataHandler({List<UrType>? expectedUrType})
      : _bcUrQrScanDataHandler = BcUrQrScanDataHandler(expectedUrType: expectedUrType),
        _descriptorQrScanDataHandler = DescriptorQrScanDataHandler();

  @override
  dynamic get result => _selected?.result;

  @override
  double get progress => _selected?.progress ?? 0.0;

  @override
  bool isCompleted() {
    return _selected?.isCompleted() ?? false;
  }

  @override
  bool joinData(String data) {
    assert(_selected != null, "validateFormat()을 먼저 호출, 결과가 true일 때 호출 해야 합니다.");
    return _selected!.joinData(data);
  }

  @override
  bool validateFormat(String data) {
    try {
      if (_selected == null) {
        if (_descriptorQrScanDataHandler.validateFormat(data)) {
          _selected = _descriptorQrScanDataHandler;
        } else if (_bcUrQrScanDataHandler.validateFormat(data)) {
          _selected = _bcUrQrScanDataHandler;
        } else {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void reset() {
    _bcUrQrScanDataHandler.reset();
    _descriptorQrScanDataHandler.reset();
  }

  @override
  int? get sequenceLength {
    if (_selected is IFragmentedQrScanDataHandler) {
      return (_selected as IFragmentedQrScanDataHandler).sequenceLength;
    }
    return null;
  }

  @override
  bool validateSequenceLength(String data) {
    if (_selected is IFragmentedQrScanDataHandler) {
      return (_selected as IFragmentedQrScanDataHandler).validateSequenceLength(data);
    }
    return false;
  }
}
