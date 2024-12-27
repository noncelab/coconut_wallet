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

/// [id] - wallet id 기반으로 태그 관리
class UtxoTagScreen extends StatefulWidget {
  final int id;
  const UtxoTagScreen({super.key, required this.id});

  @override
  State<UtxoTagScreen> createState() => _UtxoTagScreenState();
}

class _UtxoTagScreenState extends State<UtxoTagScreen> {
  /// UtxoTag 가져오기, 추가, 편집, 삭제 메소드 호출
  late AppStateModel _appModel;

  /// CustomTagSelector 에서 사용자가 선택하여 콜백 반환 된 UtxoTag
  UtxoTag? _selectedUtxoTag;

  /// 태그 편집 바텀시트에서 변경된 UtxoTag name
  /// - CustomTagSelector 상태 업데이트
  String? _updateUtxoTagName;

  @override
  void initState() {
    super.initState();
    _appModel = Provider.of<AppStateModel>(context, listen: false);
    _appModel.loadUtxoTagListWithWalletId(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppStateModel, List<UtxoTag>>(
      selector: (_, model) => model.utxoTagList,
      builder: (context, utxoTagList, child) {
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
                    utxoTags: utxoTagList,
                    onUpdated: (utxoTag) {
                      final createUTag = utxoTag.copyWith(walletId: widget.id);
                      _appModel.addUtxoTag(createUTag);
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
                  if (utxoTagList.isEmpty) ...{
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
                  if (utxoTagList.isNotEmpty && _selectedUtxoTag != null) ...{
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
                                utxoTags: utxoTagList,
                                updateUtxoTag: _selectedUtxoTag,
                                onUpdated: (utxoTag) {
                                  if (_selectedUtxoTag?.name.isNotEmpty ==
                                      true) {
                                    _appModel.updateUtxoTag(utxoTag);
                                    setState(() {
                                      _updateUtxoTagName = utxoTag.name;
                                      _selectedUtxoTag =
                                          _selectedUtxoTag?.copyWith(
                                        name: utxoTag.name,
                                        colorIndex: utxoTag.colorIndex,
                                        utxoIdList: utxoTag.utxoIdList ?? [],
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
                                  '#${_selectedUtxoTag?.name}를 정말로 삭제하시겠어요?'
                                  '\n${_selectedUtxoTag?.utxoIdList?.isNotEmpty == true ? '${_selectedUtxoTag?.utxoIdList?.length}개 UTXO에 적용되어 있어요.' : ''}',
                              onConfirm: () async {
                                if (_selectedUtxoTag != null) {
                                  _appModel.deleteUtxoTag(_selectedUtxoTag!);
                                  Navigator.of(context).pop();
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
                      tags: utxoTagList,
                      externalUpdatedTagName: _updateUtxoTagName,
                      onSelectedTag: (tag) {
                        setState(() {
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
