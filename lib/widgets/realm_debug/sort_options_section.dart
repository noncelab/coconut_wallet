import 'package:coconut_wallet/providers/view_model/settings/realm_debug_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 정렬 옵션 섹션 위젯
class SortOptionsSection extends StatelessWidget {
  final TextEditingController queryController;

  const SortOptionsSection({
    super.key,
    required this.queryController,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RealmDebugViewModel>(
      builder: (context, viewModel, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSortToggle(context, viewModel),
              if (viewModel.enableSort) ...[
                const SizedBox(height: 8),
                _buildSortControls(context, viewModel),
                const SizedBox(height: 8),
                _buildQueryPreview(context, viewModel),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortToggle(BuildContext context, RealmDebugViewModel viewModel) {
    return Row(
      children: [
        const Text(
          '정렬 옵션',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Switch(
          value: viewModel.enableSort,
          onChanged: (value) => viewModel.toggleSortEnabled(value),
        ),
      ],
    );
  }

  Widget _buildSortControls(BuildContext context, RealmDebugViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 정렬 활성화/비활성화 스위치
        SwitchListTile(
          title: const Text('정렬 사용'),
          value: viewModel.enableSort,
          onChanged: viewModel.isLoading ? null : viewModel.toggleSortEnabled,
          dense: true,
        ),

        if (viewModel.enableSort) ...[
          const SizedBox(height: 8),

          // 정렬 필드 선택
          Row(
            children: [
              const Text('정렬 기준: '),
              Expanded(
                child: DropdownButton<String>(
                  value:
                      viewModel.selectedSortField.isNotEmpty ? viewModel.selectedSortField : null,
                  hint: const Text('필드 선택'),
                  isExpanded: true,
                  items: viewModel.getSortableFields().map((field) {
                    return DropdownMenuItem(
                      value: field,
                      child: Text(field),
                    );
                  }).toList(),
                  onChanged: viewModel.isLoading
                      ? null
                      : (value) {
                          if (value != null) {
                            viewModel.changeSortField(value);
                          }
                        },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 정렬 방향 선택
          Row(
            children: [
              const Text('정렬 방향: '),
              ToggleButtons(
                isSelected: [!viewModel.sortDescending, viewModel.sortDescending],
                onPressed: viewModel.isLoading
                    ? null
                    : (index) {
                        viewModel.changeSortDirection(index == 1);
                      },
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('오름차순'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('내림차순'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 쿼리 프리뷰
          _buildQueryPreview(context, viewModel),
        ],
      ],
    );
  }

  Widget _buildQueryPreview(BuildContext context, RealmDebugViewModel viewModel) {
    return Text(
      '최종 쿼리: ${viewModel.buildFinalQuery(queryController.text.trim().isEmpty ? 'TRUEPREDICATE' : queryController.text)}',
      style: TextStyle(
        fontSize: 11,
        fontFamily: 'monospace',
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
