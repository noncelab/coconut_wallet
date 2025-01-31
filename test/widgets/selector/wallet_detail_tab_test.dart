import 'package:coconut_wallet/widgets/selector/wallet_detail_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletDetailTab', () {
    testWidgets('callback test', (tester) async {
      WalletDetailTabType selectedListType = WalletDetailTabType.transaction;
      bool isDropdownVisible = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WalletDetailTab(
            selectedListType: selectedListType,
            isUpdateProgress: false,
            utxoListLength: 0,
            isUtxoDropdownVisible: true,
            utxoOrderText: '큰 금액순',
            onTapTransaction: () {
              selectedListType = WalletDetailTabType.transaction;
            },
            onTapUtxo: () {
              selectedListType = WalletDetailTabType.utxo;
            },
            onTapUtxoDropdown: () {
              isDropdownVisible = true;
            },
          ),
        ),
      ));

      await tester.tap(find.text('UTXO 목록'));
      await tester.pumpAndSettle();
      expect(selectedListType, WalletDetailTabType.utxo);

      await tester.tap(find.text('큰 금액순'));
      await tester.pumpAndSettle();
      expect(isDropdownVisible, true);

      await tester.tap(find.text('거래 내역'));
      await tester.pumpAndSettle();
      expect(selectedListType, WalletDetailTabType.transaction);
    });
  });
}
