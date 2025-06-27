import 'package:coconut_wallet/providers/view_model/settings/realm_debug_view_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/widgets/realm_debug/query_input_section.dart';
import 'package:coconut_wallet/widgets/realm_debug/results_area.dart';
import 'package:coconut_wallet/widgets/realm_debug/transaction_edit_dialog.dart';
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
      _viewModel.executeQuery('TRUEPREDICATE');
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  /// 트랜잭션 데이터 수정 다이얼로그
  Future<void> _showEditTransactionDialog(Map<String, dynamic> transactionData) async {
    final result = await TransactionEditDialogHelper.show(
      context,
      transactionData,
      _viewModel,
    );

    if (result != null) {
      try {
        await _viewModel.updateTransactionData(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('트랜잭션 데이터가 수정되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('JSON 데이터가 클립보드에 복사되었습니다'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                },
              ),

              const SizedBox(height: 16),

              // 결과 영역
              ResultsArea(
                onEditTransaction: _showEditTransactionDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
