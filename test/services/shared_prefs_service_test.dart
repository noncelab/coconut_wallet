import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:coconut_wallet/model/faucet_history.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([SharedPreferences])
import 'shared_prefs_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefs', () {
    late SharedPrefs sharedPrefs;
    late MockSharedPreferences mockPrefs;

    setUp(() async {
      mockPrefs = MockSharedPreferences();
      sharedPrefs = SharedPrefs();
      sharedPrefs.setSharedPreferencesForTest(mockPrefs);
    });

    test('LAST_UPDATE_TIME integer must be saved and imported', () async {
      final dateTime = DateTime.now().millisecondsSinceEpoch;
      when(mockPrefs.setInt(SharedPrefs.kLastUpdateTime, dateTime))
          .thenAnswer((_) async => true);
      when(mockPrefs.getInt(SharedPrefs.kLastUpdateTime)).thenReturn(dateTime);

      await sharedPrefs.sharedPrefs
          .setInt(SharedPrefs.kLastUpdateTime, dateTime);
      final result =
          sharedPrefs.sharedPrefs.getInt(SharedPrefs.kLastUpdateTime);

      expect(result, dateTime);
    });

    test('FAUCET_HISTORIES string(json) must be saved and imported', () async {
      final histories = {
        1: FaucetHistory(id: 1, dateTime: 1627848390, count: 3),
        2: FaucetHistory(id: 2, dateTime: 1627848390, count: 3),
      };

      final encodedData = json.encode(histories
          .map((key, value) => MapEntry(key.toString(), value.toJson())));
      when(mockPrefs.setString(SharedPrefs.kFaucetHistories, encodedData))
          .thenAnswer((_) async => true);
      when(mockPrefs.getString(SharedPrefs.kFaucetHistories))
          .thenReturn(encodedData);

      await sharedPrefs.saveFaucetHistory(histories[1]!);
      final result1 = sharedPrefs.getFaucetHistoryWithId(1);
      expect(result1, histories[1]);

      await sharedPrefs.saveFaucetHistory(histories[2]!);
      final result2 = sharedPrefs.getFaucetHistoryWithId(2);
      expect(result2, histories[2]);
    });

    test('IS_BALANCE_HIDDEN boolean must be saved and imported', () async {
      when(mockPrefs.setBool(SharedPrefs.kIsBalanceHidden, true))
          .thenAnswer((_) async => true);
      when(mockPrefs.getBool(SharedPrefs.kIsBalanceHidden)).thenReturn(true);

      await sharedPrefs.sharedPrefs.setBool(SharedPrefs.kIsBalanceHidden, true);
      final result =
          sharedPrefs.sharedPrefs.getBool(SharedPrefs.kIsBalanceHidden);

      expect(result, true);
    });
  });
}
