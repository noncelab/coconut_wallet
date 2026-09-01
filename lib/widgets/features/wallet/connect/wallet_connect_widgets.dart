import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/animation/success_check_lottie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';

/// Unified info row used by wallet connect screens.
///
/// Displays a label–value pair either horizontally or vertically.
class WalletConnectInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Axis direction;

  const WalletConnectInfoRow({super.key, required this.label, required this.value, this.direction = Axis.horizontal});

  @override
  Widget build(BuildContext context) {
    final labelStyle = CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText);
    final valueStyle = CoconutTypography.body2_14_NumberBold.setColor(context.coconutColors.primaryText);

    if (direction == Axis.horizontal) {
      return Row(children: [Text(label, style: labelStyle), const Spacer(), Text(value, style: valueStyle)]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(label, style: labelStyle), CoconutLayout.spacing_100h, Text(value, style: valueStyle)],
    );
  }
}

/// Unified error card used by wallet connect screens.
///
/// Shows a warning icon, title, description, error message, and optional
/// numbered troubleshooting steps.
class WalletConnectErrorCard extends StatelessWidget {
  final String title;
  final String description;
  final String? errorMessage;
  final List<String>? steps;

  const WalletConnectErrorCard({
    super.key,
    required this.title,
    required this.description,
    this.errorMessage,
    this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SvgPicture.asset(
            CommonStateIconPath.circleWarning,
            colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
            height: 48,
            width: 48,
          ),
          CoconutLayout.spacing_200h,
          Text(title, style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.danger)),
          CoconutLayout.spacing_400h,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: context.coconutColors.surface,
              borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
            ),
            child: Column(
              children: [
                Text(
                  description,
                  style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
                  textAlign: TextAlign.center,
                ),
                CoconutLayout.spacing_200h,
                Text(
                  errorMessage ?? 'Unknown error',
                  style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.secondaryText),
                  textAlign: TextAlign.center,
                ),
                if (steps != null && steps!.isNotEmpty) ...[
                  CoconutLayout.spacing_300h,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        steps!.asMap().entries.map((e) {
                          final isLast = e.key == steps!.length - 1;
                          return Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${e.key + 1}. ',
                                    style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                                  ),
                                  TextSpan(
                                    text: e.value,
                                    style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.left,
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Unified instruction tooltip used by wallet connect screens.
///
/// Each step can be a plain [String] or a [List<TextSpan>] for rich text.
/// An optional [notice] string is shown in bold above the steps.
class WalletConnectInstructionToolTip extends StatelessWidget {
  final List<Object> steps;
  final String? notice;

  const WalletConnectInstructionToolTip({super.key, required this.steps, this.notice});

  @override
  Widget build(BuildContext context) {
    return CoconutToolTip(
      backgroundColor: context.coconutColors.surface,
      borderColor: context.coconutColors.surface,
      icon: SvgPicture.asset(
        CommonStateIconPath.circleInfo,
        width: 20,
        colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
      ),
      tooltipType: CoconutTooltipType.fixed,
      richText: RichText(
        text: TextSpan(
          style: CoconutTypography.body2_14,
          children: [
            if (notice != null) ...[
              TextSpan(
                text: notice,
                style: TextStyle(color: context.coconutColors.primaryText, fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '\n\n'),
            ],
            ...steps.asMap().entries.expand((e) {
              final isLast = e.key == steps.length - 1;
              final stepSpans =
                  e.value is String
                      ? [TextSpan(text: e.value as String, style: TextStyle(color: context.coconutColors.primaryText))]
                      : e.value as List<TextSpan>;
              return [
                if (steps.length > 1)
                  TextSpan(text: '${e.key + 1}. ', style: TextStyle(color: context.coconutColors.primaryText)),
                ...stepSpans,
                if (!isLast) const TextSpan(text: '\n'),
              ];
            }),
          ],
        ),
      ),
    );
  }
}

/// Unified progress card with spinner, title, and numbered step instructions.
class WalletConnectProgressCard extends StatelessWidget {
  final String title;
  final List<Object> steps;

  const WalletConnectProgressCard({super.key, required this.title, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(color: context.coconutColors.primary, strokeWidth: 3),
          ),
          CoconutLayout.spacing_200h,
          Text(
            title,
            style: CoconutTypography.body2_14.setColor(context.coconutColors.primary),
            textAlign: TextAlign.center,
          ),
          CoconutLayout.spacing_400h,
          WalletConnectInstructionToolTip(steps: steps),
        ],
      ),
    );
  }
}

/// Unified wallet info skeleton with shimmer placeholders.
class WalletConnectWalletInfoSkeleton extends StatelessWidget {
  const WalletConnectWalletInfoSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: context.coconutColors.surface,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRowSkeleton(context, labelWidth: 100, valueWidth: 90),
          CoconutLayout.spacing_300h,
          _buildInfoRowSkeleton(context, labelWidth: 90, valueWidth: 70),
          CoconutLayout.spacing_300h,
          _buildInfoColumnSkeleton(context, labelWidth: 120),
        ],
      ),
    );
  }

  Widget _buildInfoRowSkeleton(BuildContext context, {required double labelWidth, required double valueWidth}) {
    return Row(
      children: [
        _buildSkeletonBox(context, width: labelWidth),
        const Spacer(),
        _buildSkeletonBox(context, width: valueWidth),
      ],
    );
  }

  Widget _buildInfoColumnSkeleton(BuildContext context, {required double labelWidth}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSkeletonBox(context, width: labelWidth),
        CoconutLayout.spacing_100h,
        _buildSkeletonBox(context, width: double.infinity, height: 14),
      ],
    );
  }

  Widget _buildSkeletonBox(BuildContext context, {required double width, double height = 12}) {
    return Shimmer.fromColors(
      baseColor: context.coconutColors.surfaceSkeletonBase,
      highlightColor: context.coconutColors.surfaceSkeletonHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.coconutColors.surfaceSkeletonBase,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Unified success card with checkmark icon, title, and optional child content.
class WalletConnectSuccessCard extends StatelessWidget {
  final String title;
  final Widget? child;

  const WalletConnectSuccessCard({super.key, required this.title, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SuccessCheckLottie(size: 40, color: context.coconutColors.success),
          CoconutLayout.spacing_200h,
          Text(
            title,
            style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
            textAlign: TextAlign.center,
          ),
          CoconutLayout.spacing_200h,
          CoconutLayout.spacing_600h,
          if (child != null) child!,
        ],
      ),
    );
  }
}

/// Wallet mismatch card — connection succeeded but the connected wallet
/// doesn't match the expected wallet. Shows a warning icon, a short mismatch
/// title, an optional secondary description, optional child content (e.g.
/// wallet info), and an optional footer message shown in danger color below
/// the child content.
class WalletConnectMismatchCard extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? child;
  final String? footerText;

  const WalletConnectMismatchCard({super.key, required this.title, this.description, this.child, this.footerText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SvgPicture.asset(
            CommonStateIconPath.triangleWarning,
            colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
            height: 48,
            width: 48,
          ),
          CoconutLayout.spacing_200h,
          Text(
            title,
            style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.danger),
            textAlign: TextAlign.center,
          ),
          if (description != null && description!.isNotEmpty) ...[
            CoconutLayout.spacing_200h,
            Text(
              description!,
              style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
              textAlign: TextAlign.center,
            ),
          ],
          CoconutLayout.spacing_200h,
          CoconutLayout.spacing_600h,
          if (child != null) child!,
          if (footerText != null && footerText!.isNotEmpty) ...[
            CoconutLayout.spacing_300h,
            Text(
              footerText!,
              style: CoconutTypography.body2_14.setColor(context.coconutColors.danger),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Secondary label shown above a wallet info card, e.g. "Connected Wallet".
class WalletConnectSectionLabel extends StatelessWidget {
  final String label;

  const WalletConnectSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(label, style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
      ),
    );
  }
}

/// Unified wallet info card container with configurable content.
class WalletConnectWalletInfoCard extends StatelessWidget {
  final List<Widget> children;

  const WalletConnectWalletInfoCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: context.coconutColors.surface,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

/// Fingerprint comparison card shown when a wallet mismatch is detected.
/// Displays the expected wallet's master fingerprint alongside the
/// currently connected device's master fingerprint.
class FingerprintCompareCard extends StatelessWidget {
  final String expectedFingerprint;
  final String connectedFingerprint;

  const FingerprintCompareCard({super.key, required this.expectedFingerprint, required this.connectedFingerprint});

  @override
  Widget build(BuildContext context) {
    return WalletConnectWalletInfoCard(
      children: [
        WalletConnectInfoRow(
          label: t.trezor_sign_screen.fingerprint_compare.expected,
          value: expectedFingerprint.toUpperCase(),
        ),
        CoconutLayout.spacing_300h,
        WalletConnectInfoRow(
          label: t.trezor_sign_screen.fingerprint_compare.connected,
          value: connectedFingerprint.toUpperCase(),
        ),
      ],
    );
  }
}

/// Wallet info card showing device name, fingerprint, derivation path, and xpub.
class HardwareWalletInfoCard extends StatelessWidget {
  final String deviceName;
  final String fingerprint;
  final String xpub;
  final String? deviceNameLabel;
  final String? fingerprintLabel;
  final String? derivationPathLabel;
  final String? xpubLabel;

  const HardwareWalletInfoCard({
    super.key,
    required this.deviceName,
    required this.fingerprint,
    required this.xpub,
    this.deviceNameLabel,
    this.fingerprintLabel,
    this.derivationPathLabel,
    this.xpubLabel,
  });

  @override
  Widget build(BuildContext context) {
    return WalletConnectWalletInfoCard(
      children: [
        if (deviceName.isNotEmpty) ...[
          WalletConnectInfoRow(
            label: deviceNameLabel ?? t.wallet_connect_screen.guide_trezor.paired.device_name,
            value: deviceName,
          ),
          CoconutLayout.spacing_300h,
        ],
        WalletConnectInfoRow(
          label: fingerprintLabel ?? t.wallet_connect_screen.guide_trezor.paired.master_fingerprint,
          value: fingerprint.toUpperCase(),
        ),
        CoconutLayout.spacing_300h,
        WalletConnectInfoRow(
          label: derivationPathLabel ?? t.wallet_connect_screen.guide_trezor.paired.derivation_path,
          value: NetworkType.currentNetworkType.isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'",
        ),
        CoconutLayout.spacing_300h,
        WalletConnectInfoRow(
          label: xpubLabel ?? t.wallet_connect_screen.guide_trezor.paired.xpub,
          value: xpub,
          direction: Axis.vertical,
        ),
      ],
    );
  }
}
