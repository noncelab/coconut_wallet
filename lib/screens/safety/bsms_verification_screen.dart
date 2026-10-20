import 'dart:convert';

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/coconut_qr_scanner.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/bc_ur_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/i_fragmented_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_icon_small.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:ur/cbor_lite.dart';
import 'package:ur/fountain_encoder.dart';
import 'package:ur/ur.dart';
import 'package:ur/ur_decoder.dart';

class BsmsVerificationScreen extends StatefulWidget {
  const BsmsVerificationScreen({super.key, required this.walletId});

  final int walletId;

  static Future<void> open(BuildContext context, {required int walletId}) => Navigator.of(context).push<void>(
    CupertinoPageRoute(
      settings: const RouteSettings(name: '/wallet-health/bsms-verification'),
      builder: (_) => BsmsVerificationScreen(walletId: walletId),
    ),
  );

  @override
  State<BsmsVerificationScreen> createState() => _BsmsVerificationScreenState();
}

class _BsmsVerificationScreenState extends State<BsmsVerificationScreen> {
  BsmsComparison? _comparison;
  String? _error;
  bool _busy = false;

  MultisigWalletItem? _wallet() {
    final wallets = context.read<WalletProvider?>()?.walletItemList;
    if (wallets == null) return null;
    for (final wallet in wallets) {
      if (wallet.id == widget.walletId && wallet is MultisigWalletItem) return wallet;
    }
    return null;
  }

  Future<void> _scan() async {
    if (_busy) return;
    final wallet = _wallet();
    if (wallet == null) return;
    setState(() => _busy = true);
    try {
      final backup = await Navigator.of(context).push<String>(
        CupertinoPageRoute(
          settings: const RouteSettings(name: '/wallet-health/bsms-verification/scan'),
          builder: (_) => const _BsmsScannerScreen(),
        ),
      );
      if (!mounted || backup == null || _wallet() != wallet) return;
      BsmsComparison comparison;
      try {
        comparison = WalletVerification.compareBsms(wallet.walletBase as MultisignatureWallet, backup);
      } on FormatException {
        setState(() {
          _comparison = null;
          _error = t.wallet_health.bsms_verify.error_parse;
        });
        return;
      }
      final provider = context.read<SafetyProvider?>();
      if (provider == null) return;
      await provider.recordBsmsVerification(
        widget.walletId,
        matched: comparison.matched,
        // 입력 수집기와 같은 원본 표기를 해시한다(h와 '의 재직렬화 차이).
        configHash: WalletVerification.descriptorHash(wallet.descriptor),
      );
      if (!mounted || _wallet() != wallet) return;
      setState(() {
        _comparison = comparison;
        _error = null;
      });
      comparison.matched ? vibrateLight() : vibrateLightDouble();
    } catch (_) {
      if (mounted) setState(() => _error = t.wallet_health.save_failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _comparisonRow(String title, bool? matched, {String? value}) {
    final colors = context.coconutColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            matched == null
                ? CommonFormIconPath.circle
                : matched
                ? CommonFormIconPath.circleCheck
                : CommonStateIconPath.triangleWarning,
            width: 18,
            height: 18,
            semanticsLabel:
                matched == null
                    ? t.wallet_health.evidence.not_checked
                    : matched
                    ? t.wallet_health.bsms_verify.match
                    : t.wallet_health.bsms_verify.mismatch,
            colorFilter: ColorFilter.mode(
              matched == null
                  ? colors.iconSecondary
                  : matched
                  ? colors.success
                  : colors.dangerText,
              BlendMode.srcIn,
            ),
          ),
          CoconutLayout.spacing_300w,
          Expanded(child: Text(title, style: CoconutTypography.body2_14.setColor(colors.primaryText))),
          CoconutLayout.spacing_300w,
          Flexible(
            child: Text(
              value ??
                  (matched == null
                      ? t.wallet_health.evidence.not_checked
                      : matched
                      ? t.wallet_health.bsms_verify.match
                      : t.wallet_health.bsms_verify.mismatch),
              textAlign: TextAlign.end,
              style: CoconutTypography.body3_12_Number.setColor(colors.secondaryText),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<SafetyProvider?>() == null) return const SizedBox.shrink();
    context.watch<WalletProvider?>();
    final wallet = _wallet();
    if (wallet == null) return const SizedBox.shrink();
    final base = wallet.walletBase as MultisignatureWallet;
    final colors = context.coconutColors;
    final copy = t.wallet_health.bsms_verify;
    final comparison = _comparison;
    final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    return Scaffold(
      key: const Key('bsms-verification-screen'),
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, title: copy.title, backgroundColor: colors.background),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(copy.description, style: CoconutTypography.heading3_21_Bold.setColor(colors.primaryText)),
                CoconutLayout.spacing_600h,
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          WalletIconSmall(
                            walletImportSource: wallet.walletImportSource,
                            colorIndex: wallet.colorIndex,
                            iconIndex: wallet.iconIndex,
                          ),
                          CoconutLayout.spacing_300w,
                          Expanded(
                            child: Text(
                              wallet.name,
                              style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
                            ),
                          ),
                          Text(
                            '${base.requiredSignature}/${base.totalSigner}',
                            style: CoconutTypography.body3_12_Number.setColor(colors.secondaryText),
                          ),
                        ],
                      ),
                      CoconutLayout.spacing_400h,
                      Divider(color: colors.border.withValues(alpha: 0.21), height: 1),
                      CoconutLayout.spacing_200h,
                      _comparisonRow(
                        copy.quorum,
                        comparison?.quorum,
                        value: '${base.requiredSignature}/${base.totalSigner}',
                      ),
                      _comparisonRow(
                        copy.signer_fingerprints,
                        comparison?.fingerprints,
                        value: wallet.signerBsmsList.map((signer) => signer.fingerprint).join('\n'),
                      ),
                      _comparisonRow(
                        copy.derivation_paths,
                        comparison?.derivationPaths,
                        value: wallet.signerBsmsList.map((signer) => signer.derivationPath).toSet().join('\n'),
                      ),
                      _comparisonRow(copy.xpubs, comparison?.extendedPublicKeys),
                      _comparisonRow(
                        copy.script_type,
                        comparison?.scriptType,
                        value: base.addressType.name.toUpperCase(),
                      ),
                      _comparisonRow(copy.first_address, comparison?.firstAddress),
                    ],
                  ),
                ),
                CoconutLayout.spacing_400h,
                AnimatedSwitcher(
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
                  child:
                      comparison == null
                          ? const SizedBox.shrink()
                          : SafetyStatusBanner(
                            key: ValueKey(comparison.matched),
                            background: comparison.matched ? colors.successSurface : colors.dangerSurface,
                            iconPath:
                                comparison.matched
                                    ? CommonStateIconPath.shieldCheck
                                    : CommonStateIconPath.triangleWarning,
                            iconColor: comparison.matched ? colors.success : colors.dangerText,
                            title: comparison.matched ? copy.verified_title : copy.mismatch_title,
                            body: comparison.matched ? copy.verified_body : copy.mismatch_body,
                          ),
                ),
                if (_error != null) ...[
                  CoconutLayout.spacing_300h,
                  Text(
                    _error!,
                    key: const Key('bsms-verification-error'),
                    style: CoconutTypography.body2_14.setColor(colors.dangerText),
                  ),
                ],
              ],
            ),
          ),
          FixedBottomButton(
            buttonKey: const Key('bsms-verification-primary'),
            text: comparison?.matched == true ? t.confirm : copy.scan,
            isActive: !_busy,
            onButtonClicked: comparison?.matched == true ? () => Navigator.pop(context) : _scan,
          ),
        ],
      ),
    );
  }
}

class _BsmsScannerScreen extends StatefulWidget {
  const _BsmsScannerScreen();

  @override
  State<_BsmsScannerScreen> createState() => _BsmsScannerScreenState();
}

class _BsmsScannerScreenState extends State<_BsmsScannerScreen> {
  final _handler = _BsmsQrDataHandler();
  bool _completed = false;
  bool _invalid = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.coconutColors.background,
    appBar: CoconutAppBar.build(context: context, title: t.wallet_health.bsms_verify.scan),
    body: Stack(
      children: [
        CoconutQrScanner(
          key: const Key('bsms-verification-scanner'),
          setMobileScannerController: (_) {},
          qrDataHandler: _handler,
          onComplete: (value) {
            if (_completed) return;
            _completed = true;
            Navigator.pop(context, value as String);
          },
          onFailed: (_, __) {
            _handler.reset();
            setState(() => _invalid = true);
          },
        ),
        if (_invalid)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: context.coconutColors.surface,
              padding: const EdgeInsets.all(20),
              child: Text(
                t.wallet_health.bsms_verify.error_parse,
                style: CoconutTypography.body2_14.setColor(context.coconutColors.dangerText),
              ),
            ),
          ),
      ],
    ),
  );
}

// 기존 UR 조립기를 재사용하고 원문 QR·단일 UR도 받는다.
class _BsmsQrDataHandler implements IFragmentedQrScanDataHandler {
  static const _maxSequenceLength = 1024;
  static const _maxMessageBytes = WalletVerification.maxBackupBytes + 9;
  static const _maxFrameCharacters = 2 * (_maxMessageBytes + 64) + 32;
  final _ur = BcUrQrScanDataHandler(expectedUrType: [UrType.bytes]);
  final _sequences = <int>{};
  FountainEncoderPart? _firstPart;
  int _receivedBytes = 0;
  String? _text;

  @override
  String? get result => _text;
  @override
  double get progress => _text != null ? 1 : _ur.progress;
  @override
  bool isCompleted() => _text != null;
  @override
  int? get sequenceLength => _ur.sequenceLength;
  @override
  bool validateSequenceLength(String data) => _ur.validateSequenceLength(data);
  @override
  bool validateFormat(String data) => data.length <= _maxFrameCharacters && data.trim().isNotEmpty;
  @override
  void reset() {
    _text = null;
    _firstPart = null;
    _receivedBytes = 0;
    _sequences.clear();
    _ur.reset();
  }

  @override
  bool joinData(String data) {
    try {
      if (!validateFormat(data)) throw const FormatException();
      final text = data.trim();
      if (!text.toLowerCase().startsWith('ur:')) {
        if (utf8.encode(text).length > WalletVerification.maxBackupBytes) throw const FormatException();
        _text = text;
        return true;
      }
      final (type, components) = URDecoder.parse(text);
      if (type != UrType.bytes.value) throw const FormatException();
      UR? decoded;
      if (components.length == 1) {
        decoded = URDecoder.decode(text);
      } else {
        if (components.length != 2) throw const FormatException();
        final (sequence, count) = URDecoder.parseSequenceComponent(components.first);
        if (sequence > 0xffffffff || count > _maxSequenceLength) throw const FormatException();
        final encoded = URDecoder.decodeByType(type, components.last).cbor;
        final part = FountainEncoderPart.fromCbor(encoded);
        // 공용 조립기가 헤더 값으로 메모리를 할당하기 전에 제한한다.
        if (part.seqNum != sequence ||
            part.seqLen != count ||
            part.messageLen <= 0 ||
            part.messageLen > _maxMessageBytes ||
            part.checksum > 0xffffffff ||
            part.data.isEmpty ||
            part.messageLen > count * part.data.length ||
            part.messageLen <= (count - 1) * part.data.length) {
          throw const FormatException();
        }
        final first = _firstPart;
        if (first != null &&
            (part.seqLen != first.seqLen ||
                part.messageLen != first.messageLen ||
                part.checksum != first.checksum ||
                part.data.length != first.data.length)) {
          throw const FormatException();
        }
        if (_sequences.contains(sequence)) return true;
        if (_sequences.length >= 4 * _maxSequenceLength || _receivedBytes + encoded.length > 4 * _maxMessageBytes) {
          throw const FormatException();
        }
        _firstPart ??= part;
        _sequences.add(sequence);
        _receivedBytes += encoded.length;
        _ur.joinData(text);
        if (_ur.isCompleted()) decoded = _ur.result as UR;
      }
      if (decoded != null) {
        if (decoded.cbor.length > _maxMessageBytes) throw const FormatException();
        final (bytes, consumed) = CBORDecoder(decoded.cbor).decodeBytes();
        if (consumed != decoded.cbor.length || bytes.length > WalletVerification.maxBackupBytes) {
          throw const FormatException();
        }
        _text = utf8.decode(bytes);
      }
      return true;
    } catch (_) {
      // 공용 스캐너가 남기는 오류에 백업 원문을 넣지 않는다.
      throw const FormatException('Invalid BSMS QR');
    }
  }
}
