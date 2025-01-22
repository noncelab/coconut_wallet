import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_tag_view_model.dart';
import 'package:coconut_wallet/repository/wallet_data_manager.dart';
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
    return ChangeNotifierProvider(
      create: (_) => UtxoTagViewModel(id, WalletDataManager()),
      child: Consumer<UtxoTagViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: MyColors.black,
            appBar: CustomAppBar.build(
              title: '태그 관리',
              context: context,
              hasRightIcon: true,
              showTestnetLabel: false,
              onBackPressed: () {
                Navigator.pop(context, viewModel.isUpdatedTagList);
              },
              rightIconButton: IconButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => TagBottomSheet(
                      type: TagBottomSheetType.create,
                      utxoTags: viewModel.utxoTagList,
                      onUpdated: (utxoTag) {
                        if (!viewModel.addUtxoTag(utxoTag)) {
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
                    if (viewModel.utxoTagList.isEmpty) ...{
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
                    if (viewModel.selectedUtxoTag != null) ...{
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
                                  utxoTags: viewModel.utxoTagList,
                                  updateUtxoTag: viewModel.selectedUtxoTag,
                                  onUpdated: (utxoTag) {
                                    if (!viewModel.updateUtxoTag(utxoTag)) {
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
                                message: viewModel.getDeleteMessage(),
                                onConfirm: () {
                                  if (viewModel.deleteUtxoTag()) {
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
                        tags: viewModel.utxoTagList,
                        externalUpdatedTagName: viewModel.updatedTagName,
                        onSelectedTag: viewModel.setSelectedUtxoTag,
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
}
