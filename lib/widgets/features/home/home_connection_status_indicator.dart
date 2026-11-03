import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeConnectionStatusIndicator extends StatelessWidget {
  static const _iconSize = 16.0;
  static const _textOpticalOffsetY = -0.7;

  final NetworkStatus networkStatus;
  final bool showReconnected;
  final bool isSyncing;
  final bool showUpdateCompleted;

  const HomeConnectionStatusIndicator({
    super.key,
    required this.networkStatus,
    required this.showReconnected,
    required this.isSyncing,
    this.showUpdateCompleted = false,
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
        leading: _icon(FeatureConnectivityIconPath.cloudDisconnected, colors.dangerText),
        message: errorMessage(networkStatus),
        color: colors.dangerText,
      );
    } else if (showReconnected) {
      child = _row(
        context,
        key: 'reconnected',
        leading: _icon(CommonFormIconPath.circleCheck, colors.success),
        message: t.home_connection_status.electrum_connection_restored,
        color: colors.success,
      );
    } else if (isSyncing) {
      child = _row(
        context,
        key: 'syncing',
        leading: SizedBox.square(
          dimension: _iconSize,
          child: Center(
            child: SizedBox.square(
              dimension: _iconSize * 20 / 24,
              child: CircularProgressIndicator(
                strokeWidth: _iconSize * 2 / 24,
                strokeAlign: CircularProgressIndicator.strokeAlignInside,
                color: colors.secondaryText,
              ),
            ),
          ),
        ),
        message: t.status_updating,
        color: colors.secondaryTextStrong,
      );
    } else if (showUpdateCompleted) {
      child = _row(
        context,
        key: 'update-completed',
        leading: _icon(CommonFormIconPath.circleCheck, colors.success),
        message: t.home_connection_status.update_completed,
        color: colors.success,
      );
    } else {
      child = const SizedBox.shrink(key: ValueKey('empty'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      layoutBuilder:
          (currentChild, previousChildren) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previousChildren, if (currentChild != null) currentChild],
          ),
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
        CoconutLayout.spacing_100w,
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: const Offset(0, _textOpticalOffsetY),
              child: Text(
                message,
                maxLines: 1,
                style: CoconutTypography.body3_12_Bold.copyWith(
                  color: color,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _icon(String path, Color color) => SizedBox.square(
    dimension: _iconSize,
    child: Center(
      child: SvgPicture.asset(
        path,
        width: _iconSize,
        height: _iconSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    ),
  );
}
