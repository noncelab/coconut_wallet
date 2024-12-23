import 'package:coconut_wallet/model/utxo_tag.dart';
import 'package:coconut_wallet/screens/bottomsheet/tag_bottom_sheet_container.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_selector.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';

class UtxoTagScreen extends StatefulWidget {
  const UtxoTagScreen({super.key});

  @override
  State<UtxoTagScreen> createState() => _UtxoTagScreenState();
}

class _UtxoTagScreenState extends State<UtxoTagScreen> {
  final List<UtxoTag> _utxoTagList = [
    const UtxoTag(tag: 'coconut', colorIndex: 0, usedCount: 10),
    const UtxoTag(tag: 'keystone', colorIndex: 1, usedCount: 4),
    const UtxoTag(tag: 'strike', colorIndex: 5, usedCount: 8),
    const UtxoTag(tag: 'non-kyc', colorIndex: 7, usedCount: 18),
  ];

  UtxoTag? _selectedUtxoTag;

  @override
  Widget build(BuildContext context) {
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
                utxoTags: _utxoTagList,
                onComplete: (_, utxo) {
                  // TODO: 태그생성
                  print('create utxo -> $utxo');
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
              if (_selectedUtxoTag != null) ...{
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
                            type: TagBottomSheetType.manage,
                            utxoTags: _utxoTagList,
                            manageUtxoTag: _selectedUtxoTag,
                            onComplete: (_, utxo) {
                              // TODO: 태그편집
                              print('change utxo -> $utxo');
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
                              '#${_selectedUtxoTag?.tag}를 정말로 삭제하시겠어요?\n${_selectedUtxoTag?.usedCount}개 UTXO에 적용되어 있어요.',
                          onConfirm: () async {
                            // TODO: 태그삭제
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
                  tags: _utxoTagList,
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
  }
}
