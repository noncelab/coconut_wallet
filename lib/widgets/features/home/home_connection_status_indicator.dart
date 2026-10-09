import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeConnectionStatusIndicator extends StatelessWidget {
  final NetworkStatus networkStatus;
  final bool showReconnected;
  final bool isSyncing;

  const HomeConnectionStatusIndicator({
    super.key,
    required this.networkStatus,
    required this.showReconnected,
    required this.isSyncing,
  });

  static String errorMessage(NetworkStatus networkStatus) {
    return switch (networkStatus) {
      NetworkStatus.offline => t.errors.network_disconnected,
      NetworkStatus.connectionFailed => t.home_connection_status.electrum_connection_failed,
      NetworkStatus.vpnBlocked => t.errors.vpn_connected,
      NetworkStatus.online => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final showingError = networkStatus != NetworkStatus.online;

    final Widget child;
    if (showingError) {
      child = _row(
        context,
        key: 'error',
        leading: SvgPicture.asset(FeatureConnectivityIconPath.cloudDisconnected, width: 16),
        message: errorMessage(networkStatus),
        color: colors.danger,
      );
    } else if (showReconnected) {
      child = _row(
        context,
        key: 'reconnected',
        leading: SvgPicture.asset(
          CommonFormIconPath.circleCheck,
          width: 16,
          colorFilter: ColorFilter.mode(colors.success, BlendMode.srcIn),
        ),
        message: t.home_connection_status.electrum_connection_restored,
        color: colors.success,
      );
    } else if (isSyncing) {
      child = _row(
        context,
        key: 'syncing',
        leading: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.secondaryText),
        ),
        message: t.status_updating,
        color: colors.secondaryText,
      );
    } else {
      child = const SizedBox.shrink(key: ValueKey('empty'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: child,
    );
  }

  Widget _row(
    BuildContext context, {
    required String key,
    required Widget leading,
    required String message,
    required Color color,
  }) {
    return Row(
      key: ValueKey(key),
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        CoconutLayout.spacing_150w,
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(message, maxLines: 1, style: CoconutTypography.body3_12_Bold.copyWith(color: color)),
          ),
        ),
      ],
    );
  }
}
