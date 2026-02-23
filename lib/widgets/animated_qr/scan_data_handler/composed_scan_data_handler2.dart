import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/bb_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/bc_ur_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/descriptor_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/extended_pub_key_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_fragmented_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

/// TODO: 0.8.0 배포 시 SeedSigner 추가 기능에 영향을 주고 싶지 않아서 별도로 구현
/// TODO: 추가 테스트 완료 후 wallet_add_scanner_screen.dart에 적용 필요
class ComposedScanDataHandler2 implements IFragmentedQrScanDataHandler {
  //final List<UrType>? expectedUrType;
  final BcUrQrScanDataHandler _bcUrQrScanDataHandler;
  final BbQrScanDataHandler _bbQrScanDataHandler;
  final DescriptorQrScanDataHandler _descriptorQrScanDataHandler;
  final ExtendedPublicKeyQrScanDataHandler _extendedPublicKeyQrScanDataHandler;
  IQrScanDataHandler? _selected;

  ComposedScanDataHandler2({List<UrType>? expectedUrType})
    : _bcUrQrScanDataHandler = BcUrQrScanDataHandler(expectedUrType: expectedUrType),
      _bbQrScanDataHandler = BbQrScanDataHandler(),
      _descriptorQrScanDataHandler = DescriptorQrScanDataHandler(),
      _extendedPublicKeyQrScanDataHandler = ExtendedPublicKeyQrScanDataHandler();

  IQrScanDataHandler? get selectedHandler => _selected;

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
        } else if (_bbQrScanDataHandler.validateFormat(data)) {
          _selected = _bbQrScanDataHandler;
        } else if (_extendedPublicKeyQrScanDataHandler.validateFormat(data)) {
          _selected = _extendedPublicKeyQrScanDataHandler;
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
    _selected = null;
    _bcUrQrScanDataHandler.reset();
    _bbQrScanDataHandler.reset();
    _descriptorQrScanDataHandler.reset();
    _extendedPublicKeyQrScanDataHandler.reset();
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
