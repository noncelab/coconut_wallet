import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/analytics/analytics_wallet_type.dart';
import 'package:coconut_wallet/analytics/wallet_add_analytics.dart';
import 'package:coconut_wallet/analytics/wallet_resync_analytics.dart';
import 'package:coconut_wallet/analytics/wallet_sync_analytics.dart';
import 'package:coconut_wallet/analytics/wallet_detail_analytics.dart';
import 'package:coconut_wallet/analytics/backup_analytics.dart';
import 'package:coconut_wallet/analytics/external_link_analytics.dart';
import 'package:coconut_wallet/analytics/analytics_value_formatter.dart';
import 'package:coconut_wallet/analytics/user_cohort_analytics.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Sink extends Fake implements FirebaseAnalytics {
  final calls = <Invocation>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return Future<void>.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Sink sink;
  late AnalyticsService service;
  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'QA',
      packageName: 'qa',
      version: '0.19.0',
      buildNumber: '1',
      buildSignature: '',
    );
    NetworkType.setNetworkType(NetworkType.regtest);
    sink = Sink();
    service = AnalyticsService(sink, false);
    await Future<void>.delayed(Duration.zero);
    sink.calls.clear();
  });
  Future<void> check(void Function() emit, String event, Map<String, Object> expected) async {
    emit();
    await Future<void>.delayed(Duration.zero);
    final calls = sink.calls.where((x) => x.memberName == #logEvent).toList();
    expect(calls, hasLength(1));
    expect(calls.single.namedArguments[#name], event);
    expect(calls.single.namedArguments[#parameters], expected);
    sink.calls.clear();
  }

  for (final source in WalletAddEntrySource.values) {
    test(
      'wallet_add_button_clicked source=${source.name}',
      () => check(() => service.logWalletAddButtonClicked(entrySource: source), 'wallet_add_button_clicked', {
        'source': source.name,
      }),
    );
  }
  test(
    'legacy optional source remains absent',
    () => check(() => service.logWalletAddButtonClicked(), 'wallet_add_button_clicked', {}),
  );
  for (final hot in [false, true]) {
    test(
      'wallet_add_menu_entered hot=$hot',
      () => check(() => service.logWalletAddMenuEntered(isHotWallet: hot), 'wallet_add_menu_entered', {
        'wallet_type': hot ? 'hotWallet' : 'watchOnly',
      }),
    );
  }
  for (final restore in [false, true]) {
    test(
      'hot_wallet_action_selected restore=$restore',
      () => check(() => service.logHotWalletActionSelected(isRestore: restore), 'hot_wallet_action_selected', {
        'add_method': restore ? 'restore' : 'create',
      }),
    );
    test(
      'hot wallet_add_completed restore=$restore',
      () => check(() => service.logHotWalletAddCompleted(isRestore: restore), 'wallet_add_completed', {
        'wallet_type': 'hotWallet',
        'add_method': restore ? 'restore' : 'create',
      }),
    );
  }
  for (final source in WalletImportSource.values) {
    test(
      'import entered ${source.name}',
      () => check(() => service.logWalletAddScreenEntered(source), 'wallet_add_screen_entered', {
        'wallet_add_import_source': source.name,
      }),
    );
    test(
      'import complete ${source.name}',
      () => check(() => service.logWalletAddCompleted(source), 'wallet_add_completed', {
        'wallet_add_import_source': source.name,
      }),
    );
  }
  for (final type in AnalyticsWalletType.values) {
    test(
      'add sync success ${type.name}',
      () =>
          check(() => service.logWalletAddSyncCompleted(type), 'wallet_add_sync_completed', {'wallet_type': type.name}),
    );
    test(
      'add sync failure ${type.name}',
      () => check(() => service.logWalletAddSyncFailed(type), 'wallet_add_sync_failed', {'wallet_type': type.name}),
    );
    test(
      'resync start ${type.name}',
      () => check(() => service.logWalletResyncStarted(type), 'wallet_resync_started', {'wallet_type': type.name}),
    );
    test(
      'resync complete ${type.name}',
      () => check(() => service.logWalletResyncCompleted(type), 'wallet_resync_completed', {'wallet_type': type.name}),
    );
    test(
      'resync fail ${type.name}',
      () => check(() => service.logWalletResyncFailed(type), 'wallet_resync_failed', {'wallet_type': type.name}),
    );
  }
  for (final history in [false, true]) {
    test(
      'hot history $history is SDK string',
      () => check(
        () => service.logWalletAddSyncCompleted(AnalyticsWalletType.hotWallet, hasHistory: history),
        'wallet_add_sync_completed',
        {'wallet_type': 'hotWallet', 'has_history': '$history'},
      ),
    );
  }
  test(
    'bulk complete has no params',
    () => check(() => service.logWalletBulkSyncCompleted(), 'wallet_bulk_sync_completed', {}),
  );
  test('bulk fail has no params', () => check(() => service.logWalletBulkSyncFailed(), 'wallet_bulk_sync_failed', {}));
  for (final source in BackupPromptLocation.values) {
    test(
      'backup source ${source.name}',
      () => check(() => service.logBackupPromptTapped(source), 'backup_prompt_tapped', {'source': source.name}),
    );
  }
  final ages = <int, String>{0: 'lt1h', 2: '1to24h', 25: '1to7d', 169: 'gt7d'};
  for (final e in ages.entries) {
    test(
      'backup bucket ${e.value}',
      () => check(
        () => service.logBackupCompleted(DateTime.now().subtract(Duration(hours: e.key))),
        'backup_completed',
        {'since_created_bucket': e.value},
      ),
    );
  }
  test('backup unknown age omits bucket', () => check(() => service.logBackupCompleted(null), 'backup_completed', {}));
  test('time bucket exact boundaries', () {
    final t = DateTime.utc(2026);
    for (final e
        in {0: 'lt1h', 3599999999: 'lt1h', 3600000000: '1to24h', 86400000000: '1to7d', 604800000000: 'gt7d'}.entries) {
      expect(AnalyticsValueFormatter.sinceCreated(t, now: t.add(Duration(microseconds: e.key))), e.value);
    }
  });
  for (final action in WalletDetailAction.values) {
    test(
      'detail ${action.name}',
      () => check(() => service.logWalletDetailAction(action), 'wallet_detail_action', {'element': action.name}),
    );
  }
  test(
    'target save no money or other params',
    () => check(() => service.logTargetAmountSaved(), 'target_amount_saved', {}),
  );
  for (final filter in WalletFilter.values) {
    test(
      'filter ${filter.name}',
      () => check(() => service.logWalletFilterChanged(filter), 'wallet_filter_changed', {
        'wallet_type_filter': filter.name,
      }),
    );
  }
  for (final destination in ExternalLinkDestination.values) {
    test(
      'external ${destination.value} only category',
      () => check(() => service.logExternalLinkOpened(destination), 'external_link_opened', {
        'external_link_destination': destination.value,
      }),
    );
  }
  for (final cohort in AnalyticsUserCohort.values) {
    test('user cohort ${cohort.value}', () async {
      await service.setUserCohort(cohort);
      final call = sink.calls.single;
      expect(call.memberName, #setUserProperty);
      expect(call.namedArguments, {#name: 'user_cohort', #value: cohort.value, #callOptions: null});
    });
  }
  test('disabled analytics sends nothing', () async {
    final disabled = AnalyticsService(sink, true);
    disabled.logHotWalletAddCompleted(isRestore: false);
    await disabled.logScreenView(screenName: '/hot-wallet-create');
    await disabled.setUserCohort(AnalyticsUserCohort.newUser);
    await Future<void>.delayed(Duration.zero);
    expect(sink.calls, isEmpty);
  });
}
