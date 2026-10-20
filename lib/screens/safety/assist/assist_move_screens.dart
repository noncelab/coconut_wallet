import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutUnderlinedButton;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/wallet_lifecycle_event.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/routes/route_observer.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_actions.dart';
import 'package:coconut_wallet/screens/premium/premium_paywall_screen.dart';
import 'package:coconut_wallet/screens/safety/assist/safety_assist_screen.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/services/safety/safety_assist.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_guide_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 새 지갑 자동 생성 같은 자동화를 새로 시작할 때만 구독을 확인한다(만료돼도 이미 만든 것은 막지 않음)
/// 페이월이 true를 돌려줘도 그 사이 만료·취소됐을 수 있어서 결과 값이 아니라 지금 권한을 다시 읽는다(G-R4)
Future<bool> ensurePremium(BuildContext context) async {
  bool active() => context.read<EntitlementService?>()?.state.value.isActive == true;
  if (active()) return true;
  await PremiumPaywallScreen.open(context);
  return context.mounted && active();
}

/// 비트코인 옮기기 진행(move-progress): 이 기기에 새 핫월렛 → 받기 주소 → 거래 준비 → 마무리 → 검토
class AssistNewHotWalletScreen extends StatefulWidget {
  const AssistNewHotWalletScreen({super.key, required this.session});

  final AssistSession session;

  @override
  State<AssistNewHotWalletScreen> createState() => _AssistNewHotWalletScreenState();
}

class _AssistNewHotWalletScreenState extends State<AssistNewHotWalletScreen> {
  int _step = 0;
  bool _failed = false;

  /// 지갑을 만든 뒤 실패하면 다시 시도할 때 또 만들지 않는다
  int? _walletId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    setState(() => _failed = false);
    final walletProvider = context.read<WalletProvider>();
    final reduceMotion = safetyReduceMotion(context);
    Future<void> advance() async {
      if (!reduceMotion) await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _step++);
    }

    try {
      if (_walletId == null) {
        if (!await ensurePremium(context) || !mounted) return _leave();
        final id = await SafetyAssist.createHotWallet(context);
        if (!mounted) return;
        if (id == null) return _leave(); // 기기 비밀번호가 없어 기존 안내에서 멈춤
        _walletId = id;
      }
      await advance();
      final wallet = walletProvider.getWalletById(_walletId!);
      final address = SafetyAssist.receiveAddressOf(walletProvider, wallet);
      await advance();
      // 구성만 확인한다(서명·전송 없음). 실제 거래는 검토 뒤 기존 보내기 확인에서 다시 만든다
      SweepBuilder.build(widget.session.plan, wallet: widget.session.wallet, destination: address);
      await advance();
      await advance();
      if (!mounted) return;
      vibrateLight();
      unawaited(
        Navigator.of(context).pushReplacement(
          assistRoute(
            'move-review',
            AssistReviewScreen(
              session: widget.session,
              destination: AssistTarget(address: address, wallet: wallet, isNewWallet: true),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _leave() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.safety_guide.move;
    final colors = context.coconutColors;
    return SafetyGuidePage(
      key: const Key('safety-assist-move-progress'),
      progress: 0.25,
      title: strings.title,
      buttonText: t.retry,
      onButton: _failed ? _run : null,
      children: [
        SafetyStepList(
          steps: [strings.step_create_wallet, strings.step_address, strings.step_prepare, strings.step_finalize],
          activeIndex: _step,
          failed: _failed,
        ),
        if (_failed) ...[
          CoconutLayout.spacing_600h,
          SafetyStatusBanner(
            key: const Key('safety-assist-move-failed'),
            background: colors.dangerSurface,
            iconPath: CommonStateIconPath.triangleWarning,
            iconColor: colors.danger,
            title: _walletId == null ? strings.create_failed : strings.prepare_failed,
            body: t.errors.network_error,
          ),
        ],
      ],
    );
  }
}

/// 서명 기기에서 새 지갑 만들기 안내(signer-new-wallet)
class AssistSignerGuideScreen extends StatelessWidget {
  const AssistSignerGuideScreen({super.key, required this.session});

  final AssistSession session;

  @override
  Widget build(BuildContext context) {
    final strings = t.safety_guide.step2_watch_only;
    final colors = context.coconutColors;
    final isVault = session.wallet.walletImportSource == WalletImportSource.coconutVault;
    return SafetyGuidePage(
      key: const Key('safety-assist-signer-guide'),
      progress: 0.25,
      iconPath: FeatureWalletIconPath.walletAddDefault,
      title: isVault ? strings.vault_title : strings.device_guide_title,
      description: strings.no_reuse(wallet: session.wallet.name),
      buttonText: strings.created,
      onButton: () => Navigator.of(context).push(assistRoute('add-wallet', AssistAddWalletScreen(session: session))),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(CoconutStyles.radius_250),
          ),
          child: Column(
            children: [
              for (final (i, text) in [strings.guide_1, strings.guide_2, strings.guide_3, strings.guide_4].indexed) ...[
                if (i > 0) CoconutLayout.spacing_300h,
                SafetyNumberedRow(number: i + 1, title: text),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 새 지갑 추가(add-wallet) → 기존 지갑 추가 스캔 흐름. 추가가 끝나 이 화면으로 돌아오면 "새 지갑 추가됨"으로.
/// 사고 지갑과 같은 니모닉(MFP)이면 받지 않는다
class AssistAddWalletScreen extends StatefulWidget {
  const AssistAddWalletScreen({super.key, required this.session});

  final AssistSession session;

  @override
  State<AssistAddWalletScreen> createState() => _AssistAddWalletScreenState();
}

class _AssistAddWalletScreenState extends State<AssistAddWalletScreen> with RouteAware {
  StreamSubscription<WalletLifecycleEvent>? _events;
  int? _addedWalletId;
  bool _sameSeed = false;
  ModalRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    _events = context.read<WalletProvider>().lifecycleEvents.listen((event) {
      if (event is WalletAdded) _addedWalletId = event.walletId;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route && route != null) {
      if (_route != null) routeObserver.unsubscribe(this);
      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// 지갑 추가 흐름(지갑 상세까지)에서 돌아왔을 때. 내비게이터가 pop을 처리하는 중이라 다음 프레임에 넘어간다
  @override
  void didPopNext() => WidgetsBinding.instance.addPostFrameCallback((_) => _onReturned());

  void _onReturned() {
    final id = _addedWalletId;
    if (id == null || !mounted) return;
    _addedWalletId = null;
    final walletProvider = context.read<WalletProvider>();
    final WalletItemBase wallet;
    try {
      wallet = walletProvider.getWalletById(id);
    } catch (_) {
      return;
    }
    final allowed = SafetyAssist.destinations(
      incidentWallet: widget.session.wallet,
      wallets: [widget.session.wallet, wallet],
      safetyState: context.read<SafetyProvider?>()?.state,
    ).any((d) => d.wallet?.id == id);
    if (!allowed) {
      vibrateLightDouble();
      setState(() => _sameSeed = true);
      return;
    }
    Navigator.of(
      context,
    ).pushReplacement(assistRoute('wallet-added', AssistWalletAddedScreen(session: widget.session, wallet: wallet)));
  }

  void _openAddFlow() {
    setState(() => _sameSeed = false);
    // 핫월렛 사고면 볼트에서, 보기 전용이면 같은 종류의 서명 기기에서 만든 새 지갑을 추가한다
    final source =
        widget.session.wallet.hasLocalKey ? WalletImportSource.coconutVault : widget.session.wallet.walletImportSource;
    WalletAddActions.openSource(context, Navigator.of(context), source);
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.safety_guide.step2_watch_only;
    final colors = context.coconutColors;
    return SafetyGuidePage(
      key: const Key('safety-assist-add-wallet'),
      progress: 0.25,
      iconPath: FeatureWalletIconPath.walletAddDefault,
      title: strings.add_title,
      description: strings.add_body,
      buttonText: strings.add_button,
      onButton: _openAddFlow,
      children: [
        if (_sameSeed)
          SafetyStatusBanner(
            key: const Key('safety-assist-add-same-seed'),
            background: colors.dangerSurface,
            iconPath: CommonStateIconPath.triangleWarning,
            iconColor: colors.danger,
            title: strings.same_seed_error,
            body: t.premium.destination.excluded_note,
          ),
      ],
    );
  }
}

/// 새 지갑 추가됨(wallet-added) → 거래 만들기 → 검토
class AssistWalletAddedScreen extends StatelessWidget {
  const AssistWalletAddedScreen({super.key, required this.session, required this.wallet});

  final AssistSession session;
  final WalletItemBase wallet;

  @override
  Widget build(BuildContext context) {
    final strings = t.safety_guide.step2_watch_only;
    return SafetyResultPage(
      key: const Key('safety-assist-wallet-added'),
      progress: 0.25,
      title: strings.added_title,
      description: strings.added_body,
      buttonText: strings.create_transaction,
      onButton:
          () => Navigator.of(context).push(
            assistRoute(
              'move-review',
              AssistReviewScreen(
                session: session,
                destination: AssistTarget(
                  address: SafetyAssist.receiveAddressOf(context.read<WalletProvider>(), wallet),
                  wallet: wallet,
                  isNewWallet: true,
                ),
              ),
            ),
          ),
      children: [AssistWalletCard(wallet: wallet)],
    );
  }
}
