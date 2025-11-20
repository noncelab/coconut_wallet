import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/transaction_draft/transaction_draft_view_model.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
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
  bool? _isSignedTransactionSelected;

  /// 스크롤
  final bool _isScrollOverTitleHeight = false;
  late ScrollController _controller;

  /// 현재 열린 카드 ID (스와이프된 카드)
  int? _swipedCardId;

  /// AnimatedList를 위한 키
  final GlobalKey<AnimatedListState> _animatedListKey = GlobalKey<AnimatedListState>();

  /// 현재 표시 중인 리스트 (AnimatedList용)
  List<RealmTransactionDraft> _displayedDraftList = [];

  /// 애니메이션 duration
  static const Duration _duration = Duration(milliseconds: 300);

  /// 초기 선택 상태가 설정되었는지 여부
  bool _initialSelectionSet = false;

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
          // 초기 선택 상태 설정 (한 번만 실행)
          if (!_initialSelectionSet) {
            final signedList = viewModel.signedTransactionDraftList;
            final unsignedList = viewModel.unsignedTransactionDraftList;

            if (signedList.isEmpty && unsignedList.isNotEmpty) {
              // 서명 완료 탭이 비어있고 서명 전 탭이 비어있지 않으면 서명 전 탭 선택
              _isSignedTransactionSelected = false;
            } else {
              // 둘 다 비어있거나 다른 경우 서명 완료 탭 선택 (기본값)
              _isSignedTransactionSelected = true;
            }
            _initialSelectionSet = true;
          }

          // ViewModel 리스트와 _displayedDraftList 동기화
          final currentList =
              (_isSignedTransactionSelected ?? true)
                  ? viewModel.signedTransactionDraftList
                  : viewModel.unsignedTransactionDraftList;

          // 초기 로드 시 또는 세그먼트 전환 시에만 동기화
          if (_displayedDraftList.isEmpty && currentList.isNotEmpty) {
            // setState를 사용하여 상태 업데이트 (다음 프레임에 AnimatedList가 올바른 initialItemCount로 생성됨)
            Future.microtask(() {
              if (mounted) {
                setState(() {
                  _displayedDraftList = List.from(currentList);
                });
              }
            });
          }

          return Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: _buildAppBar(context),
            body: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildSegmentedControl(context, viewModel),
                  Expanded(child: _buildTransactionDraftList(currentList)),
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

  Widget _buildSegmentedControl(BuildContext context, TransactionDraftViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 14),
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

          // 세그먼트 전환 시 _displayedDraftList 초기화
          if (wasSignedSelected != (_isSignedTransactionSelected ?? true)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final newList =
                    (_isSignedTransactionSelected ?? true)
                        ? viewModel.signedTransactionDraftList
                        : viewModel.unsignedTransactionDraftList;
                setState(() {
                  _displayedDraftList = List.from(newList);
                  _swipedCardId = null;
                });
              }
            });
          }

          await scrollToTop();
        },
      ),
    );
  }

  Widget _buildTransactionDraftList(List<RealmTransactionDraft> transactionDraftList) {
    if (transactionDraftList.isEmpty) {
      // 리스트가 비어있으면 _displayedDraftList도 비우기
      if (_displayedDraftList.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _displayedDraftList = [];
            });
          }
        });
      }
      return Column(children: [CoconutLayout.spacing_2500h, Text(t.transaction_draft.empty_message)]);
    }

    // 초기 로드가 완료되지 않았으면 로딩 표시
    if (_displayedDraftList.isEmpty && transactionDraftList.isNotEmpty) {
      return Container();
    }

    return _isInitializing
        ? const Center(child: CircularProgressIndicator(color: CoconutColors.white))
        : GestureDetector(
          onTap: () {
            // 화면 탭 시 열린 카드 닫기
            if (_swipedCardId != null) {
              setState(() {
                _swipedCardId = null;
              });
            }
          },
          child: AnimatedList(
            key: ValueKey('${_displayedDraftList.length}_$_isSignedTransactionSelected'),
            initialItemCount: _displayedDraftList.length,
            itemBuilder: (context, index, animation) {
              if (index >= _displayedDraftList.length) {
                return const SizedBox.shrink();
              }

              // Realm 객체가 유효한지 확인
              final transactionDraft = _displayedDraftList[index];
              int? cardId;
              try {
                cardId = transactionDraft.id;
              } catch (e) {
                // Realm 객체가 이미 invalidated된 경우
                return const SizedBox.shrink();
              }

              return Column(
                children: [
                  if (index > 0) CoconutLayout.spacing_300h,
                  _buildTransactionDraftCard(transactionDraft, index, animation, cardId),
                ],
              );
            },
          ),
        );
  }

  Widget _buildTransactionDraftCard(
    RealmTransactionDraft transactionDraft,
    int index,
    Animation<double> animation,
    int cardId,
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
        transactionDraft: transactionDraft,
        isSwiped: _swipedCardId == cardId,
        onSwipeChanged: (isSwiped) {
          setState(() {
            _swipedCardId = isSwiped ? cardId : null;
          });
        },
        onDelete: () async {
          final transactionDraftRepository = Provider.of<TransactionDraftRepository>(context, listen: false);
          try {
            showDialog(
              context: context,
              builder: (context) {
                return CoconutPopup(
                  title: t.transaction_draft.dialog.transaction_draft_delete,
                  description: t.transaction_draft.dialog.transaction_draft_delete_description,
                  leftButtonText: t.cancel,
                  rightButtonText: t.confirm,
                  rightButtonColor: CoconutColors.white,
                  onTapRight: () async {
                    Navigator.pop(context);

                    // 삭제될 아이템 인덱스와 ID 저장
                    final deletedIndex = index;
                    final deletedCardId = cardId;

                    // Realm 객체 삭제 먼저 수행
                    final result = await transactionDraftRepository.deleteTransactionDraft(cardId);

                    if (result.isSuccess) {
                      // _displayedDraftList에서 해당 ID를 가진 항목만 제거 (인덱스로 접근하면 안됨)
                      setState(() {
                        _displayedDraftList.removeWhere((draft) {
                          try {
                            return draft.id == deletedCardId;
                          } catch (e) {
                            // invalidated 객체는 제거
                            return false;
                          }
                        });
                        _swipedCardId = null;
                      });

                      // 애니메이션과 함께 삭제
                      // 삭제된 후에는 _displayedDraftList의 길이가 줄어들지만,
                      // AnimatedList는 removeItem이 호출될 때까지 원래 길이를 유지
                      if (_animatedListKey.currentState != null && deletedIndex >= 0) {
                        _animatedListKey.currentState?.removeItem(
                          deletedIndex,
                          (context, animation) => _buildRemoveCardPlaceholder(animation),
                          duration: _duration,
                        );
                        vibrateLight();
                      }
                    } else {
                      vibrateLightDouble();
                      if (mounted) {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return CoconutPopup(
                              title: t.transaction_draft.dialog.transaction_draft_delete_failed,
                              description: result.error.message,
                              rightButtonText: t.confirm,
                              rightButtonColor: CoconutColors.white,
                              onTapRight: () {
                                Navigator.pop(context);
                              },
                            );
                          },
                        );
                      }
                    }
                  },
                  onTapLeft: () {
                    Navigator.pop(context);
                  },
                );
              },
            );
          } catch (e) {
            vibrateLightDouble();
            showDialog(
              context: context,
              builder: (context) {
                return CoconutPopup(
                  title: t.transaction_draft.dialog.transaction_draft_delete_failed,
                  description: e.toString(),
                  rightButtonText: t.confirm,
                  rightButtonColor: CoconutColors.white,
                  onTapRight: () {
                    Navigator.pop(context);
                  },
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildRemoveCardPlaceholder(Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Column(
          children: [
            if (_displayedDraftList.isNotEmpty) CoconutLayout.spacing_300h,
            // 삭제되는 카드와 동일한 높이의 플레이스홀더
            Container(
              decoration: BoxDecoration(color: CoconutColors.gray800, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: Sizes.size24, vertical: Sizes.size16),
              // 대략적인 카드 높이 (타임스탬프, 지갑 정보, 주소, 수수료 등)
              height: 120,
            ),
          ],
        ),
      ),
    );
  }
}
