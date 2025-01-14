import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/check_list.dart';

class SecuritySelfCheckBottomSheet extends StatefulWidget {
  final VoidCallback? onNextPressed;

  const SecuritySelfCheckBottomSheet({
    super.key,
    this.onNextPressed,
  });

  @override
  State<SecuritySelfCheckBottomSheet> createState() =>
      _SecuritySelfCheckBottomSheetState();
}

class _SecuritySelfCheckBottomSheetState
    extends State<SecuritySelfCheckBottomSheet> {
  final List<ChecklistItem> _items = [
    ChecklistItem(title: '나의 개인키는 내가 스스로 책임집니다.'),
    ChecklistItem(title: '니모닉 문구 화면을 캡처하거나 촬영하지 않습니다.'),
    ChecklistItem(title: '니모닉 문구를 네트워크와 연결된 환경에 저장하지 않습니다.'),
    ChecklistItem(title: '니모닉 문구의 순서와 단어의 철자를 확인합니다.'),
    ChecklistItem(title: '패스프레이즈에 혹시 의도하지 않은 문자가 포함되지는 않았는지 한번 더 확인합니다.'),
    ChecklistItem(title: '니모닉 문구와 패스프레이즈는 아무도 없는 안전한 곳에서 확인합니다.'),
    ChecklistItem(title: '니모닉 문구와 패스프레이즈를 함께 보관하지 않습니다.'),
    ChecklistItem(title: '소액으로 보내기 테스트를 한 후 지갑 사용을 시작합니다.'),
    ChecklistItem(title: '위 사항을 주기적으로 점검하고, 안전하게 니모닉 문구를 보관하겠습니다.'),
  ];

  // bool get _allItemsChecked {
  //   return _items.every((item) => item.isChecked);
  // }

  void _onChecklistItemChanged(bool? value, int index) {
    setState(() {
      _items[index].isChecked = value ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.black,
      appBar: CustomAppBar.build(
        title: '셀프 보안 점검',
        context: context,
        onBackPressed: null,
        hasRightIcon: false,
        isBottom: true,
        showTestnetLabel: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecorations.boxDecoration,
                    child: Text(
                      '아래 점검 항목을 숙지하고 비트코인을 반드시 안전하게 보관합니다.',
                      style: Styles.subLabel.merge(const TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.white)),
                    )),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  const double itemHeight = 40.0;
                  final double totalHeight = _items.length * itemHeight;
                  final bool needScrolling =
                      totalHeight > constraints.maxHeight;

                  return needScrolling
                      ? SingleChildScrollView(
                          child: Column(
                            children: _items.asMap().entries.map((entry) {
                              int index = entry.key;
                              ChecklistItem item = entry.value;
                              return ChecklistTile(
                                item: item,
                                onChanged: (bool? value) {
                                  _onChecklistItemChanged(value, index);
                                },
                              );
                            }).toList(),
                          ),
                        )
                      : Column(
                          children: _items.asMap().entries.map((entry) {
                            int index = entry.key;
                            ChecklistItem item = entry.value;
                            return ChecklistTile(
                              item: item,
                              onChanged: (bool? value) {
                                _onChecklistItemChanged(value, index);
                              },
                            );
                          }).toList(),
                        );
                },
              )
            ]),
          ),
        ),
      ),
    );
  }
}
