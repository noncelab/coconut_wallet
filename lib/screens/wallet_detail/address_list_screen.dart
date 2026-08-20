import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/constants/address.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/address_list_view_model.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/card/address_list_address_item_card.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/common/qr_with_copy_text_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddressListScreen extends StatefulWidget {
  final int id;
  final bool isFullScreen;
  final double paddingTop;
  final Color? backgroundColor;
  final bool initialShowOnlyWatchedAddresses;

  const AddressListScreen({
    super.key,
    required this.id,
    this.isFullScreen = true,
    this.paddingTop = 0,
    this.backgroundColor,
    this.initialShowOnlyWatchedAddresses = false,
  });

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  /// 페이지네이션
  late final AddressListViewModel viewModel;
  bool _isInitializing = false;
  bool _isLoadMoreRunning = false;
  bool _isScrollingToTop = false;
  bool _isReceivingSelected = true;

  /// 모니터링 중인 주소만 보기
  bool _showOnlyWatchedAddresses = false;
  List<WalletAddress> _watchedReceivingAddressList = [];
  List<WalletAddress> _watchedChangeAddressList = [];
  StreamSubscription<WalletUpdateInfo>? _watchedAddressesRefreshSubscription;

  final GlobalKey _appBarKey = GlobalKey();
  Size _appBarSize = const Size(0, 0);

  /// 세그먼트 컨트롤 말풍선 툴팁
  static const int kSegmentTooltipDuration = 5;
  final GlobalKey _screenStackKey = GlobalKey();
  final GlobalKey _receivingSegmentKey = GlobalKey();
  final GlobalKey _changeSegmentKey = GlobalKey();
  Timer? _segmentTooltipTimer;
  int _segmentTooltipRemainingSeconds = 0;
  bool _isSegmentTooltipForReceiving = true;
  Offset _segmentTooltipAnchorPosition = Offset.zero;
  Size _segmentTooltipAnchorSize = Size.zero;

  /// 스크롤
  final bool _isScrollOverTitleHeight = false;
  late ScrollController _controller;
  late BitcoinUnit _currentUnit;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Consumer<AddressListViewModel>(
        builder: (context, viewModel, child) {
          final showOnlyUnusedAddresses = context.select<PreferenceProvider, bool>(
            (provider) => provider.showOnlyUnusedAddresses,
          );
          List<WalletAddress> addressList;
          if (_showOnlyWatchedAddresses) {
            addressList = _filteredWatchedAddresses(_isReceivingSelected, showOnlyUnusedAddresses);
          } else {
            addressList = _isReceivingSelected ? viewModel.receivingAddressList : viewModel.changeAddressList;
          }
          final backgroundColor = _backgroundColor(context);
          return Stack(
            key: _screenStackKey,
            children: [
              GestureDetector(
                onTapDown: (_) => _removeSegmentTooltip(),
                child: Scaffold(
                  extendBodyBehindAppBar: true,
                  backgroundColor: backgroundColor,
                  appBar: _buildAppBar(context, backgroundColor),
                  body: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        _buildSegmentedControl(),
                        _buildShowOnlyUsedAddressesButton(),
                        _buildShowOnlyWatchedAddressesButton(showOnlyUnusedAddresses),
                        Expanded(child: _buildAddressList(addressList)),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSegmentTooltip(),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _watchedAddressesRefreshSubscription?.cancel();
    _segmentTooltipTimer?.cancel();
    viewModel.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final preferenceProvider = context.read<PreferenceProvider>();

    viewModel = AddressListViewModel(context.read<WalletProvider>(), context.read<NodeProvider>(), widget.id);
    _currentUnit = preferenceProvider.currentUnit;
    _controller = ScrollController();
    _initializeAddressList();

    _showOnlyWatchedAddresses = widget.initialShowOnlyWatchedAddresses;
    if (_showOnlyWatchedAddresses) {
      _loadWatchedAddresses();
    }

    _watchedAddressesRefreshSubscription = context.read<NodeProvider>().getWalletStateStream(widget.id).listen((_) {
      if (_showOnlyWatchedAddresses) {
        _loadWatchedAddresses();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_appBarKey.currentContext?.mounted ?? false) {
        final renderBox = _appBarKey.currentContext!.findRenderObject() as RenderBox;
        final renderSize = renderBox.size;
        final topPadding = widget.isFullScreen ? 0.0 : MediaQuery.of(context).padding.top;
        setState(() {
          _appBarSize = Size(renderSize.width, renderSize.height + topPadding);
        });
      }

      _controller.addListener(_nextLoad);

      // _appBarSize 반영이 완료되어 세그먼트 컨트롤 위치가 확정된 다음 프레임에 초기 툴팁을 띄운다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showSegmentTooltip(_isReceivingSelected);
      });
    });
  }

  Future<void> _initializeAddressList() async {
    if (_isInitializing) return;

    if (mounted) {
      setState(() {
        _isInitializing = true;
      });
    }

    final showOnlyUnusedAddresses = context.read<PreferenceProvider>().showOnlyUnusedAddresses;

    if (_isReceivingSelected) {
      viewModel.receivingAddressList.clear();
    } else {
      viewModel.changeAddressList.clear();
    }

    await viewModel.initializeAddressList(kInitialAddressCount, showOnlyUnusedAddresses);

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> scrollToTop() async {
    _isScrollingToTop = true;
    if (_controller.hasClients) {
      await _controller.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
    }
    _isScrollingToTop = false;
  }

  Color _backgroundColor(BuildContext context) {
    return widget.backgroundColor ?? context.coconutColors.background;
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, Color backgroundColor) {
    return CoconutAppBar.build(
      context: context,
      entireWidgetKey: _appBarKey,
      backgroundColor: _isScrollOverTitleHeight ? backgroundColor.withValues(alpha: 0.5) : backgroundColor,
      title: t.address_list_screen.wallet_name(name: viewModel.walletBaseItem!.name),
      actionButtonList: [
        IconButton(
          onPressed: () {
            Navigator.pushNamed(context, '/address-search', arguments: {'id': widget.id});
          },
          icon: Icon(Icons.search_rounded, color: context.coconutColors.iconDefault),
        ),
      ],
    );
  }

  Widget _buildFilterToggleRow({
    required bool isSelected,
    required String label,
    required VoidCallback onToggle,
    EdgeInsets padding = const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 8),
  }) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        color: Colors.transparent,
        padding: padding,
        child: Row(
          children: [
            CoconutCheckbox(isSelected: isSelected, onChanged: (_) => onToggle(), width: 14),
            CoconutLayout.spacing_150w,
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label, style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowOnlyUsedAddressesButton() {
    return Selector<PreferenceProvider, bool>(
      selector: (_, viewModel) => viewModel.showOnlyUnusedAddresses,
      builder: (context, showOnlyUnusedAddresses, child) {
        return _buildFilterToggleRow(
          isSelected: showOnlyUnusedAddresses,
          label: t.address_list_screen.show_only_unused_address,
          onToggle: () {
            context.read<PreferenceProvider>().changeShowOnlyUnusedAddresses(!showOnlyUnusedAddresses);
            scrollToTop().then((_) => _initializeAddressList());
          },
          padding: const EdgeInsets.only(left: 12, right: 16, top: 8),
        );
      },
    );
  }

  /// '모니터링 중인 주소만 보기'와 '사용 전 주소만 보기'가 동시에 켜졌을 때
  /// watched 목록에서 사용된 주소를 제외해 두 필터가 조합되어 적용
  List<WalletAddress> _filteredWatchedAddresses(bool isReceiving, bool showOnlyUnusedAddresses) {
    final watchedList = isReceiving ? _watchedReceivingAddressList : _watchedChangeAddressList;
    if (!showOnlyUnusedAddresses) return watchedList;
    return watchedList.where((address) => !address.isUsed).toList();
  }

  Widget _buildShowOnlyWatchedAddressesButton(bool showOnlyUnusedAddresses) {
    final watchedCount = _filteredWatchedAddresses(_isReceivingSelected, showOnlyUnusedAddresses).length;
    return _buildFilterToggleRow(
      isSelected: _showOnlyWatchedAddresses,
      label:
          _showOnlyWatchedAddresses
              ? t.address_list_screen.show_only_watched_address_count(count: watchedCount)
              : t.address_list_screen.show_only_watched_address,
      onToggle: () async {
        final newValue = !_showOnlyWatchedAddresses;
        if (newValue) {
          await _loadWatchedAddresses();
        }
        if (!mounted) return;
        setState(() {
          _showOnlyWatchedAddresses = newValue;
        });
        await scrollToTop();
      },
    );
  }

  Future<void> _loadWatchedAddresses() async {
    final receiving = await viewModel.getWatchedAddresses(false);
    final change = await viewModel.getWatchedAddresses(true);
    if (!mounted) return;
    setState(() {
      _watchedReceivingAddressList = receiving;
      _watchedChangeAddressList = change;
    });
  }

  Widget _buildSegmentedControl() {
    return Padding(
      padding: EdgeInsets.only(top: _appBarSize.height),
      child: CoconutSegmentedControl(
        keys: [_receivingSegmentKey, _changeSegmentKey],
        isSelected: [_isReceivingSelected, !_isReceivingSelected],
        onPressed: (index) async {
          final isReceiving = index == 0;
          if (isReceiving != _isReceivingSelected) {
            setState(() {
              _isReceivingSelected = isReceiving;
            });
          }
          _showSegmentTooltip(isReceiving);
          await scrollToTop();
          await _initializeAddressList();
        },
        selectedColor: context.coconutColors.segmentedControlSelected,
        segmentedControlContainerColor: context.coconutColors.segmentedControlBackground,
        selectedTextColor: context.coconutColors.segmentedControlSelectedText,
        unselectedTextColor: context.coconutColors.segmentedControlUnselectedText,
        children: [Text(t.address_list_screen.receiving), Text(t.address_list_screen.change)],
      ),
    );
  }

  void _showSegmentTooltip(bool isReceiving) {
    final preferenceProvider = context.read<PreferenceProvider>();
    final hasSeenToday =
        isReceiving
            ? preferenceProvider.hasSeenReceivingTooltipToday()
            : preferenceProvider.hasSeenChangeTooltipToday();
    if (hasSeenToday) {
      return;
    }

    final labelKey = isReceiving ? _receivingSegmentKey : _changeSegmentKey;
    final labelRenderBox = labelKey.currentContext?.findRenderObject();
    final stackRenderBox = _screenStackKey.currentContext?.findRenderObject();
    if (labelRenderBox is! RenderBox || !labelRenderBox.hasSize || stackRenderBox is! RenderBox) {
      return;
    }

    setState(() {
      _isSegmentTooltipForReceiving = isReceiving;
      _segmentTooltipAnchorPosition = labelRenderBox.localToGlobal(Offset.zero, ancestor: stackRenderBox);
      _segmentTooltipAnchorSize = labelRenderBox.size;
      _segmentTooltipRemainingSeconds = kSegmentTooltipDuration;
    });

    if (isReceiving) {
      preferenceProvider.markReceivingTooltipShownToday();
    } else {
      preferenceProvider.markChangeTooltipShownToday();
    }

    _segmentTooltipTimer?.cancel();
    _segmentTooltipTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_segmentTooltipRemainingSeconds > 0) {
          _segmentTooltipRemainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _removeSegmentTooltip() {
    if (_segmentTooltipRemainingSeconds == 0) return;
    _segmentTooltipTimer?.cancel();
    setState(() {
      _segmentTooltipRemainingSeconds = 0;
    });
  }

  double _clampBubbleOffset(double value, double min, double max) {
    if (max < min) return min;
    return value.clamp(min, max);
  }

  Widget _buildSegmentTooltip() {
    final anchorCenterX = _segmentTooltipAnchorPosition.dx + _segmentTooltipAnchorSize.width / 2;
    final anchorBottom = _segmentTooltipAnchorPosition.dy + _segmentTooltipAnchorSize.height - 14;
    const leftTriangleOffset = 39.0;
    const rightTriangleOffset = 19.0;
    const horizontalMargin = 10.0;
    final containerWidth = MediaQuery.sizeOf(context).width;
    final bubbleWidth = (containerWidth - horizontalMargin * 2) * 0.67;
    final maxOffset = containerWidth - bubbleWidth - horizontalMargin;

    return Positioned(
      top: anchorBottom,
      left:
          _isSegmentTooltipForReceiving
              ? _clampBubbleOffset(anchorCenterX - leftTriangleOffset, horizontalMargin, maxOffset)
              : null,
      right:
          _isSegmentTooltipForReceiving
              ? null
              : _clampBubbleOffset(containerWidth - anchorCenterX - rightTriangleOffset, horizontalMargin, maxOffset),
      // TODO: CoconutToolTip의 placement 타입은 내부적으로 width 파라미터를 사용하지 않고
      // 텍스트 내용에 맞춰 Stack 폭까지 크기를 잡기 때문에, 여기서 SizedBox로
      // 실제 렌더링 폭을 강제해야 계산한 bubbleWidth/left/right가 적용됨
      child: SizedBox(
        width: bubbleWidth,
        child: CoconutToolTip(
          width: bubbleWidth,
          isBubbleClipperSideLeft: _isSegmentTooltipForReceiving,
          tooltipType: CoconutTooltipType.placement,
          backgroundColor: context.coconutColors.popoverBackground,
          richText: RichText(
            text: TextSpan(
              text: _isSegmentTooltipForReceiving ? t.tooltip.address_receiving : t.tooltip.address_change,
              style: CoconutTypography.body3_12
                  .setColor(context.coconutColors.popoverText)
                  .merge(const TextStyle(height: 1.3)),
            ),
          ),
          onTapRemove: _removeSegmentTooltip,
          isPlacementTooltipVisible: _segmentTooltipRemainingSeconds > 0,
        ),
      ),
    );
  }

  Widget _buildAddressList(List<WalletAddress> addressList) {
    return _isInitializing
        ? const Center(child: CircularProgressIndicator())
        : CustomScrollView(
          controller: _controller,
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return Container(
                  color: _backgroundColor(context),
                  child: Column(
                    children: [
                      AddressItemCard(
                        onPressed: () {
                          AppGuard.disablePrivacyScreen();
                          CommonBottomSheets.showCustomHeightBottomSheet(
                            context: context,
                            heightRatio: 0.9,
                            childBuilder:
                                (scrollController) => QrWithCopyTextScreen(
                                  scrollController: scrollController,
                                  backgroundColor: context.coconutColors.surfaceBottomSheet,
                                  showBottomActions: true,
                                  qrcodeTopWidget: Text(
                                    addressList[index].derivationPath,
                                    style: CoconutTypography.body2_14.merge(
                                      TextStyle(color: context.coconutColors.primaryText.withValues(alpha: 0.7)),
                                    ),
                                  ),
                                  qrData: addressList[index].address,
                                  isAddress: true,
                                  title: t.address_list_screen.address_index(index: addressList[index].index),
                                  isBottom: true,
                                  showPulldownMenu: false,
                                  showQrEmbedImage: true,
                                ),
                          ).whenComplete(() => AppGuard.enablePrivacyScreen());
                        },
                        address: addressList[index].address,
                        derivationPath: addressList[index].derivationPath,
                        isUsed: addressList[index].isUsed,
                        isWatched: viewModel.isAddressWatched(addressList[index]),
                        balanceInSats: addressList[index].total,
                        currentUnit: _currentUnit,
                      ),
                    ],
                  ),
                );
              }, childCount: addressList.length),
            ),
            if (_isLoadMoreRunning)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40, top: 20),
                  child: Center(child: CircularProgressIndicator(color: context.coconutColors.iconDefault)),
                ),
              ),
          ],
        );
  }

  Future<void> _nextLoad() async {
    if (_showOnlyWatchedAddresses) return;

    if (_isInitializing || _isLoadMoreRunning || _controller.position.extentAfter > 500) {
      return;
    }

    // 현재 탭 상태 저장 (로딩 중 탭 변경 시 데이터 추가 방지)
    final wasReceivingSelected = _isReceivingSelected;

    setState(() {
      _isLoadMoreRunning = true;
    });

    List<WalletAddress> newAddresses = [];
    try {
      final cursor = !_isReceivingSelected ? viewModel.changeInitialCursor : viewModel.receivingInitialCursor;
      newAddresses = await viewModel.getWalletAddressList(
        viewModel.walletBaseItem!,
        cursor,
        kAddressLoadCount,
        !_isReceivingSelected,
        context.read<PreferenceProvider>().showOnlyUnusedAddresses,
      );

      // UI 업데이트 - 탭 상태가 변경되지 않았을 때만 데이터 추가
      if (mounted && wasReceivingSelected == _isReceivingSelected && !_isScrollingToTop) {
        setState(() {
          if (_isReceivingSelected) {
            viewModel.receivingAddressList.addAll(newAddresses);
          } else {
            viewModel.changeAddressList.addAll(newAddresses);
          }
        });
      }
    } catch (e) {
      Logger.log(e.toString());
    } finally {
      // 로딩 상태 해제
      if (mounted) {
        setState(() {
          _isLoadMoreRunning = false;
        });
        // 탭 상태가 변경되지 않았을 때만 백그라운드 저장
        if (wasReceivingSelected == _isReceivingSelected) {
          _addAddressesWithGapLimit(newAddresses, !_isReceivingSelected);
        }
      }
    }
  }

  /// 추후 다시 조회할 경우 조회 속도 향상을 위해 백그라운드에서 주소를 저장
  void _addAddressesWithGapLimit(List<WalletAddress> newAddresses, bool isChange) {
    if (viewModel.walletBaseItem == null) {
      return;
    }
    // 백그라운드에서 비동기적으로 실행하여 UI 블로킹 방지
    Future.microtask(() async {
      try {
        await viewModel.walletProvider.addAddressesWithGapLimit(
          walletItemBase: viewModel.walletBaseItem!,
          newAddresses: newAddresses,
          isChange: isChange,
        );
      } catch (e) {
        Logger.error('[_preloadAddressesInBackground] Failed to preload addresses: $e');
      }
    });
  }
}
