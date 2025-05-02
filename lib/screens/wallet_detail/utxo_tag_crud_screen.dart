import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_tag_crud_view_model.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/screens/common/tag_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_vertical_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UtxoTagCrudScreen extends StatelessWidget {
  final int id;
  const UtxoTagCrudScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UtxoTagCrudViewModel>(
      create: (context) => UtxoTagCrudViewModel(
        Provider.of<UtxoTagProvider>(context, listen: false),
        id,
      ),
      child: Consumer<UtxoTagCrudViewModel>(
        builder: (context, model, child) {
          return Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: CoconutAppBar.build(
                title: t.tag_manage,
                context: context,
                onBackPressed: () {
                  Navigator.pop(context);
                },
                actionButtonList: [
                  IconButton(
                    onPressed: () {
                      _handleAddTagPressed(context, model);
                    },
                    icon: const Icon(Icons.add_rounded),
                    color: CoconutColors.white,
                  ),
                ]),
            body: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (model.utxoTagList.isEmpty) _buildEmptyView(context),
                    _buildEditButtons(context, model),
                    Expanded(
                      child: CustomTagVerticalSelector(
                        key: ValueKey(model.utxoTagList.map((e) => e.name).join(':')),
                        tags: model.utxoTagList,
                        externalUpdatedTagName: model.updatedTagName,
                        onSelectedTag: model.toggleUtxoTag,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    return Column(
      children: [
        CoconutLayout.spacing_900h,
        const SizedBox(height: 56),
        Text(
          t.utxo_tag_screen.no_such_tag,
          style: CoconutTypography.body1_16_Bold,
        ),
        CoconutLayout.spacing_200h,
        Text(
          t.utxo_tag_screen.add_tag,
          style: CoconutTypography.body2_14.copyWith(color: CoconutColors.gray350),
        ),
      ],
    );
  }

  Widget _buildEditButtons(BuildContext context, UtxoTagCrudViewModel model) {
    debugPrint('${model.selectedUtxoTag == null}');
    if (model.selectedUtxoTag == null) return CoconutLayout.spacing_600h;
    return Column(children: [
      CoconutLayout.spacing_300h,
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CustomUnderlinedButton(
            text: t.edit,
            onTap: () {
              _handleEditTagPressed(context, model);
            },
            padding: const EdgeInsets.all(0),
          ),
          CoconutLayout.spacing_300w,
          CustomUnderlinedButton(
            text: t.delete,
            onTap: () {
              _handeDeleteTagPressed(context, model);
            },
            padding: const EdgeInsets.all(0),
          ),
        ],
      ),
      CoconutLayout.spacing_300h,
    ]);
  }

  void _handeDeleteTagPressed(BuildContext context, UtxoTagCrudViewModel model) {
    CustomDialogs.showCustomAlertDialog(
      context,
      title: t.alert.tag_delete.title,
      message: model.selectedUtxoTag?.utxoIdList?.isNotEmpty == true
          ? t.alert.tag_delete.description_utxo_tag(
              name: model.selectedUtxoTag!.name,
              count: model.selectedUtxoTag?.utxoIdList!.length ?? 0)
          : t.alert.tag_delete.description(name: model.selectedUtxoTag!.name),
      onConfirm: () {
        if (model.deleteUtxoTag()) {
          Navigator.of(context).pop();
        } else {
          CoconutToast.showWarningToast(
            context: context,
            text: t.toast.tag_delete_failed,
          );
        }
      },
      onCancel: () {
        Navigator.of(context).pop();
      },
      confirmButtonText: t.delete,
      confirmButtonColor: CoconutColors.hotPink,
    );
  }

  void _handleEditTagPressed(BuildContext context, UtxoTagCrudViewModel model) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TagBottomSheet(
        type: TagBottomSheetType.update,
        utxoTags: model.utxoTagList,
        updateUtxoTag: model.selectedUtxoTag,
        onUpdated: (utxoTag) {
          final success = model.updateUtxoTag(utxoTag);
          if (!success) {
            CoconutToast.showWarningToast(
              context: context,
              text: t.toast.tag_update_failed,
            );
          }
        },
      ),
    );
  }

  void _handleAddTagPressed(BuildContext context, UtxoTagCrudViewModel model) {
    model.deselectUtxoTag();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TagBottomSheet(
        type: TagBottomSheetType.create,
        utxoTags: model.utxoTagList,
        onUpdated: (utxoTag) {
          if (!model.addUtxoTag(utxoTag)) {
            CoconutToast.showWarningToast(
              context: context,
              text: t.toast.tag_add_failed,
            );
          }
        },
      ),
    );
  }
}
