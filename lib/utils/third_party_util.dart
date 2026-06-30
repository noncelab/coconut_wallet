import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

String getNextThirdPartyWalletName(
  WalletImportSource walletImportSource,
  List<String> walletNames, {
  String? passportModel,
}) {
  assert(walletImportSource != WalletImportSource.coconutVault);
  String baseName = _getThirdPartyDefaultName(walletImportSource, passportModel: passportModel);
  final regex = RegExp('^$baseName(?: (\\d+))?\$');

  final takenNumbers = <int>{};

  for (final name in walletNames) {
    final match = regex.firstMatch(name);
    if (match != null) {
      final numberGroup = match.group(1);
      if (numberGroup == null) {
        takenNumbers.add(1); // "키스톤" 자체는 1번으로 취급
      } else {
        takenNumbers.add(int.tryParse(numberGroup) ?? 1);
      }
    }
  }

  if (!takenNumbers.contains(1)) {
    return baseName;
  }

  int nextNumber = 2;
  while (takenNumbers.contains(nextNumber)) {
    nextNumber++;
  }

  return '$baseName $nextNumber';
}

String _getThirdPartyDefaultName(WalletImportSource walletImportSource, {String? passportModel}) {
  switch (walletImportSource) {
    case WalletImportSource.keystone:
      return t.third_party.keystone;
    case WalletImportSource.jade:
      return t.third_party.jade;
    case WalletImportSource.seedSigner:
      return t.third_party.seed_signer;
    case WalletImportSource.coldCard:
      return t.third_party.cold_card;
    case WalletImportSource.krux:
      return t.third_party.krux;
    case WalletImportSource.passport:
      return _passportWalletName(passportModel);
    case WalletImportSource.extendedPublicKey:
    case WalletImportSource.descriptor:
      return NetworkType.currentNetworkType == NetworkType.mainnet
          ? t.third_party.extended_public_keys.zpub
          : t.third_party.extended_public_keys.vpub;
    case WalletImportSource.coconutVault:
      throw 'Coconut Vault is not third party';
  }
}

/// Maps the device model flag carried in the import payload to a wallet name.
/// Falls back to the generic "Passport" name when the model is absent or unknown.
String _passportWalletName(String? passportModel) {
  switch (passportModel) {
    case 'passport-prime':
      return t.third_party.passport_prime;
    case 'passport-core':
      return t.third_party.passport_core;
    default:
      return t.third_party.passport;
  }
}
