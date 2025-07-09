import 'package:coconut_wallet/providers/view_model/settings/realm_debug_view_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/widgets/realm_debug/query_input_section.dart';
import 'package:coconut_wallet/widgets/realm_debug/results_area.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Realm 데이터베이스 디버그 화면
///
/// 개발 과정에서 Realm 데이터를 동적으로 조회하고 관리할 수 있는 화면입니다.
/// SQL 쿼리와 유사한 방식으로 Realm 데이터를 조회할 수 있습니다.
class RealmDebugScreen extends StatefulWidget {
  final RealmManager realmManager;

  const RealmDebugScreen({
    super.key,
    required this.realmManager,
  });

  @override
  State<RealmDebugScreen> createState() => _RealmDebugScreenState();
}

class _RealmDebugScreenState extends State<RealmDebugScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late RealmDebugViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = RealmDebugViewModel(widget.realmManager);
    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.changeSelectedTable(_viewModel.selectedTable);
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  /// 트랜잭션 데이터 비우기 확인 다이얼로그
  Future<void> _showClearTransactionDialog(Map<String, dynamic> transactionData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('트랜잭션 데이터 비우기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('다음 트랜잭션의 데이터를 비우시겠습니까?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                // color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ID: ${transactionData['id']}\n'
                'Hash: ${transactionData['transactionHash']?.toString().substring(0, 16)}...',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 문자열 필드는 빈 문자열로\n'
              '• 숫자 필드는 1로\n'
              '• 날짜 필드는 현재 시간으로\n'
              '• 리스트 필드는 빈 리스트로 변경됩니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('비우기'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _viewModel.clearTransactionData(transactionData);
        if (mounted) {
          _showSuccessMessage('트랜잭션 데이터가 비워졌습니다.');
        }
      } catch (e) {
        if (mounted) {
          _showErrorMessage('오류가 발생했습니다: $e');
        }
      }
    }
  }

  /// 성공 메시지 표시 (ScaffoldMessenger 안전하게 사용)
  void _showSuccessMessage(String message) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // ScaffoldMessenger가 없는 경우 다이얼로그로 표시
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('완료'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  /// 에러 메시지 표시 (ScaffoldMessenger 안전하게 사용)
  void _showErrorMessage(String message) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // ScaffoldMessenger가 없는 경우 다이얼로그로 표시
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('오류'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Realm 데이터베이스 디버거'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 테이블 선택 및 쿼리 입력 영역
              QueryInputSection(
                queryController: _queryController,
                onExecuteQuery: () async {
                  await _viewModel.executeQuery(_queryController.text.trim().isEmpty
                      ? 'TRUEPREDICATE'
                      : _queryController.text);
                },
                onRefreshAll: () async {
                  _queryController.text = 'TRUEPREDICATE';
                  await _viewModel.executeQuery('TRUEPREDICATE');
                },
                onExportJson: () {
                  try {
                    _viewModel.exportToJson();
                    _showSuccessMessage('JSON 데이터가 클립보드에 복사되었습니다');
                  } catch (e) {
                    _showErrorMessage(e.toString());
                  }
                },
              ),

              const SizedBox(height: 16),

              // 결과 영역
              ResultsArea(
                onClearTransaction: _showClearTransactionDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
