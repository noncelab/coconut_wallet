import 'dart:convert';

import 'package:cbor/cbor.dart';
import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/air-gapped/unsigned_transaction_qr_view_model.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/qr/adaptive_qr_image.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/coconut_qr_scanner.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/signed_psbt_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/view_data_handler/bc_ur_qr_view_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:ur/ur.dart';

/// Takes a payjoin PSBT to Coconut Vault and back in one screen: the PSBT
/// as an animated QR for the vault to scan, then the scanner for the
/// vault's signed answer.
///
/// [accept] turns the scanned PSBT into the result the screen pops with,
/// and throws if the answer is not the one asked for; the screen then keeps
/// scanning. Pops with null when the user leaves.
class PayjoinVaultSignScreen extends StatefulWidget {
  const PayjoinVaultSignScreen({super.key, required this.psbtBase64, required this.instruction, required this.accept});

  final String psbtBase64;
  final String instruction;
  final String Function(String signedPsbtBase64) accept;

  @override
  State<PayjoinVaultSignScreen> createState() => _PayjoinVaultSignScreenState();
}

class _PayjoinVaultSignScreenState extends State<PayjoinVaultSignScreen> {
  final SignedPsbtScanDataHandler _scanHandler = SignedPsbtScanDataHandler();
  MobileScannerController? _controller;
  bool _scanning = false;
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(
        title: _scanning ? t.payjoin.vault_waiting : t.payjoin.vault_sign_title,
        context: context,
        onBackPressed: () {
          if (_scanning) {
            setState(() => _scanning = false);
          } else {
            Navigator.pop(context);
          }
        },
      ),
      body: SafeArea(child: _scanning ? _buildScanner() : _buildQr()),
    );
  }

  Widget _buildQr() {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 32, left: 16, right: 16),
                child: _buildGuide(widget.instruction, context.coconutColors.tooltipBackground),
              ),
              AdaptiveQrImage(
                key: const ValueKey('payjoin-vault-psbt-qr'),
                qrDensity: QrScanDensity.fast,
                qrViewDataHandler: BcUrQrViewHandler(widget.psbtBase64, QrScanDensity.fast, {'urType': 'crypto-psbt'}),
              ),
              const SizedBox(height: 150),
            ],
          ),
        ),
        FixedBottomButton(onButtonClicked: () => setState(() => _scanning = true), text: t.payjoin.vault_scan_signed),
      ],
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        CoconutQrScanner(
          setMobileScannerController: (controller) => _controller = controller,
          onComplete: _onScanned,
          onFailed: (message, _) => _showError(t.alert.scan_failed_description(error: message)),
          qrDataHandler: _scanHandler,
        ),
        Padding(
          padding: const EdgeInsets.only(
            top: 20,
            left: CoconutLayout.defaultPadding,
            right: CoconutLayout.defaultPadding,
          ),
          child: _buildGuide(t.payjoin.vault_scan_guide, context.coconutColors.surface),
        ),
      ],
    );
  }

  Future<void> _onScanned(Object data) async {
    if (_processing) return;
    _processing = true;
    try {
      final result = widget.accept(_psbtFromScan(data));
      await _controller?.stop();
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      Logger.error('Payjoin: vault answer refused: $e');
      await _showError(t.payjoin.vault_signature_mismatch);
    }
  }

  String _psbtFromScan(Object data) => switch (data) {
    UR ur => base64Encode((cbor.decode(ur.cbor) as CborBytes).bytes),
    String text => text,
    _ => throw FormatException('unexpected scan result ${data.runtimeType}'),
  };

  Future<void> _showError(String message) async {
    if (!mounted) return;
    _processing = true;
    try {
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => CoconutPopup(
              languageCode: dialogContext.read<PreferenceProvider>().language,
              title: t.alert.scan_failed,
              description: message,
              onTapRight: () => Navigator.pop(dialogContext),
              rightButtonText: t.OK,
            ),
      );
    } finally {
      _processing = false;
    }
  }

  Widget _buildGuide(String text, Color background) {
    return CoconutToolTip(
      backgroundColor: background,
      borderColor: background,
      icon: SvgPicture.asset(
        CommonStateIconPath.circleInfo,
        width: 20,
        colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
      ),
      tooltipType: CoconutTooltipType.fixed,
      richText: RichText(
        text: TextSpan(
          text: text,
          style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText).copyWith(height: 1.3),
        ),
      ),
    );
  }
}
