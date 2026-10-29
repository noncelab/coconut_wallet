import 'package:coconut_wallet/widgets/common/overlays/content_height_bottom_sheet.dart';
import 'package:coconut_wallet/providers/view_model/send/select_wallet_view_model.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/size_reporting_widget.dart';
import 'dart:math' as math;
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_stack_list_view_model.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart' show formatHomeRelativeTime;
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_carousel_indicator.dart';
import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

export 'package:coconut_wallet/providers/view_model/send/select_wallet_view_model.dart' show BalanceMode;

class SelectWalletBottomSheet extends StatefulWidget {
  final Function(int) onWalletChanged;
  final ScrollController? scrollController;
  final int walletId;
  final BitcoinUnit currentUnit;
  final bool showOnlyMfpWallets;
  final BalanceMode balanceMode;
  final List<int>? candidateWalletIds;

  const SelectWalletBottomSheet({
    super.key,
    required this.walletId,
    required this.onWalletChanged,
    required this.currentUnit,
    required this.showOnlyMfpWallets,
    this.scrollController,
    this.balanceMode = BalanceMode.includingPending,
    this.candidateWalletIds,
  });

  static Future<T?> show<T>({required BuildContext context, required String screenName, required Widget child}) =>
      ContentHeightBottomSheet.show<T>(
        context: context,
        screenName: screenName,
        child: child,
        dragAreaKey: const Key('select-wallet-sheet-drag'),
      );

  @override
  State<SelectWalletBottomSheet> createState() => _SelectWalletBottomSheetState();
}

class _SelectWalletBottomSheetState extends State<SelectWalletBottomSheet> {
  static const _carouselViewportFraction = 0.50;
  late final SelectWalletViewModel _viewModel;
  List<WalletItemBase> get _walletList => _viewModel.wallets;
  int get _selectedWalletId => _viewModel.selectedWalletId;
  bool get _grid => _viewModel.isGrid;
  WalletStackListViewModel get _facts => _viewModel.facts;
  bool _restoringCarousel = false;

  late final PageController _pageController;
  double? _contentHeight;

  void _updateCarouselHeight(Size size) {
    if (mounted && (_contentHeight == null || (_contentHeight! - size.height).abs() > 0.5)) {
      setState(() => _contentHeight = size.height);
      ContentHeightSheetNotification(80 + size.height).dispatch(context);
    }
  }

  Future<void> _toggleLayout() async {
    if (_grid) {
      final scrollController = widget.scrollController ?? PrimaryScrollController.maybeOf(context);
      if (scrollController != null && scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.minScrollExtent);
      }
    }
    _restoringCarousel = _grid;
    final save = _viewModel.toggleLayout();
    if (!_grid) _restoreCarouselPage();
    if (!await save && mounted && _viewModel.layoutSaveFailed) {
      _restoringCarousel = !_grid;
      if (!_grid) _restoreCarouselPage();
      CoconutToast.showToast(context: context, text: t.errors.storage_write_error);
    }
  }

  void _restoreCarouselPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_grid && _pageController.hasClients) {
        final index = _walletList.indexWhere((wallet) => wallet.id == _selectedWalletId);
        if (index >= 0) _pageController.jumpToPage(index);
      }
      _restoringCarousel = false;
    });
  }

  Widget _card(WalletItemBase wallet, {required bool grid, required int balance}) {
    final appearances = context.watchWalletAppearance();
    final selected = _selectedWalletId == wallet.id;
    return Stack(
      fit: StackFit.expand,
      children: [
        WalletCard(
          key: ValueKey('select-wallet-card-${wallet.id}'),
          wallet: wallet,
          appearance: appearances?.appearanceOf(wallet) ?? WalletAppearance.of(wallet),
          backgroundPhoto: appearances?.photoFileFor(wallet.id),
          size: WalletCardSize.small,
          balanceDisplay: widget.currentUnit.displayBitcoinAmount(balance, withUnit: true),
          onPressed: () => _viewModel.selectWallet(wallet.id),
        ),
        if (grid && selected)
          Positioned.fill(
            key: ValueKey('select-wallet-selected-${wallet.id}'),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.coconutColors.iconPrimary, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fact(String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: CoconutTypography.body3_12.copyWith(color: context.coconutColors.secondaryText)),
      const SizedBox(height: 4),
      Text(value, style: CoconutTypography.body2_14_Bold.copyWith(color: context.coconutColors.primaryText)),
    ],
  );

  Widget _details(WalletItemBase wallet) {
    final last = _facts.lastTransactionTime(wallet);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _fact(t.name, wallet.name)),
              const SizedBox(width: 16),
              Expanded(child: _fact(t.wallet_stack_list.utxos, '${_facts.utxoCount(wallet)}')),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _fact(
                  t.wallet_stack_list.last_transaction,
                  last == null ? t.wallet_stack_list.no_transaction : formatHomeRelativeTime(last, DateTime.now()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _fact(t.wallet_stack_list.type, _facts.typeLabel(wallet) ?? '')),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _viewModel,
    builder:
        (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
            return AnimatedContainer(
              duration: Duration(milliseconds: reduceMotion ? 0 : 250),
              curve: Curves.easeOutCubic,
              height: math.min(constraints.maxHeight, 60 + (_contentHeight ?? 480)),
              child: _buildSheet(context),
            );
          },
        ),
  );

  Widget _buildSheet(BuildContext context) {
    final backgroundColor = context.coconutColors.surfaceBottomSheet;
    final selected = _walletList.where((wallet) => wallet.id == _selectedWalletId).firstOrNull;
    final walletBalanceMap = _initBalanceMap();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: backgroundColor,
      appBar: CoconutAppBar.build(
        title: t.send_screen.select_wallet,
        context: context,
        backgroundColor: backgroundColor,
        isBottom: true,
        actionButtonList: [
          IconButton(
            key: const Key('select-wallet-layout-toggle'),
            tooltip: _grid ? t.wallet_selection_carousel : t.wallet_selection_grid,
            onPressed: _toggleLayout,
            icon:
                _grid
                    ? SvgPicture.asset(
                      CommonMenuIconPath.carousel,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                    )
                    : SvgPicture.asset(
                      CommonMenuIconPath.grid,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                    ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardHeight =
                      (_grid
                              ? (constraints.maxWidth - 2 * CoconutLayout.defaultPadding - 12) / 2
                              : constraints.maxWidth * _carouselViewportFraction - 12)
                          .clamp(170.0, 360.0)
                          .toDouble();
                  final carouselCardHeight =
                      (constraints.maxWidth * _carouselViewportFraction - 12).clamp(170.0, 360.0).toDouble();
                  return SingleChildScrollView(
                    controller: widget.scrollController ?? PrimaryScrollController.maybeOf(context),
                    child: SizeReportingWidget(
                      onSizeChanged: (size) {
                        if (!_grid) _updateCarouselHeight(size);
                      },
                      child: Stack(
                        children: [
                          if (_grid)
                            Offstage(
                              child: SizeReportingWidget(
                                onSizeChanged: _updateCarouselHeight,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 16, bottom: 112 + MediaQuery.paddingOf(context).bottom),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(height: carouselCardHeight + 24),
                                      if (_walletList.isNotEmpty) const SizedBox(height: 32),
                                      const SizedBox(height: 24),
                                      if (_walletList.isNotEmpty) _details(selected ?? _walletList.first),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: EdgeInsets.only(top: 16, bottom: 112 + MediaQuery.paddingOf(context).bottom),
                            child:
                                _grid
                                    ? Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
                                      child: GridView.builder(
                                        key: const Key('select-wallet-grid'),
                                        shrinkWrap: true,
                                        primary: false,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _walletList.length,
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          mainAxisExtent: cardHeight,
                                        ),
                                        itemBuilder:
                                            (context, index) => _card(
                                              _walletList[index],
                                              grid: true,
                                              balance: walletBalanceMap[_walletList[index].id] ?? 0,
                                            ),
                                      ),
                                    )
                                    : Column(
                                      children: [
                                        SizedBox(
                                          height: cardHeight + 24,
                                          child: PageView.builder(
                                            key: const Key('select-wallet-carousel'),
                                            controller: _pageController,
                                            clipBehavior: Clip.none,
                                            itemCount: _walletList.length,
                                            onPageChanged: (index) {
                                              if (_grid || _restoringCarousel) return;
                                              final walletId = _walletList[index].id;
                                              if (_selectedWalletId != walletId) vibrateExtraLight();
                                              _viewModel.focusCarouselWallet(walletId);
                                            },
                                            itemBuilder:
                                                (context, index) => AnimatedBuilder(
                                                  animation: _pageController,
                                                  child: _card(
                                                    _walletList[index],
                                                    grid: false,
                                                    balance: walletBalanceMap[_walletList[index].id] ?? 0,
                                                  ),
                                                  builder: (context, child) {
                                                    final page =
                                                        _pageController.hasClients &&
                                                                _pageController.position.hasContentDimensions
                                                            ? _pageController.page ??
                                                                _pageController.initialPage.toDouble()
                                                            : _pageController.initialPage.toDouble();
                                                    final distance = index - page;
                                                    final visibility = (2 - distance.abs()).clamp(0.0, 1.0);
                                                    final emphasis = 1 - distance.abs().clamp(0.0, 1.0) * 0.65;
                                                    final isDark = Theme.of(context).brightness == Brightness.dark;
                                                    final reduceMotion =
                                                        MediaQuery.disableAnimationsOf(context) ||
                                                        MediaQuery.accessibleNavigationOf(context);
                                                    final direction =
                                                        Directionality.of(context) == TextDirection.rtl ? -1 : 1;
                                                    final offset = distance.clamp(-1.0, 1.0) * direction;
                                                    final angle = reduceMotion ? 0.0 : math.pi / 4;
                                                    final rotation = offset * angle;
                                                    final pageWidth =
                                                        constraints.maxWidth * _pageController.viewportFraction;
                                                    final halfCard = math.min(cardHeight, pageWidth) / 2;
                                                    // 원근 회전으로 좁아진 안쪽 모서리까지의 거리를 보정한다.
                                                    final projectedHalf =
                                                        halfCard *
                                                        math.cos(angle) /
                                                        (1 + 0.0015 * halfCard * math.sin(angle));
                                                    final translation =
                                                        offset * (halfCard + projectedHalf + 8 - pageWidth);
                                                    return IgnorePointer(
                                                      ignoring: distance.abs() > 0.5,
                                                      child: Opacity(
                                                        opacity: visibility,
                                                        child: Transform.translate(
                                                          offset: Offset(translation, 0),
                                                          child: Transform(
                                                            key: ValueKey('select-wallet-carousel-transform-$index'),
                                                            alignment: Alignment.center,
                                                            transform:
                                                                Matrix4.identity()
                                                                  ..setEntry(3, 2, 0.0015)
                                                                  ..rotateY(rotation),
                                                            child: Center(
                                                              child: FittedBox(
                                                                fit: BoxFit.scaleDown,
                                                                child: SizedBox.square(
                                                                  dimension: cardHeight,
                                                                  child: DecoratedBox(
                                                                    decoration: BoxDecoration(
                                                                      borderRadius: BorderRadius.circular(20),
                                                                      boxShadow: [
                                                                        BoxShadow(
                                                                          color: context.coconutColors.primaryText
                                                                              .withValues(
                                                                                alpha:
                                                                                    (isDark ? 0.14 : 0.04) * emphasis,
                                                                              ),
                                                                          blurRadius: 22,
                                                                          spreadRadius: 1,
                                                                        ),
                                                                        BoxShadow(
                                                                          color: Colors.black.withValues(
                                                                            alpha: (isDark ? 0.3 : 0.12) * emphasis,
                                                                          ),
                                                                          blurRadius: 20,
                                                                          offset: const Offset(0, 8),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    child: child,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                          ),
                                        ),
                                        if (_walletList.isNotEmpty)
                                          WalletCarouselIndicator(
                                            controller: _pageController,
                                            count: _walletList.length,
                                            keyPrefix: 'select-wallet',
                                            hapticOnChange: false,
                                          ),
                                        const SizedBox(height: 24),
                                        if (selected != null) _details(selected),
                                      ],
                                    ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            FixedBottomButton(
              onButtonClicked: () {
                if (selected != null) widget.onWalletChanged(selected.id);
              },
              isActive: selected != null && selected.id != widget.walletId,
              isVisibleAboveKeyboard: false,
              showSurroundings: true,
              surroundingsColor: backgroundColor,
              text: t.complete,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final walletProvider = context.read<WalletProvider>();
    final preferenceProvider = context.read<PreferenceProvider>();

    _viewModel = SelectWalletViewModel(
      walletProvider: walletProvider,
      preferenceProvider: preferenceProvider,
      nodeProvider: context.read<NodeProvider?>(),
      walletId: widget.walletId,
      balanceMode: widget.balanceMode,
      showOnlyMfpWallets: widget.showOnlyMfpWallets,
      candidateWalletIds: widget.candidateWalletIds,
    );
    _pageController = PageController(
      initialPage: _viewModel.carouselIndex,
      viewportFraction: _carouselViewportFraction,
    );
  }

  Map<int, int> _initBalanceMap() => _viewModel.balances;
}

class P2PSelectWalletBottomSheet extends StatefulWidget {
  final Function(int) onWalletSelected;
  final ScrollController? scrollController;
  final BitcoinUnit currentUnit;
  final bool showOnlyMfpWallets;
  final BalanceMode balanceMode;

  const P2PSelectWalletBottomSheet({
    super.key,
    required this.onWalletSelected,
    required this.currentUnit,
    required this.showOnlyMfpWallets,
    this.scrollController,
    this.balanceMode = BalanceMode.includingPending,
  });

  @override
  State<P2PSelectWalletBottomSheet> createState() => _P2PSelectWalletBottomSheetState();
}

class _P2PSelectWalletBottomSheetState extends State<P2PSelectWalletBottomSheet> {
  @override
  Widget build(BuildContext context) => SelectWalletBottomSheet(
    walletId: -1,
    onWalletChanged: widget.onWalletSelected,
    currentUnit: widget.currentUnit,
    showOnlyMfpWallets: widget.showOnlyMfpWallets,
    scrollController: widget.scrollController,
    balanceMode: widget.balanceMode,
  );
}
