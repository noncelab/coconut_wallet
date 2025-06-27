import 'package:coconut_wallet/providers/view_model/settings/realm_debug_view_model.dart';
import 'package:flutter/material.dart';

/// 트랜잭션 데이터 수정 다이얼로그 위젯
class TransactionEditDialog extends StatefulWidget {
  final Map<String, dynamic> transactionData;
  final RealmDebugViewModel viewModel;

  const TransactionEditDialog({
    super.key,
    required this.transactionData,
    required this.viewModel,
  });

  @override
  State<TransactionEditDialog> createState() => _TransactionEditDialogState();
}

class _TransactionEditDialogState extends State<TransactionEditDialog> {
  late final TextEditingController _walletIdController;
  late final TextEditingController _timestampController;
  late final TextEditingController _blockHeightController;
  late final TextEditingController _transactionTypeController;
  late final TextEditingController _amountController;
  late final TextEditingController _feeController;
  late final TextEditingController _vSizeController;
  late final TextEditingController _inputAddressListController;
  late final TextEditingController _outputAddressListController;
  late final TextEditingController _createdAtController;
  late final TextEditingController _replaceByTransactionHashController;

  @override
  void initState() {
    super.initState();
    _walletIdController = TextEditingController(
      text: widget.transactionData['walletId']?.toString() ?? '',
    );
    _timestampController = TextEditingController(
      text: widget.transactionData['timestamp']?.toString() ?? '',
    );
    _blockHeightController = TextEditingController(
      text: widget.transactionData['blockHeight']?.toString() ?? '',
    );
    _transactionTypeController = TextEditingController(
      text: widget.transactionData['transactionType']?.toString() ?? '',
    );
    _amountController = TextEditingController(
      text: widget.transactionData['amount']?.toString() ?? '',
    );
    _feeController = TextEditingController(
      text: widget.transactionData['fee']?.toString() ?? '',
    );
    _vSizeController = TextEditingController(
      text: widget.transactionData['vSize']?.toString() ?? '',
    );
    _inputAddressListController = TextEditingController(
      text: _listToString(widget.transactionData['inputAddressList']),
    );
    _outputAddressListController = TextEditingController(
      text: _listToString(widget.transactionData['outputAddressList']),
    );
    _createdAtController = TextEditingController(
      text: widget.transactionData['createdAt']?.toString() ?? '',
    );
    _replaceByTransactionHashController = TextEditingController(
      text: widget.transactionData['replaceByTransactionHash']?.toString() ?? '',
    );
  }

  /// List를 문자열로 변환 (JSON 형태로)
  String _listToString(dynamic list) {
    if (list == null) return '';
    if (list is List) {
      return list.join('\n');
    }
    return list.toString();
  }

  /// 문자열을 List로 변환
  List<String> _stringToList(String text) {
    if (text.trim().isEmpty) return [];
    return text.split('\n').where((line) => line.trim().isNotEmpty).toList();
  }

  @override
  void dispose() {
    _walletIdController.dispose();
    _timestampController.dispose();
    _blockHeightController.dispose();
    _transactionTypeController.dispose();
    _amountController.dispose();
    _feeController.dispose();
    _vSizeController.dispose();
    _inputAddressListController.dispose();
    _outputAddressListController.dispose();
    _createdAtController.dispose();
    _replaceByTransactionHashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('트랜잭션 수정 (테스트용)'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 경고 메시지
              _buildWarningMessage(context),

              const SizedBox(height: 16),

              // 읽기 전용 필드들
              _buildReadOnlyFields(),

              const SizedBox(height: 16),

              // 수정 가능한 필드들
              _buildEditableFields(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _onSave,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Widget _buildWarningMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '테스트 목적으로만 사용하세요. 실제 트랜잭션 데이터가 변경됩니다.',
              style: TextStyle(
                color: Colors.orange[700],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyFields() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '읽기 전용 필드',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          _buildReadOnlyField('ID', widget.transactionData['id']?.toString() ?? ''),
          _buildReadOnlyField('Wallet ID', widget.transactionData['walletId']?.toString() ?? ''),
          _buildReadOnlyField(
              'Transaction Hash', widget.transactionData['transactionHash']?.toString() ?? ''),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFields() {
    return Column(
      children: [
        // 기본 정보
        _buildSectionTitle('기본 정보'),
        TextField(
          controller: _timestampController,
          decoration: const InputDecoration(
            labelText: 'Timestamp (ISO 8601)',
            hintText: '2024-01-01T12:00:00.000Z',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _blockHeightController,
          decoration: const InputDecoration(
            labelText: 'Block Height',
            hintText: '850000',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _transactionTypeController,
          decoration: const InputDecoration(
            labelText: 'Transaction Type',
            hintText: 'send, receive, etc.',
          ),
        ),

        const SizedBox(height: 16),

        // 금액 정보
        _buildSectionTitle('금액 정보'),
        TextField(
          controller: _amountController,
          decoration: const InputDecoration(
            labelText: 'Amount (satoshi)',
            hintText: '100000',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _feeController,
          decoration: const InputDecoration(
            labelText: 'Fee (satoshi)',
            hintText: '1000',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _vSizeController,
          decoration: const InputDecoration(
            labelText: 'vSize',
            hintText: '250.5',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),

        const SizedBox(height: 16),

        // 주소 정보
        _buildSectionTitle('주소 정보'),
        TextField(
          controller: _inputAddressListController,
          decoration: const InputDecoration(
            labelText: 'Input Address List',
            hintText: '한 줄에 하나씩 입력',
            alignLabelWithHint: true,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _outputAddressListController,
          decoration: const InputDecoration(
            labelText: 'Output Address List',
            hintText: '한 줄에 하나씩 입력',
            alignLabelWithHint: true,
          ),
          maxLines: 3,
        ),

        const SizedBox(height: 16),

        // 기타 정보
        _buildSectionTitle('기타 정보'),
        TextField(
          controller: _createdAtController,
          decoration: const InputDecoration(
            labelText: 'Created At (ISO 8601)',
            hintText: '2024-01-01T12:00:00.000Z',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _replaceByTransactionHashController,
          decoration: const InputDecoration(
            labelText: 'Replace By Transaction Hash',
            hintText: '선택사항 - RBF된 경우',
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.edit_note, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _onSave() {
    try {
      final updatedData = widget.viewModel.validateTransactionUpdateData(
        id: widget.transactionData['id'].toString(),
        transactionHash: widget.transactionData['transactionHash'],
        walletId: _walletIdController.text,
        timestamp: _timestampController.text,
        blockHeight: _blockHeightController.text,
        transactionType: _transactionTypeController.text,
        amount: _amountController.text,
        fee: _feeController.text,
        vSize: _vSizeController.text,
        inputAddressList: _stringToList(_inputAddressListController.text),
        outputAddressList: _stringToList(_outputAddressListController.text),
        createdAt: _createdAtController.text,
        replaceByTransactionHash: _replaceByTransactionHashController.text.trim().isEmpty
            ? null
            : _replaceByTransactionHashController.text,
      );
      Navigator.of(context).pop(updatedData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

/// 편의성을 위한 정적 메서드
class TransactionEditDialogHelper {
  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    Map<String, dynamic> transactionData,
    RealmDebugViewModel viewModel,
  ) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TransactionEditDialog(
        transactionData: transactionData,
        viewModel: viewModel,
      ),
    );
  }
}
