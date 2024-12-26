import 'package:coconut_wallet/model/utxo_tag.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/screens/bottomsheet/tag_bottom_sheet_container.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_selector.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:provider/provider.dart';

class UtxoTagScreen extends StatefulWidget {
  final int id;
  const UtxoTagScreen({super.key, required this.id});

  @override
  State<UtxoTagScreen> createState() => _UtxoTagScreenState();
}

class _UtxoTagScreenState extends State<UtxoTagScreen> {
  UtxoTag? _selectedUtxoTag;
  String? _changeUtxoTagName;

  @override
  void initState() {
    super.initState();
    final model = Provider.of<AppStateModel>(context, listen: false);
    model.loadUtxoTagListWithWalletId(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateModel>(
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: MyColors.black,
          appBar: CustomAppBar.build(
            title: '태그 관리',
            context: context,
            hasRightIcon: true,
            showTestnetLabel: false,
            rightIconButton: IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => TagBottomSheetContainer(
                    type: TagBottomSheetType.create,
                    utxoTags: model.utxoTagList,
                    onUpdated: (createUtxoTag) {
                      model.addUtxoTag(
                        walletId: widget.id,
                        name: createUtxoTag?.name ?? '',
                        colorIndex: createUtxoTag?.colorIndex ?? 0,
                      );
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
                  if (model.utxoTagList.isEmpty) ...{
                    const SizedBox(height: 56),
                    Text(
                      '태그가 없어요',
                      style: Styles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '+ 버튼을 눌러 태그를 추가해 보세요',
                      style: Styles.body2
                          .copyWith(fontSize: 12, color: MyColors.gray200),
                    ),
                  },
                  if (model.utxoTagList.isNotEmpty &&
                      _selectedUtxoTag != null) ...{
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CustomUnderlinedButton(
                          text: '편집',
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) => TagBottomSheetContainer(
                                type: TagBottomSheetType.update,
                                utxoTags: model.utxoTagList,
                                updateUtxoTag: _selectedUtxoTag,
                                onUpdated: (updatedUtxoTag) {
                                  if (_selectedUtxoTag?.name.isNotEmpty ==
                                      true) {
                                    model.updateUtxoTag(
                                      id: updatedUtxoTag?.id ?? '',
                                      walletId: updatedUtxoTag?.walletId ?? 0,
                                      name: updatedUtxoTag?.name ?? '',
                                      colorIndex:
                                          updatedUtxoTag?.colorIndex ?? 0,
                                      utxoIdList:
                                          updatedUtxoTag?.utxoIdList ?? [],
                                    );

                                    setState(() {
                                      _changeUtxoTagName = updatedUtxoTag?.name;
                                      _selectedUtxoTag =
                                          _selectedUtxoTag?.copyWith(
                                        name: updatedUtxoTag?.name,
                                        colorIndex:
                                            updatedUtxoTag?.colorIndex ?? 0,
                                        utxoIdList:
                                            updatedUtxoTag?.utxoIdList ?? [],
                                      );
                                    });
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
                                  '#${_selectedUtxoTag?.name}를 정말로 삭제하시겠어요?\n${_selectedUtxoTag?.utxoIdList?.isNotEmpty == true ? '${_selectedUtxoTag?.utxoIdList?.length}개 UTXO에 적용되어 있어요.' : ''}',
                              onConfirm: () async {
                                if (_selectedUtxoTag?.name.isNotEmpty == true) {
                                  model.deleteUtxoTag(
                                    _selectedUtxoTag!.id,
                                    _selectedUtxoTag!.walletId,
                                  );
                                  Navigator.of(context).pop();

                                  setState(() {
                                    _selectedUtxoTag = null;
                                    _changeUtxoTagName = null;
                                  });
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
                  },
                  Expanded(
                    child: CustomTagSelector(
                      tags: model.utxoTagList,
                      externalUpdatedTagName: _changeUtxoTagName,
                      onSelectedTag: (tag) {
                        setState(() {
                          _changeUtxoTagName = tag.name;
                          _selectedUtxoTag = tag;
                        });
                      },
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
