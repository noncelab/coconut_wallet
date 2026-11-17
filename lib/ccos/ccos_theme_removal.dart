import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ccos_store_view_model.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 적용 중인 코코넛 테마 제거 확인. 취소하면 false
Future<bool> confirmCoconutThemeRemoval(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => CoconutPopup(
              languageCode: context.read<PreferenceProvider>().language,
              title: t.ccos.intro_screen.delete_popup_title,
              description: t.ccos.intro_screen.delete_popup_description,
              leftButtonText: t.cancel,
              rightButtonText: t.delete,
              onTapLeft: () => Navigator.pop(dialogContext, false),
              onTapRight: () => Navigator.pop(dialogContext, true),
            ),
      ) ??
      false;
}

/// 코코넛 테마 제거. 적용 중이면 확인 후 다크 테마로 바꿈. 취소하면 false
Future<bool> removeCoconutThemeWithConfirm(BuildContext context) async {
  final viewModel = CcosStoreViewModel(context.read<PreferenceProvider>());
  try {
    if (viewModel.needsRemoveConfirm(CoconutThemeFeature.id) && !await confirmCoconutThemeRemoval(context)) {
      return false;
    }
    await viewModel.remove(CoconutThemeFeature.id);
  } finally {
    viewModel.dispose();
  }
  if (!context.mounted) return true;
  CoconutToast.showToast(
    context: context,
    text: t.ccos.intro_screen.theme_removed,
    isVisibleIcon: true,
    iconPath: CommonStateIconPath.circleInfo,
  );
  return true;
}
