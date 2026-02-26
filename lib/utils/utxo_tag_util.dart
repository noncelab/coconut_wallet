import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/screens/common/tag_apply_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class UtxoTagUtil {
  static List<String> calculateUpdatedTags({
    required List<String> currentTagNames,
    required Map<String, TagApplyState> tagStates,
  }) {
    final Set<String> updatedTagsSet = currentTagNames.toSet();

    tagStates.forEach((tagName, state) {
      if (state == TagApplyState.checked) {
        updatedTagsSet.add(tagName);
      } else if (state == TagApplyState.unchecked) {
        updatedTagsSet.remove(tagName);
      }
    });

    return updatedTagsSet.toList();
  }

  static Future<void> handleTagApplyCompleted({
    required BuildContext context,
    required UtxoTagApplyEditMode mode,
    required Map<String, TagApplyState> tagStates,
    required int walletId,
    required List<String> selectedUtxoIds,
    required List<String> Function(String utxoId) getCurrentTagsCallback,
    required VoidCallback onRefreshUI,
    VoidCallback? onClearSelection,
  }) async {
    if (mode == UtxoTagApplyEditMode.add ||
        mode == UtxoTagApplyEditMode.update ||
        mode == UtxoTagApplyEditMode.delete) {
      onRefreshUI();
      return;
    }

    if (mode == UtxoTagApplyEditMode.changeAppliedTags) {
      final tagProvider = context.read<UtxoTagProvider>();

      await tagProvider.applyTagsToUtxos(
        walletId: walletId,
        selectedUtxoIds: selectedUtxoIds,
        tagStates: tagStates,
        getCurrentTagsCallback: getCurrentTagsCallback,
      );

      onRefreshUI();
      onClearSelection?.call();

      if (context.mounted) {
        CoconutToast.showToast(
          context: context,
          isVisibleIcon: true,
          iconPath: 'assets/svg/circle-info.svg',
          text: t.utxo_list_screen.utxo_tag_updated,
        );
      }
    }
  }
}
