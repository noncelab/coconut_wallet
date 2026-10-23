import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/i_fragmented_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

/// 첫 스캔 데이터의 형식에 맞는 handler를 선택하고 이후 처리를 위임한다.
/// handlers 목록의 순서가 형식 판별 우선순위다.
class ComposedScanDataHandler implements IFragmentedQrScanDataHandler<Object> {
  final List<IQrScanDataHandler<Object>> _handlers;
  IQrScanDataHandler<Object>? _selected;

  ComposedScanDataHandler(this._handlers);

  IQrScanDataHandler<Object>? get selectedHandler => _selected;

  @override
  Object? get result => _selected?.result;

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
        for (final handler in _handlers) {
          if (handler.validateFormat(data)) {
            _selected = handler;
            break;
          }
        }
        if (_selected == null) {
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
    for (final handler in _handlers) {
      handler.reset();
    }
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
