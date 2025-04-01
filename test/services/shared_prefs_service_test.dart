import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coconut_wallet/model/faucet/faucet_history.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([SharedPreferences])
import 'shared_prefs_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefs', () {
    late SharedPrefsRepository sharedPrefs;
    late MockSharedPreferences mockPrefs;

    setUp(() async {
      mockPrefs = MockSharedPreferences();
      sharedPrefs = SharedPrefsRepository();
      sharedPrefs.setSharedPreferencesForTest(mockPrefs);
    });

    test('FAUCET_HISTORIES string(json) must be saved and imported', () async {
      final histories = {
        1: FaucetRecord(id: 1, dateTime: 1627848390, count: 3),
        2: FaucetRecord(id: 2, dateTime: 1627848390, count: 3),
      };

      final encodedData = json.encode(histories
          .map((key, value) => MapEntry(key.toString(), value.toJson())));
      when(mockPrefs.setString(SharedPrefKeys.kFaucetHistories, encodedData))
          .thenAnswer((_) async => true);
      when(mockPrefs.getString(SharedPrefKeys.kFaucetHistories))
          .thenReturn(encodedData);

      await sharedPrefs.saveFaucetHistory(histories[1]!);
      final result1 = sharedPrefs.getFaucetHistoryWithId(1);
      expect(result1, histories[1]);

      await sharedPrefs.saveFaucetHistory(histories[2]!);
      final result2 = sharedPrefs.getFaucetHistoryWithId(2);
      expect(result2, histories[2]);
    });

    test('IS_BALANCE_HIDDEN boolean must be saved and imported', () async {
      when(mockPrefs.setBool(SharedPrefKeys.kIsBalanceHidden, true))
          .thenAnswer((_) async => true);
      when(mockPrefs.getBool(SharedPrefKeys.kIsBalanceHidden)).thenReturn(true);

      await sharedPrefs.sharedPrefs
          .setBool(SharedPrefKeys.kIsBalanceHidden, true);
      final result =
          sharedPrefs.sharedPrefs.getBool(SharedPrefKeys.kIsBalanceHidden);

      expect(result, true);
    });
  });
}
