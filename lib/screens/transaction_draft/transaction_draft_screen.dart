import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/transaction_draft/transaction_draft_view_model.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/widgets/card/transaction_draft_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TransactionDraftScreen extends StatefulWidget {
  const TransactionDraftScreen({super.key});

  @override
  State<TransactionDraftScreen> createState() => _TransactionDraftScreenState();
}

class _TransactionDraftScreenState extends State<TransactionDraftScreen> {
  final bool _isInitializing = false;
  bool _isSignedTransactionSelected = true;

  /// 스크롤
  final bool _isScrollOverTitleHeight = false;
  late ScrollController _controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TransactionDraftViewModel>(
      create:
          (_) => TransactionDraftViewModel(
            Provider.of<TransactionDraftRepository>(context, listen: false),
            0, // id는 사용되지 않음
          )..initializeDraftList(),
      child: Consumer<TransactionDraftViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: _buildAppBar(context),
            body: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildSegmentedControl(),
                  Expanded(
                    child: _buildTransactionDraftList(
                      _isSignedTransactionSelected
                          ? viewModel.signedTransactionDraftList
                          : viewModel.unsignedTransactionDraftList,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  Future<void> scrollToTop() async {
    if (_controller.hasClients) {
      await _controller.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
      context: context,
      backgroundColor: _isScrollOverTitleHeight ? CoconutColors.black.withOpacity(0.5) : CoconutColors.black,
      title: t.transaction_draft.title,
    );
  }

  Widget _buildSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 14),
      child: CoconutSegmentedControl(
        labels: [t.transaction_draft.signed, t.transaction_draft.unsigned],
        isSelected: [_isSignedTransactionSelected, !_isSignedTransactionSelected],
        onPressed: (index) async {
          if (index == 0) {
            if (!_isSignedTransactionSelected) {
              setState(() {
                _isSignedTransactionSelected = true;
              });
            }
          } else {
            if (_isSignedTransactionSelected) {
              setState(() {
                _isSignedTransactionSelected = false;
              });
            }
          }
          await scrollToTop();
        },
      ),
    );
  }

  Widget _buildTransactionDraftList(List<RealmTransactionDraft> transactionDraftList) {
    if (transactionDraftList.isEmpty) {
      return Column(children: [CoconutLayout.spacing_2500h, Text(t.transaction_draft.empty_message)]);
    }
    return _isInitializing
        ? const Center(child: CircularProgressIndicator())
        : ListView.separated(
          separatorBuilder: (context, index) => CoconutLayout.spacing_300h,
          itemCount: transactionDraftList.length,
          itemBuilder: (context, index) {
            return TransactionDraftCard(transactionDraft: transactionDraftList[index]);
          },
        );
  }
}
