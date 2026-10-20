import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/view_model/settings/label_export_view_model.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/shared_preference/safety_store.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/label_file_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../services/safety/safety_fakes.dart';

class _FileService extends Fake implements LabelFileService {
  bool fail = false;
  @override
  Future<XFile> saveLabelFile(
    String content, {
    String baseName = 'coconut-labels',
    bool useTimestampOrCounter = true,
  }) async {
    if (fail) throw StateError('save failed');
    return XFile('labels.jsonl');
  }
}

class _FailingDisk extends InMemorySharedPreferencesStore {
  _FailingDisk() : super.withData({});
  @override
  Future<bool> setValue(String valueType, String key, Object value) async => throw StateError('storage unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SafetyWalletsFake wallets;
  late LabelExportViewModel model;
  late _FileService files;
  late SafetyStore store;
  setUp(() async {
    NetworkType.setNetworkType(NetworkType.testnet);
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
    store = SafetyStore(SharedPrefsRepository());
    wallets = SafetyWalletsFake([safetyWallet()]);
    wallets.memos[1] = [RealmTransactionMemo(1, 'tx', 1, 'Memo', DateTime(2026))];
    files = _FileService();
    model = LabelExportViewModel(walletProvider: wallets, fileService: files);
  });
  tearDown(() {
    model.dispose();
    wallets.dispose();
  });
  test('single-wallet export records actual saved memo and tag counts', () async {
    expect(await model.exportLabelsForWallet(1), isNotNull);
    await Future<void>.delayed(Duration.zero);
    expect(store.load().metadataExport!.memoCount, 1);
    expect(store.load().metadataExport!.tagCount, 0);
  });
  test('multi-wallet export records completion', () async {
    expect((await model.exportLabelsForWallets([1])).xFile, isNotNull);
    await Future<void>.delayed(Duration.zero);
    expect(store.load().metadataExport!.memoCount, 1);
  });
  test('failed file save never records completion', () async {
    files.fail = true;
    await expectLater(model.exportLabelsForWallet(1), throwsStateError);
    expect(store.load().metadataExport, isNull);
  });
  test('safety write failure never changes successful export result', () async {
    SharedPreferencesStorePlatform.instance = _FailingDisk();
    expect(await model.exportLabelsForWallet(1), isNotNull);
    await Future<void>.delayed(Duration.zero);
  });
  group('baseline only from an export that covers every labelled wallet', () {
    setUp(() {
      wallets.walletItemListNotifier.value = [safetyWallet(), safetyWallet(id: 2)];
      wallets.memos[2] = [RealmTransactionMemo(2, 'tx2', 2, 'Rent', DateTime(2026))];
    });

    test('full export then a partial export with no edits keeps the full baseline', () async {
      expect((await model.exportLabelsForWallets([1, 2])).xFile, isNotNull);
      await Future<void>.delayed(Duration.zero);
      final full = store.load().metadataExport!;
      expect(full.memoCount, 2); // 두 지갑 메모 합(점검이 비교하는 전체 수와 같다)

      expect(await model.exportLabelsForWallet(1), isNotNull);
      await Future<void>.delayed(Duration.zero);
      final after = store.load().metadataExport!;
      expect(after.memoCount, 2);
      expect(after.tagCount, full.tagCount);
      expect(after.at, full.at); // 일부 내보내기는 기록을 건드리지 않는다
    });

    test('a partial-only export is not recorded', () async {
      expect(await model.exportLabelsForWallet(1), isNotNull);
      expect((await model.exportLabelsForWallets([2])).xFile, isNotNull);
      await Future<void>.delayed(Duration.zero);
      expect(store.load().metadataExport, isNull);
    });

    test('a single-wallet export counts when that wallet is the only labelled one', () async {
      wallets.memos.remove(2);
      expect(await model.exportLabelsForWallet(1), isNotNull);
      await Future<void>.delayed(Duration.zero);
      expect(store.load().metadataExport!.memoCount, 1);
    });
  });

  test('empty export does not create metadata backup record', () async {
    wallets.memos.clear();
    expect(await model.exportLabelsForWallet(1), isNull);
    expect(store.load().metadataExport, isNull);
  });
}
