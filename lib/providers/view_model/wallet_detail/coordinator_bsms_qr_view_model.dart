import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class CoordinatorBsmsQrViewModel extends ChangeNotifier {
  late String qrData;
  late Map<String, String> walletQrDataMap;
  late Map<String, String> walletTextDataMap;

  CoordinatorBsmsQrViewModel(WalletProvider walletProvider, int id) {
    _init(walletProvider, id);
  }

  void _init(WalletProvider walletProvider, int id) {
    //   final vaultListItem = walletProvider.getVaultById(id) as MultisigVaultListItem;

    //   String outputDescriptor = _generateDescriptor(vaultListItem);

    //   String bsmsText = _generateBsmsTextFormat(vaultListItem, outputDescriptor);
    //   String coldcardText = _generateColdcardTextFormat(vaultListItem);
    //   String keystoneText = _generateKeystoneTextFormat(vaultListItem);

    //   String bsmsUr = _encodeToUrBytes(bsmsText);
    //   String coldcardQr = _encodeColdcardQr(coldcardText);
    //   String keystoneUr = _encodeToUrBytes(keystoneText);

    //   Map<String, dynamic> walletSyncString = jsonDecode(vaultListItem.getWalletSyncString());
    //   Map<String, String> namesMap = {};
    //   for (var signer in vaultListItem.signers) {
    //     if (signer.name == null) continue;
    //     namesMap[signer.keyStore.masterFingerprint] = signer.name!;
    //   }

    //   qrData = jsonEncode(
    //     MultisigImportDetail(
    //       name: walletSyncString['name'],
    //       colorIndex: walletSyncString['colorIndex'],
    //       iconIndex: walletSyncString['iconIndex'],
    //       namesMap: namesMap,
    //       coordinatorBsms: bsmsText,
    //     ),
    //   );

    //   walletQrDataMap = {
    //     'BSMS': bsmsUr,
    //     'BlueWallet Vault Multisig': _generateBlueWalletFormat(vaultListItem),
    //     'Coldcard Multisig': coldcardQr,
    //     'Keystone Multisig': keystoneUr,
    //     'Output Descriptor': outputDescriptor,
    //     'Specter Desktop': _generateSpecterFormat(vaultListItem, outputDescriptor),
    //   };

    //   walletTextDataMap = {
    //     'BSMS': bsmsText,
    //     'BlueWallet Vault Multisig': walletQrDataMap['BlueWallet Vault Multisig']!,
    //     'Coldcard Multisig': coldcardText,
    //     'Keystone Multisig': keystoneText,
    //     'Output Descriptor': outputDescriptor,
    //     'Specter Desktop': walletQrDataMap['Specter Desktop']!,
    //   };

    //   notifyListeners();
  }

  // String _encodeToUrBytes(String text) {
  //   try {
  //     Uint8List utf8Data = Uint8List.fromList(utf8.encode(text));
  //     final cborEncoder = CBOREncoder();
  //     cborEncoder.encodeBytes(utf8Data);
  //     final ur = UR('bytes', cborEncoder.getBytes());
  //     final urEncoder = UREncoder(ur, 2000);
  //     return urEncoder.nextPart();
  //   } catch (e) {
  //     return "Error encoding UR: $e";
  //   }
  // }

  // String _encodeColdcardQr(String text) {
  //   try {
  //     List<String> qrFragments = BbQrEncoder.encode(data: text);
  //     if (qrFragments.isNotEmpty) {
  //       return qrFragments.first;
  //     } else {
  //       return "Error: Empty QR result";
  //     }
  //   } catch (e) {
  //     return "Error encoding Coldcard QR: $e";
  //   }
  // }

  // String _generateBsmsTextFormat(MultisigVaultListItem vault, String descriptor) {
  //   StringBuffer buffer = StringBuffer();
  //   buffer.writeln("BSMS 1.0");
  //   buffer.writeln(descriptor);
  //   return buffer.toString();
  // }

  // String _generateKeystoneTextFormat(MultisigVaultListItem vault) {
  //   StringBuffer buffer = StringBuffer();
  //   buffer.writeln("# Keystone Multisig setup file (created by Coconut Vault)");
  //   buffer.writeln("#\n");

  //   String safeName = vault.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-');
  //   if (safeName.isEmpty) safeName = "Multisig";
  //   buffer.writeln("Name: $safeName");
  //   buffer.writeln("Policy: ${vault.requiredSignatureCount} of ${vault.signers.length}");

  //   String derivation = vault.signers.first.getSignerDerivationPath();
  //   if (!derivation.startsWith("m/")) derivation = "m/$derivation";
  //   buffer.writeln("Derivation: $derivation");
  //   buffer.writeln("Format: P2WSH\n");

  //   for (var signer in vault.signers) {
  //     String fingerprint = signer.keyStore.masterFingerprint.toUpperCase();
  //     String xpub = signer.keyStore.extendedPublicKey.serialize(toXpub: true);
  //     buffer.writeln("$fingerprint: $xpub");
  //   }

  //   return buffer.toString();
  // }

  // String _generateColdcardTextFormat(MultisigVaultListItem vault) {
  //   StringBuffer buffer = StringBuffer();
  //   String safeName = vault.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  //   if (safeName.isEmpty) safeName = "Multisig";
  //   if (safeName.length > 20) safeName = safeName.substring(0, 20);
  //   buffer.writeln("Name: $safeName");

  //   buffer.writeln("Policy: ${vault.requiredSignatureCount} of ${vault.signers.length}");
  //   buffer.writeln("Format: P2WSH");

  //   String path = vault.signers.first.getSignerDerivationPath();
  //   if (!path.startsWith('m/')) path = 'm/$path';
  //   path = path.trim();
  //   buffer.writeln("Derivation: $path");

  //   for (var signer in vault.signers) {
  //     String xpub = signer.keyStore.extendedPublicKey.serialize(toXpub: true);
  //     String fingerprint = signer.keyStore.masterFingerprint.toUpperCase();
  //     buffer.writeln("$fingerprint: $xpub");
  //   }

  //   return buffer.toString().trim();
  // }

  // String _generateBlueWalletFormat(MultisigVaultListItem vault) {
  //   StringBuffer buffer = StringBuffer();
  //   buffer.writeln("# Blue Wallet Vault Multisig setup file (created by Coconut Vault)\n#");
  //   buffer.writeln("Name: ${vault.name}");
  //   buffer.writeln("Policy: ${vault.requiredSignatureCount} of ${vault.signers.length}");
  //   buffer.writeln("Derivation: ${vault.signers.first.getSignerDerivationPath()}");
  //   buffer.writeln("Format: P2WSH\n");
  //   for (var signer in vault.signers) {
  //     String xpub = signer.keyStore.extendedPublicKey.serialize(toXpub: true);
  //     buffer.writeln("${signer.keyStore.masterFingerprint}: $xpub");
  //   }
  //   return buffer.toString();
  // }

  // String _generateDescriptor(MultisigVaultListItem vault) {
  //   String derivationPath = vault.signers.first.getSignerDerivationPath().replaceAll('m/', '').replaceAll("'", "h");

  //   List<_SignerSortWrapper> sortedSigners =
  //       vault.signers.map((signer) {
  //         String fingerprint = signer.keyStore.masterFingerprint.toLowerCase();
  //         String xpub = signer.keyStore.extendedPublicKey.serialize(toXpub: true);

  //         String keyString = "[$fingerprint/$derivationPath]$xpub/<0;1>/*";
  //         return _SignerSortWrapper(xpub, fingerprint, keyString);
  //       }).toList();

  //   sortedSigners.sort((a, b) => a.fullKeyString.compareTo(b.fullKeyString));

  //   List<String> publicKeyList = sortedSigners.map((e) => e.xpub).toList();
  //   List<String> fingerprintList = sortedSigners.map((e) => e.fingerprint).toList();

  //   Descriptor descriptor = Descriptor.forMultisignature(
  //     AddressType.p2wsh,
  //     publicKeyList,
  //     derivationPath,
  //     fingerprintList,
  //     vault.requiredSignatureCount,
  //   );

  //   return descriptor.serialize();
  // }

  // String _generateSpecterFormat(MultisigVaultListItem vault, String descriptor) {
  //   final Map<String, dynamic> data = {"label": vault.name, "blockheight": 0, "descriptor": descriptor};
  //   const encoder = JsonEncoder.withIndent('  ');
  //   return encoder.convert(data);
  // }
}

class _SignerSortWrapper {
  final String xpub;
  final String fingerprint;
  final String fullKeyString;

  _SignerSortWrapper(this.xpub, this.fingerprint, this.fullKeyString);
}
