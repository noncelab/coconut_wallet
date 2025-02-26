import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:coconut_wallet/screens/common/tag_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_vertical_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UtxoTagScreen extends StatelessWidget {
  final int id;
  const UtxoTagScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Consumer<UtxoTagProvider>(
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: MyColors.black,
          appBar: CustomAppBar.build(
            title: t.tag_manage,
            context: context,
            hasRightIcon: true,
            showTestnetLabel: false,
            onBackPressed: () {
              Navigator.pop(context);
            },
            rightIconButton: IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => TagBottomSheet(
                    type: TagBottomSheetType.create,
                    utxoTags: model.utxoTags,
                    onUpdated: (utxoTag) {
                      if (!model.addUtxoTag(id, utxoTag)) {
                        CustomToast.showWarningToast(
                          context: context,
                          text: t.toast.tag_add_failed,
                        );
                      }
                    },
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              color: MyColors.white,
            ),
          ),
          body: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (model.utxoTags.isEmpty == true) ...{
                    const SizedBox(height: 56),
                    Text(
                      t.utxo_tag_screen.no_such_tag,
                      style: Styles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.utxo_tag_screen.add_tag,
                      style: Styles.body2
                          .copyWith(fontSize: 13, color: MyColors.gray200),
                    ),
                  },
                  if (model.selectedUtxoTag != null) ...{
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CustomUnderlinedButton(
                          text: t.edit,
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) => TagBottomSheet(
                                type: TagBottomSheetType.update,
                                utxoTags: model.utxoTags,
                                updateUtxoTag: model.selectedUtxoTag,
                                onUpdated: (utxoTag) {
                                  if (!model.updateUtxoTag(id, utxoTag)) {
                                    CustomToast.showWarningToast(
                                      context: context,
                                      text: t.toast.tag_update_failed,
                                    );
                                  }
                                },
                              ),
                            );
                          },
                          padding: const EdgeInsets.all(0),
                        ),
                        const SizedBox(width: 12),
                        CustomUnderlinedButton(
                          text: t.delete,
                          onTap: () {
                            CustomDialogs.showCustomAlertDialog(
                              context,
                              title: t.alert.tag_delete.title,
                              message: model.selectedUtxoTag?.utxoIdList
                                          ?.isNotEmpty ==
                                      true
                                  ? t.alert.tag_delete.description_utxo_tag(
                                      name: model.selectedUtxoTag!.name,
                                      count: model.selectedUtxoTag?.utxoIdList!
                                              .length ??
                                          0)
                                  : t.alert.tag_delete.description(
                                      name: model.selectedUtxoTag!.name),
                              onConfirm: () {
                                if (model.deleteUtxoTag(id)) {
                                  Navigator.of(context).pop();
                                } else {
                                  CustomToast.showWarningToast(
                                    context: context,
                                    text: t.toast.tag_delete_failed,
                                  );
                                }
                              },
                              onCancel: () {
                                Navigator.of(context).pop();
                              },
                              confirmButtonText: t.delete,
                              confirmButtonColor: MyColors.warningRed,
                            );
                          },
                          padding: const EdgeInsets.all(0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  } else ...{
                    const SizedBox(height: 23.5),
                  },
                  Expanded(
                    child: CustomTagVerticalSelector(
                      tags: model.utxoTags,
                      externalUpdatedTagName: model.updatedTagName,
                      onSelectedTag: model.selectUtxoTag,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
