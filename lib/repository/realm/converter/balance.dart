import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

WalletBalance mapRealmToWalletBalance(RealmWalletBalance realmWalletBalance) {
  return WalletBalance(
    realmWalletBalance.receiveAddressBalanceList
        .map((balance) => AddressBalance(
            balance.confirmed, balance.unconfirmed, balance.index))
        .toList(),
    realmWalletBalance.changeAddressBalanceList
        .map((balance) => AddressBalance(
            balance.confirmed, balance.unconfirmed, balance.index))
        .toList(),
  );
}
