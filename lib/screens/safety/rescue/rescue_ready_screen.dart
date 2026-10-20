import 'package:coconut_design_system/coconut_design_system.dart'
    show CoconutLayout, CoconutStyles, CoconutTypography, Sizes, TextColorExtension;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/safety/assist/assist_move_screens.dart' show ensurePremium;
import 'package:coconut_wallet/services/safety/safety_assist.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/utils/address_scan_util.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart' show formatHomeRelativeTime;
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
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

  /// 지갑 정보 "비상 목적지" 행에서 열면 그 지갑의 목적지 시트를 바로 연다
  final int? walletId;

  static Future<void> open(BuildContext context, {int? walletId}) => Navigator.of(context).push(
    CupertinoPageRoute<void>(
      settings: const RouteSettings(name: '/wallet-health/rescue'),
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final wallet = context.read<WalletProvider?>()?.walletItemList.firstWhereOrNull((w) => w.id == walletId);
        if (mounted && wallet != null) _choose(wallet);
      });
    }
  }

  Future<void> _choose(WalletItemBase wallet) async {
    final rescue = context.read<RescueReadyProvider?>();
    if (rescue == null || _busy) return;
    _busy = true;
    try {
      // 목적지 정하기·바꾸기는 Premium만(새 자동화). 정해 둔 목적지 지우기(정하지 않음)는 구독과 무관하게 언제나.
      // 만료돼도 초안·지금 이동은 그대로
      final current = rescue.destinationOf(wallet.id);
      if (current == null && !await ensurePremium(context)) return;
      if (!mounted) return;
      final options = [
        for (final d in rescue.destinationOptions(wallet.id)) _DestinationOption(d),
        if (current != null) const _DestinationOption(null),
      ];
      final initial = options.firstWhereOrNull((o) => o.isCurrent(current) && o.canPreselect)?.id;
      final picked = await CommonBottomSheets.showSelectableDraggableSheet<_DestinationOption>(
        context: context,
        title: t.premium.rescue.destination,
        screenName: '/wallet-health/rescue/destination',
        items: options,
        getItemId: (o) => o.id,
        initiallySelectedId: initial,
        confirmText: t.premium.rescue.save,
        itemBuilder:
            (context, option, isSelected, onTap) => SelectableBottomSheetTextItem(
              key: Key('rescue-destination-${option.id}'),
              isSelected: isSelected,
              onTap: onTap,
              reserveCheckIconSpace: true,
              child: _DestinationOptionView(option),
            ),
      );
      if (picked == null || !mounted) return;
      if (picked.assist != null && !await ensurePremium(context)) return;

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
            title: copy.hot_confirm_title,
            description: copy.hot_confirm_body,
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

  Future<String?> _enterAddress(int walletId) => CommonBottomSheets.showBottomSheet<String>(
    context: context,
    title: t.premium.destination.enter_address,
    screenName: '/wallet-health/rescue/address',
    showDragHandle: true,
    showCloseButton: true,
    child: _AddressEntry(walletId: walletId),
  );

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
              Text(copy.wallets_title, style: CoconutTypography.heading3_21_Bold.setColor(colors.primaryText)),
              CoconutLayout.spacing_300h,
              Text(copy.description, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
              CoconutLayout.spacing_200h,
              Text(
                t.premium.destination.excluded_note_setup,
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
                    title: wallet.name,
                    subtitle: _statusLine(rescue, wallet.id, status, unit),
                    subtitleColor: _needsAttention.contains(status) ? colors.warningText : null,
                    onTap: () => _choose(wallet),
                  ),
                  if (rescue.canMoveNow(wallet.id) && rescue.hasCriticalIncident(wallet.id)) ...[
                    CoconutLayout.spacing_200h,
                    _MoveNowButton(walletId: wallet.id, onPressed: () => _moveNow(wallet.id)),
                  ],
                  CoconutLayout.spacing_200h,
                ],
              CoconutLayout.spacing_200h,
              Text(copy.on_device, style: CoconutTypography.caption_10.setColor(colors.secondaryText)),
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

  /// 행 부제: "→ 목적지 · 초안 상태"
  String _statusLine(RescueReadyProvider rescue, int walletId, RescueStatus status, BitcoinUnit unit) {
    final copy = t.premium.rescue;
    if (status == RescueStatus.notSet) return copy.not_set;
    final draft = rescue.drafts[walletId];
    final time = draft == null ? null : formatHomeRelativeTime(draft.preparedAt, DateTime.now());
    final detail = switch (status) {
      RescueStatus.notSet => copy.not_set,
      RescueStatus.invalidDestination => copy.destination_invalid,
      RescueStatus.paused => time == null ? copy.draft_paused_none : copy.draft_paused(time: time),
      RescueStatus.pending => copy.draft_pending,
      RescueStatus.failed => copy.draft_failed,
      // 수수료는 초안을 만들 때의 값. 잔액 숨김이어도 보인다(잔액이 아님)
      RescueStatus.ready =>
        '${copy.draft_ready(time: time ?? '')} · ${t.estimated_fee} ${unit.displayBitcoinAmount(draft?.fee, withUnit: true)}',
      RescueStatus.noBalance => copy.draft_no_balance,
      RescueStatus.tooSmall => copy.draft_too_small,
      RescueStatus.unavailable =>
        draft?.blocker == RescueReadyProvider.feeTooHighBlocker
            ? t.premium.assist.fee_too_high(percent: SweepFee.maxSharePercent)
            : copy.draft_unavailable,
    };
    final destination = rescue.destinationLabel(walletId);
    return [if (destination != null) '→ $destination', detail].join(' · ');
  }
}

/// 사고 때만 보이는 [지금 이동]. 주 버튼보다 낮은 무게(UI_SPEC §4.7 비상 이동 카드 버튼)
class _MoveNowButton extends StatelessWidget {
  const _MoveNowButton({required this.walletId, required this.onPressed});

  final int walletId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      decoration: BoxDecoration(
        gradient: colors.premiumSurfaceGradient,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      padding: const EdgeInsets.all(Sizes.size4),
      child: ShrinkAnimationButton(
        key: Key('rescue-move-now-$walletId'),
        onPressed: onPressed,
        defaultColor: colors.surface,
        pressedOverlayColor: colors.surfacePressOverlay,
        borderRadius: CoconutStyles.radius_200,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Center(
            child: Text(t.premium.rescue.move_now, style: CoconutTypography.body2_14_Bold.setColor(colors.premiumText)),
          ),
        ),
      ),
    );
  }
}

/// 목적지 시트 한 줄. [assist]가 null이면 "정하지 않음"
class _DestinationOption {
  const _DestinationOption(this.assist);

  final AssistDestination? assist;

  String get id => switch (assist) {
    null => 'off',
    AssistDestination(:final wallet?) => 'wallet:${wallet.id}',
    AssistDestination(kind: AssistDestinationKind.newHotWallet) => 'hot:new',
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
    final title = switch (d) {
      null => t.premium.rescue.turn_off,
      AssistDestination(:final wallet?) => wallet.name,
      AssistDestination(kind: AssistDestinationKind.newHotWallet) => copy.new_hot_wallet,
      AssistDestination(:final address?) => shortenAddress(address),
      _ => copy.enter_address,
    };
    final subtitle = switch (d) {
      AssistDestination(cannotVerifySeed: true) => null, // 아래 정보 줄
      AssistDestination(kind: AssistDestinationKind.watchOnlyWallet) => copy.watch_only_wallets_body,
      AssistDestination(kind: AssistDestinationKind.newHotWallet) => copy.new_hot_wallet_body,
      AssistDestination(address: _?) => copy.enter_address,
      _ => null,
    };
    final unverified = _isUnverifiedWatchOnly(context.watch<SafetyProvider?>()?.state, d?.wallet);
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
          Text(subtitle, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
        ],
        if (d?.cannotVerifySeed ?? false)
          _NoteLine(
            iconPath: CommonStateIconPath.circleInfo,
            iconColor: colors.iconSecondary,
            text: copy.unknown_seed,
            textColor: colors.secondaryText,
          ),
        if (d?.onThisDevice ?? false)
          _NoteLine(
            iconPath: CommonStateIconPath.triangleWarning,
            iconColor: colors.warningText,
            text: copy.new_hot_wallet_warning,
            textColor: colors.warningText,
          ),
        if (unverified)
          _NoteLine(
            iconPath: CommonStateIconPath.triangleWarning,
            iconColor: colors.warningText,
            text: t.wallet_health.check.watch_only_verify.not_verified,
            textColor: colors.warningText,
          ),
      ],
    );
  }

  /// 보기 전용 검증(서명 기기 주소와 대조)을 아직 안 한 보기 전용 목적지. xpub이 바꿔치기된 지갑으로 옮기지 않게 표시한다.
  /// 검증 규칙은 엔진과 같다(디스크립터가 바뀐 기록은 무효). 불일치 지갑은 목적지 후보에서 이미 빠진다
  static bool _isUnverifiedWatchOnly(SafetyState? state, WalletItemBase? wallet) {
    if (state == null || wallet == null || wallet.hasLocalKey || wallet.walletType == WalletType.multiSignature) {
      return false;
    }
    final v = state.watchOnlyVerifications[wallet.id];
    return v == null ||
        v.result != VerificationResult.match ||
        v.descriptorHash != WalletVerification.descriptorHash(wallet.descriptor);
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.iconPath, required this.iconColor, required this.text, required this.textColor});

  final String iconPath;
  final Color iconColor;
  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Sizes.size4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SvgPicture.asset(
              iconPath,
              width: 12,
              height: 12,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
          CoconutLayout.spacing_100w,
          Expanded(child: Text(text, style: CoconutTypography.body3_12.setColor(textColor))),
        ],
      ),
    );
  }
}

/// 주소 직접 입력. 지금 네트워크 형식 검사(기존 AddressValidator) + 이 지갑·제외 지갑 주소 거절
class _AddressEntry extends StatefulWidget {
  const _AddressEntry({required this.walletId});

  final int walletId;

  @override
  State<_AddressEntry> createState() => _AddressEntryState();
}

class _AddressEntryState extends State<_AddressEntry> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _checking = false;

  /// 저장할 때 확인한, 제외 지갑에서 나온 주소(그 주소가 입력돼 있는 동안 오류로 보인다)
  String? _derivedFromExcluded;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? get _error {
    final text = _controller.text.trim();
    if (text.isEmpty) return null;
    final check = context.read<RescueReadyProvider>().checkAddress(widget.walletId, text);
    if (check.format != null) return check.format!.message;
    final excluded = check.ownedByExcluded || normalizeAddress(text) == _derivedFromExcluded;
    return excluded ? t.premium.destination.error_self_address : null;
  }

  /// 만들어 둔 주소 목록 밖의 제외 지갑 주소도 저장 전에 한 번 확인한다(무거워서 누를 때만)
  Future<void> _save() async {
    final address = normalizeAddress(_controller.text.trim());
    setState(() => _checking = true);
    final excluded = await context.read<RescueReadyProvider>().derivesFromExcludedWallet(widget.walletId, address);
    if (!mounted) return;
    if (excluded) {
      setState(() {
        _checking = false;
        _derivedFromExcluded = address;
      });
      vibrateLightDouble();
      return;
    }
    Navigator.pop(context, address);
  }

  Future<void> _scan() async {
    final scanned = await showAddressScannerBottomSheet(context, title: t.premium.destination.enter_address);
    if (scanned == null || !mounted) return;
    _controller.text = normalizeAddress(scanned.trim());
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final error = _error;
    final canSave = _controller.text.trim().isNotEmpty && error == null && !_checking;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoconutTextField(
            key: const Key('rescue-address-field'),
            controller: _controller,
            focusNode: _focusNode,
            onChanged: (_) => setState(() {}),
            backgroundColor: colors.inputSurface,
            height: 52,
            padding: const EdgeInsets.only(left: 16),
            maxLines: 1,
            placeholderText: t.premium.destination.address_hint,
            clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
            onClear: () => setState(_controller.clear),
            suffixIconAsset: CommonActionIconPath.scan,
            suffixSemanticLabel: t.premium.destination.enter_address,
            suffixIconColor: colors.primaryText,
            onSuffixPressed: _scan,
            isError: error != null,
            errorText: error,
            isErrorTextMultiline: true,
          ),
          CoconutLayout.spacing_300h,
          _NoteLine(
            iconPath: CommonStateIconPath.circleInfo,
            iconColor: colors.iconSecondary,
            text: t.premium.destination.external_warning,
            textColor: colors.secondaryText,
          ),
          CoconutLayout.spacing_600h,
          InlineActionButton(
            key: const Key('rescue-address-save'),
            isActive: canSave,
            text: t.premium.rescue.save,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
