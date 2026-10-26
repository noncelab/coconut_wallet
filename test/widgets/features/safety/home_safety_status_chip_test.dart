import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/safety/home_safety_status_resolver.dart';
import 'package:coconut_wallet/widgets/features/home/home_app_bar.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/safety/home_safety_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 무한 애니메이션 등으로 멈추면 공유 레인을 오래 잡지 않게
const _timeout = Timeout(Duration(seconds: 60));

const _critical = HomeSafetyStatus(HomeSafetyStatusKind.critical);
const _attention = HomeSafetyStatus(HomeSafetyStatusKind.actionNeeded, count: 3);
const _allStatuses = [
  _critical,
  HomeSafetyStatus(HomeSafetyStatusKind.connectionProblem, networkStatus: NetworkStatus.offline),
  HomeSafetyStatus(HomeSafetyStatusKind.connectionProblem, networkStatus: NetworkStatus.connectionFailed),
  HomeSafetyStatus(HomeSafetyStatusKind.connectionProblem, networkStatus: NetworkStatus.vpnBlocked),
  _attention,
  HomeSafetyStatus(HomeSafetyStatusKind.reconnected),
  HomeSafetyStatus(HomeSafetyStatusKind.updating),
  HomeSafetyStatus(HomeSafetyStatusKind.noIssues),
  HomeSafetyStatus(HomeSafetyStatusKind.upToDate),
];

Widget _app(Widget child, {CoconutThemeVariant variant = CoconutThemeVariant.light}) =>
    MaterialApp(theme: buildCoconutThemeData(variant: variant), home: Scaffold(body: child));

Future<void> _pumpChip(WidgetTester tester, HomeSafetyStatus status, double maxWidth, {VoidCallback? onTap}) async {
  await tester.pumpWidget(
    _app(
      Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: HomeSafetyStatusChip(status: status, maxWidth: maxWidth, onTap: onTap),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 450));
}

Future<void> _pumpBar(
  WidgetTester tester,
  double width,
  HomeSafetyStatus status,
  CoconutThemeVariant variant, {
  double textScale = 1,
  VoidCallback? onStatusTap,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  await tester.pumpWidget(
    _app(
      MediaQuery(
        data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(textScale)),
        child: CustomScrollView(
          slivers: [
            HomeAppBar(
              networkStatus: status.networkStatus,
              showReconnected: false,
              isSyncing: false,
              isArranging: false,
              addWalletButtonLink: LayerLink(),
              onArrangeDone: () {},
              onAddWallet: () {},
              onSettings: () {},
              onEdit: () {},
              safetyStatus: status,
              onStatusTap: onStatusTap ?? () {},
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 900)),
          ],
        ),
      ),
      variant: variant,
    ),
  );
  await tester.pump(const Duration(milliseconds: 450));
}

Finder _inChip(Finder matching) => find.descendant(of: find.byType(HomeSafetyStatusChip), matching: matching);

String _chipText(HomeSafetyStatus status) => switch (status.kind) {
  HomeSafetyStatusKind.critical => t.wallet_health.status_chip.critical,
  HomeSafetyStatusKind.connectionProblem => switch (status.networkStatus) {
    NetworkStatus.offline => t.wallet_health.status_chip.offline,
    NetworkStatus.vpnBlocked => t.wallet_health.status_chip.vpn,
    _ => t.wallet_health.status_chip.connection_failed,
  },
  HomeSafetyStatusKind.actionNeeded => t.wallet_health.status_chip.attention(n: status.count),
  HomeSafetyStatusKind.reconnected => t.wallet_health.status_chip.reconnected,
  HomeSafetyStatusKind.updating => t.status_updating,
  HomeSafetyStatusKind.noIssues => t.wallet_health.summary.no_issues_found,
  HomeSafetyStatusKind.upToDate => t.wallet_health.status_chip.up_to_date,
};

void main() {
  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  testWidgets('every status shows its own text with room, and the a11y label is always the full text', (tester) async {
    final handle = tester.ensureSemantics();
    for (final status in _allStatuses) {
      await _pumpChip(tester, status, 600);
      final text = _chipText(status);
      expect(find.text(text), findsOneWidget, reason: '$status');
      expect(find.bySemanticsLabel(t.wallet_health.status_chip.a11y(status: text)), findsOneWidget, reason: '$status');
      expect(tester.takeException(), isNull, reason: '$status');
    }
    handle.dispose();
  }, timeout: _timeout);

  testWidgets('text keeps its size when it fits, otherwise the chip turns into the short form', (tester) async {
    final handle = tester.ensureSemantics();
    for (final status in [_critical, _attention]) {
      final text = _chipText(status);
      await _pumpChip(tester, status, 600);
      final width = measureHomeText(
        tester.element(find.byType(HomeSafetyStatusChip)),
        text,
        CoconutTypography.body2_14_Bold,
      );

      await _pumpChip(tester, status, 36 + width + 1);
      expect(tester.getRect(find.text(text)).width, moreOrLessEquals(width, epsilon: 0.5));

      await _pumpChip(tester, status, 36 + width - 1);
      expect(find.text(text), findsNothing);
      expect(_inChip(find.byType(Text)), status == _attention ? findsOneWidget : findsNothing);
      if (status == _attention) expect(find.text('3'), findsOneWidget);
      expect(find.bySemanticsLabel(t.wallet_health.status_chip.a11y(status: text)), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    handle.dispose();
  }, timeout: _timeout);

  testWidgets('tapping the chip calls onTap', (tester) async {
    var taps = 0;
    await _pumpChip(tester, _attention, 300, onTap: () => taps++);
    await tester.tap(find.byType(HomeSafetyStatusChip));
    expect(taps, 1);
  }, timeout: _timeout);

  for (final variant in CoconutThemeVariant.values) {
    testWidgets('${variant.name}: short form on the 344dp Fold cover, full text at 412dp, left of three actions', (
      tester,
    ) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      // 테스트 글꼴은 모든 글자가 1em이라 "Security alert"가 168dp, "Check 3 items"가 156dp:
      // 344dp의 글자 자리 116에는 짧은 꼴, 412dp(184)에는 그대로
      LocaleSettings.setLocaleSync(AppLocale.en);

      await _pumpBar(tester, 344, _critical, variant);
      expect(_inChip(find.byType(Text)), findsNothing);
      await _pumpBar(tester, 344, _attention, variant);
      expect(_inChip(find.byType(Text)), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // 테스트 글꼴은 글자 폭이 글자 크기와 같아 넓은 폭에서 전체 문구를 본다
      await _pumpBar(tester, 480, _critical, variant);
      final text = tester.widget<Text>(find.text(t.wallet_health.status_chip.critical));
      expect(text.style!.color, resolveCoconutThemeExtension(variant: variant).walletHealth.critical);

      for (final width in [344.0, 412.0]) {
        await _pumpBar(tester, width, _critical, variant);
        final actions = [
          for (final key in ['home-edit-button', 'home-add-wallet-button', 'home-settings-button'])
            tester.getRect(find.byKey(Key(key))),
        ];
        expect(actions.map((rect) => rect.width), everyElement(HomeAppBar.actionButtonWidth));
        expect(tester.getRect(find.byType(HomeSafetyStatusChip)).right, lessThanOrEqualTo(actions.first.left));
        expect(tester.takeException(), isNull);
      }
    }, timeout: _timeout);
  }

  testWidgets('ko short labels keep their text on the 344dp Fold cover at 1.3× in every theme', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // 한글은 테스트 글꼴(1em)과 Pretendard 폭이 거의 같아 실제 기기의 맞춤을 그대로 따른다(UI_SPEC §3.2 표: 전부 ○)
    for (final variant in CoconutThemeVariant.values) {
      for (final status in _allStatuses) {
        await _pumpBar(tester, 344, status, variant, textScale: 1.3);
        final reason = '${variant.name} $status';
        expect(find.text(_chipText(status)), findsOneWidget, reason: reason);
        final add = tester.getRect(find.byKey(const Key('home-add-wallet-button')));
        expect(tester.getRect(find.byType(HomeSafetyStatusChip)).right, lessThanOrEqualTo(add.left), reason: reason);
        expect(tester.takeException(), isNull, reason: reason);
      }
    }
  }, timeout: _timeout);

  // 320dp는 넘침만 본다: 테스트 글꼴은 띄어쓰기도 1em이라 "점검 이상 없음"·"확인 n"이 기기(Pretendard)보다 일찍 짧은 꼴이 된다
  testWidgets('every status fits beside the three actions at 320/344/412dp and 1.0/1.3/2.0× text', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final handle = tester.ensureSemantics();
    for (final width in [320.0, 344.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final status in _allStatuses) {
          await _pumpBar(tester, width, status, CoconutThemeVariant.light, textScale: scale);
          final reason = '${width.toInt()}dp ×$scale $status';
          final add = tester.getRect(find.byKey(const Key('home-add-wallet-button')));
          expect(tester.getRect(find.byType(HomeSafetyStatusChip)).right, lessThanOrEqualTo(add.left), reason: reason);
          final label = t.wallet_health.status_chip.a11y(status: _chipText(status));
          expect(find.bySemanticsLabel(label), findsOneWidget, reason: reason);
          expect(tester.takeException(), isNull, reason: reason);
        }
      }
    }
    handle.dispose();
  }, timeout: _timeout);

  for (final flag in ['disableAnimations', 'accessibleNavigation']) {
    testWidgets('reduced motion ($flag): the updating mark stands still and statuses switch without a fade', (
      tester,
    ) async {
      Future<void> pump(HomeSafetyStatus status, {required bool reduce}) => tester.pumpWidget(
        _app(
          Builder(
            builder:
                (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: reduce && flag == 'disableAnimations',
                    accessibleNavigation: reduce && flag == 'accessibleNavigation',
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: HomeSafetyStatusChip(status: status, maxWidth: 300),
                  ),
                ),
          ),
        ),
      );
      CircularProgressIndicator indicator() =>
          tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
      const updating = HomeSafetyStatus(HomeSafetyStatusKind.updating);
      const noIssues = HomeSafetyStatus(HomeSafetyStatusKind.noIssues);

      // 마운트된 채로 켜져도 바로 멈춘다
      await pump(updating, reduce: false);
      expect(indicator().value, isNull);
      await pump(updating, reduce: true);
      expect(indicator().value, isNotNull);

      await pump(noIssues, reduce: true);
      await tester.pump();
      expect(find.text(t.status_updating), findsNothing);
      expect(find.text(t.wallet_health.summary.no_issues_found), findsOneWidget);

      // 동작 줄이기가 아니면 400ms 동안 겹쳐 바뀐다
      await pump(updating, reduce: false);
      await tester.pump(const Duration(milliseconds: 450));
      await pump(noIssues, reduce: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(t.status_updating), findsOneWidget);
    }, timeout: _timeout);
  }

  testWidgets('the chip also takes taps 4dp above and below it (a 48dp target) without moving', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var taps = 0;
    await _pumpBar(tester, 412, _attention, CoconutThemeVariant.light, onStatusTap: () => taps++);
    final chip = tester.getRect(find.byType(HomeSafetyStatusChip));
    expect(chip.height, 40);

    for (final dy in [chip.top - 3, chip.bottom + 3]) {
      await tester.tapAt(Offset(chip.center.dx, dy));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(taps, 2);
    for (final dy in [chip.top - 6, chip.bottom + 6]) {
      await tester.tapAt(Offset(chip.center.dx, dy));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(taps, 2);
  }, timeout: _timeout);
}
