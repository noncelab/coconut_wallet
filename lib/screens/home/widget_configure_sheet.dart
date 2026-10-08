import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutSwitch, CoconutTypography;
import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/widget_configure_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/home/configure/home_configure_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 위젯 설정 시트. 저장하면 [HomeWidgetSettings]를 돌려준다. [initial]이 null이면 새로 추가하는 위젯이다.
/// 호들 인사이트처럼 위젯이 아닌 화면의 설정에도 쓴다([title], [description]).
class WidgetConfigureSheet extends StatefulWidget {
  final String heading;
  final HomeWidgetSettingsSpec spec;
  final List<WalletItemBase> wallets;
  final HomeWidgetSettings? initial;
  final String? title;
  final String? description;

  /// 지금 크기(이미 홈에 있는 위젯). 새로 추가하면 null이고 [HomeWidgetSettingsSpec.sizes]의 첫 크기가 기본이다.
  final HomeSpan? initialSpan;

  /// 크기를 고르는 위젯의 미리보기. 시트는 홈 위젯 데이터에 닿지 않으므로 여는 쪽이 만든다.
  final Widget Function(HomeSpan span)? previewBuilder;

  const WidgetConfigureSheet({
    super.key,
    required this.heading,
    required this.spec,
    required this.wallets,
    this.initial,
    this.title,
    this.description,
    this.initialSpan,
    this.previewBuilder,
  });

  static Future<HomeWidgetSettings?> open(
    BuildContext context, {
    required HomeItemDefinition definition,
    required List<WalletItemBase> wallets,
    HomeWidgetSettings? initial,
    HomeSpan? initialSpan,
    Widget Function(HomeSpan span)? previewBuilder,
  }) => openSettings(
    context,
    heading: definition.displayName(),
    spec: definition.settings,
    wallets: wallets,
    initial: initial,
    initialSpan: initialSpan,
    previewBuilder: previewBuilder,
  );

  static Future<HomeWidgetSettings?> openSettings(
    BuildContext context, {
    required String heading,
    required HomeWidgetSettingsSpec spec,
    required List<WalletItemBase> wallets,
    HomeWidgetSettings? initial,
    String? title,
    String? description,
    HomeSpan? initialSpan,
    Widget Function(HomeSpan span)? previewBuilder,
  }) {
    return CommonBottomSheets.showBottomSheet_100<HomeWidgetSettings>(
      context: context,
      screenName: '/widget-configure-sheet',
      isDismissible: true,
      child: WidgetConfigureSheet(
        heading: heading,
        spec: spec,
        wallets: wallets,
        initial: initial,
        title: title,
        description: description,
        initialSpan: initialSpan,
        previewBuilder: previewBuilder,
      ),
    );
  }

  @override
  State<WidgetConfigureSheet> createState() => _WidgetConfigureSheetState();
}

class _WidgetConfigureSheetState extends State<WidgetConfigureSheet> {
  late final WidgetConfigureViewModel _viewModel = WidgetConfigureViewModel(
    spec: widget.spec,
    wallets: widget.wallets,
    preferenceProvider: context.read<PreferenceProvider>(),
    initial: widget.initial,
    initialSpan: widget.initialSpan,
    targetOf: widget.spec.goals ? SharedPrefsRepository().getWalletTargetSats : null,
    saveTarget: widget.spec.goals ? SharedPrefsRepository().updateWalletTarget : null,
  );
  final TextEditingController _fakeBalanceController = TextEditingController();
  final Map<int, TextEditingController> _targetControllers = {};
  final Map<int, FocusNode> _targetFocusNodes = {};

  TextEditingController _targetController(int walletId) => _targetControllers.putIfAbsent(walletId, () {
    final saved = _viewModel.targetOf(walletId);
    final controller = TextEditingController(
      text: saved == null ? '' : BalanceFormatUtil.formatSatoshiToBtcInputText(saved),
    );
    controller.addListener(() {
      final text = normalizeNumTextForNumParsing(controller.text);
      _viewModel.setTarget(walletId, text.isEmpty ? null : UnitUtil.convertBitcoinStringToSatoshi(text));
    });
    return controller;
  });
  final FocusNode _fakeBalanceFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final saved = _viewModel.fakeBalance;
    if (saved != null) _fakeBalanceController.text = BalanceFormatUtil.formatSatoshiToBtcInputText(saved);
    _fakeBalanceController.addListener(() {
      final text = normalizeNumTextForNumParsing(_fakeBalanceController.text);
      _viewModel.setFakeBalance(text.isEmpty ? null : UnitUtil.convertBitcoinStringToSatoshi(text));
    });
  }

  @override
  void dispose() {
    _fakeBalanceController.dispose();
    _fakeBalanceFocusNode.dispose();
    for (final controller in _targetControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _targetFocusNodes.values) {
      focusNode.dispose();
    }
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await _viewModel.commitFakeBalance();
    await _viewModel.commitTargets();
    if (!mounted) return;
    Navigator.pop(context, _viewModel.settings);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WidgetConfigureViewModel>.value(
      value: _viewModel,
      child: Consumer<WidgetConfigureViewModel>(
        builder: (context, viewModel, _) {
          final spec = viewModel.spec;
          return HomeConfigureSheetLayout(
            title: widget.title ?? t.home_edit.configure_widget,
            heading: widget.heading,
            description:
                widget.description ??
                (viewModel.isNew
                    ? t.home_edit.configure_widget_description_add
                    : t.home_edit.configure_widget_description_edit),
            buttonText: viewModel.isNew ? t.home_edit.add_to_home : t.home_edit.save_changes,
            buttonKey: const Key('widget-configure-submit'),
            isButtonActive: viewModel.canSubmit,
            onSubmit: _submit,
            children: [
              if (spec.sizes.isNotEmpty) ..._buildSizes(viewModel),
              if (spec.wallets) ..._buildWallets(viewModel),
              if (spec.currencies != HomeWidgetCurrencyMode.none) ..._buildCurrencies(viewModel),
              if (spec.period) ..._buildPeriods(viewModel),
              if (spec.goals) ..._buildGoals(viewModel),
              if (spec.fakeBalance) ..._buildFakeBalance(viewModel),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildSizes(WidgetConfigureViewModel viewModel) {
    final sizes = viewModel.spec.sizes;
    final selected = viewModel.span ?? sizes.first;
    final preview = widget.previewBuilder;
    return [
      HomeConfigureSectionTitle(t.home_edit.size),
      for (final (index, span) in sizes.indexed)
        HomeConfigureCheckRow(
          key: ValueKey('widget-configure-size-${span.toJson()}'),
          label: '${span.width}×${span.height}',
          checked: span == selected,
          showDivider: index < sizes.length - 1,
          onTap: () => viewModel.selectSpan(span),
        ),
      if (preview != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final cell = (constraints.maxWidth - gap * 3) / 4;
              final height = cell * 2 + gap;
              final width = selected.width >= 4 ? constraints.maxWidth : height;
              return Center(
                child: SizedBox(
                  key: ValueKey('widget-configure-preview-${selected.toJson()}'),
                  width: width,
                  height: height,
                  child: IgnorePointer(child: preview(selected)),
                ),
              );
            },
          ),
        ),
    ];
  }

  List<Widget> _buildWallets(WidgetConfigureViewModel viewModel) => [
    HomeConfigureSectionTitle(t.home_edit.wallets),
    HomeConfigureCheckRow(
      key: const Key('widget-configure-all-wallets'),
      label: t.home_edit.all_wallets,
      checked: viewModel.allWallets,
      showDivider: viewModel.wallets.isNotEmpty,
      onTap: viewModel.selectAllWallets,
    ),
    for (final (index, wallet) in viewModel.wallets.indexed)
      HomeConfigureCheckRow(
        key: ValueKey('widget-configure-wallet-${wallet.id}'),
        label: wallet.name,
        checked: viewModel.isWalletSelected(wallet.id),
        showDivider: index < viewModel.wallets.length - 1,
        onTap: () => viewModel.toggleWallet(wallet.id),
      ),
  ];

  List<Widget> _buildCurrencies(WidgetConfigureViewModel viewModel) => [
    HomeConfigureSectionTitle(t.home_edit.currencies),
    if (viewModel.spec.currencies == HomeWidgetCurrencyMode.multiple &&
        viewModel.spec.maxCurrencies < viewModel.fiatOptions.length)
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Text(
          t.home_edit.currencies_limit(count: viewModel.spec.maxCurrencies),
          style: CoconutTypography.body3_12.copyWith(color: context.coconutColors.secondaryText),
        ),
      ),
    for (final (index, fiat) in viewModel.fiatOptions.indexed)
      HomeConfigureCheckRow(
        key: ValueKey('widget-configure-fiat-${fiat.code}'),
        label: fiat.code,
        note: fiat == viewModel.defaultFiat ? t.home_edit.currency_default : null,
        checked: viewModel.isFiatSelected(fiat),
        enabled: viewModel.canSelectFiat(fiat),
        showDivider: index < viewModel.fiatOptions.length - 1,
        onTap: () => viewModel.toggleFiat(fiat),
      ),
  ];

  List<Widget> _buildPeriods(WidgetConfigureViewModel viewModel) => [
    HomeConfigureSectionTitle(t.home_edit.period),
    for (final (index, period) in viewModel.spec.periods.indexed)
      HomeConfigureCheckRow(
        key: ValueKey('widget-configure-period-${period.name}'),
        label: homePeriodLabel(period),
        checked: viewModel.period == period,
        showDivider: index < viewModel.spec.periods.length - 1,
        onTap: () => viewModel.selectPeriod(period),
      ),
  ];

  List<Widget> _buildGoals(WidgetConfigureViewModel viewModel) {
    final colors = context.coconutColors;
    return [
      HomeConfigureSectionTitle(t.home_edit.wallet_goals),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(
          t.home_edit.wallet_goals_description,
          style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
        ),
      ),
      for (final wallet in viewModel.wallets)
        Padding(
          key: ValueKey('widget-configure-goal-${wallet.id}'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(wallet.name, style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText)),
              CoconutLayout.spacing_200h,
              CoconutTextField(
                key: ValueKey('widget-configure-goal-input-${wallet.id}'),
                textInputType: const TextInputType.numberWithOptions(decimal: true),
                textInputFormatter: const [BtcAmountInputFormatter()],
                placeholderText: t.home_edit.wallet_goal_placeholder,
                isLengthVisible: false,
                controller: _targetController(wallet.id),
                focusNode: _targetFocusNodes.putIfAbsent(wallet.id, FocusNode.new),
                onChanged: (text) {},
                backgroundColor: colors.background,
                maxLength: 19,
                suffix: Text(t.btc, style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText)),
                errorText:
                    viewModel.targetExceedsSupply(wallet.id)
                        ? '  ${t.wallet_home_screen.edit.fake_balance.fake_balance_input_exceeds_error}'
                        : '',
                isError: viewModel.targetExceedsSupply(wallet.id),
                maxLines: 1,
                clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
                onClear: _targetController(wallet.id).clear,
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _buildFakeBalance(WidgetConfigureViewModel viewModel) {
    final colors = context.coconutColors;
    return [
      HomeConfigureSectionTitle(t.home_edit.balance_display),
      SingleButton(
        key: const Key('widget-configure-fake-balance'),
        isVerticalSubtitle: true,
        title: t.wallet_home_screen.edit.fake_balance.fake_balance_display,
        subtitle: t.home_edit.fake_balance_description,
        subtitleStyle: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
        customPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        onPressed: () {
          if (_fakeBalanceFocusNode.hasFocus) {
            FocusScope.of(context).unfocus();
            return;
          }
          viewModel.setFakeBalanceActive(!viewModel.fakeBalanceActive);
        },
        backgroundColor: Colors.transparent,
        rightElement: CoconutSwitch(
          isOn: viewModel.fakeBalanceActive,
          scale: 0.7,
          activeTrackColor: colors.switchActiveTrack,
          activeThumbColor: colors.switchActiveThumb,
          inactiveTrackColor: colors.switchInactiveTrack,
          inactiveThumbColor: colors.switchInactiveThumb,
          onChanged: viewModel.setFakeBalanceActive,
        ),
      ),
      AnimatedCrossFade(
        duration: const Duration(milliseconds: 300),
        firstChild: const SizedBox(height: 0),
        secondChild: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CoconutTextField(
                key: const Key('widget-configure-fake-balance-input'),
                textInputType: const TextInputType.numberWithOptions(decimal: true),
                textInputFormatter: const [BtcAmountInputFormatter()],
                placeholderText: t.wallet_home_screen.edit.fake_balance.fake_balance_input_placeholder,
                isLengthVisible: false,
                controller: _fakeBalanceController,
                focusNode: _fakeBalanceFocusNode,
                onChanged: (text) {},
                backgroundColor: colors.background,
                maxLength: 19,
                suffix: Text(t.btc, style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText)),
                errorText:
                    viewModel.fakeBalanceExceedsSupply
                        ? '  ${t.wallet_home_screen.edit.fake_balance.fake_balance_input_exceeds_error}'
                        : '',
                isError: viewModel.fakeBalanceExceedsSupply,
                maxLines: 1,
                clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
                onClear: _fakeBalanceController.clear,
              ),
            ),
            CoconutLayout.spacing_400h,
          ],
        ),
        crossFadeState: viewModel.fakeBalanceActive ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      ),
    ];
  }
}
