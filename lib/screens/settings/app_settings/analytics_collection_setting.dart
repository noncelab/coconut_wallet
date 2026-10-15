import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutToast, CoconutToastLevel;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AnalyticsCollectionSetting extends StatelessWidget {
  const AnalyticsCollectionSetting({super.key});

  Future<void> _update(BuildContext context, AnalyticsService analytics, bool enabled) async {
    try {
      await analytics.setCollectionEnabled(enabled);
    } catch (_) {
      if (!context.mounted) return;
      CoconutToast.showToast(
        context: context,
        text: context.t.settings_screen.analytics_collection_error,
        level: CoconutToastLevel.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalyticsService>(
      builder: (context, analytics, _) {
        final colors = context.coconutColors;
        final t = context.t;
        return SingleButton(
          title: t.settings_screen.analytics_collection,
          subtitle: t.settings_screen.analytics_collection_description,
          isVerticalSubtitle: true,
          rightElement: Semantics(
            label: t.settings_screen.analytics_collection,
            toggled: analytics.isCollectionEnabled,
            enabled: !analytics.isUpdating,
            onTap: analytics.isUpdating ? null : () => _update(context, analytics, !analytics.isCollectionEnabled),
            child: ExcludeSemantics(
              child: IgnorePointer(
                ignoring: analytics.isUpdating,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: CoconutSwitch(
                    isOn: analytics.isCollectionEnabled,
                    activeTrackColor: colors.switchActiveTrack,
                    activeThumbColor: colors.switchActiveThumb,
                    inactiveTrackColor: colors.switchInactiveTrack,
                    inactiveThumbColor: colors.switchInactiveThumb,
                    onChanged: (enabled) => _update(context, analytics, enabled),
                    scale: 0.75,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
