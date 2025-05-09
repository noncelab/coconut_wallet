import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

String getNextThirdPartyWalletName(
    WalletImportSource walletImportSource, List<String> walletNames) {
  assert(walletImportSource != WalletImportSource.coconutVault);
  String baseName = _getThirdPartyDefaultName(walletImportSource);
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

String _getThirdPartyDefaultName(WalletImportSource walletImportSource) {
  switch (walletImportSource) {
    case WalletImportSource.keystone:
      return t.third_party.keystone;
    case WalletImportSource.seedSigner:
      return t.third_party.seed_signer;
    case WalletImportSource.extendedPublicKey:
      return t.third_party.zpub;
    case WalletImportSource.coconutVault:
    default:
      throw 'Coconut Vault is not third party';
  }
}
