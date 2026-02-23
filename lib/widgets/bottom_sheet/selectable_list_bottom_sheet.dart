import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';

typedef SelectableItemBuilder<T> = Widget Function(BuildContext context, T item, bool isSelected, VoidCallback? onTap);

class SelectableListBottomSheet<T> extends StatefulWidget {
  final String title; // AppBar 제목
  final List<T> items; // 보여줄 아이템 목록
  final Object? initiallySelectedId; // 초기 선택값 (없으면 null)
  final Object Function(T item) getItemId; // 아이템 식별자 추출
  final SelectableItemBuilder<T> itemBuilder; // 각 아이템을 그리는 빌더
  final Future<void> Function(T? selectedItem) onConfirm;
  // '선택' 버튼 눌렀을 때 호출 (선택된 아이템 넘겨줌, 없으면 null)

  final String confirmText; // 버튼 텍스트 (기본 '선택')
  final ScrollController? scrollController; // 필요 시 외부에서 컨트롤

  const SelectableListBottomSheet({
    super.key,
    required this.title,
    required this.items,
    this.initiallySelectedId,
    required this.getItemId,
    required this.itemBuilder,
    required this.onConfirm,
    required this.confirmText,
    this.scrollController,
  });

  @override
  State<SelectableListBottomSheet<T>> createState() => _SelectableListBottomSheetState<T>();
}

class _SelectableListBottomSheetState<T> extends State<SelectableListBottomSheet<T>> {
  Object? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initiallySelectedId;
  }

  @override
  void didUpdateWidget(covariant SelectableListBottomSheet<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallySelectedId != widget.initiallySelectedId) {
      setState(() {
        _selectedId = widget.initiallySelectedId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(title: widget.title, context: context, isBottom: true),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
              child: ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.only(bottom: Sizes.size96),
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final id = widget.getItemId(item);
                  final isSelected = _selectedId == id;

                  void handleTap() {
                    vibrateExtraLight();
                    setState(() {
                      if (_selectedId == id) {
                        _selectedId = null;
                      } else {
                        _selectedId = id;
                      }
                    });
                  }

                  return widget.itemBuilder(context, item, isSelected, handleTap);
                },
              ),
            ),
            FixedBottomButton(
              onButtonClicked: () async {
                final selectedItem =
                    _selectedId == null
                        ? null
                        : widget.items.firstWhere(
                          (item) => widget.getItemId(item) == _selectedId,
                          orElse: () => widget.items.first,
                        );

                await widget.onConfirm(_selectedId == null ? null : selectedItem);
              },
              isActive: _selectedId != null,
              text: widget.confirmText,
              backgroundColor: CoconutColors.white,
            ),
          ],
        ),
      ),
    );
  }
}
