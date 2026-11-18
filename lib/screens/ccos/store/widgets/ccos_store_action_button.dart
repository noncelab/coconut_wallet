import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ccos_store_view_model.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';

/// 추가 전이면 누를 수 있는 "추가", 추가 뒤에는 같은 모양의 상태 표시
class CcosStoreActionButton extends StatelessWidget {
  const CcosStoreActionButton({super.key, required this.state, required this.onAdd, this.onSurface = false});

  final CcosStoreItemState state;
  final VoidCallback onAdd;
  final bool onSurface;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final label = switch (state) {
      CcosStoreItemState.notAdded => t.ccos.store.add,
      CcosStoreItemState.added => t.ccos.store.added,
      CcosStoreItemState.applied => t.ccos.store.applied,
    };
    final text = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        label,
        style: CoconutTypography.body2_14_Bold.setColor(
          state == CcosStoreItemState.notAdded ? colors.primaryText : colors.secondaryText,
        ),
      ),
    );
    final background = onSurface ? colors.surfaceButtonOnSurface : colors.surfaceButton;
    if (state != CcosStoreItemState.notAdded) {
      return Container(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
        child: text,
      );
    }
    return ShrinkAnimationButton(
      onPressed: onAdd,
      defaultColor: background,
      pressedOverlayColor: colors.surfacePressOverlay,
      borderRadius: 16,
      borderWidth: 0,
      child: text,
    );
  }
}
