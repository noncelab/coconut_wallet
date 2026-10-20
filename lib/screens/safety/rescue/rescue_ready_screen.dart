import 'package:coconut_design_system/coconut_design_system.dart'
    show CoconutLayout, CoconutTypography, Sizes, TextColorExtension;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/safety/assist/assist_move_screens.dart'
    show AssistSignerGuideScreen, ensurePremium;
import 'package:coconut_wallet/services/safety/safety_assist.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart' show formatHomeRelativeTime;
import 'package:coconut_wallet/widgets/features/safety/safety_address_entry_sheet.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_verification_line.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_icon_small.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 비상 이동 준비(Premium, UI_SPEC §10.8). 지갑마다 비상 목적지를 정하고 초안 상태를 본다.
/// 초안은 서명하지 않고, 사고 때 [지금 이동]은 검토 화면을 거쳐 기존 보내기 확인으로만 간다
class RescueReadyScreen extends StatefulWidget {
  const RescueReadyScreen({super.key, this.walletId});

  /// 지갑 정보 "비상 목적지" 행에서 열면 그 지갑의 목적지 시트를 바로 연다(구독 중이거나 목적지가 있을 때만)
  final int? walletId;

  static const routeName = '/wallet-health/rescue';

  static Future<void> open(BuildContext context, {int? walletId}) => Navigator.of(context).push(
    CupertinoPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => RescueReadyScreen(walletId: walletId),
    ),
  );

  @override
  State<RescueReadyScreen> createState() => _RescueReadyScreenState();
}

class _RescueReadyScreenState extends State<RescueReadyScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final walletId = widget.walletId;
    if (walletId != null) {
      // 열자마자 페이월을 띄우지 않는다(POLISH D8). 무료 사용자는 화면을 보고, 지갑을 누르면 그때 페이월
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final rescue = context.read<RescueReadyProvider?>();
        final wallet = context.read<WalletProvider?>()?.walletItemList.firstWhereOrNull((w) => w.id == walletId);
        if (rescue == null || wallet == null) return;
        if (rescue.isPremiumActive || rescue.destinationOf(walletId) != null) _choose(wallet);
      });
    }
  }

  Future<void> _choose(WalletItemBase wallet) async {
    final rescue = context.read<RescueReadyProvider?>();
    if (rescue == null || _busy) return;
    _busy = true;
    try {
      // 목적지 정하기·바꾸기는 Premium만(새 자동화): 목적지가 없으면 페이월이 시트보다 먼저, 저장에서는 막지 않는다(D8).
      // 정해 둔 목적지 지우기(정하지 않음)는 구독과 무관하게 언제나(G-R6). 만료돼도 초안·지금 이동은 그대로
      final current = rescue.destinationOf(wallet.id);
      if (current == null && !await ensurePremium(context)) return;
      if (!mounted) return;
      final canChange = rescue.isPremiumActive;
      final options = [
        for (final d in rescue.destinationOptions(wallet.id)) _DestinationOption(d),
        if (current != null) const _DestinationOption(null),
      ];
      final initial = options.firstWhereOrNull((o) => o.isCurrent(current) && o.canPreselect)?.id;
      final colors = context.coconutColors;
      final picked = await CommonBottomSheets.showSelectableDraggableSheet<_DestinationOption>(
        context: context,
        title: t.premium.rescue.destination,
        screenName: '/wallet-health/rescue/destination',
        // 지갑마다 줄이 있고 큰 글자에서 줄이 길어져, 반 높이로 열면 여러 쪽을 넘겨야 한다(X10).
        // 앱의 받는 주소 선택 시트와 같은 높이: 0.9로 열고 0.6까지 내릴 수 있다
        initialChildSize: 0.9,
        minChildSize: 0.599,
        maxChildSize: 0.9,
        childBuilder: (scrollController) {
          final list = SelectableBottomSheetBody<_DestinationOption>(
            scrollController: scrollController,
            items: options,
            getItemId: (o) => o.id,
            initiallySelectedId: initial,
            confirmText: t.premium.rescue.save,
            backgroundColor: colors.surfaceBottomSheet,
            itemBuilder:
                (context, option, isSelected, onTap) => SelectableBottomSheetTextItem(
                  key: Key('rescue-destination-${option.id}'),
                  isSelected: isSelected,
                  // 구독이 끝났으면 지우기만(지금 목적지는 선택된 채로 보인다). 자물쇠·경고색 없이 흐리게만
                  isDisabled: !canChange && option.assist != null && option.id != initial,
                  onTap: onTap,
                  reserveCheckIconSpace: true,
                  child: _DestinationOptionView(option),
                ),
          );
          if (canChange) return list;
          // 흐린 목적지가 왜 흐린지 중립 한 줄(버튼·가격 없음). 글 시작을 목록 글과 맞춘다(목록 16 + 줄 16)
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Sizes.size32, 0, Sizes.size32, Sizes.size8),
                child: Text(
                  safetyKoText(t.premium.rescue.premium_note),
                  key: const Key('rescue-destination-premium-note'),
                  style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                ),
              ),
              Expanded(child: list),
            ],
          );
        },
      );
      if (picked == null || !mounted) return;

      final RescueDestination? next;
      switch (picked.assist) {
        case null:
          next = null; // 정하지 않음
        case AssistDestination(:final wallet?):
          next = RescueDestination(walletId: wallet.id, setAt: DateTime.now());
        case AssistDestination(kind: AssistDestinationKind.newHotWallet):
          final walletId = await _createHotWallet();
          if (walletId == null || !mounted) return;
          next = RescueDestination(walletId: walletId, setAt: DateTime.now());
        case AssistDestination(kind: AssistDestinationKind.vaultNewWallet):
          final walletId = await _addSignerWallet(wallet);
          if (walletId == null || !mounted) return;
          next = RescueDestination(walletId: walletId, setAt: DateTime.now());
        case AssistDestination(address: _?):
          return; // 지금 목적지 그대로
        case _:
          final address = await _enterAddress(wallet.id);
          if (address == null || !mounted) return;
          next = RescueDestination(address: address, setAt: DateTime.now());
      }
      await rescue.setDestination(wallet.id, next);
      vibrateLight();
      if (!mounted) return;
      CoconutToast.showToast(
        context: context,
        text: next == null ? t.premium.rescue.turned_off_toast : t.premium.rescue.saved_toast,
        isVisibleIcon: true,
        iconPath: CommonStateIconPath.circleInfo,
      );
    } on StateError {
      // 시트를 연 사이 구독이 끝남
    } on ArgumentError {
      if (mounted) _warn(t.premium.rescue.destination_invalid);
    } finally {
      _busy = false;
    }
  }

  /// 확인 창 → 기존 핫월렛 생성(12단어, 백업 필요 상태라 기존 백업 경고 대상). 취소·실패면 null
  Future<int?> _createHotWallet() async {
    final copy = t.premium.rescue;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => CoconutPopup(
            key: const Key('rescue-hot-wallet-confirm'),
            title: safetyKoText(copy.hot_confirm_title),
            description: safetyKoText(copy.hot_confirm_body),
            languageCode: LocaleSettings.currentLocale.languageCode,
            leftButtonText: t.cancel,
            rightButtonText: copy.hot_confirm_create,
            onTapLeft: () => Navigator.pop(dialogContext, false),
            onTapRight: () => Navigator.pop(dialogContext, true),
          ),
    );
    if (confirmed != true || !mounted) return null;
    try {
      return await SafetyAssist.createHotWallet(context);
    } catch (_) {
      if (mounted) _warn(t.safety_guide.move.create_failed);
      return null;
    }
  }

  /// 볼트(서명 기기)에서 새 지갑 만들기 안내 → 지갑 추가 스캔(Assist와 같은 화면, UI_SPEC §10.8). 추가해서 받아들여진 지갑 id,
  /// 그만두면 null. 같은 니모닉·사용 주의 등 제외 지갑은 안내 화면이 받지 않는다
  Future<int?> _addSignerWallet(WalletItemBase source) async {
    final here = ModalRoute.of(context);
    int? added;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        settings: const RouteSettings(name: '${RescueReadyScreen.routeName}/signer-new-wallet'),
        builder:
            (_) => AssistSignerGuideScreen(
              sourceWallet: source,
              onAdded: (context, wallet) {
                added = wallet.id;
                // 안내·추가 화면을 닫고 이 화면으로(지갑 추가 흐름이 무엇을 쌓았든)
                Navigator.of(context).popUntil((route) => route == here || route.isFirst);
              },
            ),
      ),
    );
    return added;
  }

  /// 주소 직접 입력(Assist와 같은 공용 시트, POLISH H6/I5). 지금 네트워크 형식 + 이 지갑·제외 지갑 주소 거절.
  /// 만들어 둔 주소 목록 밖의 제외 지갑 주소는 저장을 누를 때 한 번 더 확인한다(무거워서). 확인하지 못하면 받지 않는다
  Future<String?> _enterAddress(int walletId) {
    final rescue = context.read<RescueReadyProvider>();
    final selfAddress = t.premium.destination.error_self_address;
    return showSafetyAddressEntrySheet(
      context,
      screenName: '/wallet-health/rescue/address',
      actionText: t.premium.rescue.save,
      fieldKey: const Key('rescue-address-field'),
      actionKey: const Key('rescue-address-save'),
      validate: (address) {
        final check = rescue.checkAddress(walletId, address);
        return check.format?.message ?? (check.ownedByExcluded ? selfAddress : null);
      },
      confirm:
          (address) async =>
              await rescue.derivesFromExcludedWallet(walletId, address).catchError((_) => true) ? selfAddress : null,
    );
  }

  Future<void> _moveNow(int walletId) async {
    final rescue = context.read<RescueReadyProvider?>();
    if (rescue == null || _busy) return;
    _busy = true;
    try {
      await rescue.moveNow(context, walletId);
    } finally {
      _busy = false;
    }
  }

  void _warn(String text) => CoconutToast.showToast(
    context: context,
    text: text,
    isVisibleIcon: true,
    iconPath: CommonStateIconPath.triangleWarning,
    level: CoconutToastLevel.warning,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final rescue = context.watch<RescueReadyProvider?>();
    final walletProvider = context.watch<WalletProvider?>();
    // 사건·사용 주의·검증 결과가 바뀌면 행 상태와 지금 이동이 달라진다(SafetyProvider가 저장소에 쓰고 알린다)
    context.watch<SafetyProvider?>();
    final unit = context.select<PreferenceProvider?, BitcoinUnit>((p) => p?.currentUnit ?? BitcoinUnit.btc);
    final copy = t.premium.rescue;
    // 잔액 있는 지갑 먼저(같으면 목록 순서)
    final wallets = [...?walletProvider?.walletItemList];
    final funded = {for (final w in wallets) w.id: walletProvider!.getWalletBalance(w.id).total > 0};
    mergeSort(wallets, compare: (a, b) => (funded[b.id]! ? 1 : 0) - (funded[a.id]! ? 1 : 0));

    return Scaffold(
      key: const Key('rescue-ready-screen'),
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, title: copy.name, backgroundColor: colors.background),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 모든 사용자에게 같은 머리(POLISH §2.4)
              const Align(alignment: AlignmentDirectional.centerStart, child: PremiumChip()),
              CoconutLayout.spacing_200h,
              Text(
                safetyKoText(copy.wallets_title),
                style: CoconutTypography.heading3_21_Bold.setColor(colors.primaryText),
              ),
              CoconutLayout.spacing_300h,
              Text(safetyKoText(copy.description), style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
              // 구독 없음·만료일 때만(D8). 확인 중에는 구독자에게 깜박이지 않게 숨긴다
              if (rescue?.lacksPremium ?? false) ...[
                CoconutLayout.spacing_200h,
                Text(
                  safetyKoText(copy.premium_note),
                  key: const Key('rescue-premium-note'),
                  style: CoconutTypography.body3_12.setColor(colors.secondaryTextStrong),
                ),
              ],
              CoconutLayout.spacing_200h,
              Text(
                safetyKoText(t.premium.destination.excluded_note_setup),
                style: CoconutTypography.body3_12.setColor(colors.secondaryText),
              ),
              CoconutLayout.spacing_600h,
              if (rescue != null)
                for (final (wallet, status) in [for (final w in wallets) (w, rescue.statusOf(w.id))]) ...[
                  SafetyChoiceRow(
                    key: Key('rescue-wallet-${wallet.id}'),
                    backgroundColor: colors.surface,
                    leading: WalletIconSmall(
                      walletImportSource: wallet.walletImportSource,
                      colorIndex: wallet.colorIndex,
                      iconIndex: wallet.iconIndex,
                      isHotWallet: wallet.hasLocalKey,
                    ),
                    // 부제에 주소 목적지가 들어가므로 R1은 이 화면이 부분마다 한다(주소에는 이음 문자 없이)
                    keepWords: false,
                    title: safetyKoText(wallet.name),
                    subtitle: _statusLine(rescue, wallet.id, status),
                    subtitleColor: _needsAttention.contains(status) ? colors.warningText : null,
                    below:
                        status == RescueStatus.ready ? _FeeLine(fee: rescue.drafts[wallet.id]?.fee, unit: unit) : null,
                    onTap: () => _choose(wallet),
                  ),
                  // 사고 때만. 이 화면에서 겨루는 버튼이 없어 앱 표준 버튼(POLISH I3)
                  if (rescue.canMoveNow(wallet.id) && rescue.hasCriticalIncident(wallet.id)) ...[
                    CoconutLayout.spacing_200h,
                    InlineActionButton(
                      key: Key('rescue-move-now-${wallet.id}'),
                      text: safetyKoText(copy.move_now),
                      onPressed: () => _moveNow(wallet.id),
                    ),
                  ],
                  CoconutLayout.spacing_200h,
                ],
              CoconutLayout.spacing_200h,
              Text(safetyKoText(copy.on_device), style: CoconutTypography.caption_10.setColor(colors.secondaryText)),
            ],
          ),
        ),
      ),
    );
  }

  /// 행 부제를 warningText로(갱신 실패·목적지 사용 불가)
  static const _needsAttention = {
    RescueStatus.invalidDestination,
    RescueStatus.failed,
    RescueStatus.tooSmall,
    RescueStatus.unavailable,
  };

  /// 행 부제: "→ 목적지 · 초안 상태". 준비된 초안의 수수료는 아래 따로 한 줄([_FeeLine])
  String _statusLine(RescueReadyProvider rescue, int walletId, RescueStatus status) {
    final copy = t.premium.rescue;
    if (status == RescueStatus.notSet) return safetyKoText(copy.not_set);
    final draft = rescue.drafts[walletId];
    final time = draft == null ? null : formatHomeRelativeTime(draft.preparedAt, DateTime.now());
    final detail = switch (status) {
      RescueStatus.notSet => copy.not_set,
      RescueStatus.invalidDestination => copy.destination_invalid,
      RescueStatus.paused => time == null ? copy.draft_paused_none : copy.draft_paused(time: time),
      RescueStatus.pending => copy.draft_pending,
      RescueStatus.failed => copy.draft_failed,
      RescueStatus.ready => copy.draft_ready(time: time ?? ''),
      RescueStatus.noBalance => copy.draft_no_balance,
      RescueStatus.tooSmall => copy.draft_too_small,
      RescueStatus.unavailable =>
        draft?.blocker == RescueReadyProvider.feeTooHighBlocker
            ? t.premium.assist.fee_too_high(percent: SweepFee.maxSharePercent)
            : copy.draft_unavailable,
    };
    // 단어 중간 줄바꿈 금지(R1)는 부분마다. 주소 목적지는 그대로(이음 문자가 대조·복사를 바꾼다)
    final destination = rescue.destinationLabel(walletId);
    final isAddress = rescue.destinationOf(walletId)?.address != null;
    return [
      if (destination != null) '→ ${isAddress ? destination : safetyKoText(destination)}',
      safetyKoText(detail),
    ].join(' · ');
  }
}

/// 준비된 초안의 예상 수수료 한 줄. 숫자가 줄 사이로 갈리지 않게 줄여 맞춘다(POLISH R2).
/// 초안을 만들 때의 값이고, 잔액 숨김이어도 보인다(잔액이 아님)
class _FeeLine extends StatelessWidget {
  const _FeeLine({required this.fee, required this.unit});

  final int? fee;
  final BitcoinUnit unit;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      '${t.estimated_fee} ${unit.displayBitcoinAmount(fee, withUnit: true)}',
      style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
    ),
  );
}

/// 목적지 시트 한 줄. [assist]가 null이면 "정하지 않음"
class _DestinationOption {
  const _DestinationOption(this.assist);

  final AssistDestination? assist;

  String get id => switch (assist) {
    null => 'off',
    AssistDestination(:final wallet?) => 'wallet:${wallet.id}',
    AssistDestination(kind: AssistDestinationKind.newHotWallet) => 'hot:new',
    AssistDestination(kind: AssistDestinationKind.vaultNewWallet) => 'vault:new',
    AssistDestination(address: _?) => 'address:current',
    _ => 'address:new',
  };

  /// MFP 없는 지갑·이 기기 지갑은 미리 고르지 않는다
  bool get canPreselect => assist?.canPreselect ?? false;

  bool isCurrent(RescueDestination? current) => switch (assist) {
    _ when current == null => false,
    AssistDestination(:final wallet?) => wallet.id == current.walletId,
    AssistDestination(:final address?) => address == current.address,
    _ => false,
  };
}

class _DestinationOptionView extends StatelessWidget {
  const _DestinationOptionView(this.option);

  final _DestinationOption option;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final d = option.assist;
    final copy = t.premium.destination;
    // 주소에는 단어 이음 문자를 넣지 않는다(R1)
    final title = switch (d) {
      null => safetyKoText(t.premium.rescue.turn_off),
      AssistDestination(:final wallet?) => safetyKoText(wallet.name),
      AssistDestination(kind: AssistDestinationKind.newHotWallet) => safetyKoText(copy.new_hot_wallet),
      AssistDestination(kind: AssistDestinationKind.vaultNewWallet) => safetyKoText(copy.vault_new_wallet),
      AssistDestination(:final address?) => shortenAddress(address),
      _ => safetyKoText(copy.enter_address),
    };
    final subtitle = switch (d) {
      AssistDestination(cannotVerifySeed: true) => null, // 아래 정보 줄
      AssistDestination(kind: AssistDestinationKind.watchOnlyWallet) => copy.watch_only_wallets_body,
      AssistDestination(kind: AssistDestinationKind.newHotWallet) => copy.new_hot_wallet_body,
      AssistDestination(kind: AssistDestinationKind.vaultNewWallet) => copy.vault_new_wallet_body,
      AssistDestination(address: _?) => copy.enter_address,
      _ => null,
    };
    final wallet = d?.wallet;
    final checkable = wallet != null && !wallet.hasLocalKey;
    final verification = checkable ? SafetyAssist.verification(context.watch<SafetyProvider?>()?.state, wallet) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(child: Text(title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText))),
            if (d?.isRescueDestination ?? false) ...[
              CoconutLayout.spacing_200w,
              Text(t.premium.rescue.destination, style: CoconutTypography.caption_10_Bold.setColor(colors.premiumText)),
            ],
          ],
        ),
        if (subtitle != null) ...[
          CoconutLayout.spacing_50h,
          Text(safetyKoText(subtitle), style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
        ],
        if (d?.cannotVerifySeed ?? false)
          _NoteLine(
            iconPath: CommonStateIconPath.circleInfo,
            iconColor: colors.iconSecondary,
            text: copy.unknown_seed,
            textColor: colors.secondaryText,
          ),
        // 이 기기 지갑 경고. 이미 있는 핫월렛은 "이 지갑도", 새로 만들 핫월렛은 "여기 만든 지갑도"(POLISH I9). 막지는 않는다
        if (d?.onThisDevice ?? false)
          _NoteLine(
            iconPath: CommonStateIconPath.triangleWarning,
            iconColor: colors.warningText,
            text: d?.wallet != null ? copy.existing_hot_wallet_warning : copy.new_hot_wallet_warning,
            textColor: colors.warningText,
          ),
        // 서명 기기 검증 표시(POLISH H8, Assist와 같은 공용 줄). 미확인은 경보가 아니라 안내
        if (checkable)
          Padding(
            padding: const EdgeInsets.only(top: Sizes.size4),
            child: SafetyVerificationLine(verification: verification),
          ),
      ],
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.iconPath, required this.iconColor, required this.text, required this.textColor});

  static const _iconSize = 12.0;

  final String iconPath;
  final Color iconColor;
  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    const style = CoconutTypography.body3_12;
    // 아이콘을 첫 줄 가운데에 맞춘다(글자 배율 반영, POLISH R3·SafetyNumberedRow와 같은 계산)
    final lineHeight = MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;
    return Padding(
      padding: const EdgeInsets.only(top: Sizes.size4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: (lineHeight - _iconSize) / 2),
            child: SvgPicture.asset(
              iconPath,
              width: _iconSize,
              height: _iconSize,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
          CoconutLayout.spacing_100w,
          Expanded(child: Text(safetyKoText(text), style: style.setColor(textColor))),
        ],
      ),
    );
  }
}
