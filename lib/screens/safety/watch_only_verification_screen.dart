import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutAppBar, CoconutPopup, CoconutUnderlinedButton;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/utils/address_scan_util.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/utils/wallet_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 주소를 4글자 묶음으로 보이게 하는 TextSpan. 묶음 사이는 마지막 글자의 자간으로만 띄운다(복사 내용은 주소 그대로)
TextSpan _groupedAddress(String address) => TextSpan(
  children: [
    for (var i = 0; i < address.length; i += 4) ...[
      TextSpan(text: address.substring(i, i + 3 < address.length ? i + 3 : address.length)),
      if (i + 3 < address.length)
        TextSpan(text: address[i + 3], style: i + 4 < address.length ? const TextStyle(letterSpacing: 6) : null),
    ],
  ],
);

class WatchOnlyVerificationScreen extends StatefulWidget {
  const WatchOnlyVerificationScreen({super.key, required this.walletId});

  final int walletId;

  static Future<void> open(BuildContext context, {required int walletId}) => Navigator.of(context).push<void>(
    CupertinoPageRoute(
      settings: const RouteSettings(name: '/wallet-health/watch-only-verification'),
      builder: (_) => WatchOnlyVerificationScreen(walletId: walletId),
    ),
  );

  @override
  State<WatchOnlyVerificationScreen> createState() => _WatchOnlyVerificationScreenState();
}

class _WatchOnlyVerificationScreenState extends State<WatchOnlyVerificationScreen> {
  VerificationResult? _result;
  VerificationMethod? _method;
  int? _matchedIndex;
  String? _error;
  bool _busy = false;

  WalletItemBase? _wallet() {
    final wallets = context.read<WalletProvider?>()?.walletItemList;
    if (wallets == null) return null;
    for (final wallet in wallets) {
      if (wallet.id == widget.walletId && !wallet.hasLocalKey && wallet.walletBase is! MultisignatureWallet) {
        return wallet;
      }
    }
    return null;
  }

  Future<void> _record(VerificationMethod method, VerificationResult result, {int? matchedIndex}) async {
    if (_busy || _wallet() == null) return;
    setState(() => _busy = true);
    try {
      final provider = context.read<SafetyProvider?>();
      if (provider == null) return;
      await provider.recordWatchOnlyVerification(
        widget.walletId,
        method: method,
        result: result,
        matchedIndex: matchedIndex,
      );
      if (!mounted || _wallet() == null) return;
      setState(() {
        _method = method;
        _result = result;
        _matchedIndex = matchedIndex;
        _error = null;
      });
      result == VerificationResult.match ? vibrateLight() : vibrateLightDouble();
    } catch (_) {
      if (mounted) setState(() => _error = t.wallet_health.save_failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    if (_busy) return;
    final wallet = _wallet();
    if (wallet == null) return;
    setState(() => _busy = true);
    String? scanned;
    try {
      scanned = await showAddressScannerBottomSheet(context, title: t.wallet_health.watch_only_verify.scan);
    } catch (_) {
      if (mounted) setState(() => _error = t.wallet_health.watch_only_verify.error_not_address);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted || scanned == null || _wallet() != wallet) return;
    final address = extractAddressFromBip21(scanned.trim());
    if (isBech32(address) && address != address.toLowerCase() && address != address.toUpperCase()) {
      setState(() => _error = t.wallet_health.watch_only_verify.error_not_address);
      return;
    }
    final index = WalletVerification.matchReceiveAddress(wallet.walletBase, scanned);
    final validation = AddressValidator.validateAddress(address, NetworkType.currentNetworkType);
    if (index == null && validation != null) {
      setState(
        () =>
            _error = switch (validation) {
              AddressValidationError.notMainnetAddress ||
              AddressValidationError.notTestnetAddress ||
              AddressValidationError.notRegtestnetAddress => t.wallet_health.watch_only_verify.error_network,
              _ => t.wallet_health.watch_only_verify.error_not_address,
            },
      );
      return;
    }
    await _record(
      VerificationMethod.qr,
      index == null ? VerificationResult.mismatch : VerificationResult.match,
      matchedIndex: index,
    );
  }

  Future<void> _confirm({required bool mismatch}) async {
    final wallet = _wallet();
    if (wallet == null) return;
    final copy = t.wallet_health.watch_only_verify;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => CoconutPopup(
            key: const Key('watch-only-verification-confirm-dialog'),
            title: mismatch ? copy.confirm_device_title : copy.confirm_title,
            description: mismatch ? copy.confirm_device_body : copy.confirm_body,
            languageCode: LocaleSettings.currentLocale.languageCode,
            leftButtonText: t.cancel,
            rightButtonText: mismatch ? copy.confirm_device_yes : copy.confirm_match,
            onTapLeft: () => Navigator.pop(dialogContext, false),
            onTapRight: () => Navigator.pop(dialogContext, true),
          ),
    );
    if (!mounted || confirmed != true || _wallet() != wallet) return;
    await _record(
      mismatch ? (_method ?? VerificationMethod.qr) : VerificationMethod.user,
      mismatch ? VerificationResult.confirmedMismatch : VerificationResult.match,
      matchedIndex: mismatch ? null : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<SafetyProvider?>() == null) return const SizedBox.shrink();
    context.watch<WalletProvider?>();
    final wallet = _wallet();
    if (wallet == null) return const SizedBox.shrink();
    final colors = context.coconutColors;
    final copy = t.wallet_health.watch_only_verify;
    final mismatch = _result == VerificationResult.mismatch;
    final confirmedMismatch = _result == VerificationResult.confirmedMismatch;
    final manual = _result == VerificationResult.match && _method == VerificationMethod.user;
    final complete = _result == VerificationResult.match || confirmedMismatch;
    final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    final fingerprintMissing = isWalletWithoutMfp(wallet);
    return Scaffold(
      key: const Key('watch-only-verification-screen'),
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, title: copy.title, backgroundColor: colors.background),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safetyKoText(copy.heading),
                  style: CoconutTypography.heading3_21_Bold.setColor(colors.primaryText),
                ),
                CoconutLayout.spacing_300h,
                Text(safetyKoText(copy.description), style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
                CoconutLayout.spacing_600h,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(copy.address_label, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
                      CoconutLayout.spacing_200h,
                      // 4글자씩 묶어 보인다. 글자를 넣지 않고 묶음 끝 글자 뒤만 넓혀서 복사하면 원래 주소 그대로(POLISH C31)
                      SelectableText.rich(
                        _groupedAddress(wallet.walletBase.getAddress(0)),
                        style: CoconutTypography.body2_14_Number.setColor(colors.primaryText),
                      ),
                      CoconutLayout.spacing_100h,
                      Text(
                        '${wallet.walletBase.derivationPath}/0/0',
                        style: CoconutTypography.caption_10.setColor(colors.secondaryText),
                      ),
                    ],
                  ),
                ),
                CoconutLayout.spacing_400h,
                if (fingerprintMissing && _result == null)
                  SafetyStatusBanner(
                    background: colors.surface,
                    iconPath: CommonStateIconPath.circleInfo,
                    iconColor: colors.iconSecondary,
                    title: copy.no_mfp_title,
                    body: copy.no_mfp,
                  ),
                AnimatedSwitcher(
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
                  child:
                      _result == null
                          ? const SizedBox.shrink()
                          : SafetyStatusBanner(
                            key: ValueKey((_result, _method)),
                            background:
                                confirmedMismatch
                                    ? colors.dangerSurface
                                    : mismatch
                                    ? colors.warningSurface
                                    : manual
                                    ? colors.surface
                                    : colors.successSurface,
                            iconPath:
                                mismatch || confirmedMismatch
                                    ? CommonStateIconPath.triangleWarning
                                    : manual
                                    ? CommonFormIconPath.circleCheck
                                    : CommonStateIconPath.shieldCheck,
                            iconColor:
                                confirmedMismatch
                                    ? colors.danger
                                    : mismatch
                                    ? colors.warningText
                                    : manual
                                    ? colors.iconSecondary
                                    : colors.success,
                            title:
                                mismatch || confirmedMismatch
                                    ? copy.mismatch_title
                                    : manual
                                    ? copy.user_confirmed_title
                                    : copy.match_title,
                            body:
                                confirmedMismatch
                                    ? copy.mismatch_body
                                    : mismatch
                                    ? copy.mismatch_retry_body
                                    : manual
                                    ? copy.user_confirmed_body
                                    : copy.match_at_index(index: _matchedIndex ?? 0),
                          ),
                ),
                if (_error != null) ...[
                  CoconutLayout.spacing_300h,
                  Text(
                    _error!,
                    key: const Key('watch-only-verification-error'),
                    style: CoconutTypography.body2_14.setColor(colors.dangerText),
                  ),
                ],
              ],
            ),
          ),
          FixedBottomButton(
            buttonKey: const Key('watch-only-verification-primary'),
            text:
                complete
                    ? t.confirm
                    : mismatch
                    ? copy.scan_again
                    : copy.scan,
            isActive: !_busy,
            onButtonClicked: complete ? () => Navigator.pop(context) : _scan,
            subWidget:
                complete
                    ? null
                    : CoconutUnderlinedButton(
                      key: const Key('watch-only-verification-secondary'),
                      text: mismatch ? copy.confirm_device : copy.compared_manually,
                      defaultColor: colors.secondaryTextStrong,
                      isActive: !_busy,
                      onTap: () => _confirm(mismatch: mismatch),
                    ),
          ),
        ],
      ),
    );
  }
}
