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
              return SingleButton(
                title: t.settings_screen.analytics_collection,
                subtitle: t.settings_screen.analytics_collection_description,
                isVerticalSubtitle: true,
                wrapsText: true,
                rightElement: Semantics(
                  label: t.settings_screen.analytics_collection,
                  toggled: isCollectionEnabled,
                  enabled: !viewModel.isSaving,
                  onTap: viewModel.isSaving ? null : () => _update(context, viewModel, !isCollectionEnabled),
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      ignoring: viewModel.isSaving,
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
            },
          );
        },
      ),
    );
  }
}
