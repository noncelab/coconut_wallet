import 'package:coconut_wallet/providers/view_model/settings/realm_debug_view_model.dart';
import 'package:coconut_wallet/widgets/realm_debug/sort_options_section.dart';
import 'package:coconut_wallet/widgets/realm_debug/statistics_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Realm 디버그 화면의 쿼리 입력 섹션 위젯
class QueryInputSection extends StatelessWidget {
  final TextEditingController queryController;
  final Future<void> Function() onExecuteQuery;
  final Future<void> Function() onRefreshAll;
  final VoidCallback onExportJson;

  const QueryInputSection({
    super.key,
    required this.queryController,
    required this.onExecuteQuery,
    required this.onRefreshAll,
    required this.onExportJson,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RealmDebugViewModel>(
      builder: (context, viewModel, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 테이블 선택
            _buildTableSelection(context, viewModel),

            const SizedBox(height: 16),

            // 쿼리 입력
            _buildQueryInput(context),

            const SizedBox(height: 8),

            // 쿼리 예제 버튼들
            _buildQueryExamples(context, viewModel),

            const SizedBox(height: 16),

            // 정렬 옵션 UI
            SortOptionsSection(queryController: queryController),

            const SizedBox(height: 16),

            // 실행 버튼
            _buildActionButtons(context, viewModel),

            const SizedBox(height: 16),

            // 테이블 통계 정보
            const StatisticsSection(),

            const SizedBox(height: 8),

            // 결과 요약
            _buildResultSummary(context, viewModel),
          ],
        );
      },
    );
  }

  Widget _buildTableSelection(BuildContext context, RealmDebugViewModel viewModel) {
    return Row(
      children: [
        const Text('테이블: '),
        Expanded(
          child: viewModel.isLoading
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        viewModel.selectedTable,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      Text(
                        '로딩 중...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownButton<String>(
                  value: viewModel.selectedTable,
                  isExpanded: true,
                  items: viewModel.availableTables.map((table) {
                    return DropdownMenuItem(
                      value: table,
                      child: Text(table),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      viewModel.changeSelectedTable(value);
                      queryController.text = 'TRUEPREDICATE';
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildQueryInput(BuildContext context) {
    return TextField(
      controller: queryController,
      decoration: const InputDecoration(
        labelText: 'Realm 쿼리 (NSPredicate 형식)',
        hintText: '예: id > 0, name CONTAINS "test"',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
    );
  }

  Widget _buildQueryExamples(BuildContext context, RealmDebugViewModel viewModel) {
    return Wrap(
      spacing: 8,
      children: viewModel.getQueryExamples().map((example) {
        return ActionChip(
          label: Text(
            example.length > 30 ? '${example.substring(0, 30)}...' : example,
            style: const TextStyle(fontSize: 12),
          ),
          onPressed: () {
            queryController.text = example;
          },
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(BuildContext context, RealmDebugViewModel viewModel) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: viewModel.isLoading ? null : onExecuteQuery,
          icon: viewModel.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(viewModel.isLoading ? '실행 중...' : '쿼리 실행'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: viewModel.isLoading ? null : onRefreshAll,
          icon: const Icon(Icons.refresh),
          label: const Text('전체 조회'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: (viewModel.queryResults.isEmpty || viewModel.isLoading) ? null : onExportJson,
          icon: const Icon(Icons.download),
          label: const Text('JSON 내보내기'),
        ),
      ],
    );
  }

  Widget _buildResultSummary(BuildContext context, RealmDebugViewModel viewModel) {
    return Row(
      children: [
        viewModel.isLoading
            ? const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('조회 중...'),
                ],
              )
            : Text('결과: ${viewModel.queryResults.length}개'),
        const Spacer(),
        if (viewModel.queryResults.isNotEmpty && !viewModel.isLoading)
          Text(
            '선택된 테이블: ${viewModel.selectedTable}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
