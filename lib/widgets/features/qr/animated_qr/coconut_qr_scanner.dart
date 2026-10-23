import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/i_fragmented_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/scan_data_handler_exceptions.dart';
import 'package:coconut_wallet/widgets/features/qr/camera_permission_dialog.dart';
import 'package:coconut_wallet/widgets/features/qr/overlay/scanner_overlay.dart';
import 'package:coconut_wallet/widgets/features/qr/qr_scanner_view.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CoconutQrScanner extends StatefulWidget {
  static String qrFormatErrorMessage = 'Invalid QR format.';
  static String qrInvalidErrorMessage = 'Invalid QR Code.';
  final Function(MobileScannerController) setMobileScannerController;
  final Function(Object) onComplete;
  final Function(String, String?) onFailed;
  final IQrScanDataHandler<Object> qrDataHandler;
  final ValueChanged<String>? onScanData;
  final bool closeOnPermissionDenied;

  const CoconutQrScanner({
    super.key,
    required this.setMobileScannerController,
    required this.onComplete,
    required this.onFailed,
    required this.qrDataHandler,
    this.onScanData,
    this.closeOnPermissionDenied = true,
  });

  @override
  State<CoconutQrScanner> createState() => _CoconutQrScannerState();
}

class _CoconutQrScannerState extends State<CoconutQrScanner>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  final ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);
  bool _isScanningExtraData = false;
  bool _hasBeenScanningExtraData = false;
  bool _showLoadingBar = false;
  bool _isFirstScanData = true;
  bool _isShowedCameraPermissionDialog = false;
  bool _isCameraPermissionDialogOpen = false;
  bool _retryDeniedCameraOnDialogDismiss = false;

  MobileScannerController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController();

    widget.setMobileScannerController(_controller!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressNotifier.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || widget.closeOnPermissionDenied) return;
    if (_controller?.value.error?.errorCode != MobileScannerErrorCode.permissionDenied) return;
    if (_isCameraPermissionDialogOpen) {
      _retryDeniedCameraOnDialogDismiss = true;
    } else {
      _retryDeniedCamera();
    }
  }

  void _retryDeniedCamera() {
    if (!mounted || widget.closeOnPermissionDenied) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (_controller?.value.error?.errorCode == MobileScannerErrorCode.permissionDenied) {
      _controller?.start();
    }
  }

  void resetScanState() {
    _isFirstScanData = true;
  }

  void _onDetect(BarcodeCapture capture) {
    final codes = capture.barcodes;
    if (codes.isEmpty) return;

    final barcode = codes.first;
    if (barcode.rawValue == null) return;

    final scanData = barcode.rawValue!;
    widget.onScanData?.call(scanData);
    var handler = widget.qrDataHandler;

    try {
      if (_isFirstScanData) {
        // 스캔 완료 후 이 위젯을 사용하는 화면에서 handler 내부의 데이터를 활용하는 경우가 생겨서 바로 reset 호출하지 않고 여기서 reset
        handler.reset();
        if (!handler.validateFormat(scanData)) {
          widget.onFailed(CoconutQrScanner.qrFormatErrorMessage, scanData);
          setState(() {
            _showLoadingBar = false;
          });
          return;
        }
        _isFirstScanData = false;
      }

      // 핸들러가 완료되지 않은 경우 데이터 조인 시도
      if (!handler.isCompleted()) {
        try {
          bool result = handler.joinData(scanData);
          Logger.log('--> progress: ${handler.progress}');
          _progressNotifier.value = handler.progress;
          if (!result && handler is! IFragmentedQrScanDataHandler) {
            widget.onFailed(CoconutQrScanner.qrInvalidErrorMessage, scanData);
            resetScanState();
            return;
          }
          /* handler가 IFragmentedQrScanDataHandler일 땐 joinData 실패해도 무시하고 계속 스캔 진행함.
           왜냐하면 animated qr 스캔 중 노이즈 데이터가 오탐되는 경우가 있는데 매번 처음부터 다시 하면 사용성을 해침 */
        } on SequenceLengthMismatchException catch (_) {
          // QR Density 변경됨
          assert(handler is IFragmentedQrScanDataHandler);
          resetScanState();
          return;
        }
      }

      setState(() {
        _isScanningExtraData = handler.progress > 0.98;
        if (_isScanningExtraData) {
          _hasBeenScanningExtraData = true;
        }
        _showLoadingBar = true;
      });

      if (handler.isCompleted()) {
        _resetLoadingBarState();
        final result = handler.result!;
        resetScanState();
        widget.onComplete(result);
      }
    } catch (e) {
      Logger.error(e.toString());
      _resetLoadingBarState();
      resetScanState();
      widget.onFailed(e.toString(), scanData);
    }
  }

  void _resetLoadingBarState() {
    _progressNotifier.value = 0;
    setState(() {
      _isScanningExtraData = false;
      _hasBeenScanningExtraData = false;
      if (_showLoadingBar) {
        _showLoadingBar = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return QrScannerView(
      controller: _controller!,
      onDetect: _onDetect,
      errorBuilder: (_, error) {
        if (error.errorCode == MobileScannerErrorCode.permissionDenied && !_isShowedCameraPermissionDialog) {
          _isShowedCameraPermissionDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            _isCameraPermissionDialogOpen = true;
            await showCameraPermissionDialog(this.context);
            if (!mounted) return;
            _isCameraPermissionDialogOpen = false;
            if (widget.closeOnPermissionDenied) {
              Navigator.pop(this.context);
            } else if (_retryDeniedCameraOnDialogDismiss) {
              _retryDeniedCameraOnDialogDismiss = false;
              _retryDeniedCamera();
            }
          });
        }
        return Center(child: Text(error.errorCode.message));
      },
      overlayBuilder: (context, _) => _buildProgressOverlay(context),
    );
  }

  Widget _buildProgressOverlay(BuildContext context) {
    final scanAreaSize = ScannerOverlay.calculateScanAreaSize(context);
    final scanAreaTop = (MediaQuery.of(context).size.height - scanAreaSize) / 2;
    final scanAreaBottom = scanAreaTop + scanAreaSize;

    return Stack(
      children: [
        // 프로그레스 바
        Positioned(
          top: scanAreaBottom,
          left: 0,
          right: 0,
          child: Visibility(
            visible: _showLoadingBar,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CoconutLayout.spacing_1300w,
                if (!_isScanningExtraData && !_hasBeenScanningExtraData) ...[
                  _buildProgressBar(),
                  CoconutLayout.spacing_300w,
                  _buildProgressText(),
                ],
                if (_isScanningExtraData) Expanded(child: _buildReadingExtraText()),
                CoconutLayout.spacing_1300w,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Rect? getQrViewRect() {
    final renderObject = qrKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final position = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;
      return position & size;
    }
    return null;
  }

  Widget _buildReadingExtraText() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          textAlign: TextAlign.center,
          t.coconut_qr_scanner.reading_extra_data,
          style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
        ),
      ),
    );
  }

  Widget _buildProgressText() {
    return ValueListenableBuilder<double>(
      valueListenable: _progressNotifier,
      builder: (context, value, _) {
        return SizedBox(
          width: 35,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              textAlign: TextAlign.center,
              "${(value * 100).toInt()}%",
              style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxWidth = constraints.maxWidth;
          return Stack(
            children: [
              Container(
                width: maxWidth,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  color: context.coconutColors.qrScannerProgressBarTrack,
                ),
              ),
              ValueListenableBuilder<double>(
                valueListenable: _progressNotifier,
                builder: (context, value, _) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: maxWidth * _progressNotifier.value,
                    height: 6,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                      color: context.coconutColors.qrScannerProgressBarFill,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
