part of 'send_screen.dart';

extension _SendScreenDraft on _SendScreenState {
  Future<void> _onSaveNewDraft() async {
    if (_viewModel.drafts == null || !_validateEnteredAddresses()) return;
    try {
      await _viewModel.saveNewDraft();
      _showTransactionDraftSavedDialog();
    } catch (e) {
      _showTransactionDraftSaveFailedDialog(e.toString());
    }
  }

  Future<void> _onUpdateDraft() async {
    // TODO: 변경 사항 저장 로직 구현
  }

  Future<void> _onLoadDraft() async {
    final selected = await CommonBottomSheets.showSelectableDraggableSheet<TransactionDraft>(
      context: context,
      title: t.transaction_draft.title,
      items: _viewModel.drafts!,
      getItemId: (draft) => draft.id,
      itemBuilder: (context, draft, isSelected, onTap) {
        return Column(
          children: [
            TransactionDraftCard(transactionDraft: draft, isSelectable: true, isSelected: isSelected, onTap: onTap),
            CoconutLayout.spacing_300h,
          ],
        );
      },
    );
    if (selected != null) {
      await _onDraftSelected(selected);
    }
  }

  Future<void> _onDraftSelected(TransactionDraft draft) async {
    // 1. draft load
    // 1-1. UTXO가 이미 사용된 경우 토스트 알림을 띄우긴 하지만 나머지 정보들은 불러온다.
    // 1-2. UTXO가 잠긴 경우 토스트 알림을 띄우긴 하지만 나머지 정보들은 불러온다.
    // 1-3. 성공적으로 불러온다.
    try {
      _viewModel.loadTransactionDraft(draft.id);
    } on SelectedUtxoStatusException catch (e) {
      // UTXO 상태 문제가 있는 경우 삭제 확인 다이얼로그 표시
      await _showDeleteDraftDialog(e.status);
      return;
    } catch (e) {
      showInfoDialog(
        context,
        context.read<PreferenceProvider>().language,
        t.send_screen.dialog.load_draft_failed,
        e.toString(),
      );
    }

    // recipientList와 _addressControllerList 동기화
    // WidgetsBinding.instance.addPostFrameCallback을 사용하여 다음 프레임에 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncAddressControllersWithRecipientList();
      }
    });
  }

  void _showTransactionDraftSavedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.transaction_draft.dialog.transaction_draft_saved_send_screen,
          description: t.transaction_draft.dialog.transaction_draft_saved_send_screen_description,
          leftButtonText: t.transaction_draft.dialog.cancel,
          rightButtonText: t.transaction_draft.dialog.move,
          onTapRight: () {
            Navigator.pushNamedAndRemoveUntil(context, '/transaction-draft', ModalRoute.withName("/"));
          },
          onTapLeft: () {
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showTransactionDraftSaveFailedDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.transaction_draft.dialog.transaction_draft_save_failed,
          description: errorMessage,
          rightButtonText: t.transaction_draft.dialog.confirm,
          onTapRight: () {
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Future<void> _showDeleteDraftDialog(SelectedUtxoStatus status) async {
    // TODO: 제외하고 불러올까요? 로 변경하는게 어떨까...
    // final transactionDraftRepository = Provider.of<TransactionDraftRepository>(context, listen: false);
    // final description =
    //     status == SelectedUtxoStatus.locked
    //         ? t.transaction_draft.dialog.transaction_has_been_locked_utxo_included
    //         : t.transaction_draft.dialog.transaction_already_used_utxo_included;

    // await showDialog<bool>(
    //   context: context,
    //   builder: (BuildContext context) {
    //     return CoconutPopup(
    //       languageCode: context.read<PreferenceProvider>().language,
    //       title: t.transaction_draft.dialog.transaction_unavailable_to_sign,
    //       description: description,
    //       rightButtonText: t.confirm,
    //       onTapLeft: () {
    //         Navigator.pop(context, false);
    //       },
    //       onTapRight: () async {
    //         final deletedDraftId = _selectedDraftId!;
    //         final result = await transactionDraftRepository.deleteUnsignedTransactionDraft(deletedDraftId);
    //         if (result.isSuccess) {
    //           await _showDeleteCompletedDialog();
    //           final sortedDrafts = getSortedUnsignedTransactionDrafts(transactionDraftRepository);
    //           final index = sortedDrafts.indexWhere((d) {
    //             try {
    //               return d.id == deletedDraftId;
    //             } catch (e) {
    //               return false;
    //             }
    //           });

    //           if (index != -1) {
    //             removeItem(index, deletedDraftId);
    //           }

    //           setSheetState(() {
    //             _selectedDraftId = null;
    //           });
    //         }
    //         Navigator.pop(context, true);
    //       },
    //     );
    //   },
    // );
  }
}
