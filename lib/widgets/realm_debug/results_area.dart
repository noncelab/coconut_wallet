import 'package:coconut_wallet/providers/view_model/settings/realm_debug_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// 쿼리 결과 표시 영역 위젯
class ResultsArea extends StatelessWidget {
  final Function(Map<String, dynamic>) onEditTransaction;

  const ResultsArea({
    super.key,
    required this.onEditTransaction,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RealmDebugViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return _buildLoadingWidget(context);
        }

        if (viewModel.errorMessage.isNotEmpty) {
          return _buildErrorWidget(context, viewModel.errorMessage);
        }

        if (viewModel.queryResults.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text('조회 결과가 없습니다.'),
            ),
          );
        }

        return _buildResultsList(context, viewModel);
      },
    );
  }

  Widget _buildLoadingWidget(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '데이터를 조회하고 있습니다...',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '잠시만 기다려주세요',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, String errorMessage) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, RealmDebugViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: viewModel.queryResults.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        final isModified =
            viewModel.selectedTable == 'RealmTransaction' && viewModel.isModifiedTransaction(row);

        return _buildResultCard(context, viewModel, index, row, isModified);
      }).toList(),
    );
  }

  Widget _buildResultCard(BuildContext context, RealmDebugViewModel viewModel, int index,
      Map<String, dynamic> row, bool isModified) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: isModified
          ? BoxDecoration(
              border: Border.all(color: Colors.amber, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Card(
        elevation: 2,
        child: ExpansionTile(
          title: _buildCardTitle(context, viewModel, index, isModified, row),
          subtitle: _buildCardSubtitle(context, viewModel, row, isModified),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: row.entries.map((entry) {
                  return _buildFieldRow(context, viewModel, entry, isModified);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTitle(BuildContext context, RealmDebugViewModel viewModel, int index,
      bool isModified, Map<String, dynamic> row) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Row ${index + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        if (isModified)
          Icon(
            Icons.edit,
            color: Colors.amber[700],
            size: 20,
          ),
        // RealmTransaction 테이블일 때만 수정 버튼 표시
        if (viewModel.selectedTable == 'RealmTransaction')
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => onEditTransaction(row),
            tooltip: '트랜잭션 수정 (테스트용)',
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }

  Widget _buildCardSubtitle(BuildContext context, RealmDebugViewModel viewModel,
      Map<String, dynamic> row, bool isModified) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${row.keys.first}: ${row.values.first}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (isModified)
          Text(
            '수정됨 (테스트용)',
            style: TextStyle(
              color: Colors.amber[700],
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildFieldRow(BuildContext context, RealmDebugViewModel viewModel,
      MapEntry<String, dynamic> entry, bool isModified) {
    final isEditableField = viewModel.isEditableField(entry.key);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 키 (필드명)
          _buildFieldKey(context, entry.key, isEditableField),
          const SizedBox(height: 4),
          // 값
          _buildFieldValue(context, entry.value, isEditableField, isModified),
        ],
      ),
    );
  }

  Widget _buildFieldKey(BuildContext context, String key, bool isEditableField) {
    return Row(
      children: [
        Text(
          key,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isEditableField ? Colors.blue[700] : Theme.of(context).colorScheme.primary,
          ),
        ),
        if (isEditableField)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '수정가능',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFieldValue(
      BuildContext context, dynamic value, bool isEditableField, bool isModified) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value.toString()));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('클립보드에 복사되었습니다'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEditableField && isModified
                ? Colors.amber
                : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Text(
          value.toString(),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
