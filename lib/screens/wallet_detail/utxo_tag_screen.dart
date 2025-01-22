import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/overlays/tag_bottom_sheet.dart';
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
            title: '태그 관리',
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
                    utxoTags: model.tagList,
                    onUpdated: (utxoTag) {
                      if (!model.addUtxoTag(id, utxoTag)) {
                        CustomToast.showWarningToast(
                          context: context,
                          text: '태그 추가에 실패 했습니다.',
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
                  if (model.tagList.isEmpty == true) ...{
                    const SizedBox(height: 56),
                    Text(
                      '태그가 없어요',
                      style: Styles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '+ 버튼을 눌러 태그를 추가해 보세요',
                      style: Styles.body2
                          .copyWith(fontSize: 13, color: MyColors.gray200),
                    ),
                  },
                  if (model.selectedUtxoTag != null) ...{
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CustomUnderlinedButton(
                          text: '편집',
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) => TagBottomSheet(
                                type: TagBottomSheetType.update,
                                utxoTags: model.tagList,
                                updateUtxoTag: model.selectedUtxoTag,
                                onUpdated: (utxoTag) {
                                  if (!model.updateUtxoTag(id, utxoTag)) {
                                    CustomToast.showWarningToast(
                                      context: context,
                                      text: '태그 편집에 실패 했습니다.',
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
                          text: '삭제',
                          onTap: () {
                            CustomDialogs.showCustomAlertDialog(
                              context,
                              title: '태그 삭제',
                              message:
                                  '#${model.selectedUtxoTag?.name}를 정말로 삭제하시겠어요?\n${model.selectedUtxoTag?.utxoIdList?.isNotEmpty == true ? '${model.selectedUtxoTag?.utxoIdList?.length}개 UTXO에 적용되어 있어요.' : ''}',
                              onConfirm: () {
                                if (model.deleteUtxoTag(id)) {
                                  Navigator.of(context).pop();
                                } else {
                                  CustomToast.showWarningToast(
                                    context: context,
                                    text: '태그 삭제에 실패 했습니다.',
                                  );
                                }
                              },
                              onCancel: () {
                                Navigator.of(context).pop();
                              },
                              confirmButtonText: '삭제하기',
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
                      tags: model.tagList,
                      externalUpdatedTagName: model.updatedTagName,
                      onSelectedTag: model.setSelectedUtxoTag,
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
