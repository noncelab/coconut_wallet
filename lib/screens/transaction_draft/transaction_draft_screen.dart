import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/transaction_draft/transaction_draft_view_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/card/transaction_draft_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TransactionDraftScreen extends StatefulWidget {
  final bool? isSignedTabActive;

  const TransactionDraftScreen({super.key, this.isSignedTabActive});

  @override
  State<TransactionDraftScreen> createState() => _TransactionDraftScreenState();
}

class _TransactionDraftScreenState extends State<TransactionDraftScreen> {
  bool? _isSignedTransactionSelected;

  /// 스크롤
  final bool _isScrollOverTitleHeight = false;
  late ScrollController _controller;

  /// 현재 열린 카드 ID (스와이프된 카드)
  int? _swipedCardId;

  /// 초기 선택 상태가 설정되었는지 여부
  bool _initialSelectionSet = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TransactionDraftViewModel>(
      create:
          (_) =>
              TransactionDraftViewModel(Provider.of<TransactionDraftRepository>(context, listen: false))
                ..initializeDraftList(),
      child: Consumer<TransactionDraftViewModel>(
        builder: (context, viewModel, child) {
          // 초기 선택 상태 설정 (한 번만 실행, initializeDraftList 완료 후)
          if (!_initialSelectionSet && viewModel.isInitialized) {
            if (widget.isSignedTabActive != null) {
              _isSignedTransactionSelected = widget.isSignedTabActive!;
            } else {
              final signedList = viewModel.signedTransactionDraftList;
              final unsignedList = viewModel.unsignedTransactionDraftList;
              if (signedList.isNotEmpty) {
                _isSignedTransactionSelected = true;
              } else if (unsignedList.isNotEmpty) {
                _isSignedTransactionSelected = false;
              } else {
                _isSignedTransactionSelected = true;
              }
            }
            _initialSelectionSet = true;
          }

          final currentList =
              (_isSignedTransactionSelected ?? true)
                  ? viewModel.signedTransactionDraftList
                  : viewModel.unsignedTransactionDraftList;

          return Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: _buildAppBar(context),
            body: Column(
              children: [
                _buildSegmentedControl(context, viewModel),
                Expanded(child: _buildTransactionDraftList(currentList, viewModel)),
              ],
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
      isBottom: true,
    );
  }

  Widget _buildSegmentedControl(BuildContext context, TransactionDraftViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 14, left: 16, right: 16),
      child: CoconutSegmentedControl(
        labels: [t.transaction_draft.signed, t.transaction_draft.unsigned],
        isSelected: [_isSignedTransactionSelected ?? true, !(_isSignedTransactionSelected ?? true)],
        onPressed: (index) async {
          final wasSignedSelected = _isSignedTransactionSelected ?? true;
          if (index == 0) {
            if (!(_isSignedTransactionSelected ?? true)) {
              setState(() {
                _isSignedTransactionSelected = true;
              });
            }
          } else {
            if (_isSignedTransactionSelected ?? true) {
              setState(() {
                _isSignedTransactionSelected = false;
              });
            }
          }

          if (wasSignedSelected != (_isSignedTransactionSelected ?? true)) {
            _swipedCardId = null;
          }

          await scrollToTop();
        },
      ),
    );
  }

  Widget _buildTransactionDraftList(List<TransactionDraft> transactionDraftList, TransactionDraftViewModel viewModel) {
    if (transactionDraftList.isEmpty) {
      return Column(children: [CoconutLayout.spacing_2500h, Text(t.transaction_draft.empty_message)]);
    }

    return GestureDetector(
      onTap: () {
        if (_swipedCardId != null) {
          setState(() {
            _swipedCardId = null;
          });
        }
      },
      child: ListView.builder(
        controller: _controller,
        itemCount: transactionDraftList.length,
        itemBuilder: (context, index) {
          final transactionDraft = transactionDraftList[index];
          final cardId = transactionDraft.id;

          return Column(
            children: [
              if (index > 0) CoconutLayout.spacing_300h,
              _buildTransactionDraftCard(transactionDraft, index, cardId, viewModel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionDraftCard(
    TransactionDraft transactionDraft,
    int index,
    int cardId,
    TransactionDraftViewModel viewModel,
  ) {
    return GestureDetector(
      onHorizontalDragStart: (details) {
        // 다른 카드가 열려있으면 먼저 닫기
        if (_swipedCardId != null && _swipedCardId != cardId) {
          setState(() {
            _swipedCardId = null;
          });
        }
      },
      child: TransactionDraftCard(
        key: ValueKey(cardId),
        transactionDraft: transactionDraft,
        isSwiped: _swipedCardId == cardId,
        onSwipeChanged: (isSwiped) {
          setState(() {
            _swipedCardId = isSwiped ? cardId : null;
          });
        },
        onTap: () {
          _handleTransactionDraftCardTap(transactionDraft, viewModel);
        },
        onDelete: () {
          _showDeleteConfirmDialog(transactionDraft, cardId, viewModel);
        },
      ),
    );
  }

  Future<void> _handleTransactionDraftCardTap(
    TransactionDraft transactionDraft,
    TransactionDraftViewModel viewModel,
  ) async {
    if (transactionDraft.isSigned) {
      await Navigator.pushReplacementNamed(
        context,
        '/broadcasting',
        arguments: {'signedTransactionDraftId': transactionDraft.id},
      );
    } else {
      // INFO: 보내기 - 임시 저장 - 임시 저장 완료 다이얼로그 '이동하기'를 통해 이 화면 진입 시 항목 선택으로 send_screen이
      // 중복으로 스택에 쌓이는 것을 방지하기 위해 pushNamedAndRemoveUntil을 사용합니다.
      await Navigator.of(context).pushNamedAndRemoveUntil(
        '/send',
        ModalRoute.withName("/"),
        arguments: {
          'walletId': transactionDraft.walletId,
          'sendEntryPoint': SendEntryPoint.home,
          'transactionDraftId': transactionDraft.id,
        },
      );
    }
  }

  void _showDeleteConfirmDialog(TransactionDraft transactionDraft, int cardId, TransactionDraftViewModel viewModel) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return CoconutPopup(
          languageCode: dialogContext.read<PreferenceProvider>().language,
          title: t.transaction_draft.dialog.transaction_draft_delete,
          description: t.transaction_draft.dialog.transaction_draft_delete_description,
          leftButtonText: t.cancel,
          rightButtonText: t.confirm,
          rightButtonColor: CoconutColors.white,
          onTapRight: () async {
            Navigator.pop(dialogContext);
            await _deleteDraft(transactionDraft, cardId, viewModel);
          },
          onTapLeft: () {
            Navigator.pop(dialogContext);
          },
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _swipedCardId = null;
        });
      }
    });
  }

  Future<void> _deleteDraft(TransactionDraft transactionDraft, int cardId, TransactionDraftViewModel viewModel) async {
    final result = await viewModel.deleteDraft(cardId, isSigned: transactionDraft.isSigned);

    if (!mounted) return;

    if (result.isSuccess) {
      _swipedCardId = null;
      vibrateLight();
    } else {
      vibrateLightDouble();
      showDialog(
        context: context,
        builder: (dialogContext) {
          return CoconutPopup(
            languageCode: dialogContext.read<PreferenceProvider>().language,
            title: t.transaction_draft.dialog.transaction_draft_delete_failed,
            description: result.error.message,
            rightButtonText: t.confirm,
            rightButtonColor: CoconutColors.white,
            onTapRight: () {
              Navigator.pop(dialogContext);
            },
          );
        },
      );
    }
  }

  Future<void> _refreshList(TransactionDraftViewModel viewModel) async {
    await viewModel.initializeDraftList();
  }
}
