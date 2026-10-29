import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutToast, CoconutToastLevel;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/settings/analytics_collection_setting_view_model.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AnalyticsCollectionSetting extends StatelessWidget {
  const AnalyticsCollectionSetting({super.key});

  Future<void> _update(BuildContext context, AnalyticsCollectionSettingViewModel viewModel, bool enabled) async {
    if (await viewModel.setCollectionEnabled(enabled) || !context.mounted) return;
    CoconutToast.showToast(
      context: context,
      text: context.t.settings_screen.analytics_collection_error,
      level: CoconutToastLevel.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AnalyticsCollectionSettingViewModel(context.read<AnalyticsService>()),
      child: Consumer<AnalyticsCollectionSettingViewModel>(
        builder: (context, viewModel, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: viewModel.isCollectionEnabled,
            builder: (context, isCollectionEnabled, _) {
              final colors = context.coconutColors;
              final t = context.t;
              final canToggle = !viewModel.isSaving && !(viewModel.disablePending && !isCollectionEnabled);
              final setting = SingleButton(
                title: t.settings_screen.analytics_collection,
                subtitle: t.settings_screen.analytics_collection_description,
                isVerticalSubtitle: true,
                wrapsText: true,
                rightElement: Semantics(
                  label: t.settings_screen.analytics_collection,
                  toggled: isCollectionEnabled,
                  enabled: canToggle,
                  onTap: canToggle ? () => _update(context, viewModel, !isCollectionEnabled) : null,
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      ignoring: !canToggle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: CoconutSwitch(
                          isOn: isCollectionEnabled,
                          activeTrackColor: colors.switchActiveTrack,
                          activeThumbColor: colors.switchActiveThumb,
                          inactiveTrackColor: colors.switchInactiveTrack,
                          inactiveThumbColor: colors.switchInactiveThumb,
                          onChanged: (enabled) => _update(context, viewModel, enabled),
                          scale: 0.75,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              if (!viewModel.hasError) return setting;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  setting,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            t.settings_screen.analytics_collection_apply_error,
                            style: CoconutTypography.body2_14.setColor(colors.dangerText),
                          ),
                        ),
                        if (viewModel.disablePending)
                          Semantics(
                            button: true,
                            enabled: !viewModel.isSaving,
                            child: SingleButton(
                              title: t.settings_screen.analytics_collection_retry_disable,
                              titleStyle: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
                              wrapsText: true,
                              customPadding: const EdgeInsets.symmetric(vertical: 12),
                              onPressed: viewModel.isSaving ? null : () => _update(context, viewModel, false),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
