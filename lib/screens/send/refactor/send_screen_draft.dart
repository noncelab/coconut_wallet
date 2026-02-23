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
    try {
      await _viewModel.updateDraft();
      _showTransactionDraftSavedDialog(isUpdate: true);
    } catch (e) {
      _showTransactionDraftSaveFailedDialog(e.toString());
    }
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
      await _onDraftSelected(selected.id);
    }
  }

  Future<void> _onDraftSelected(int draftId) async {
    SelectedUtxoExcludedStatus? excludedUtxoStatus;
    try {
      excludedUtxoStatus = _viewModel.loadTransactionDraft(draftId);
    } catch (e) {
      showInfoDialog(
        context,
        context.read<PreferenceProvider>().language,
        t.send_screen.dialog.load_draft_failed,
        e.toString(),
      );
      return;
    }

    // 사용불가 UTXO가 제외된 경우 토스트 알림 표시
    if (excludedUtxoStatus != null) {
      final toastMessage =
          excludedUtxoStatus == SelectedUtxoExcludedStatus.used
              ? t.send_screen.toast.draft_utxo_used
              : t.send_screen.toast.draft_utxo_locked;
      CoconutToast.showWarningToast(context: context, text: toastMessage);
    }

    // recipientList와 _addressControllerList 동기화
    // WidgetsBinding.instance.addPostFrameCallback을 사용하여 다음 프레임에 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncAddressControllersWithRecipientList();
      }
    });
  }

  void _showTransactionDraftSavedDialog({bool isUpdate = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.transaction_draft.dialog.transaction_draft_saved_send_screen,
          description:
              !isUpdate
                  ? t.transaction_draft.dialog.transaction_draft_saved_send_screen_description
                  : t.transaction_draft.dialog.transaction_draft_updated_description,
          leftButtonText: t.transaction_draft.dialog.cancel,
          rightButtonText: t.transaction_draft.dialog.move,
          onTapRight: () {
            Navigator.pop(context); // Dialog close
            Navigator.pushNamed(context, '/transaction-draft', arguments: {'isSignedTabActive': false});
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
}
