import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_stack_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart' show kEntryPointWalletList;
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 지갑 목록. 카드가 화면 오른쪽 밖을 중심으로 한 원호를 따라 위아래로 돌고, 가운데 카드의 정보를 왼쪽 아래에 보여 준다.
/// 홈 스택에서 열면 스택 카드가 가운데 카드로 커지며 날아오고, 나머지 카드는 원호를 따라 펼쳐진다.
class WalletStackListScreen extends StatefulWidget {
  static const transitionDuration = Duration(milliseconds: 480);

  /// 휠 카드는 이 크기로 그린 뒤 화면에 맞게 키운다.
  static const cardBaseExtent = 240.0;

  final int? initialWalletId;
  final Object Function(int walletId)? heroTagOf;
  final void Function(int walletId)? onFocusWallet;
  final String title;

  const WalletStackListScreen({super.key, this.initialWalletId, this.heroTagOf, this.onFocusWallet, this.title = ''});

  static Future<void> open(
    BuildContext context, {
    required WalletStackKind kind,
    WalletStackOpenRequest? request,
    String title = '',
  }) {
    final walletProvider = context.read<WalletProvider>();
    final preferenceProvider = context.read<PreferenceProvider>();
    return Navigator.of(context).push(
      PageRouteBuilder(
        settings: RouteSettings(name: '/${kind.name}-wallet-list'),
        transitionDuration: transitionDuration,
        reverseTransitionDuration: transitionDuration,
        pageBuilder:
            (_, __, ___) => ChangeNotifierProvider(
              create: (_) => WalletStackListViewModel(kind, walletProvider, preferenceProvider),
              child: WalletStackListScreen(
                initialWalletId: request?.front.id,
                heroTagOf: request?.heroTagOf,
                onFocusWallet: request?.showWallet,
                title: title,
              ),
            ),
        transitionsBuilder:
            (_, animation, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
              child: child,
            ),
      ),
    );
  }

  @override
  State<WalletStackListScreen> createState() => _WalletStackListScreenState();
}

class _WalletStackListScreenState extends State<WalletStackListScreen> {
  static const _step = 0.42;
  static const _cardLeftRatio = 0.22;

  /// 한 장을 넘기는 데 드는 거리. 화면 높이에 대한 비율
  static const _pageFraction = 0.4;

  late final PageController _controller;
  int _focused = 0;

  WalletStackListViewModel get _viewModel => context.read<WalletStackListViewModel>();

  @override
  void initState() {
    super.initState();
    _focused = context.read<WalletStackListViewModel>().indexOf(widget.initialWalletId);
    _controller = PageController(initialPage: _focused, viewportFraction: _pageFraction)..addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _page =>
      _controller.hasClients && _controller.position.haveDimensions ? _controller.page ?? 0 : _focused.toDouble();

  void _onScroll() {
    final index = _page.round();
    if (index == _focused) return;
    setState(() => _focused = index);
    final wallets = _viewModel.wallets;
    if (index < wallets.length) widget.onFocusWallet?.call(wallets[index].id);
  }

  void _openWallet(WalletItemBase wallet) {
    Navigator.pushNamed(
      context,
      AppRouteNames.walletDetail,
      arguments: WalletDetailRouteArgs(id: wallet.id, entryPoint: kEntryPointWalletList),
    );
  }

  void _addWallet() => openWalletAddFor(context, _viewModel.kind);

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final viewModel = context.watch<WalletStackListViewModel>();
    final wallets = viewModel.wallets;
    final routeAnimation = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final fan = CurvedAnimation(parent: routeAnimation, curve: Curves.easeOutCubic);
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return Scaffold(
      backgroundColor: colors.background,
      extendBodyBehindAppBar: true,
      appBar: CoconutAppBar.build(
        context: context,
        title: widget.title,
        actionButtonList: [
          CupertinoButton(
            key: const Key('wallet-stack-list-add'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: _addWallet,
            child: Icon(CupertinoIcons.add, color: colors.primaryText, size: 26),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight - topInset;
            final extent = math.min(width * (1 - _cardLeftRatio), height * 0.46);
            final cardLeft = width * _cardLeftRatio;
            final centerY = topInset + height * 0.4;
            final cardRect = Rect.fromLTWH(cardLeft, centerY - extent / 2, extent, extent);
            final count = wallets.length + 1;
            return GestureDetector(
              key: const Key('wallet-stack-list-wheel'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                if (!cardRect.contains(details.localPosition)) return;
                final index = _page.round();
                index < wallets.length ? _openWallet(wallets[index]) : _addWallet();
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_controller, fan]),
                      builder: (context, _) {
                        final page = _page;
                        final order = [
                          for (var i = 0; i < count; i++)
                            if ((i - page).abs() < 3.5) i,
                        ]..sort((a, b) => (b - page).abs().compareTo((a - page).abs()));
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final i in order)
                              _positioned(
                                context,
                                index: i,
                                distance: i - page,
                                fan: fan.value,
                                rect: cardRect,
                                child:
                                    i < wallets.length
                                        ? _walletCard(context, viewModel, wallets[i])
                                        : const _AddWalletCard(),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: PageView.builder(
                      key: const Key('wallet-stack-list-pager'),
                      controller: _controller,
                      scrollDirection: Axis.vertical,
                      itemCount: count,
                      itemBuilder: (_, __) => const SizedBox.expand(),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    width: cardLeft,
                    top: centerY - 60,
                    height: 120,
                    child: IgnorePointer(child: FadeTransition(opacity: fan, child: _indicator(context, count))),
                  ),
                  Positioned(
                    left: 28,
                    right: 28,
                    bottom: 28,
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity: fan,
                        child:
                            _focused < wallets.length
                                ? _WalletFacts(
                                  key: ValueKey('wallet-stack-list-facts-${wallets[_focused].id}'),
                                  viewModel: viewModel,
                                  wallet: wallets[_focused],
                                )
                                : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// [distance]만큼 가운데에서 떨어진 카드를 원호 위에 놓는다. 펼쳐지기 전([fan] 0)에는 모두 가운데 카드 뒤에 겹쳐 있다.
  Widget _positioned(
    BuildContext context, {
    required int index,
    required double distance,
    required double fan,
    required Rect rect,
    required Widget child,
  }) {
    final away = distance.abs();
    final radius = rect.width * 1.6;
    final angle = distance * _step * fan;
    final pivot = Offset(rect.center.dx + radius, rect.center.dy);
    final center = Offset(pivot.dx - radius * math.cos(angle), pivot.dy + radius * math.sin(angle));
    final scale = 1 - 0.08 * math.min(away, 2.0).toDouble();
    final blur = 4 * math.min(away, 1.0).toDouble();
    final opacity = (1 - math.max(0.0, away - 1.6) / 1.4).clamp(0.0, 1.0) * (away < 0.5 ? 1.0 : fan);
    Widget card = child;
    if (blur > 0.1) card = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: card);
    return Positioned(
      key: ValueKey('wallet-stack-list-slot-$index'),
      left: center.dx - rect.width / 2,
      top: center.dy - rect.height / 2,
      width: rect.width,
      height: rect.height,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(angle: -angle, child: Transform.scale(scale: scale, child: card)),
      ),
    );
  }

  Widget _walletCard(BuildContext context, WalletStackListViewModel viewModel, WalletItemBase wallet) {
    final last = viewModel.lastTransactionTime(wallet);
    final card = _ScaledCard(
      child: WalletCard(
        key: ValueKey('wallet-stack-list-card-${wallet.id}'),
        wallet: wallet,
        appearance: WalletAppearance.of(wallet),
        size: WalletCardSize.small,
        balanceDisplay: viewModel.balanceText(wallet),
        secondaryText: last == null ? null : formatHomeRelativeTime(last, DateTime.now()),
      ),
    );
    final tagOf = widget.heroTagOf;
    if (tagOf == null) return card;
    return Hero(tag: tagOf(wallet.id), flightShuttleBuilder: _shuttle, child: card);
  }

  /// 스택 카드에서 휠 카드로 내용이 겹쳐 바뀐다. 4×2 스택이면 날아가는 동안 정사각형으로 줄어든다.
  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final push = direction == HeroFlightDirection.push;
    final stackHero = (push ? fromHeroContext : toHeroContext).widget as Hero;
    final wheelContext = push ? toHeroContext : fromHeroContext;
    final wheelHero = wheelContext.widget as Hero;
    final progress = CurvedAnimation(
      parent: ModalRoute.of(wheelContext)?.animation ?? animation,
      curve: const Interval(0.15, 0.85),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(opacity: ReverseAnimation(progress), child: stackHero.child),
        FadeTransition(opacity: progress, child: wheelHero.child),
      ],
    );
  }

  Widget _indicator(BuildContext context, int count) {
    final colors = context.coconutColors;
    return Center(
      child: Column(
        key: const Key('wallet-stack-list-indicator'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(vertical: 2.5),
              width: 6,
              height: i == _focused ? 20 : 6,
              decoration: BoxDecoration(
                color: i == _focused ? colors.pageIndicatorActive : colors.pageIndicatorInactive,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

/// 휠 카드는 기본 크기로 그린 뒤 칸에 맞게 키워, 글자 크기가 카드와 함께 커진다.
class _ScaledCard extends StatelessWidget {
  final Widget child;

  const _ScaledCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.cover,
      alignment: Alignment.topLeft,
      clipBehavior: Clip.hardEdge,
      child: SizedBox.square(dimension: WalletStackListScreen.cardBaseExtent, child: child),
    );
  }
}

class _AddWalletCard extends StatelessWidget {
  const _AddWalletCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return _ScaledCard(
      child: DecoratedBox(
        key: const Key('wallet-stack-list-add-card'),
        decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(20)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: colors.surfaceMuted, shape: BoxShape.circle),
                child: Icon(CupertinoIcons.add, size: 22, color: colors.primaryText),
              ),
              const SizedBox(height: 10),
              Text(
                t.home_widgets.add_wallet,
                style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletFacts extends StatelessWidget {
  final WalletStackListViewModel viewModel;
  final WalletItemBase wallet;

  const _WalletFacts({super.key, required this.viewModel, required this.wallet});

  @override
  Widget build(BuildContext context) {
    final last = viewModel.lastTransactionTime(wallet);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _fact(context, t.wallet_stack_list.utxos, '${viewModel.utxoCount(wallet)}'),
        _fact(
          context,
          t.wallet_stack_list.last_transaction,
          last == null ? t.wallet_stack_list.no_transaction : formatHomeRelativeTime(last, DateTime.now()),
        ),
        if (viewModel.typeLabel(wallet) case final type?) _fact(context, t.wallet_stack_list.type, type, last: true),
      ],
    );
  }

  Widget _fact(BuildContext context, String label, String value, {bool last = false}) {
    final colors = context.coconutColors;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CoconutTypography.body2_14.copyWith(color: colors.secondaryText)),
          const SizedBox(height: 2),
          Text(value, style: CoconutTypography.heading4_18_Bold.copyWith(color: colors.primaryText)),
        ],
      ),
    );
  }
}
