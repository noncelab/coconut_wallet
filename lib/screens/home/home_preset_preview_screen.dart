import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_preset.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 프리셋을 적용했을 때의 홈을 실제 홈 그리드로 보여 준다. [홈에 적용]을 누르면 true로 닫힌다.
class HomePresetPreviewScreen extends StatelessWidget {
  /// 마지막 위젯이 [홈에 적용] 버튼과 그 뒤 그라데이션에 가리지 않도록 남기는 아래 여백
  static const bottomSpace = 120.0;

  final HomePreset preset;

  const HomePresetPreviewScreen({super.key, required this.preset});

  static Future<bool> open(BuildContext context, HomePreset preset) async {
    final homeViewModel = context.read<HomeViewModel>();
    final widgetsViewModel = context.read<HomeWidgetsViewModel?>();
    final applied = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        settings: RouteSettings(name: '/home-preset-preview/${preset.id}'),
        builder:
            (_) => MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: homeViewModel),
                if (widgetsViewModel != null) ChangeNotifierProvider.value(value: widgetsViewModel),
              ],
              child: HomePresetPreviewScreen(preset: preset),
            ),
      ),
    );
    return applied ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final viewModel = context.watch<HomeViewModel>();
    return Scaffold(
      backgroundColor: colors.homeBackground,
      appBar: CoconutAppBar.build(context: context, backgroundColor: colors.homeBackground, title: preset.name()),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const Key('home-preset-preview-scroll'),
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.paddingOf(context).bottom + bottomSpace),
            child: IgnorePointer(
              child: HomeItemsView(configuration: viewModel.previewOf(preset), registry: viewModel.registry),
            ),
          ),
          FixedBottomButton(
            buttonKey: const Key('home-preset-preview-apply'),
            text: t.home_presets.apply,
            isVisibleAboveKeyboard: false,
            surroundingsColor: colors.homeBackground,
            onButtonClicked: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
