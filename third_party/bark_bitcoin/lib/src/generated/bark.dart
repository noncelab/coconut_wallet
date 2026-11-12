library bark_bitcoin;

import "dart:async";
import "dart:convert";
import "dart:ffi";
import "dart:io" show Platform, File, Directory;
import "dart:isolate";
import "dart:typed_data";
import "package:ffi/ffi.dart";

class Config {
  final String serverAddress;
  final String? serverAccessToken;
  final String? esploraAddress;
  final String? bitcoindAddress;
  final String? bitcoindCookiefile;
  final String? bitcoindUser;
  final String? bitcoindPass;
  final int? vtxoRefreshExpiryThreshold;
  final int? vtxoExitMargin;
  final int? htlcRecvClaimDelta;
  final int? fallbackFeeRate;
  final int? roundTxRequiredConfirmations;
  final int? daemonSyncIntervalSecs;
  final int? offboardRequiredConfirmations;
  final bool? daemonManualSync;
  final int? lightningReceiveClaimRetries;
  final String? userAgent;
  final int? vtxoKeyGapLimit;
  Config({
    required this.serverAddress,
    this.serverAccessToken,
    this.esploraAddress,
    this.bitcoindAddress,
    this.bitcoindCookiefile,
    this.bitcoindUser,
    this.bitcoindPass,
    this.vtxoRefreshExpiryThreshold,
    this.vtxoExitMargin,
    this.htlcRecvClaimDelta,
    this.fallbackFeeRate,
    this.roundTxRequiredConfirmations,
    this.daemonSyncIntervalSecs,
    this.offboardRequiredConfirmations,
    this.daemonManualSync,
    this.lightningReceiveClaimRetries,
    this.userAgent,
    this.vtxoKeyGapLimit,
  });
}

class FfiConverterConfig {
  static Config lift(RustBuffer buf) {
    return FfiConverterConfig.read(buf.asUint8List()).value;
  }

  static LiftRetVal<Config> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final serverAddress_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final serverAddress = serverAddress_lifted.value;
    new_offset += serverAddress_lifted.bytesRead;
    final serverAccessToken_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final serverAccessToken = serverAccessToken_lifted.value;
    new_offset += serverAccessToken_lifted.bytesRead;
    final esploraAddress_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final esploraAddress = esploraAddress_lifted.value;
    new_offset += esploraAddress_lifted.bytesRead;
    final bitcoindAddress_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final bitcoindAddress = bitcoindAddress_lifted.value;
    new_offset += bitcoindAddress_lifted.bytesRead;
    final bitcoindCookiefile_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final bitcoindCookiefile = bitcoindCookiefile_lifted.value;
    new_offset += bitcoindCookiefile_lifted.bytesRead;
    final bitcoindUser_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final bitcoindUser = bitcoindUser_lifted.value;
    new_offset += bitcoindUser_lifted.bytesRead;
    final bitcoindPass_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final bitcoindPass = bitcoindPass_lifted.value;
    new_offset += bitcoindPass_lifted.bytesRead;
    final vtxoRefreshExpiryThreshold_lifted = FfiConverterOptionalUInt16.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vtxoRefreshExpiryThreshold = vtxoRefreshExpiryThreshold_lifted.value;
    new_offset += vtxoRefreshExpiryThreshold_lifted.bytesRead;
    final vtxoExitMargin_lifted = FfiConverterOptionalUInt16.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vtxoExitMargin = vtxoExitMargin_lifted.value;
    new_offset += vtxoExitMargin_lifted.bytesRead;
    final htlcRecvClaimDelta_lifted = FfiConverterOptionalUInt16.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final htlcRecvClaimDelta = htlcRecvClaimDelta_lifted.value;
    new_offset += htlcRecvClaimDelta_lifted.bytesRead;
    final fallbackFeeRate_lifted = FfiConverterOptionalUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final fallbackFeeRate = fallbackFeeRate_lifted.value;
    new_offset += fallbackFeeRate_lifted.bytesRead;
    final roundTxRequiredConfirmations_lifted = FfiConverterOptionalUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final roundTxRequiredConfirmations =
        roundTxRequiredConfirmations_lifted.value;
    new_offset += roundTxRequiredConfirmations_lifted.bytesRead;
    final daemonSyncIntervalSecs_lifted = FfiConverterOptionalUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final daemonSyncIntervalSecs = daemonSyncIntervalSecs_lifted.value;
    new_offset += daemonSyncIntervalSecs_lifted.bytesRead;
    final offboardRequiredConfirmations_lifted =
        FfiConverterOptionalUInt32.read(Uint8List.view(buf.buffer, new_offset));
    final offboardRequiredConfirmations =
        offboardRequiredConfirmations_lifted.value;
    new_offset += offboardRequiredConfirmations_lifted.bytesRead;
    final daemonManualSync_lifted = FfiConverterOptionalBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final daemonManualSync = daemonManualSync_lifted.value;
    new_offset += daemonManualSync_lifted.bytesRead;
    final lightningReceiveClaimRetries_lifted = FfiConverterOptionalUInt8.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final lightningReceiveClaimRetries =
        lightningReceiveClaimRetries_lifted.value;
    new_offset += lightningReceiveClaimRetries_lifted.bytesRead;
    final userAgent_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final userAgent = userAgent_lifted.value;
    new_offset += userAgent_lifted.bytesRead;
    final vtxoKeyGapLimit_lifted = FfiConverterOptionalUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vtxoKeyGapLimit = vtxoKeyGapLimit_lifted.value;
    new_offset += vtxoKeyGapLimit_lifted.bytesRead;
    return LiftRetVal(
      Config(
        serverAddress: serverAddress,
        serverAccessToken: serverAccessToken,
        esploraAddress: esploraAddress,
        bitcoindAddress: bitcoindAddress,
        bitcoindCookiefile: bitcoindCookiefile,
        bitcoindUser: bitcoindUser,
        bitcoindPass: bitcoindPass,
        vtxoRefreshExpiryThreshold: vtxoRefreshExpiryThreshold,
        vtxoExitMargin: vtxoExitMargin,
        htlcRecvClaimDelta: htlcRecvClaimDelta,
        fallbackFeeRate: fallbackFeeRate,
        roundTxRequiredConfirmations: roundTxRequiredConfirmations,
        daemonSyncIntervalSecs: daemonSyncIntervalSecs,
        offboardRequiredConfirmations: offboardRequiredConfirmations,
        daemonManualSync: daemonManualSync,
        lightningReceiveClaimRetries: lightningReceiveClaimRetries,
        userAgent: userAgent,
        vtxoKeyGapLimit: vtxoKeyGapLimit,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(Config value) {
    final total_length =
        FfiConverterString.allocationSize(value.serverAddress) +
        FfiConverterOptionalString.allocationSize(value.serverAccessToken) +
        FfiConverterOptionalString.allocationSize(value.esploraAddress) +
        FfiConverterOptionalString.allocationSize(value.bitcoindAddress) +
        FfiConverterOptionalString.allocationSize(value.bitcoindCookiefile) +
        FfiConverterOptionalString.allocationSize(value.bitcoindUser) +
        FfiConverterOptionalString.allocationSize(value.bitcoindPass) +
        FfiConverterOptionalUInt16.allocationSize(
          value.vtxoRefreshExpiryThreshold,
        ) +
        FfiConverterOptionalUInt16.allocationSize(value.vtxoExitMargin) +
        FfiConverterOptionalUInt16.allocationSize(value.htlcRecvClaimDelta) +
        FfiConverterOptionalUInt64.allocationSize(value.fallbackFeeRate) +
        FfiConverterOptionalUInt32.allocationSize(
          value.roundTxRequiredConfirmations,
        ) +
        FfiConverterOptionalUInt64.allocationSize(
          value.daemonSyncIntervalSecs,
        ) +
        FfiConverterOptionalUInt32.allocationSize(
          value.offboardRequiredConfirmations,
        ) +
        FfiConverterOptionalBool.allocationSize(value.daemonManualSync) +
        FfiConverterOptionalUInt8.allocationSize(
          value.lightningReceiveClaimRetries,
        ) +
        FfiConverterOptionalString.allocationSize(value.userAgent) +
        FfiConverterOptionalUInt32.allocationSize(value.vtxoKeyGapLimit) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(Config value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.serverAddress,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.serverAccessToken,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.esploraAddress,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.bitcoindAddress,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.bitcoindCookiefile,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.bitcoindUser,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.bitcoindPass,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt16.write(
      value.vtxoRefreshExpiryThreshold,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt16.write(
      value.vtxoExitMargin,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt16.write(
      value.htlcRecvClaimDelta,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt64.write(
      value.fallbackFeeRate,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt32.write(
      value.roundTxRequiredConfirmations,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt64.write(
      value.daemonSyncIntervalSecs,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt32.write(
      value.offboardRequiredConfirmations,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalBool.write(
      value.daemonManualSync,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt8.write(
      value.lightningReceiveClaimRetries,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.userAgent,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt32.write(
      value.vtxoKeyGapLimit,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(Config value) {
    return FfiConverterString.allocationSize(value.serverAddress) +
        FfiConverterOptionalString.allocationSize(value.serverAccessToken) +
        FfiConverterOptionalString.allocationSize(value.esploraAddress) +
        FfiConverterOptionalString.allocationSize(value.bitcoindAddress) +
        FfiConverterOptionalString.allocationSize(value.bitcoindCookiefile) +
        FfiConverterOptionalString.allocationSize(value.bitcoindUser) +
        FfiConverterOptionalString.allocationSize(value.bitcoindPass) +
        FfiConverterOptionalUInt16.allocationSize(
          value.vtxoRefreshExpiryThreshold,
        ) +
        FfiConverterOptionalUInt16.allocationSize(value.vtxoExitMargin) +
        FfiConverterOptionalUInt16.allocationSize(value.htlcRecvClaimDelta) +
        FfiConverterOptionalUInt64.allocationSize(value.fallbackFeeRate) +
        FfiConverterOptionalUInt32.allocationSize(
          value.roundTxRequiredConfirmations,
        ) +
        FfiConverterOptionalUInt64.allocationSize(
          value.daemonSyncIntervalSecs,
        ) +
        FfiConverterOptionalUInt32.allocationSize(
          value.offboardRequiredConfirmations,
        ) +
        FfiConverterOptionalBool.allocationSize(value.daemonManualSync) +
        FfiConverterOptionalUInt8.allocationSize(
          value.lightningReceiveClaimRetries,
        ) +
        FfiConverterOptionalString.allocationSize(value.userAgent) +
        FfiConverterOptionalUInt32.allocationSize(value.vtxoKeyGapLimit) +
        0;
  }
}

class WalletOpenArgs {
  final bool runDaemon;
  final String datadir;
  final OnchainWallet? onchain;
  final bool createIfNotExists;
  final bool createWithoutServer;
  final bool skipRecovery;
  WalletOpenArgs({
    this.runDaemon = true,
    required this.datadir,
    this.onchain,
    this.createIfNotExists = true,
    this.createWithoutServer = false,
    this.skipRecovery = false,
  });
}

class FfiConverterWalletOpenArgs {
  static WalletOpenArgs lift(RustBuffer buf) {
    return FfiConverterWalletOpenArgs.read(buf.asUint8List()).value;
  }

  static LiftRetVal<WalletOpenArgs> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final runDaemon_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final runDaemon = runDaemon_lifted.value;
    new_offset += runDaemon_lifted.bytesRead;
    final datadir_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final datadir = datadir_lifted.value;
    new_offset += datadir_lifted.bytesRead;
    final onchain_lifted = FfiConverterOptionalOnchainWallet.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final onchain = onchain_lifted.value;
    new_offset += onchain_lifted.bytesRead;
    final createIfNotExists_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final createIfNotExists = createIfNotExists_lifted.value;
    new_offset += createIfNotExists_lifted.bytesRead;
    final createWithoutServer_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final createWithoutServer = createWithoutServer_lifted.value;
    new_offset += createWithoutServer_lifted.bytesRead;
    final skipRecovery_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final skipRecovery = skipRecovery_lifted.value;
    new_offset += skipRecovery_lifted.bytesRead;
    return LiftRetVal(
      WalletOpenArgs(
        runDaemon: runDaemon,
        datadir: datadir,
        onchain: onchain,
        createIfNotExists: createIfNotExists,
        createWithoutServer: createWithoutServer,
        skipRecovery: skipRecovery,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(WalletOpenArgs value) {
    final total_length =
        FfiConverterBool.allocationSize(value.runDaemon) +
        FfiConverterString.allocationSize(value.datadir) +
        FfiConverterOptionalOnchainWallet.allocationSize(value.onchain) +
        FfiConverterBool.allocationSize(value.createIfNotExists) +
        FfiConverterBool.allocationSize(value.createWithoutServer) +
        FfiConverterBool.allocationSize(value.skipRecovery) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(WalletOpenArgs value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterBool.write(
      value.runDaemon,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.datadir,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalOnchainWallet.write(
      value.onchain,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBool.write(
      value.createIfNotExists,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBool.write(
      value.createWithoutServer,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBool.write(
      value.skipRecovery,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(WalletOpenArgs value) {
    return FfiConverterBool.allocationSize(value.runDaemon) +
        FfiConverterString.allocationSize(value.datadir) +
        FfiConverterOptionalOnchainWallet.allocationSize(value.onchain) +
        FfiConverterBool.allocationSize(value.createIfNotExists) +
        FfiConverterBool.allocationSize(value.createWithoutServer) +
        FfiConverterBool.allocationSize(value.skipRecovery) +
        0;
  }
}

class AddressWithIndex {
  final String address;
  final int index;
  AddressWithIndex({required this.address, required this.index});
}

class FfiConverterAddressWithIndex {
  static AddressWithIndex lift(RustBuffer buf) {
    return FfiConverterAddressWithIndex.read(buf.asUint8List()).value;
  }

  static LiftRetVal<AddressWithIndex> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final address_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final address = address_lifted.value;
    new_offset += address_lifted.bytesRead;
    final index_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final index = index_lifted.value;
    new_offset += index_lifted.bytesRead;
    return LiftRetVal(
      AddressWithIndex(address: address, index: index),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(AddressWithIndex value) {
    final total_length =
        FfiConverterString.allocationSize(value.address) +
        FfiConverterUInt32.allocationSize(value.index) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(AddressWithIndex value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.address,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.index,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(AddressWithIndex value) {
    return FfiConverterString.allocationSize(value.address) +
        FfiConverterUInt32.allocationSize(value.index) +
        0;
  }
}

class ArkInfo {
  final Network network;
  final String serverPubkey;
  final int roundIntervalSecs;
  final int nbRoundNonces;
  final int vtxoExitDelta;
  final int vtxoLifetime;
  final int vtxoExpiryDelta;
  final int htlcSendExpiryDelta;
  final int htlcExpiryDelta;
  final int? maxVtxoAmountSats;
  final int requiredBoardConfirmations;
  final int maxUserInvoiceCltvDelta;
  final int minBoardAmountSats;
  final bool lnReceiveAntiDosRequired;
  final FeeSchedule feeSchedule;
  final int maxVtxoExitDepth;
  ArkInfo({
    required this.network,
    required this.serverPubkey,
    required this.roundIntervalSecs,
    required this.nbRoundNonces,
    required this.vtxoExitDelta,
    required this.vtxoLifetime,
    required this.vtxoExpiryDelta,
    required this.htlcSendExpiryDelta,
    required this.htlcExpiryDelta,
    this.maxVtxoAmountSats,
    required this.requiredBoardConfirmations,
    required this.maxUserInvoiceCltvDelta,
    required this.minBoardAmountSats,
    required this.lnReceiveAntiDosRequired,
    required this.feeSchedule,
    required this.maxVtxoExitDepth,
  });
}

class FfiConverterArkInfo {
  static ArkInfo lift(RustBuffer buf) {
    return FfiConverterArkInfo.read(buf.asUint8List()).value;
  }

  static LiftRetVal<ArkInfo> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final network_lifted = FfiConverterNetwork.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final network = network_lifted.value;
    new_offset += network_lifted.bytesRead;
    final serverPubkey_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final serverPubkey = serverPubkey_lifted.value;
    new_offset += serverPubkey_lifted.bytesRead;
    final roundIntervalSecs_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final roundIntervalSecs = roundIntervalSecs_lifted.value;
    new_offset += roundIntervalSecs_lifted.bytesRead;
    final nbRoundNonces_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final nbRoundNonces = nbRoundNonces_lifted.value;
    new_offset += nbRoundNonces_lifted.bytesRead;
    final vtxoExitDelta_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vtxoExitDelta = vtxoExitDelta_lifted.value;
    new_offset += vtxoExitDelta_lifted.bytesRead;
    final vtxoLifetime_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vtxoLifetime = vtxoLifetime_lifted.value;
    new_offset += vtxoLifetime_lifted.bytesRead;
    final vtxoExpiryDelta_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vtxoExpiryDelta = vtxoExpiryDelta_lifted.value;
    new_offset += vtxoExpiryDelta_lifted.bytesRead;
    final htlcSendExpiryDelta_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final htlcSendExpiryDelta = htlcSendExpiryDelta_lifted.value;
    new_offset += htlcSendExpiryDelta_lifted.bytesRead;
    final htlcExpiryDelta_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final htlcExpiryDelta = htlcExpiryDelta_lifted.value;
    new_offset += htlcExpiryDelta_lifted.bytesRead;
    final maxVtxoAmountSats_lifted = FfiConverterOptionalUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final maxVtxoAmountSats = maxVtxoAmountSats_lifted.value;
    new_offset += maxVtxoAmountSats_lifted.bytesRead;
    final requiredBoardConfirmations_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final requiredBoardConfirmations = requiredBoardConfirmations_lifted.value;
    new_offset += requiredBoardConfirmations_lifted.bytesRead;
    final maxUserInvoiceCltvDelta_lifted = FfiConverterUInt16.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final maxUserInvoiceCltvDelta = maxUserInvoiceCltvDelta_lifted.value;
    new_offset += maxUserInvoiceCltvDelta_lifted.bytesRead;
    final minBoardAmountSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final minBoardAmountSats = minBoardAmountSats_lifted.value;
    new_offset += minBoardAmountSats_lifted.bytesRead;
    final lnReceiveAntiDosRequired_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final lnReceiveAntiDosRequired = lnReceiveAntiDosRequired_lifted.value;
    new_offset += lnReceiveAntiDosRequired_lifted.bytesRead;
    final feeSchedule_lifted = FfiConverterFeeSchedule.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final feeSchedule = feeSchedule_lifted.value;
    new_offset += feeSchedule_lifted.bytesRead;
    final maxVtxoExitDepth_lifted = FfiConverterUInt16.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final maxVtxoExitDepth = maxVtxoExitDepth_lifted.value;
    new_offset += maxVtxoExitDepth_lifted.bytesRead;
    return LiftRetVal(
      ArkInfo(
        network: network,
        serverPubkey: serverPubkey,
        roundIntervalSecs: roundIntervalSecs,
        nbRoundNonces: nbRoundNonces,
        vtxoExitDelta: vtxoExitDelta,
        vtxoLifetime: vtxoLifetime,
        vtxoExpiryDelta: vtxoExpiryDelta,
        htlcSendExpiryDelta: htlcSendExpiryDelta,
        htlcExpiryDelta: htlcExpiryDelta,
        maxVtxoAmountSats: maxVtxoAmountSats,
        requiredBoardConfirmations: requiredBoardConfirmations,
        maxUserInvoiceCltvDelta: maxUserInvoiceCltvDelta,
        minBoardAmountSats: minBoardAmountSats,
        lnReceiveAntiDosRequired: lnReceiveAntiDosRequired,
        feeSchedule: feeSchedule,
        maxVtxoExitDepth: maxVtxoExitDepth,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(ArkInfo value) {
    final total_length =
        FfiConverterNetwork.allocationSize(value.network) +
        FfiConverterString.allocationSize(value.serverPubkey) +
        FfiConverterUInt64.allocationSize(value.roundIntervalSecs) +
        FfiConverterUInt32.allocationSize(value.nbRoundNonces) +
        FfiConverterUInt32.allocationSize(value.vtxoExitDelta) +
        FfiConverterUInt32.allocationSize(value.vtxoLifetime) +
        FfiConverterUInt32.allocationSize(value.vtxoExpiryDelta) +
        FfiConverterUInt32.allocationSize(value.htlcSendExpiryDelta) +
        FfiConverterUInt32.allocationSize(value.htlcExpiryDelta) +
        FfiConverterOptionalUInt64.allocationSize(value.maxVtxoAmountSats) +
        FfiConverterUInt32.allocationSize(value.requiredBoardConfirmations) +
        FfiConverterUInt16.allocationSize(value.maxUserInvoiceCltvDelta) +
        FfiConverterUInt64.allocationSize(value.minBoardAmountSats) +
        FfiConverterBool.allocationSize(value.lnReceiveAntiDosRequired) +
        FfiConverterFeeSchedule.allocationSize(value.feeSchedule) +
        FfiConverterUInt16.allocationSize(value.maxVtxoExitDepth) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(ArkInfo value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterNetwork.write(
      value.network,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.serverPubkey,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.roundIntervalSecs,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.nbRoundNonces,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.vtxoExitDelta,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.vtxoLifetime,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.vtxoExpiryDelta,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.htlcSendExpiryDelta,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.htlcExpiryDelta,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt64.write(
      value.maxVtxoAmountSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.requiredBoardConfirmations,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt16.write(
      value.maxUserInvoiceCltvDelta,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.minBoardAmountSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBool.write(
      value.lnReceiveAntiDosRequired,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterFeeSchedule.write(
      value.feeSchedule,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt16.write(
      value.maxVtxoExitDepth,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(ArkInfo value) {
    return FfiConverterNetwork.allocationSize(value.network) +
        FfiConverterString.allocationSize(value.serverPubkey) +
        FfiConverterUInt64.allocationSize(value.roundIntervalSecs) +
        FfiConverterUInt32.allocationSize(value.nbRoundNonces) +
        FfiConverterUInt32.allocationSize(value.vtxoExitDelta) +
        FfiConverterUInt32.allocationSize(value.vtxoLifetime) +
        FfiConverterUInt32.allocationSize(value.vtxoExpiryDelta) +
        FfiConverterUInt32.allocationSize(value.htlcSendExpiryDelta) +
        FfiConverterUInt32.allocationSize(value.htlcExpiryDelta) +
        FfiConverterOptionalUInt64.allocationSize(value.maxVtxoAmountSats) +
        FfiConverterUInt32.allocationSize(value.requiredBoardConfirmations) +
        FfiConverterUInt16.allocationSize(value.maxUserInvoiceCltvDelta) +
        FfiConverterUInt64.allocationSize(value.minBoardAmountSats) +
        FfiConverterBool.allocationSize(value.lnReceiveAntiDosRequired) +
        FfiConverterFeeSchedule.allocationSize(value.feeSchedule) +
        FfiConverterUInt16.allocationSize(value.maxVtxoExitDepth) +
        0;
  }
}

class Balance {
  final int spendableSats;
  final int pendingInRoundSats;
  final int pendingExitSats;
  final int pendingLightningSendSats;
  final int claimableLightningReceiveSats;
  final int pendingBoardSats;
  Balance({
    required this.spendableSats,
    required this.pendingInRoundSats,
    required this.pendingExitSats,
    required this.pendingLightningSendSats,
    required this.claimableLightningReceiveSats,
    required this.pendingBoardSats,
  });
}

class FfiConverterBalance {
  static Balance lift(RustBuffer buf) {
    return FfiConverterBalance.read(buf.asUint8List()).value;
  }

  static LiftRetVal<Balance> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final spendableSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final spendableSats = spendableSats_lifted.value;
    new_offset += spendableSats_lifted.bytesRead;
    final pendingInRoundSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final pendingInRoundSats = pendingInRoundSats_lifted.value;
    new_offset += pendingInRoundSats_lifted.bytesRead;
    final pendingExitSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final pendingExitSats = pendingExitSats_lifted.value;
    new_offset += pendingExitSats_lifted.bytesRead;
    final pendingLightningSendSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final pendingLightningSendSats = pendingLightningSendSats_lifted.value;
    new_offset += pendingLightningSendSats_lifted.bytesRead;
    final claimableLightningReceiveSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final claimableLightningReceiveSats =
        claimableLightningReceiveSats_lifted.value;
    new_offset += claimableLightningReceiveSats_lifted.bytesRead;
    final pendingBoardSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final pendingBoardSats = pendingBoardSats_lifted.value;
    new_offset += pendingBoardSats_lifted.bytesRead;
    return LiftRetVal(
      Balance(
        spendableSats: spendableSats,
        pendingInRoundSats: pendingInRoundSats,
        pendingExitSats: pendingExitSats,
        pendingLightningSendSats: pendingLightningSendSats,
        claimableLightningReceiveSats: claimableLightningReceiveSats,
        pendingBoardSats: pendingBoardSats,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(Balance value) {
    final total_length =
        FfiConverterUInt64.allocationSize(value.spendableSats) +
        FfiConverterUInt64.allocationSize(value.pendingInRoundSats) +
        FfiConverterUInt64.allocationSize(value.pendingExitSats) +
        FfiConverterUInt64.allocationSize(value.pendingLightningSendSats) +
        FfiConverterUInt64.allocationSize(value.claimableLightningReceiveSats) +
        FfiConverterUInt64.allocationSize(value.pendingBoardSats) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(Balance value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt64.write(
      value.spendableSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.pendingInRoundSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.pendingExitSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.pendingLightningSendSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.claimableLightningReceiveSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.pendingBoardSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(Balance value) {
    return FfiConverterUInt64.allocationSize(value.spendableSats) +
        FfiConverterUInt64.allocationSize(value.pendingInRoundSats) +
        FfiConverterUInt64.allocationSize(value.pendingExitSats) +
        FfiConverterUInt64.allocationSize(value.pendingLightningSendSats) +
        FfiConverterUInt64.allocationSize(value.claimableLightningReceiveSats) +
        FfiConverterUInt64.allocationSize(value.pendingBoardSats) +
        0;
  }
}

class BlockRef {
  final int height;
  final String hash;
  BlockRef({required this.height, required this.hash});
}

class FfiConverterBlockRef {
  static BlockRef lift(RustBuffer buf) {
    return FfiConverterBlockRef.read(buf.asUint8List()).value;
  }

  static LiftRetVal<BlockRef> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final height_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final height = height_lifted.value;
    new_offset += height_lifted.bytesRead;
    final hash_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final hash = hash_lifted.value;
    new_offset += hash_lifted.bytesRead;
    return LiftRetVal(
      BlockRef(height: height, hash: hash),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(BlockRef value) {
    final total_length =
        FfiConverterUInt32.allocationSize(value.height) +
        FfiConverterString.allocationSize(value.hash) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(BlockRef value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt32.write(
      value.height,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.hash,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(BlockRef value) {
    return FfiConverterUInt32.allocationSize(value.height) +
        FfiConverterString.allocationSize(value.hash) +
        0;
  }
}

class BoardFees {
  final int minFeeSats;
  final int baseFeeSats;
  final int ppm;
  BoardFees({
    required this.minFeeSats,
    required this.baseFeeSats,
    required this.ppm,
  });
}

class FfiConverterBoardFees {
  static BoardFees lift(RustBuffer buf) {
    return FfiConverterBoardFees.read(buf.asUint8List()).value;
  }

  static LiftRetVal<BoardFees> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final minFeeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final minFeeSats = minFeeSats_lifted.value;
    new_offset += minFeeSats_lifted.bytesRead;
    final baseFeeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final baseFeeSats = baseFeeSats_lifted.value;
    new_offset += baseFeeSats_lifted.bytesRead;
    final ppm_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final ppm = ppm_lifted.value;
    new_offset += ppm_lifted.bytesRead;
    return LiftRetVal(
      BoardFees(minFeeSats: minFeeSats, baseFeeSats: baseFeeSats, ppm: ppm),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(BoardFees value) {
    final total_length =
        FfiConverterUInt64.allocationSize(value.minFeeSats) +
        FfiConverterUInt64.allocationSize(value.baseFeeSats) +
        FfiConverterUInt64.allocationSize(value.ppm) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(BoardFees value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt64.write(
      value.minFeeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.baseFeeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.ppm,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(BoardFees value) {
    return FfiConverterUInt64.allocationSize(value.minFeeSats) +
        FfiConverterUInt64.allocationSize(value.baseFeeSats) +
        FfiConverterUInt64.allocationSize(value.ppm) +
        0;
  }
}

class BoardFundingInfo {
  final String address;
  final int expiryHeight;
  final int keypairIndex;
  BoardFundingInfo({
    required this.address,
    required this.expiryHeight,
    required this.keypairIndex,
  });
}

class FfiConverterBoardFundingInfo {
  static BoardFundingInfo lift(RustBuffer buf) {
    return FfiConverterBoardFundingInfo.read(buf.asUint8List()).value;
  }

  static LiftRetVal<BoardFundingInfo> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final address_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final address = address_lifted.value;
    new_offset += address_lifted.bytesRead;
    final expiryHeight_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final expiryHeight = expiryHeight_lifted.value;
    new_offset += expiryHeight_lifted.bytesRead;
    final keypairIndex_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final keypairIndex = keypairIndex_lifted.value;
    new_offset += keypairIndex_lifted.bytesRead;
    return LiftRetVal(
      BoardFundingInfo(
        address: address,
        expiryHeight: expiryHeight,
        keypairIndex: keypairIndex,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(BoardFundingInfo value) {
    final total_length =
        FfiConverterString.allocationSize(value.address) +
        FfiConverterUInt32.allocationSize(value.expiryHeight) +
        FfiConverterUInt32.allocationSize(value.keypairIndex) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(BoardFundingInfo value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.address,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.expiryHeight,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.keypairIndex,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(BoardFundingInfo value) {
    return FfiConverterString.allocationSize(value.address) +
        FfiConverterUInt32.allocationSize(value.expiryHeight) +
        FfiConverterUInt32.allocationSize(value.keypairIndex) +
        0;
  }
}

class CpfpParams {
  final String txHex;
  final String feesType;
  final int effectiveFeeRateSatPerVb;
  final int? currentPackageFeeSats;
  CpfpParams({
    required this.txHex,
    required this.feesType,
    required this.effectiveFeeRateSatPerVb,
    this.currentPackageFeeSats,
  });
}

class FfiConverterCpfpParams {
  static CpfpParams lift(RustBuffer buf) {
    return FfiConverterCpfpParams.read(buf.asUint8List()).value;
  }

  static LiftRetVal<CpfpParams> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final txHex_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final txHex = txHex_lifted.value;
    new_offset += txHex_lifted.bytesRead;
    final feesType_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final feesType = feesType_lifted.value;
    new_offset += feesType_lifted.bytesRead;
    final effectiveFeeRateSatPerVb_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final effectiveFeeRateSatPerVb = effectiveFeeRateSatPerVb_lifted.value;
    new_offset += effectiveFeeRateSatPerVb_lifted.bytesRead;
    final currentPackageFeeSats_lifted = FfiConverterOptionalUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final currentPackageFeeSats = currentPackageFeeSats_lifted.value;
    new_offset += currentPackageFeeSats_lifted.bytesRead;
    return LiftRetVal(
      CpfpParams(
        txHex: txHex,
        feesType: feesType,
        effectiveFeeRateSatPerVb: effectiveFeeRateSatPerVb,
        currentPackageFeeSats: currentPackageFeeSats,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(CpfpParams value) {
    final total_length =
        FfiConverterString.allocationSize(value.txHex) +
        FfiConverterString.allocationSize(value.feesType) +
        FfiConverterUInt64.allocationSize(value.effectiveFeeRateSatPerVb) +
        FfiConverterOptionalUInt64.allocationSize(value.currentPackageFeeSats) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(CpfpParams value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.txHex,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.feesType,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.effectiveFeeRateSatPerVb,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt64.write(
      value.currentPackageFeeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(CpfpParams value) {
    return FfiConverterString.allocationSize(value.txHex) +
        FfiConverterString.allocationSize(value.feesType) +
        FfiConverterUInt64.allocationSize(value.effectiveFeeRateSatPerVb) +
        FfiConverterOptionalUInt64.allocationSize(value.currentPackageFeeSats) +
        0;
  }
}

class Destination {
  final String address;
  final int amountSats;
  Destination({required this.address, required this.amountSats});
}

class FfiConverterDestination {
  static Destination lift(RustBuffer buf) {
    return FfiConverterDestination.read(buf.asUint8List()).value;
  }

  static LiftRetVal<Destination> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final address_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final address = address_lifted.value;
    new_offset += address_lifted.bytesRead;
    final amountSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final amountSats = amountSats_lifted.value;
    new_offset += amountSats_lifted.bytesRead;
    return LiftRetVal(
      Destination(address: address, amountSats: amountSats),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(Destination value) {
    final total_length =
        FfiConverterString.allocationSize(value.address) +
        FfiConverterUInt64.allocationSize(value.amountSats) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(Destination value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.address,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.amountSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(Destination value) {
    return FfiConverterString.allocationSize(value.address) +
        FfiConverterUInt64.allocationSize(value.amountSats) +
        0;
  }
}

class EmergencyExitFeeEstimate {
  final int exitBroadcastFeeSats;
  final int claimFeeSats;
  final int totalFeeSats;
  final int feeRateSatPerVb;
  final int txsToBroadcast;
  final bool fundable;
  EmergencyExitFeeEstimate({
    required this.exitBroadcastFeeSats,
    required this.claimFeeSats,
    required this.totalFeeSats,
    required this.feeRateSatPerVb,
    required this.txsToBroadcast,
    required this.fundable,
  });
}

class FfiConverterEmergencyExitFeeEstimate {
  static EmergencyExitFeeEstimate lift(RustBuffer buf) {
    return FfiConverterEmergencyExitFeeEstimate.read(buf.asUint8List()).value;
  }

  static LiftRetVal<EmergencyExitFeeEstimate> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final exitBroadcastFeeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final exitBroadcastFeeSats = exitBroadcastFeeSats_lifted.value;
    new_offset += exitBroadcastFeeSats_lifted.bytesRead;
    final claimFeeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final claimFeeSats = claimFeeSats_lifted.value;
    new_offset += claimFeeSats_lifted.bytesRead;
    final totalFeeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final totalFeeSats = totalFeeSats_lifted.value;
    new_offset += totalFeeSats_lifted.bytesRead;
    final feeRateSatPerVb_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final feeRateSatPerVb = feeRateSatPerVb_lifted.value;
    new_offset += feeRateSatPerVb_lifted.bytesRead;
    final txsToBroadcast_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final txsToBroadcast = txsToBroadcast_lifted.value;
    new_offset += txsToBroadcast_lifted.bytesRead;
    final fundable_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final fundable = fundable_lifted.value;
    new_offset += fundable_lifted.bytesRead;
    return LiftRetVal(
      EmergencyExitFeeEstimate(
        exitBroadcastFeeSats: exitBroadcastFeeSats,
        claimFeeSats: claimFeeSats,
        totalFeeSats: totalFeeSats,
        feeRateSatPerVb: feeRateSatPerVb,
        txsToBroadcast: txsToBroadcast,
        fundable: fundable,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(EmergencyExitFeeEstimate value) {
    final total_length =
        FfiConverterUInt64.allocationSize(value.exitBroadcastFeeSats) +
        FfiConverterUInt64.allocationSize(value.claimFeeSats) +
        FfiConverterUInt64.allocationSize(value.totalFeeSats) +
        FfiConverterUInt64.allocationSize(value.feeRateSatPerVb) +
        FfiConverterUInt64.allocationSize(value.txsToBroadcast) +
        FfiConverterBool.allocationSize(value.fundable) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(EmergencyExitFeeEstimate value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt64.write(
      value.exitBroadcastFeeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.claimFeeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.totalFeeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.feeRateSatPerVb,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.txsToBroadcast,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBool.write(
      value.fundable,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(EmergencyExitFeeEstimate value) {
    return FfiConverterUInt64.allocationSize(value.exitBroadcastFeeSats) +
        FfiConverterUInt64.allocationSize(value.claimFeeSats) +
        FfiConverterUInt64.allocationSize(value.totalFeeSats) +
        FfiConverterUInt64.allocationSize(value.feeRateSatPerVb) +
        FfiConverterUInt64.allocationSize(value.txsToBroadcast) +
        FfiConverterBool.allocationSize(value.fundable) +
        0;
  }
}

class ExitCancelResult {
  final bool canceled;
  final ExitCancelFailure? reason;
  ExitCancelResult({required this.canceled, this.reason});
}

class FfiConverterExitCancelResult {
  static ExitCancelResult lift(RustBuffer buf) {
    return FfiConverterExitCancelResult.read(buf.asUint8List()).value;
  }

  static LiftRetVal<ExitCancelResult> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final canceled_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final canceled = canceled_lifted.value;
    new_offset += canceled_lifted.bytesRead;
    final reason_lifted = FfiConverterOptionalExitCancelFailure.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final reason = reason_lifted.value;
    new_offset += reason_lifted.bytesRead;
    return LiftRetVal(
      ExitCancelResult(canceled: canceled, reason: reason),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(ExitCancelResult value) {
    final total_length =
        FfiConverterBool.allocationSize(value.canceled) +
        FfiConverterOptionalExitCancelFailure.allocationSize(value.reason) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(ExitCancelResult value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterBool.write(
      value.canceled,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalExitCancelFailure.write(
      value.reason,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(ExitCancelResult value) {
    return FfiConverterBool.allocationSize(value.canceled) +
        FfiConverterOptionalExitCancelFailure.allocationSize(value.reason) +
        0;
  }
}

class ExitClaimTransaction {
  final String psbtBase64;
  final int feeSats;
  ExitClaimTransaction({required this.psbtBase64, required this.feeSats});
}

class FfiConverterExitClaimTransaction {
  static ExitClaimTransaction lift(RustBuffer buf) {
    return FfiConverterExitClaimTransaction.read(buf.asUint8List()).value;
  }

  static LiftRetVal<ExitClaimTransaction> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final psbtBase64_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final psbtBase64 = psbtBase64_lifted.value;
    new_offset += psbtBase64_lifted.bytesRead;
    final feeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final feeSats = feeSats_lifted.value;
    new_offset += feeSats_lifted.bytesRead;
    return LiftRetVal(
      ExitClaimTransaction(psbtBase64: psbtBase64, feeSats: feeSats),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(ExitClaimTransaction value) {
    final total_length =
        FfiConverterString.allocationSize(value.psbtBase64) +
        FfiConverterUInt64.allocationSize(value.feeSats) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(ExitClaimTransaction value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.psbtBase64,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.feeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(ExitClaimTransaction value) {
    return FfiConverterString.allocationSize(value.psbtBase64) +
        FfiConverterUInt64.allocationSize(value.feeSats) +
        0;
  }
}

class ExitProgressStatus {
  final String vtxoId;
  final ExitState state;
  final String? error;
  ExitProgressStatus({required this.vtxoId, required this.state, this.error});
}

class FfiConverterExitProgressStatus {
  static ExitProgressStatus lift(RustBuffer buf) {
    return FfiConverterExitProgressStatus.read(buf.asUint8List()).value;
  }

  static LiftRetVal<ExitProgressStatus> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final vtxoId_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vtxoId = vtxoId_lifted.value;
    new_offset += vtxoId_lifted.bytesRead;
    final state_lifted = FfiConverterExitState.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final state = state_lifted.value;
    new_offset += state_lifted.bytesRead;
    final error_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final error = error_lifted.value;
    new_offset += error_lifted.bytesRead;
    return LiftRetVal(
      ExitProgressStatus(vtxoId: vtxoId, state: state, error: error),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(ExitProgressStatus value) {
    final total_length =
        FfiConverterString.allocationSize(value.vtxoId) +
        FfiConverterExitState.allocationSize(value.state) +
        FfiConverterOptionalString.allocationSize(value.error) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(ExitProgressStatus value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.vtxoId,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterExitState.write(
      value.state,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.error,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(ExitProgressStatus value) {
    return FfiConverterString.allocationSize(value.vtxoId) +
        FfiConverterExitState.allocationSize(value.state) +
        FfiConverterOptionalString.allocationSize(value.error) +
        0;
  }
}

class ExitTransactionStatus {
  final String vtxoId;
  final ExitState state;
  final List<ExitState>? history;
  final int transactionCount;
  ExitTransactionStatus({
    required this.vtxoId,
    required this.state,
    this.history,
    required this.transactionCount,
  });
}

class FfiConverterExitTransactionStatus {
  static ExitTransactionStatus lift(RustBuffer buf) {
    return FfiConverterExitTransactionStatus.read(buf.asUint8List()).value;
  }

  static LiftRetVal<ExitTransactionStatus> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final vtxoId_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vtxoId = vtxoId_lifted.value;
    new_offset += vtxoId_lifted.bytesRead;
    final state_lifted = FfiConverterExitState.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final state = state_lifted.value;
    new_offset += state_lifted.bytesRead;
    final history_lifted = FfiConverterOptionalSequenceExitState.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final history = history_lifted.value;
    new_offset += history_lifted.bytesRead;
    final transactionCount_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final transactionCount = transactionCount_lifted.value;
    new_offset += transactionCount_lifted.bytesRead;
    return LiftRetVal(
      ExitTransactionStatus(
        vtxoId: vtxoId,
        state: state,
        history: history,
        transactionCount: transactionCount,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(ExitTransactionStatus value) {
    final total_length =
        FfiConverterString.allocationSize(value.vtxoId) +
        FfiConverterExitState.allocationSize(value.state) +
        FfiConverterOptionalSequenceExitState.allocationSize(value.history) +
        FfiConverterUInt32.allocationSize(value.transactionCount) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(ExitTransactionStatus value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.vtxoId,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterExitState.write(
      value.state,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalSequenceExitState.write(
      value.history,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.transactionCount,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(ExitTransactionStatus value) {
    return FfiConverterString.allocationSize(value.vtxoId) +
        FfiConverterExitState.allocationSize(value.state) +
        FfiConverterOptionalSequenceExitState.allocationSize(value.history) +
        FfiConverterUInt32.allocationSize(value.transactionCount) +
        0;
  }
}

class ExitTx {
  final String txid;
  final ExitTxStatus status;
  ExitTx({required this.txid, required this.status});
}

class FfiConverterExitTx {
  static ExitTx lift(RustBuffer buf) {
    return FfiConverterExitTx.read(buf.asUint8List()).value;
  }

  static LiftRetVal<ExitTx> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final txid_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final txid = txid_lifted.value;
    new_offset += txid_lifted.bytesRead;
    final status_lifted = FfiConverterExitTxStatus.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final status = status_lifted.value;
    new_offset += status_lifted.bytesRead;
    return LiftRetVal(
      ExitTx(txid: txid, status: status),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(ExitTx value) {
    final total_length =
        FfiConverterString.allocationSize(value.txid) +
        FfiConverterExitTxStatus.allocationSize(value.status) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(ExitTx value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.txid,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterExitTxStatus.write(
      value.status,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(ExitTx value) {
    return FfiConverterString.allocationSize(value.txid) +
        FfiConverterExitTxStatus.allocationSize(value.status) +
        0;
  }
}

class ExitVtxo {
  final String vtxoId;
  final int amountSats;
  final ExitState state;
  final bool isClaimable;
  ExitVtxo({
    required this.vtxoId,
    required this.amountSats,
    required this.state,
    required this.isClaimable,
  });
}

class FfiConverterExitVtxo {
  static ExitVtxo lift(RustBuffer buf) {
    return FfiConverterExitVtxo.read(buf.asUint8List()).value;
  }

  static LiftRetVal<ExitVtxo> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final vtxoId_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vtxoId = vtxoId_lifted.value;
    new_offset += vtxoId_lifted.bytesRead;
    final amountSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final amountSats = amountSats_lifted.value;
    new_offset += amountSats_lifted.bytesRead;
    final state_lifted = FfiConverterExitState.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final state = state_lifted.value;
    new_offset += state_lifted.bytesRead;
    final isClaimable_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final isClaimable = isClaimable_lifted.value;
    new_offset += isClaimable_lifted.bytesRead;
    return LiftRetVal(
      ExitVtxo(
        vtxoId: vtxoId,
        amountSats: amountSats,
        state: state,
        isClaimable: isClaimable,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(ExitVtxo value) {
    final total_length =
        FfiConverterString.allocationSize(value.vtxoId) +
        FfiConverterUInt64.allocationSize(value.amountSats) +
        FfiConverterExitState.allocationSize(value.state) +
        FfiConverterBool.allocationSize(value.isClaimable) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(ExitVtxo value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.vtxoId,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.amountSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterExitState.write(
      value.state,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBool.write(
      value.isClaimable,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(ExitVtxo value) {
    return FfiConverterString.allocationSize(value.vtxoId) +
        FfiConverterUInt64.allocationSize(value.amountSats) +
        FfiConverterExitState.allocationSize(value.state) +
        FfiConverterBool.allocationSize(value.isClaimable) +
        0;
  }
}

class FeeEstimate {
  final int grossAmountSats;
  final int feeSats;
  final int netAmountSats;
  final List<String> vtxosSpent;
  FeeEstimate({
    required this.grossAmountSats,
    required this.feeSats,
    required this.netAmountSats,
    required this.vtxosSpent,
  });
}

class FfiConverterFeeEstimate {
  static FeeEstimate lift(RustBuffer buf) {
    return FfiConverterFeeEstimate.read(buf.asUint8List()).value;
  }

  static LiftRetVal<FeeEstimate> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final grossAmountSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final grossAmountSats = grossAmountSats_lifted.value;
    new_offset += grossAmountSats_lifted.bytesRead;
    final feeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final feeSats = feeSats_lifted.value;
    new_offset += feeSats_lifted.bytesRead;
    final netAmountSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final netAmountSats = netAmountSats_lifted.value;
    new_offset += netAmountSats_lifted.bytesRead;
    final vtxosSpent_lifted = FfiConverterSequenceString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vtxosSpent = vtxosSpent_lifted.value;
    new_offset += vtxosSpent_lifted.bytesRead;
    return LiftRetVal(
      FeeEstimate(
        grossAmountSats: grossAmountSats,
        feeSats: feeSats,
        netAmountSats: netAmountSats,
        vtxosSpent: vtxosSpent,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(FeeEstimate value) {
    final total_length =
        FfiConverterUInt64.allocationSize(value.grossAmountSats) +
        FfiConverterUInt64.allocationSize(value.feeSats) +
        FfiConverterUInt64.allocationSize(value.netAmountSats) +
        FfiConverterSequenceString.allocationSize(value.vtxosSpent) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(FeeEstimate value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt64.write(
      value.grossAmountSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.feeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.netAmountSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterSequenceString.write(
      value.vtxosSpent,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(FeeEstimate value) {
    return FfiConverterUInt64.allocationSize(value.grossAmountSats) +
        FfiConverterUInt64.allocationSize(value.feeSats) +
        FfiConverterUInt64.allocationSize(value.netAmountSats) +
        FfiConverterSequenceString.allocationSize(value.vtxosSpent) +
        0;
  }
}

class FeeRates {
  final int fastSatPerKwu;
  final int regularSatPerKwu;
  final int slowSatPerKwu;
  FeeRates({
    required this.fastSatPerKwu,
    required this.regularSatPerKwu,
    required this.slowSatPerKwu,
  });
}

class FfiConverterFeeRates {
  static FeeRates lift(RustBuffer buf) {
    return FfiConverterFeeRates.read(buf.asUint8List()).value;
  }

  static LiftRetVal<FeeRates> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final fastSatPerKwu_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final fastSatPerKwu = fastSatPerKwu_lifted.value;
    new_offset += fastSatPerKwu_lifted.bytesRead;
    final regularSatPerKwu_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final regularSatPerKwu = regularSatPerKwu_lifted.value;
    new_offset += regularSatPerKwu_lifted.bytesRead;
    final slowSatPerKwu_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final slowSatPerKwu = slowSatPerKwu_lifted.value;
    new_offset += slowSatPerKwu_lifted.bytesRead;
    return LiftRetVal(
      FeeRates(
        fastSatPerKwu: fastSatPerKwu,
        regularSatPerKwu: regularSatPerKwu,
        slowSatPerKwu: slowSatPerKwu,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(FeeRates value) {
    final total_length =
        FfiConverterUInt64.allocationSize(value.fastSatPerKwu) +
        FfiConverterUInt64.allocationSize(value.regularSatPerKwu) +
        FfiConverterUInt64.allocationSize(value.slowSatPerKwu) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(FeeRates value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt64.write(
      value.fastSatPerKwu,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.regularSatPerKwu,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.slowSatPerKwu,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(FeeRates value) {
    return FfiConverterUInt64.allocationSize(value.fastSatPerKwu) +
        FfiConverterUInt64.allocationSize(value.regularSatPerKwu) +
        FfiConverterUInt64.allocationSize(value.slowSatPerKwu) +
        0;
  }
}

class FeeSchedule {
  final BoardFees board;
  final OffboardFees offboard;
  final RefreshFees refresh;
  final LightningReceiveFees lightningReceive;
  final LightningSendFees lightningSend;
  FeeSchedule({
    required this.board,
    required this.offboard,
    required this.refresh,
    required this.lightningReceive,
    required this.lightningSend,
  });
}

class FfiConverterFeeSchedule {
  static FeeSchedule lift(RustBuffer buf) {
    return FfiConverterFeeSchedule.read(buf.asUint8List()).value;
  }

  static LiftRetVal<FeeSchedule> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final board_lifted = FfiConverterBoardFees.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final board = board_lifted.value;
    new_offset += board_lifted.bytesRead;
    final offboard_lifted = FfiConverterOffboardFees.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final offboard = offboard_lifted.value;
    new_offset += offboard_lifted.bytesRead;
    final refresh_lifted = FfiConverterRefreshFees.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final refresh = refresh_lifted.value;
    new_offset += refresh_lifted.bytesRead;
    final lightningReceive_lifted = FfiConverterLightningReceiveFees.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final lightningReceive = lightningReceive_lifted.value;
    new_offset += lightningReceive_lifted.bytesRead;
    final lightningSend_lifted = FfiConverterLightningSendFees.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final lightningSend = lightningSend_lifted.value;
    new_offset += lightningSend_lifted.bytesRead;
    return LiftRetVal(
      FeeSchedule(
        board: board,
        offboard: offboard,
        refresh: refresh,
        lightningReceive: lightningReceive,
        lightningSend: lightningSend,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(FeeSchedule value) {
    final total_length =
        FfiConverterBoardFees.allocationSize(value.board) +
        FfiConverterOffboardFees.allocationSize(value.offboard) +
        FfiConverterRefreshFees.allocationSize(value.refresh) +
        FfiConverterLightningReceiveFees.allocationSize(
          value.lightningReceive,
        ) +
        FfiConverterLightningSendFees.allocationSize(value.lightningSend) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(FeeSchedule value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterBoardFees.write(
      value.board,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOffboardFees.write(
      value.offboard,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterRefreshFees.write(
      value.refresh,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterLightningReceiveFees.write(
      value.lightningReceive,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterLightningSendFees.write(
      value.lightningSend,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(FeeSchedule value) {
    return FfiConverterBoardFees.allocationSize(value.board) +
        FfiConverterOffboardFees.allocationSize(value.offboard) +
        FfiConverterRefreshFees.allocationSize(value.refresh) +
        FfiConverterLightningReceiveFees.allocationSize(
          value.lightningReceive,
        ) +
        FfiConverterLightningSendFees.allocationSize(value.lightningSend) +
        0;
  }
}

class ImportVtxoArgs {
  final int? gapLimit;
  final bool skipStatusCheck;
  final bool allowPartial;
  ImportVtxoArgs({
    this.gapLimit = null,
    this.skipStatusCheck = false,
    this.allowPartial = false,
  });
}

class FfiConverterImportVtxoArgs {
  static ImportVtxoArgs lift(RustBuffer buf) {
    return FfiConverterImportVtxoArgs.read(buf.asUint8List()).value;
  }

  static LiftRetVal<ImportVtxoArgs> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final gapLimit_lifted = FfiConverterOptionalUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final gapLimit = gapLimit_lifted.value;
    new_offset += gapLimit_lifted.bytesRead;
    final skipStatusCheck_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final skipStatusCheck = skipStatusCheck_lifted.value;
    new_offset += skipStatusCheck_lifted.bytesRead;
    final allowPartial_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final allowPartial = allowPartial_lifted.value;
    new_offset += allowPartial_lifted.bytesRead;
    return LiftRetVal(
      ImportVtxoArgs(
        gapLimit: gapLimit,
        skipStatusCheck: skipStatusCheck,
        allowPartial: allowPartial,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(ImportVtxoArgs value) {
    final total_length =
        FfiConverterOptionalUInt32.allocationSize(value.gapLimit) +
        FfiConverterBool.allocationSize(value.skipStatusCheck) +
        FfiConverterBool.allocationSize(value.allowPartial) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(ImportVtxoArgs value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterOptionalUInt32.write(
      value.gapLimit,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBool.write(
      value.skipStatusCheck,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBool.write(
      value.allowPartial,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(ImportVtxoArgs value) {
    return FfiConverterOptionalUInt32.allocationSize(value.gapLimit) +
        FfiConverterBool.allocationSize(value.skipStatusCheck) +
        FfiConverterBool.allocationSize(value.allowPartial) +
        0;
  }
}

class LightningInvoice {
  final String invoice;
  final String paymentHash;
  final int amountSats;
  LightningInvoice({
    required this.invoice,
    required this.paymentHash,
    required this.amountSats,
  });
}

class FfiConverterLightningInvoice {
  static LightningInvoice lift(RustBuffer buf) {
    return FfiConverterLightningInvoice.read(buf.asUint8List()).value;
  }

  static LiftRetVal<LightningInvoice> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final invoice_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final invoice = invoice_lifted.value;
    new_offset += invoice_lifted.bytesRead;
    final paymentHash_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final paymentHash = paymentHash_lifted.value;
    new_offset += paymentHash_lifted.bytesRead;
    final amountSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final amountSats = amountSats_lifted.value;
    new_offset += amountSats_lifted.bytesRead;
    return LiftRetVal(
      LightningInvoice(
        invoice: invoice,
        paymentHash: paymentHash,
        amountSats: amountSats,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(LightningInvoice value) {
    final total_length =
        FfiConverterString.allocationSize(value.invoice) +
        FfiConverterString.allocationSize(value.paymentHash) +
        FfiConverterUInt64.allocationSize(value.amountSats) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(LightningInvoice value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.invoice,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.paymentHash,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.amountSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(LightningInvoice value) {
    return FfiConverterString.allocationSize(value.invoice) +
        FfiConverterString.allocationSize(value.paymentHash) +
        FfiConverterUInt64.allocationSize(value.amountSats) +
        0;
  }
}

class LightningReceive {
  final String paymentHash;
  final String invoice;
  final int? amountSats;
  final String state;
  final String? paymentPreimage;
  final int? settledAt;
  final String? claimDestination;
  LightningReceive({
    required this.paymentHash,
    required this.invoice,
    this.amountSats,
    required this.state,
    this.paymentPreimage,
    this.settledAt,
    this.claimDestination,
  });
}

class FfiConverterLightningReceive {
  static LightningReceive lift(RustBuffer buf) {
    return FfiConverterLightningReceive.read(buf.asUint8List()).value;
  }

  static LiftRetVal<LightningReceive> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final paymentHash_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final paymentHash = paymentHash_lifted.value;
    new_offset += paymentHash_lifted.bytesRead;
    final invoice_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final invoice = invoice_lifted.value;
    new_offset += invoice_lifted.bytesRead;
    final amountSats_lifted = FfiConverterOptionalUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final amountSats = amountSats_lifted.value;
    new_offset += amountSats_lifted.bytesRead;
    final state_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final state = state_lifted.value;
    new_offset += state_lifted.bytesRead;
    final paymentPreimage_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final paymentPreimage = paymentPreimage_lifted.value;
    new_offset += paymentPreimage_lifted.bytesRead;
    final settledAt_lifted = FfiConverterOptionalInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final settledAt = settledAt_lifted.value;
    new_offset += settledAt_lifted.bytesRead;
    final claimDestination_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final claimDestination = claimDestination_lifted.value;
    new_offset += claimDestination_lifted.bytesRead;
    return LiftRetVal(
      LightningReceive(
        paymentHash: paymentHash,
        invoice: invoice,
        amountSats: amountSats,
        state: state,
        paymentPreimage: paymentPreimage,
        settledAt: settledAt,
        claimDestination: claimDestination,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(LightningReceive value) {
    final total_length =
        FfiConverterString.allocationSize(value.paymentHash) +
        FfiConverterString.allocationSize(value.invoice) +
        FfiConverterOptionalUInt64.allocationSize(value.amountSats) +
        FfiConverterString.allocationSize(value.state) +
        FfiConverterOptionalString.allocationSize(value.paymentPreimage) +
        FfiConverterOptionalInt64.allocationSize(value.settledAt) +
        FfiConverterOptionalString.allocationSize(value.claimDestination) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(LightningReceive value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.paymentHash,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.invoice,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt64.write(
      value.amountSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.state,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.paymentPreimage,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalInt64.write(
      value.settledAt,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.claimDestination,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(LightningReceive value) {
    return FfiConverterString.allocationSize(value.paymentHash) +
        FfiConverterString.allocationSize(value.invoice) +
        FfiConverterOptionalUInt64.allocationSize(value.amountSats) +
        FfiConverterString.allocationSize(value.state) +
        FfiConverterOptionalString.allocationSize(value.paymentPreimage) +
        FfiConverterOptionalInt64.allocationSize(value.settledAt) +
        FfiConverterOptionalString.allocationSize(value.claimDestination) +
        0;
  }
}

class LightningReceiveFees {
  final int baseFeeSats;
  final int ppm;
  LightningReceiveFees({required this.baseFeeSats, required this.ppm});
}

class FfiConverterLightningReceiveFees {
  static LightningReceiveFees lift(RustBuffer buf) {
    return FfiConverterLightningReceiveFees.read(buf.asUint8List()).value;
  }

  static LiftRetVal<LightningReceiveFees> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final baseFeeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final baseFeeSats = baseFeeSats_lifted.value;
    new_offset += baseFeeSats_lifted.bytesRead;
    final ppm_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final ppm = ppm_lifted.value;
    new_offset += ppm_lifted.bytesRead;
    return LiftRetVal(
      LightningReceiveFees(baseFeeSats: baseFeeSats, ppm: ppm),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(LightningReceiveFees value) {
    final total_length =
        FfiConverterUInt64.allocationSize(value.baseFeeSats) +
        FfiConverterUInt64.allocationSize(value.ppm) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(LightningReceiveFees value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt64.write(
      value.baseFeeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.ppm,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(LightningReceiveFees value) {
    return FfiConverterUInt64.allocationSize(value.baseFeeSats) +
        FfiConverterUInt64.allocationSize(value.ppm) +
        0;
  }
}

class LightningSend {
  final String invoice;
  final int amountSats;
  final int feeSats;
  final int htlcVtxoCount;
  final bool hasFailedRevocation;
  LightningSend({
    required this.invoice,
    required this.amountSats,
    required this.feeSats,
    required this.htlcVtxoCount,
    required this.hasFailedRevocation,
  });
}

class FfiConverterLightningSend {
  static LightningSend lift(RustBuffer buf) {
    return FfiConverterLightningSend.read(buf.asUint8List()).value;
  }

  static LiftRetVal<LightningSend> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final invoice_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final invoice = invoice_lifted.value;
    new_offset += invoice_lifted.bytesRead;
    final amountSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final amountSats = amountSats_lifted.value;
    new_offset += amountSats_lifted.bytesRead;
    final feeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final feeSats = feeSats_lifted.value;
    new_offset += feeSats_lifted.bytesRead;
    final htlcVtxoCount_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final htlcVtxoCount = htlcVtxoCount_lifted.value;
    new_offset += htlcVtxoCount_lifted.bytesRead;
    final hasFailedRevocation_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final hasFailedRevocation = hasFailedRevocation_lifted.value;
    new_offset += hasFailedRevocation_lifted.bytesRead;
    return LiftRetVal(
      LightningSend(
        invoice: invoice,
        amountSats: amountSats,
        feeSats: feeSats,
        htlcVtxoCount: htlcVtxoCount,
        hasFailedRevocation: hasFailedRevocation,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(LightningSend value) {
    final total_length =
        FfiConverterString.allocationSize(value.invoice) +
        FfiConverterUInt64.allocationSize(value.amountSats) +
        FfiConverterUInt64.allocationSize(value.feeSats) +
        FfiConverterUInt32.allocationSize(value.htlcVtxoCount) +
        FfiConverterBool.allocationSize(value.hasFailedRevocation) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(LightningSend value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.invoice,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.amountSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.feeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.htlcVtxoCount,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBool.write(
      value.hasFailedRevocation,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(LightningSend value) {
    return FfiConverterString.allocationSize(value.invoice) +
        FfiConverterUInt64.allocationSize(value.amountSats) +
        FfiConverterUInt64.allocationSize(value.feeSats) +
        FfiConverterUInt32.allocationSize(value.htlcVtxoCount) +
        FfiConverterBool.allocationSize(value.hasFailedRevocation) +
        0;
  }
}

class LightningSendFees {
  final int minFeeSats;
  final int baseFeeSats;
  final List<PpmExpiryFeeEntry> ppmExpiryTable;
  LightningSendFees({
    required this.minFeeSats,
    required this.baseFeeSats,
    required this.ppmExpiryTable,
  });
}

class FfiConverterLightningSendFees {
  static LightningSendFees lift(RustBuffer buf) {
    return FfiConverterLightningSendFees.read(buf.asUint8List()).value;
  }

  static LiftRetVal<LightningSendFees> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final minFeeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final minFeeSats = minFeeSats_lifted.value;
    new_offset += minFeeSats_lifted.bytesRead;
    final baseFeeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final baseFeeSats = baseFeeSats_lifted.value;
    new_offset += baseFeeSats_lifted.bytesRead;
    final ppmExpiryTable_lifted = FfiConverterSequencePpmExpiryFeeEntry.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final ppmExpiryTable = ppmExpiryTable_lifted.value;
    new_offset += ppmExpiryTable_lifted.bytesRead;
    return LiftRetVal(
      LightningSendFees(
        minFeeSats: minFeeSats,
        baseFeeSats: baseFeeSats,
        ppmExpiryTable: ppmExpiryTable,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(LightningSendFees value) {
    final total_length =
        FfiConverterUInt64.allocationSize(value.minFeeSats) +
        FfiConverterUInt64.allocationSize(value.baseFeeSats) +
        FfiConverterSequencePpmExpiryFeeEntry.allocationSize(
          value.ppmExpiryTable,
        ) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(LightningSendFees value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt64.write(
      value.minFeeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.baseFeeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterSequencePpmExpiryFeeEntry.write(
      value.ppmExpiryTable,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(LightningSendFees value) {
    return FfiConverterUInt64.allocationSize(value.minFeeSats) +
        FfiConverterUInt64.allocationSize(value.baseFeeSats) +
        FfiConverterSequencePpmExpiryFeeEntry.allocationSize(
          value.ppmExpiryTable,
        ) +
        0;
  }
}

class Movement {
  final int id;
  final String status;
  final String subsystemName;
  final String subsystemKind;
  final String metadataJson;
  final int intendedBalanceSats;
  final int effectiveBalanceSats;
  final int offchainFeeSats;
  final List<String> sentToAddresses;
  final List<String> receivedOnAddresses;
  final List<String> inputVtxoIds;
  final List<String> outputVtxoIds;
  final List<String> exitedVtxoIds;
  final String createdAt;
  final String updatedAt;
  final String? completedAt;
  final String? paymentHash;
  final String? lightningInvoice;
  final String? lightningOffer;
  Movement({
    required this.id,
    required this.status,
    required this.subsystemName,
    required this.subsystemKind,
    required this.metadataJson,
    required this.intendedBalanceSats,
    required this.effectiveBalanceSats,
    required this.offchainFeeSats,
    required this.sentToAddresses,
    required this.receivedOnAddresses,
    required this.inputVtxoIds,
    required this.outputVtxoIds,
    required this.exitedVtxoIds,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.paymentHash,
    this.lightningInvoice,
    this.lightningOffer,
  });
}

class FfiConverterMovement {
  static Movement lift(RustBuffer buf) {
    return FfiConverterMovement.read(buf.asUint8List()).value;
  }

  static LiftRetVal<Movement> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final id_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final id = id_lifted.value;
    new_offset += id_lifted.bytesRead;
    final status_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final status = status_lifted.value;
    new_offset += status_lifted.bytesRead;
    final subsystemName_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final subsystemName = subsystemName_lifted.value;
    new_offset += subsystemName_lifted.bytesRead;
    final subsystemKind_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final subsystemKind = subsystemKind_lifted.value;
    new_offset += subsystemKind_lifted.bytesRead;
    final metadataJson_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final metadataJson = metadataJson_lifted.value;
    new_offset += metadataJson_lifted.bytesRead;
    final intendedBalanceSats_lifted = FfiConverterInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final intendedBalanceSats = intendedBalanceSats_lifted.value;
    new_offset += intendedBalanceSats_lifted.bytesRead;
    final effectiveBalanceSats_lifted = FfiConverterInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final effectiveBalanceSats = effectiveBalanceSats_lifted.value;
    new_offset += effectiveBalanceSats_lifted.bytesRead;
    final offchainFeeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final offchainFeeSats = offchainFeeSats_lifted.value;
    new_offset += offchainFeeSats_lifted.bytesRead;
    final sentToAddresses_lifted = FfiConverterSequenceString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final sentToAddresses = sentToAddresses_lifted.value;
    new_offset += sentToAddresses_lifted.bytesRead;
    final receivedOnAddresses_lifted = FfiConverterSequenceString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final receivedOnAddresses = receivedOnAddresses_lifted.value;
    new_offset += receivedOnAddresses_lifted.bytesRead;
    final inputVtxoIds_lifted = FfiConverterSequenceString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final inputVtxoIds = inputVtxoIds_lifted.value;
    new_offset += inputVtxoIds_lifted.bytesRead;
    final outputVtxoIds_lifted = FfiConverterSequenceString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final outputVtxoIds = outputVtxoIds_lifted.value;
    new_offset += outputVtxoIds_lifted.bytesRead;
    final exitedVtxoIds_lifted = FfiConverterSequenceString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final exitedVtxoIds = exitedVtxoIds_lifted.value;
    new_offset += exitedVtxoIds_lifted.bytesRead;
    final createdAt_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final createdAt = createdAt_lifted.value;
    new_offset += createdAt_lifted.bytesRead;
    final updatedAt_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final updatedAt = updatedAt_lifted.value;
    new_offset += updatedAt_lifted.bytesRead;
    final completedAt_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final completedAt = completedAt_lifted.value;
    new_offset += completedAt_lifted.bytesRead;
    final paymentHash_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final paymentHash = paymentHash_lifted.value;
    new_offset += paymentHash_lifted.bytesRead;
    final lightningInvoice_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final lightningInvoice = lightningInvoice_lifted.value;
    new_offset += lightningInvoice_lifted.bytesRead;
    final lightningOffer_lifted = FfiConverterOptionalString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final lightningOffer = lightningOffer_lifted.value;
    new_offset += lightningOffer_lifted.bytesRead;
    return LiftRetVal(
      Movement(
        id: id,
        status: status,
        subsystemName: subsystemName,
        subsystemKind: subsystemKind,
        metadataJson: metadataJson,
        intendedBalanceSats: intendedBalanceSats,
        effectiveBalanceSats: effectiveBalanceSats,
        offchainFeeSats: offchainFeeSats,
        sentToAddresses: sentToAddresses,
        receivedOnAddresses: receivedOnAddresses,
        inputVtxoIds: inputVtxoIds,
        outputVtxoIds: outputVtxoIds,
        exitedVtxoIds: exitedVtxoIds,
        createdAt: createdAt,
        updatedAt: updatedAt,
        completedAt: completedAt,
        paymentHash: paymentHash,
        lightningInvoice: lightningInvoice,
        lightningOffer: lightningOffer,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(Movement value) {
    final total_length =
        FfiConverterUInt32.allocationSize(value.id) +
        FfiConverterString.allocationSize(value.status) +
        FfiConverterString.allocationSize(value.subsystemName) +
        FfiConverterString.allocationSize(value.subsystemKind) +
        FfiConverterString.allocationSize(value.metadataJson) +
        FfiConverterInt64.allocationSize(value.intendedBalanceSats) +
        FfiConverterInt64.allocationSize(value.effectiveBalanceSats) +
        FfiConverterUInt64.allocationSize(value.offchainFeeSats) +
        FfiConverterSequenceString.allocationSize(value.sentToAddresses) +
        FfiConverterSequenceString.allocationSize(value.receivedOnAddresses) +
        FfiConverterSequenceString.allocationSize(value.inputVtxoIds) +
        FfiConverterSequenceString.allocationSize(value.outputVtxoIds) +
        FfiConverterSequenceString.allocationSize(value.exitedVtxoIds) +
        FfiConverterString.allocationSize(value.createdAt) +
        FfiConverterString.allocationSize(value.updatedAt) +
        FfiConverterOptionalString.allocationSize(value.completedAt) +
        FfiConverterOptionalString.allocationSize(value.paymentHash) +
        FfiConverterOptionalString.allocationSize(value.lightningInvoice) +
        FfiConverterOptionalString.allocationSize(value.lightningOffer) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(Movement value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt32.write(
      value.id,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.status,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.subsystemName,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.subsystemKind,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.metadataJson,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterInt64.write(
      value.intendedBalanceSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterInt64.write(
      value.effectiveBalanceSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.offchainFeeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterSequenceString.write(
      value.sentToAddresses,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterSequenceString.write(
      value.receivedOnAddresses,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterSequenceString.write(
      value.inputVtxoIds,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterSequenceString.write(
      value.outputVtxoIds,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterSequenceString.write(
      value.exitedVtxoIds,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.createdAt,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.updatedAt,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.completedAt,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.paymentHash,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.lightningInvoice,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalString.write(
      value.lightningOffer,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(Movement value) {
    return FfiConverterUInt32.allocationSize(value.id) +
        FfiConverterString.allocationSize(value.status) +
        FfiConverterString.allocationSize(value.subsystemName) +
        FfiConverterString.allocationSize(value.subsystemKind) +
        FfiConverterString.allocationSize(value.metadataJson) +
        FfiConverterInt64.allocationSize(value.intendedBalanceSats) +
        FfiConverterInt64.allocationSize(value.effectiveBalanceSats) +
        FfiConverterUInt64.allocationSize(value.offchainFeeSats) +
        FfiConverterSequenceString.allocationSize(value.sentToAddresses) +
        FfiConverterSequenceString.allocationSize(value.receivedOnAddresses) +
        FfiConverterSequenceString.allocationSize(value.inputVtxoIds) +
        FfiConverterSequenceString.allocationSize(value.outputVtxoIds) +
        FfiConverterSequenceString.allocationSize(value.exitedVtxoIds) +
        FfiConverterString.allocationSize(value.createdAt) +
        FfiConverterString.allocationSize(value.updatedAt) +
        FfiConverterOptionalString.allocationSize(value.completedAt) +
        FfiConverterOptionalString.allocationSize(value.paymentHash) +
        FfiConverterOptionalString.allocationSize(value.lightningInvoice) +
        FfiConverterOptionalString.allocationSize(value.lightningOffer) +
        0;
  }
}

class OffboardFees {
  final int baseFeeSats;
  final int fixedAdditionalVb;
  final List<PpmExpiryFeeEntry> ppmExpiryTable;
  OffboardFees({
    required this.baseFeeSats,
    required this.fixedAdditionalVb,
    required this.ppmExpiryTable,
  });
}

class FfiConverterOffboardFees {
  static OffboardFees lift(RustBuffer buf) {
    return FfiConverterOffboardFees.read(buf.asUint8List()).value;
  }

  static LiftRetVal<OffboardFees> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final baseFeeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final baseFeeSats = baseFeeSats_lifted.value;
    new_offset += baseFeeSats_lifted.bytesRead;
    final fixedAdditionalVb_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final fixedAdditionalVb = fixedAdditionalVb_lifted.value;
    new_offset += fixedAdditionalVb_lifted.bytesRead;
    final ppmExpiryTable_lifted = FfiConverterSequencePpmExpiryFeeEntry.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final ppmExpiryTable = ppmExpiryTable_lifted.value;
    new_offset += ppmExpiryTable_lifted.bytesRead;
    return LiftRetVal(
      OffboardFees(
        baseFeeSats: baseFeeSats,
        fixedAdditionalVb: fixedAdditionalVb,
        ppmExpiryTable: ppmExpiryTable,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(OffboardFees value) {
    final total_length =
        FfiConverterUInt64.allocationSize(value.baseFeeSats) +
        FfiConverterUInt64.allocationSize(value.fixedAdditionalVb) +
        FfiConverterSequencePpmExpiryFeeEntry.allocationSize(
          value.ppmExpiryTable,
        ) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(OffboardFees value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt64.write(
      value.baseFeeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.fixedAdditionalVb,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterSequencePpmExpiryFeeEntry.write(
      value.ppmExpiryTable,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(OffboardFees value) {
    return FfiConverterUInt64.allocationSize(value.baseFeeSats) +
        FfiConverterUInt64.allocationSize(value.fixedAdditionalVb) +
        FfiConverterSequencePpmExpiryFeeEntry.allocationSize(
          value.ppmExpiryTable,
        ) +
        0;
  }
}

class OffboardResult {
  final String txid;
  OffboardResult({required this.txid});
}

class FfiConverterOffboardResult {
  static OffboardResult lift(RustBuffer buf) {
    return FfiConverterOffboardResult.read(buf.asUint8List()).value;
  }

  static LiftRetVal<OffboardResult> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final txid_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final txid = txid_lifted.value;
    new_offset += txid_lifted.bytesRead;
    return LiftRetVal(
      OffboardResult(txid: txid),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(OffboardResult value) {
    final total_length = FfiConverterString.allocationSize(value.txid) + 0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(OffboardResult value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.txid,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(OffboardResult value) {
    return FfiConverterString.allocationSize(value.txid) + 0;
  }
}

class OnchainBalance {
  final int confirmedSats;
  final int pendingSats;
  final int totalSats;
  OnchainBalance({
    required this.confirmedSats,
    required this.pendingSats,
    required this.totalSats,
  });
}

class FfiConverterOnchainBalance {
  static OnchainBalance lift(RustBuffer buf) {
    return FfiConverterOnchainBalance.read(buf.asUint8List()).value;
  }

  static LiftRetVal<OnchainBalance> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final confirmedSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final confirmedSats = confirmedSats_lifted.value;
    new_offset += confirmedSats_lifted.bytesRead;
    final pendingSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final pendingSats = pendingSats_lifted.value;
    new_offset += pendingSats_lifted.bytesRead;
    final totalSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final totalSats = totalSats_lifted.value;
    new_offset += totalSats_lifted.bytesRead;
    return LiftRetVal(
      OnchainBalance(
        confirmedSats: confirmedSats,
        pendingSats: pendingSats,
        totalSats: totalSats,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(OnchainBalance value) {
    final total_length =
        FfiConverterUInt64.allocationSize(value.confirmedSats) +
        FfiConverterUInt64.allocationSize(value.pendingSats) +
        FfiConverterUInt64.allocationSize(value.totalSats) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(OnchainBalance value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt64.write(
      value.confirmedSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.pendingSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.totalSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(OnchainBalance value) {
    return FfiConverterUInt64.allocationSize(value.confirmedSats) +
        FfiConverterUInt64.allocationSize(value.pendingSats) +
        FfiConverterUInt64.allocationSize(value.totalSats) +
        0;
  }
}

class OutPoint {
  final String txid;
  final int vout;
  OutPoint({required this.txid, required this.vout});
}

class FfiConverterOutPoint {
  static OutPoint lift(RustBuffer buf) {
    return FfiConverterOutPoint.read(buf.asUint8List()).value;
  }

  static LiftRetVal<OutPoint> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final txid_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final txid = txid_lifted.value;
    new_offset += txid_lifted.bytesRead;
    final vout_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vout = vout_lifted.value;
    new_offset += vout_lifted.bytesRead;
    return LiftRetVal(
      OutPoint(txid: txid, vout: vout),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(OutPoint value) {
    final total_length =
        FfiConverterString.allocationSize(value.txid) +
        FfiConverterUInt32.allocationSize(value.vout) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(OutPoint value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.txid,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.vout,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(OutPoint value) {
    return FfiConverterString.allocationSize(value.txid) +
        FfiConverterUInt32.allocationSize(value.vout) +
        0;
  }
}

class PendingBoard {
  final String vtxoId;
  final int amountSats;
  final String txid;
  PendingBoard({
    required this.vtxoId,
    required this.amountSats,
    required this.txid,
  });
}

class FfiConverterPendingBoard {
  static PendingBoard lift(RustBuffer buf) {
    return FfiConverterPendingBoard.read(buf.asUint8List()).value;
  }

  static LiftRetVal<PendingBoard> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final vtxoId_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vtxoId = vtxoId_lifted.value;
    new_offset += vtxoId_lifted.bytesRead;
    final amountSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final amountSats = amountSats_lifted.value;
    new_offset += amountSats_lifted.bytesRead;
    final txid_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final txid = txid_lifted.value;
    new_offset += txid_lifted.bytesRead;
    return LiftRetVal(
      PendingBoard(vtxoId: vtxoId, amountSats: amountSats, txid: txid),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(PendingBoard value) {
    final total_length =
        FfiConverterString.allocationSize(value.vtxoId) +
        FfiConverterUInt64.allocationSize(value.amountSats) +
        FfiConverterString.allocationSize(value.txid) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(PendingBoard value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.vtxoId,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.amountSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.txid,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(PendingBoard value) {
    return FfiConverterString.allocationSize(value.vtxoId) +
        FfiConverterUInt64.allocationSize(value.amountSats) +
        FfiConverterString.allocationSize(value.txid) +
        0;
  }
}

class PpmExpiryFeeEntry {
  final int expiryBlocksThreshold;
  final int ppm;
  PpmExpiryFeeEntry({required this.expiryBlocksThreshold, required this.ppm});
}

class FfiConverterPpmExpiryFeeEntry {
  static PpmExpiryFeeEntry lift(RustBuffer buf) {
    return FfiConverterPpmExpiryFeeEntry.read(buf.asUint8List()).value;
  }

  static LiftRetVal<PpmExpiryFeeEntry> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final expiryBlocksThreshold_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final expiryBlocksThreshold = expiryBlocksThreshold_lifted.value;
    new_offset += expiryBlocksThreshold_lifted.bytesRead;
    final ppm_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final ppm = ppm_lifted.value;
    new_offset += ppm_lifted.bytesRead;
    return LiftRetVal(
      PpmExpiryFeeEntry(expiryBlocksThreshold: expiryBlocksThreshold, ppm: ppm),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(PpmExpiryFeeEntry value) {
    final total_length =
        FfiConverterUInt32.allocationSize(value.expiryBlocksThreshold) +
        FfiConverterUInt64.allocationSize(value.ppm) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(PpmExpiryFeeEntry value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt32.write(
      value.expiryBlocksThreshold,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.ppm,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(PpmExpiryFeeEntry value) {
    return FfiConverterUInt32.allocationSize(value.expiryBlocksThreshold) +
        FfiConverterUInt64.allocationSize(value.ppm) +
        0;
  }
}

class RecoveryBucket {
  final List<String> vtxoIds;
  final int totalSats;
  RecoveryBucket({required this.vtxoIds, required this.totalSats});
}

class FfiConverterRecoveryBucket {
  static RecoveryBucket lift(RustBuffer buf) {
    return FfiConverterRecoveryBucket.read(buf.asUint8List()).value;
  }

  static LiftRetVal<RecoveryBucket> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final vtxoIds_lifted = FfiConverterSequenceString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vtxoIds = vtxoIds_lifted.value;
    new_offset += vtxoIds_lifted.bytesRead;
    final totalSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final totalSats = totalSats_lifted.value;
    new_offset += totalSats_lifted.bytesRead;
    return LiftRetVal(
      RecoveryBucket(vtxoIds: vtxoIds, totalSats: totalSats),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(RecoveryBucket value) {
    final total_length =
        FfiConverterSequenceString.allocationSize(value.vtxoIds) +
        FfiConverterUInt64.allocationSize(value.totalSats) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(RecoveryBucket value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterSequenceString.write(
      value.vtxoIds,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.totalSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(RecoveryBucket value) {
    return FfiConverterSequenceString.allocationSize(value.vtxoIds) +
        FfiConverterUInt64.allocationSize(value.totalSats) +
        0;
  }
}

class RecoveryReport {
  final RecoveryBucket recovered;
  final RecoveryBucket skipped;
  final RecoveryBucket foreign;
  final RecoveryBucket failed;
  final RecoveryBucket exited;
  final bool isComplete;
  RecoveryReport({
    required this.recovered,
    required this.skipped,
    required this.foreign,
    required this.failed,
    required this.exited,
    required this.isComplete,
  });
}

class FfiConverterRecoveryReport {
  static RecoveryReport lift(RustBuffer buf) {
    return FfiConverterRecoveryReport.read(buf.asUint8List()).value;
  }

  static LiftRetVal<RecoveryReport> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final recovered_lifted = FfiConverterRecoveryBucket.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final recovered = recovered_lifted.value;
    new_offset += recovered_lifted.bytesRead;
    final skipped_lifted = FfiConverterRecoveryBucket.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final skipped = skipped_lifted.value;
    new_offset += skipped_lifted.bytesRead;
    final foreign_lifted = FfiConverterRecoveryBucket.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final foreign = foreign_lifted.value;
    new_offset += foreign_lifted.bytesRead;
    final failed_lifted = FfiConverterRecoveryBucket.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final failed = failed_lifted.value;
    new_offset += failed_lifted.bytesRead;
    final exited_lifted = FfiConverterRecoveryBucket.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final exited = exited_lifted.value;
    new_offset += exited_lifted.bytesRead;
    final isComplete_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final isComplete = isComplete_lifted.value;
    new_offset += isComplete_lifted.bytesRead;
    return LiftRetVal(
      RecoveryReport(
        recovered: recovered,
        skipped: skipped,
        foreign: foreign,
        failed: failed,
        exited: exited,
        isComplete: isComplete,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(RecoveryReport value) {
    final total_length =
        FfiConverterRecoveryBucket.allocationSize(value.recovered) +
        FfiConverterRecoveryBucket.allocationSize(value.skipped) +
        FfiConverterRecoveryBucket.allocationSize(value.foreign) +
        FfiConverterRecoveryBucket.allocationSize(value.failed) +
        FfiConverterRecoveryBucket.allocationSize(value.exited) +
        FfiConverterBool.allocationSize(value.isComplete) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(RecoveryReport value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterRecoveryBucket.write(
      value.recovered,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterRecoveryBucket.write(
      value.skipped,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterRecoveryBucket.write(
      value.foreign,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterRecoveryBucket.write(
      value.failed,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterRecoveryBucket.write(
      value.exited,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBool.write(
      value.isComplete,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(RecoveryReport value) {
    return FfiConverterRecoveryBucket.allocationSize(value.recovered) +
        FfiConverterRecoveryBucket.allocationSize(value.skipped) +
        FfiConverterRecoveryBucket.allocationSize(value.foreign) +
        FfiConverterRecoveryBucket.allocationSize(value.failed) +
        FfiConverterRecoveryBucket.allocationSize(value.exited) +
        FfiConverterBool.allocationSize(value.isComplete) +
        0;
  }
}

class RefreshFees {
  final int baseFeeSats;
  final List<PpmExpiryFeeEntry> ppmExpiryTable;
  RefreshFees({required this.baseFeeSats, required this.ppmExpiryTable});
}

class FfiConverterRefreshFees {
  static RefreshFees lift(RustBuffer buf) {
    return FfiConverterRefreshFees.read(buf.asUint8List()).value;
  }

  static LiftRetVal<RefreshFees> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final baseFeeSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final baseFeeSats = baseFeeSats_lifted.value;
    new_offset += baseFeeSats_lifted.bytesRead;
    final ppmExpiryTable_lifted = FfiConverterSequencePpmExpiryFeeEntry.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final ppmExpiryTable = ppmExpiryTable_lifted.value;
    new_offset += ppmExpiryTable_lifted.bytesRead;
    return LiftRetVal(
      RefreshFees(baseFeeSats: baseFeeSats, ppmExpiryTable: ppmExpiryTable),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(RefreshFees value) {
    final total_length =
        FfiConverterUInt64.allocationSize(value.baseFeeSats) +
        FfiConverterSequencePpmExpiryFeeEntry.allocationSize(
          value.ppmExpiryTable,
        ) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(RefreshFees value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt64.write(
      value.baseFeeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterSequencePpmExpiryFeeEntry.write(
      value.ppmExpiryTable,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(RefreshFees value) {
    return FfiConverterUInt64.allocationSize(value.baseFeeSats) +
        FfiConverterSequencePpmExpiryFeeEntry.allocationSize(
          value.ppmExpiryTable,
        ) +
        0;
  }
}

class RoundState {
  final int id;
  final bool ongoing;
  final RoundFlowKind state;
  final int? scheduledHeight;
  RoundState({
    required this.id,
    required this.ongoing,
    required this.state,
    this.scheduledHeight,
  });
}

class FfiConverterRoundState {
  static RoundState lift(RustBuffer buf) {
    return FfiConverterRoundState.read(buf.asUint8List()).value;
  }

  static LiftRetVal<RoundState> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final id_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final id = id_lifted.value;
    new_offset += id_lifted.bytesRead;
    final ongoing_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final ongoing = ongoing_lifted.value;
    new_offset += ongoing_lifted.bytesRead;
    final state_lifted = FfiConverterRoundFlowKind.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final state = state_lifted.value;
    new_offset += state_lifted.bytesRead;
    final scheduledHeight_lifted = FfiConverterOptionalUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final scheduledHeight = scheduledHeight_lifted.value;
    new_offset += scheduledHeight_lifted.bytesRead;
    return LiftRetVal(
      RoundState(
        id: id,
        ongoing: ongoing,
        state: state,
        scheduledHeight: scheduledHeight,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(RoundState value) {
    final total_length =
        FfiConverterUInt32.allocationSize(value.id) +
        FfiConverterBool.allocationSize(value.ongoing) +
        FfiConverterRoundFlowKind.allocationSize(value.state) +
        FfiConverterOptionalUInt32.allocationSize(value.scheduledHeight) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(RoundState value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterUInt32.write(
      value.id,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBool.write(
      value.ongoing,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterRoundFlowKind.write(
      value.state,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt32.write(
      value.scheduledHeight,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(RoundState value) {
    return FfiConverterUInt32.allocationSize(value.id) +
        FfiConverterBool.allocationSize(value.ongoing) +
        FfiConverterRoundFlowKind.allocationSize(value.state) +
        FfiConverterOptionalUInt32.allocationSize(value.scheduledHeight) +
        0;
  }
}

class Vtxo {
  final String id;
  final int amountSats;
  final int expiryHeight;
  final String kind;
  final VtxoState state;
  final int exitDepth;
  final int exitTxWeightWu;
  final bool registered;
  Vtxo({
    required this.id,
    required this.amountSats,
    required this.expiryHeight,
    required this.kind,
    required this.state,
    required this.exitDepth,
    required this.exitTxWeightWu,
    required this.registered,
  });
}

class FfiConverterVtxo {
  static Vtxo lift(RustBuffer buf) {
    return FfiConverterVtxo.read(buf.asUint8List()).value;
  }

  static LiftRetVal<Vtxo> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final id_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final id = id_lifted.value;
    new_offset += id_lifted.bytesRead;
    final amountSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final amountSats = amountSats_lifted.value;
    new_offset += amountSats_lifted.bytesRead;
    final expiryHeight_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final expiryHeight = expiryHeight_lifted.value;
    new_offset += expiryHeight_lifted.bytesRead;
    final kind_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final kind = kind_lifted.value;
    new_offset += kind_lifted.bytesRead;
    final state_lifted = FfiConverterVtxoState.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final state = state_lifted.value;
    new_offset += state_lifted.bytesRead;
    final exitDepth_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final exitDepth = exitDepth_lifted.value;
    new_offset += exitDepth_lifted.bytesRead;
    final exitTxWeightWu_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final exitTxWeightWu = exitTxWeightWu_lifted.value;
    new_offset += exitTxWeightWu_lifted.bytesRead;
    final registered_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final registered = registered_lifted.value;
    new_offset += registered_lifted.bytesRead;
    return LiftRetVal(
      Vtxo(
        id: id,
        amountSats: amountSats,
        expiryHeight: expiryHeight,
        kind: kind,
        state: state,
        exitDepth: exitDepth,
        exitTxWeightWu: exitTxWeightWu,
        registered: registered,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(Vtxo value) {
    final total_length =
        FfiConverterString.allocationSize(value.id) +
        FfiConverterUInt64.allocationSize(value.amountSats) +
        FfiConverterUInt32.allocationSize(value.expiryHeight) +
        FfiConverterString.allocationSize(value.kind) +
        FfiConverterVtxoState.allocationSize(value.state) +
        FfiConverterUInt32.allocationSize(value.exitDepth) +
        FfiConverterUInt64.allocationSize(value.exitTxWeightWu) +
        FfiConverterBool.allocationSize(value.registered) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(Vtxo value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.id,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.amountSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.expiryHeight,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.kind,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterVtxoState.write(
      value.state,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      value.exitDepth,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      value.exitTxWeightWu,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBool.write(
      value.registered,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(Vtxo value) {
    return FfiConverterString.allocationSize(value.id) +
        FfiConverterUInt64.allocationSize(value.amountSats) +
        FfiConverterUInt32.allocationSize(value.expiryHeight) +
        FfiConverterString.allocationSize(value.kind) +
        FfiConverterVtxoState.allocationSize(value.state) +
        FfiConverterUInt32.allocationSize(value.exitDepth) +
        FfiConverterUInt64.allocationSize(value.exitTxWeightWu) +
        FfiConverterBool.allocationSize(value.registered) +
        0;
  }
}

class WalletProperties {
  final Network network;
  final String fingerprint;
  WalletProperties({required this.network, required this.fingerprint});
}

class FfiConverterWalletProperties {
  static WalletProperties lift(RustBuffer buf) {
    return FfiConverterWalletProperties.read(buf.asUint8List()).value;
  }

  static LiftRetVal<WalletProperties> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final network_lifted = FfiConverterNetwork.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final network = network_lifted.value;
    new_offset += network_lifted.bytesRead;
    final fingerprint_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final fingerprint = fingerprint_lifted.value;
    new_offset += fingerprint_lifted.bytesRead;
    return LiftRetVal(
      WalletProperties(network: network, fingerprint: fingerprint),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(WalletProperties value) {
    final total_length =
        FfiConverterNetwork.allocationSize(value.network) +
        FfiConverterString.allocationSize(value.fingerprint) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(WalletProperties value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterNetwork.write(
      value.network,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.fingerprint,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(WalletProperties value) {
    return FfiConverterNetwork.allocationSize(value.network) +
        FfiConverterString.allocationSize(value.fingerprint) +
        0;
  }
}

class WalletTransaction {
  final String txid;
  final String txHex;
  final int? onchainFeeSats;
  final int balanceChangeSats;
  final BlockRef? confirmation;
  final bool isCpfp;
  WalletTransaction({
    required this.txid,
    required this.txHex,
    this.onchainFeeSats,
    required this.balanceChangeSats,
    this.confirmation,
    required this.isCpfp,
  });
}

class FfiConverterWalletTransaction {
  static WalletTransaction lift(RustBuffer buf) {
    return FfiConverterWalletTransaction.read(buf.asUint8List()).value;
  }

  static LiftRetVal<WalletTransaction> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final txid_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final txid = txid_lifted.value;
    new_offset += txid_lifted.bytesRead;
    final txHex_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final txHex = txHex_lifted.value;
    new_offset += txHex_lifted.bytesRead;
    final onchainFeeSats_lifted = FfiConverterOptionalUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final onchainFeeSats = onchainFeeSats_lifted.value;
    new_offset += onchainFeeSats_lifted.bytesRead;
    final balanceChangeSats_lifted = FfiConverterInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final balanceChangeSats = balanceChangeSats_lifted.value;
    new_offset += balanceChangeSats_lifted.bytesRead;
    final confirmation_lifted = FfiConverterOptionalBlockRef.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final confirmation = confirmation_lifted.value;
    new_offset += confirmation_lifted.bytesRead;
    final isCpfp_lifted = FfiConverterBool.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final isCpfp = isCpfp_lifted.value;
    new_offset += isCpfp_lifted.bytesRead;
    return LiftRetVal(
      WalletTransaction(
        txid: txid,
        txHex: txHex,
        onchainFeeSats: onchainFeeSats,
        balanceChangeSats: balanceChangeSats,
        confirmation: confirmation,
        isCpfp: isCpfp,
      ),
      new_offset - buf.offsetInBytes,
    );
  }

  static RustBuffer lower(WalletTransaction value) {
    final total_length =
        FfiConverterString.allocationSize(value.txid) +
        FfiConverterString.allocationSize(value.txHex) +
        FfiConverterOptionalUInt64.allocationSize(value.onchainFeeSats) +
        FfiConverterInt64.allocationSize(value.balanceChangeSats) +
        FfiConverterOptionalBlockRef.allocationSize(value.confirmation) +
        FfiConverterBool.allocationSize(value.isCpfp) +
        0;
    final buf = Uint8List(total_length);
    write(value, buf);
    return toRustBuffer(buf);
  }

  static int write(WalletTransaction value, Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    new_offset += FfiConverterString.write(
      value.txid,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      value.txHex,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt64.write(
      value.onchainFeeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterInt64.write(
      value.balanceChangeSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalBlockRef.write(
      value.confirmation,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBool.write(
      value.isCpfp,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset - buf.offsetInBytes;
  }

  static int allocationSize(WalletTransaction value) {
    return FfiConverterString.allocationSize(value.txid) +
        FfiConverterString.allocationSize(value.txHex) +
        FfiConverterOptionalUInt64.allocationSize(value.onchainFeeSats) +
        FfiConverterInt64.allocationSize(value.balanceChangeSats) +
        FfiConverterOptionalBlockRef.allocationSize(value.confirmation) +
        FfiConverterBool.allocationSize(value.isCpfp) +
        0;
  }
}

enum ErrorException implements Exception { inner }

class FfiConverterErrorException {
  static LiftRetVal<ErrorException> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    switch (index) {
      case 1:
        return LiftRetVal(ErrorException.inner, 4);
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static ErrorException lift(RustBuffer buffer) {
    return FfiConverterErrorException.read(buffer.asUint8List()).value;
  }

  static RustBuffer lower(ErrorException input) {
    return toRustBuffer(createUint8ListFromInt(input.index + 1));
  }

  static int allocationSize(ErrorException _value) {
    return 4;
  }

  static int write(ErrorException value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.index + 1);
    return 4;
  }
}

/// COCONUT PATCH: a bark error with its message.
///
/// bark-ffi's `Error` is a uniffi `flat_error`: on the wire, the variant index is followed by the
/// error's message. The generated [FfiConverterErrorException] reads only the index, so every
/// error used to surface as the bare `ErrorException.inner`. The handler below keeps the message.
class BarkException implements Exception {
  const BarkException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ErrorExceptionErrorHandler extends UniffiRustCallStatusErrorHandler {
  @override
  Exception lift(RustBuffer errorBuf) {
    final bytes = errorBuf.asUint8List();
    if (bytes.length > 4) {
      return BarkException(FfiConverterString.read(Uint8List.sublistView(bytes, 4)).value);
    }
    return FfiConverterErrorException.lift(errorBuf);
  }
}

final ErrorExceptionErrorHandler errorExceptionErrorHandler =
    ErrorExceptionErrorHandler();

enum LogLevel { error, warn, info, debug, trace }

class FfiConverterLogLevel {
  static LiftRetVal<LogLevel> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    switch (index) {
      case 1:
        return LiftRetVal(LogLevel.error, 4);
      case 2:
        return LiftRetVal(LogLevel.warn, 4);
      case 3:
        return LiftRetVal(LogLevel.info, 4);
      case 4:
        return LiftRetVal(LogLevel.debug, 4);
      case 5:
        return LiftRetVal(LogLevel.trace, 4);
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static LogLevel lift(RustBuffer buffer) {
    return FfiConverterLogLevel.read(buffer.asUint8List()).value;
  }

  static RustBuffer lower(LogLevel input) {
    return toRustBuffer(createUint8ListFromInt(input.index + 1));
  }

  static int allocationSize(LogLevel _value) {
    return 4;
  }

  static int write(LogLevel value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.index + 1);
    return 4;
  }
}

abstract class ExitCancelFailure {
  RustBuffer lower();
  int allocationSize();
  int write(Uint8List buf);
}

class FfiConverterExitCancelFailure {
  static ExitCancelFailure lift(RustBuffer buffer) {
    return FfiConverterExitCancelFailure.read(buffer.asUint8List()).value;
  }

  static LiftRetVal<ExitCancelFailure> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    final subview = Uint8List.view(buf.buffer, buf.offsetInBytes + 4);
    switch (index) {
      case 1:
        final lifted = NotExitingExitCancelFailure.read(subview);
        return LiftRetVal<ExitCancelFailure>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 2:
        final lifted = TooLateExitCancelFailure.read(subview);
        return LiftRetVal<ExitCancelFailure>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 3:
        final lifted = AlreadyBroadcastExitCancelFailure.read(subview);
        return LiftRetVal<ExitCancelFailure>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static RustBuffer lower(ExitCancelFailure value) {
    return value.lower();
  }

  static int allocationSize(ExitCancelFailure value) {
    return value.allocationSize();
  }

  static int write(ExitCancelFailure value, Uint8List buf) {
    return value.write(buf) - buf.offsetInBytes;
  }
}

class NotExitingExitCancelFailure extends ExitCancelFailure {
  NotExitingExitCancelFailure();
  NotExitingExitCancelFailure._();
  static LiftRetVal<NotExitingExitCancelFailure> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    return LiftRetVal(NotExitingExitCancelFailure._(), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 1);
    int new_offset = buf.offsetInBytes + 4;
    return new_offset;
  }
}

class TooLateExitCancelFailure extends ExitCancelFailure {
  final ExitStateKind state;
  TooLateExitCancelFailure(ExitStateKind this.state);
  TooLateExitCancelFailure._(ExitStateKind this.state);
  static LiftRetVal<TooLateExitCancelFailure> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final state_int = buf.buffer.asByteData(new_offset).getInt32(0);
    final state = FfiConverterExitStateKind.lift(
      toRustBuffer(createUint8ListFromInt(state_int)),
    );
    new_offset += 4;
    return LiftRetVal(TooLateExitCancelFailure._(state), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return 4 + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 2);
    int new_offset = buf.offsetInBytes + 4;
    final state_buffer = FfiConverterExitStateKind.lower(state);
    final state_int = state_buffer.asUint8List().buffer.asByteData().getInt32(
      0,
    );
    buf.buffer.asByteData(new_offset).setInt32(0, state_int);
    new_offset += 4;
    return new_offset;
  }
}

class AlreadyBroadcastExitCancelFailure extends ExitCancelFailure {
  final String txid;
  AlreadyBroadcastExitCancelFailure(String this.txid);
  AlreadyBroadcastExitCancelFailure._(String this.txid);
  static LiftRetVal<AlreadyBroadcastExitCancelFailure> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final txid_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final txid = txid_lifted.value;
    new_offset += txid_lifted.bytesRead;
    return LiftRetVal(AlreadyBroadcastExitCancelFailure._(txid), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterString.allocationSize(txid) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 3);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterString.write(
      txid,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

abstract class ExitState {
  RustBuffer lower();
  int allocationSize();
  int write(Uint8List buf);
}

class FfiConverterExitState {
  static ExitState lift(RustBuffer buffer) {
    return FfiConverterExitState.read(buffer.asUint8List()).value;
  }

  static LiftRetVal<ExitState> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    final subview = Uint8List.view(buf.buffer, buf.offsetInBytes + 4);
    switch (index) {
      case 1:
        final lifted = StartExitState.read(subview);
        return LiftRetVal<ExitState>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 2:
        final lifted = ProcessingExitState.read(subview);
        return LiftRetVal<ExitState>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 3:
        final lifted = AwaitingDeltaExitState.read(subview);
        return LiftRetVal<ExitState>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 4:
        final lifted = ClaimableExitState.read(subview);
        return LiftRetVal<ExitState>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 5:
        final lifted = ClaimInProgressExitState.read(subview);
        return LiftRetVal<ExitState>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 6:
        final lifted = ClaimedExitState.read(subview);
        return LiftRetVal<ExitState>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 7:
        final lifted = VtxoAlreadySpentExitState.read(subview);
        return LiftRetVal<ExitState>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 8:
        final lifted = CanceledExitState.read(subview);
        return LiftRetVal<ExitState>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static RustBuffer lower(ExitState value) {
    return value.lower();
  }

  static int allocationSize(ExitState value) {
    return value.allocationSize();
  }

  static int write(ExitState value, Uint8List buf) {
    return value.write(buf) - buf.offsetInBytes;
  }
}

class StartExitState extends ExitState {
  final int tipHeight;
  StartExitState(int this.tipHeight);
  StartExitState._(int this.tipHeight);
  static LiftRetVal<StartExitState> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final tipHeight_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final tipHeight = tipHeight_lifted.value;
    new_offset += tipHeight_lifted.bytesRead;
    return LiftRetVal(StartExitState._(tipHeight), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterUInt32.allocationSize(tipHeight) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 1);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterUInt32.write(
      tipHeight,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class ProcessingExitState extends ExitState {
  final int tipHeight;
  final List<ExitTx> transactions;
  ProcessingExitState({
    required int this.tipHeight,
    required List<ExitTx> this.transactions,
  });
  ProcessingExitState._(int this.tipHeight, List<ExitTx> this.transactions);
  static LiftRetVal<ProcessingExitState> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final tipHeight_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final tipHeight = tipHeight_lifted.value;
    new_offset += tipHeight_lifted.bytesRead;
    final transactions_lifted = FfiConverterSequenceExitTx.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final transactions = transactions_lifted.value;
    new_offset += transactions_lifted.bytesRead;
    return LiftRetVal(
      ProcessingExitState._(tipHeight, transactions),
      new_offset,
    );
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterUInt32.allocationSize(tipHeight) +
        FfiConverterSequenceExitTx.allocationSize(transactions) +
        4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 2);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterUInt32.write(
      tipHeight,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterSequenceExitTx.write(
      transactions,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class AwaitingDeltaExitState extends ExitState {
  final int tipHeight;
  final BlockRef confirmedBlock;
  final int claimableHeight;
  AwaitingDeltaExitState({
    required int this.tipHeight,
    required BlockRef this.confirmedBlock,
    required int this.claimableHeight,
  });
  AwaitingDeltaExitState._(
    int this.tipHeight,
    BlockRef this.confirmedBlock,
    int this.claimableHeight,
  );
  static LiftRetVal<AwaitingDeltaExitState> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final tipHeight_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final tipHeight = tipHeight_lifted.value;
    new_offset += tipHeight_lifted.bytesRead;
    final confirmedBlock_lifted = FfiConverterBlockRef.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final confirmedBlock = confirmedBlock_lifted.value;
    new_offset += confirmedBlock_lifted.bytesRead;
    final claimableHeight_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final claimableHeight = claimableHeight_lifted.value;
    new_offset += claimableHeight_lifted.bytesRead;
    return LiftRetVal(
      AwaitingDeltaExitState._(tipHeight, confirmedBlock, claimableHeight),
      new_offset,
    );
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterUInt32.allocationSize(tipHeight) +
        FfiConverterBlockRef.allocationSize(confirmedBlock) +
        FfiConverterUInt32.allocationSize(claimableHeight) +
        4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 3);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterUInt32.write(
      tipHeight,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBlockRef.write(
      confirmedBlock,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      claimableHeight,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class ClaimableExitState extends ExitState {
  final int tipHeight;
  final BlockRef claimableSince;
  final BlockRef? lastScannedBlock;
  ClaimableExitState({
    required int this.tipHeight,
    required BlockRef this.claimableSince,
    required BlockRef? this.lastScannedBlock,
  });
  ClaimableExitState._(
    int this.tipHeight,
    BlockRef this.claimableSince,
    BlockRef? this.lastScannedBlock,
  );
  static LiftRetVal<ClaimableExitState> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final tipHeight_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final tipHeight = tipHeight_lifted.value;
    new_offset += tipHeight_lifted.bytesRead;
    final claimableSince_lifted = FfiConverterBlockRef.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final claimableSince = claimableSince_lifted.value;
    new_offset += claimableSince_lifted.bytesRead;
    final lastScannedBlock_lifted = FfiConverterOptionalBlockRef.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final lastScannedBlock = lastScannedBlock_lifted.value;
    new_offset += lastScannedBlock_lifted.bytesRead;
    return LiftRetVal(
      ClaimableExitState._(tipHeight, claimableSince, lastScannedBlock),
      new_offset,
    );
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterUInt32.allocationSize(tipHeight) +
        FfiConverterBlockRef.allocationSize(claimableSince) +
        FfiConverterOptionalBlockRef.allocationSize(lastScannedBlock) +
        4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 4);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterUInt32.write(
      tipHeight,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBlockRef.write(
      claimableSince,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalBlockRef.write(
      lastScannedBlock,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class ClaimInProgressExitState extends ExitState {
  final int tipHeight;
  final BlockRef claimableSince;
  final String claimTxid;
  ClaimInProgressExitState({
    required int this.tipHeight,
    required BlockRef this.claimableSince,
    required String this.claimTxid,
  });
  ClaimInProgressExitState._(
    int this.tipHeight,
    BlockRef this.claimableSince,
    String this.claimTxid,
  );
  static LiftRetVal<ClaimInProgressExitState> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final tipHeight_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final tipHeight = tipHeight_lifted.value;
    new_offset += tipHeight_lifted.bytesRead;
    final claimableSince_lifted = FfiConverterBlockRef.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final claimableSince = claimableSince_lifted.value;
    new_offset += claimableSince_lifted.bytesRead;
    final claimTxid_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final claimTxid = claimTxid_lifted.value;
    new_offset += claimTxid_lifted.bytesRead;
    return LiftRetVal(
      ClaimInProgressExitState._(tipHeight, claimableSince, claimTxid),
      new_offset,
    );
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterUInt32.allocationSize(tipHeight) +
        FfiConverterBlockRef.allocationSize(claimableSince) +
        FfiConverterString.allocationSize(claimTxid) +
        4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 5);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterUInt32.write(
      tipHeight,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBlockRef.write(
      claimableSince,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      claimTxid,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class ClaimedExitState extends ExitState {
  final int tipHeight;
  final String txid;
  final BlockRef block;
  ClaimedExitState({
    required int this.tipHeight,
    required String this.txid,
    required BlockRef this.block,
  });
  ClaimedExitState._(int this.tipHeight, String this.txid, BlockRef this.block);
  static LiftRetVal<ClaimedExitState> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final tipHeight_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final tipHeight = tipHeight_lifted.value;
    new_offset += tipHeight_lifted.bytesRead;
    final txid_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final txid = txid_lifted.value;
    new_offset += txid_lifted.bytesRead;
    final block_lifted = FfiConverterBlockRef.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final block = block_lifted.value;
    new_offset += block_lifted.bytesRead;
    return LiftRetVal(ClaimedExitState._(tipHeight, txid, block), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterUInt32.allocationSize(tipHeight) +
        FfiConverterString.allocationSize(txid) +
        FfiConverterBlockRef.allocationSize(block) +
        4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 6);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterUInt32.write(
      tipHeight,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      txid,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBlockRef.write(
      block,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class VtxoAlreadySpentExitState extends ExitState {
  final int tipHeight;
  VtxoAlreadySpentExitState(int this.tipHeight);
  VtxoAlreadySpentExitState._(int this.tipHeight);
  static LiftRetVal<VtxoAlreadySpentExitState> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final tipHeight_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final tipHeight = tipHeight_lifted.value;
    new_offset += tipHeight_lifted.bytesRead;
    return LiftRetVal(VtxoAlreadySpentExitState._(tipHeight), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterUInt32.allocationSize(tipHeight) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 7);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterUInt32.write(
      tipHeight,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class CanceledExitState extends ExitState {
  final int tipHeight;
  CanceledExitState(int this.tipHeight);
  CanceledExitState._(int this.tipHeight);
  static LiftRetVal<CanceledExitState> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final tipHeight_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final tipHeight = tipHeight_lifted.value;
    new_offset += tipHeight_lifted.bytesRead;
    return LiftRetVal(CanceledExitState._(tipHeight), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterUInt32.allocationSize(tipHeight) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 8);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterUInt32.write(
      tipHeight,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

enum ExitStateKind {
  start,
  processing,
  awaitingDelta,
  claimable,
  claimInProgress,
  claimed,
  vtxoAlreadySpent,
  canceled,
}

class FfiConverterExitStateKind {
  static LiftRetVal<ExitStateKind> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    switch (index) {
      case 1:
        return LiftRetVal(ExitStateKind.start, 4);
      case 2:
        return LiftRetVal(ExitStateKind.processing, 4);
      case 3:
        return LiftRetVal(ExitStateKind.awaitingDelta, 4);
      case 4:
        return LiftRetVal(ExitStateKind.claimable, 4);
      case 5:
        return LiftRetVal(ExitStateKind.claimInProgress, 4);
      case 6:
        return LiftRetVal(ExitStateKind.claimed, 4);
      case 7:
        return LiftRetVal(ExitStateKind.vtxoAlreadySpent, 4);
      case 8:
        return LiftRetVal(ExitStateKind.canceled, 4);
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static ExitStateKind lift(RustBuffer buffer) {
    return FfiConverterExitStateKind.read(buffer.asUint8List()).value;
  }

  static RustBuffer lower(ExitStateKind input) {
    return toRustBuffer(createUint8ListFromInt(input.index + 1));
  }

  static int allocationSize(ExitStateKind _value) {
    return 4;
  }

  static int write(ExitStateKind value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.index + 1);
    return 4;
  }
}

abstract class ExitTxOrigin {
  RustBuffer lower();
  int allocationSize();
  int write(Uint8List buf);
}

class FfiConverterExitTxOrigin {
  static ExitTxOrigin lift(RustBuffer buffer) {
    return FfiConverterExitTxOrigin.read(buffer.asUint8List()).value;
  }

  static LiftRetVal<ExitTxOrigin> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    final subview = Uint8List.view(buf.buffer, buf.offsetInBytes + 4);
    switch (index) {
      case 1:
        final lifted = WalletExitTxOrigin.read(subview);
        return LiftRetVal<ExitTxOrigin>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 2:
        final lifted = MempoolExitTxOrigin.read(subview);
        return LiftRetVal<ExitTxOrigin>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 3:
        final lifted = BlockExitTxOrigin.read(subview);
        return LiftRetVal<ExitTxOrigin>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static RustBuffer lower(ExitTxOrigin value) {
    return value.lower();
  }

  static int allocationSize(ExitTxOrigin value) {
    return value.allocationSize();
  }

  static int write(ExitTxOrigin value, Uint8List buf) {
    return value.write(buf) - buf.offsetInBytes;
  }
}

class WalletExitTxOrigin extends ExitTxOrigin {
  final BlockRef? confirmedIn;
  WalletExitTxOrigin(BlockRef? this.confirmedIn);
  WalletExitTxOrigin._(BlockRef? this.confirmedIn);
  static LiftRetVal<WalletExitTxOrigin> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final confirmedIn_lifted = FfiConverterOptionalBlockRef.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final confirmedIn = confirmedIn_lifted.value;
    new_offset += confirmedIn_lifted.bytesRead;
    return LiftRetVal(WalletExitTxOrigin._(confirmedIn), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterOptionalBlockRef.allocationSize(confirmedIn) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 1);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterOptionalBlockRef.write(
      confirmedIn,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class MempoolExitTxOrigin extends ExitTxOrigin {
  MempoolExitTxOrigin();
  MempoolExitTxOrigin._();
  static LiftRetVal<MempoolExitTxOrigin> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    return LiftRetVal(MempoolExitTxOrigin._(), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 2);
    int new_offset = buf.offsetInBytes + 4;
    return new_offset;
  }
}

class BlockExitTxOrigin extends ExitTxOrigin {
  final BlockRef confirmedIn;
  BlockExitTxOrigin(BlockRef this.confirmedIn);
  BlockExitTxOrigin._(BlockRef this.confirmedIn);
  static LiftRetVal<BlockExitTxOrigin> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final confirmedIn_lifted = FfiConverterBlockRef.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final confirmedIn = confirmedIn_lifted.value;
    new_offset += confirmedIn_lifted.bytesRead;
    return LiftRetVal(BlockExitTxOrigin._(confirmedIn), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterBlockRef.allocationSize(confirmedIn) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 3);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterBlockRef.write(
      confirmedIn,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

abstract class ExitTxStatus {
  RustBuffer lower();
  int allocationSize();
  int write(Uint8List buf);
}

class FfiConverterExitTxStatus {
  static ExitTxStatus lift(RustBuffer buffer) {
    return FfiConverterExitTxStatus.read(buffer.asUint8List()).value;
  }

  static LiftRetVal<ExitTxStatus> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    final subview = Uint8List.view(buf.buffer, buf.offsetInBytes + 4);
    switch (index) {
      case 1:
        final lifted = VerifyInputsExitTxStatus.read(subview);
        return LiftRetVal<ExitTxStatus>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 2:
        final lifted = AwaitingInputConfirmationExitTxStatus.read(subview);
        return LiftRetVal<ExitTxStatus>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 3:
        final lifted = AwaitingCpfpBroadcastExitTxStatus.read(subview);
        return LiftRetVal<ExitTxStatus>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 4:
        final lifted = AwaitingConfirmationExitTxStatus.read(subview);
        return LiftRetVal<ExitTxStatus>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 5:
        final lifted = ConfirmedExitTxStatus.read(subview);
        return LiftRetVal<ExitTxStatus>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static RustBuffer lower(ExitTxStatus value) {
    return value.lower();
  }

  static int allocationSize(ExitTxStatus value) {
    return value.allocationSize();
  }

  static int write(ExitTxStatus value, Uint8List buf) {
    return value.write(buf) - buf.offsetInBytes;
  }
}

class VerifyInputsExitTxStatus extends ExitTxStatus {
  VerifyInputsExitTxStatus();
  VerifyInputsExitTxStatus._();
  static LiftRetVal<VerifyInputsExitTxStatus> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    return LiftRetVal(VerifyInputsExitTxStatus._(), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 1);
    int new_offset = buf.offsetInBytes + 4;
    return new_offset;
  }
}

class AwaitingInputConfirmationExitTxStatus extends ExitTxStatus {
  final List<String> txids;
  AwaitingInputConfirmationExitTxStatus(List<String> this.txids);
  AwaitingInputConfirmationExitTxStatus._(List<String> this.txids);
  static LiftRetVal<AwaitingInputConfirmationExitTxStatus> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final txids_lifted = FfiConverterSequenceString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final txids = txids_lifted.value;
    new_offset += txids_lifted.bytesRead;
    return LiftRetVal(
      AwaitingInputConfirmationExitTxStatus._(txids),
      new_offset,
    );
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterSequenceString.allocationSize(txids) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 2);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterSequenceString.write(
      txids,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class AwaitingCpfpBroadcastExitTxStatus extends ExitTxStatus {
  AwaitingCpfpBroadcastExitTxStatus();
  AwaitingCpfpBroadcastExitTxStatus._();
  static LiftRetVal<AwaitingCpfpBroadcastExitTxStatus> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    return LiftRetVal(AwaitingCpfpBroadcastExitTxStatus._(), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 3);
    int new_offset = buf.offsetInBytes + 4;
    return new_offset;
  }
}

class AwaitingConfirmationExitTxStatus extends ExitTxStatus {
  final String childTxid;
  final ExitTxOrigin origin;
  AwaitingConfirmationExitTxStatus({
    required String this.childTxid,
    required ExitTxOrigin this.origin,
  });
  AwaitingConfirmationExitTxStatus._(
    String this.childTxid,
    ExitTxOrigin this.origin,
  );
  static LiftRetVal<AwaitingConfirmationExitTxStatus> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final childTxid_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final childTxid = childTxid_lifted.value;
    new_offset += childTxid_lifted.bytesRead;
    final origin_lifted = FfiConverterExitTxOrigin.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final origin = origin_lifted.value;
    new_offset += origin_lifted.bytesRead;
    return LiftRetVal(
      AwaitingConfirmationExitTxStatus._(childTxid, origin),
      new_offset,
    );
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterString.allocationSize(childTxid) +
        FfiConverterExitTxOrigin.allocationSize(origin) +
        4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 4);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterString.write(
      childTxid,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterExitTxOrigin.write(
      origin,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class ConfirmedExitTxStatus extends ExitTxStatus {
  final String childTxid;
  final BlockRef block;
  final ExitTxOrigin origin;
  ConfirmedExitTxStatus({
    required String this.childTxid,
    required BlockRef this.block,
    required ExitTxOrigin this.origin,
  });
  ConfirmedExitTxStatus._(
    String this.childTxid,
    BlockRef this.block,
    ExitTxOrigin this.origin,
  );
  static LiftRetVal<ConfirmedExitTxStatus> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final childTxid_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final childTxid = childTxid_lifted.value;
    new_offset += childTxid_lifted.bytesRead;
    final block_lifted = FfiConverterBlockRef.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final block = block_lifted.value;
    new_offset += block_lifted.bytesRead;
    final origin_lifted = FfiConverterExitTxOrigin.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final origin = origin_lifted.value;
    new_offset += origin_lifted.bytesRead;
    return LiftRetVal(
      ConfirmedExitTxStatus._(childTxid, block, origin),
      new_offset,
    );
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterString.allocationSize(childTxid) +
        FfiConverterBlockRef.allocationSize(block) +
        FfiConverterExitTxOrigin.allocationSize(origin) +
        4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 5);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterString.write(
      childTxid,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterBlockRef.write(
      block,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterExitTxOrigin.write(
      origin,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

abstract class LightningSendStatus {
  RustBuffer lower();
  int allocationSize();
  int write(Uint8List buf);
}

class FfiConverterLightningSendStatus {
  static LightningSendStatus lift(RustBuffer buffer) {
    return FfiConverterLightningSendStatus.read(buffer.asUint8List()).value;
  }

  static LiftRetVal<LightningSendStatus> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    final subview = Uint8List.view(buf.buffer, buf.offsetInBytes + 4);
    switch (index) {
      case 1:
        final lifted = UnknownLightningSendStatus.read(subview);
        return LiftRetVal<LightningSendStatus>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 2:
        final lifted = InProgressLightningSendStatus.read(subview);
        return LiftRetVal<LightningSendStatus>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 3:
        final lifted = PaidLightningSendStatus.read(subview);
        return LiftRetVal<LightningSendStatus>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static RustBuffer lower(LightningSendStatus value) {
    return value.lower();
  }

  static int allocationSize(LightningSendStatus value) {
    return value.allocationSize();
  }

  static int write(LightningSendStatus value, Uint8List buf) {
    return value.write(buf) - buf.offsetInBytes;
  }
}

class UnknownLightningSendStatus extends LightningSendStatus {
  UnknownLightningSendStatus();
  UnknownLightningSendStatus._();
  static LiftRetVal<UnknownLightningSendStatus> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    return LiftRetVal(UnknownLightningSendStatus._(), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 1);
    int new_offset = buf.offsetInBytes + 4;
    return new_offset;
  }
}

class InProgressLightningSendStatus extends LightningSendStatus {
  final LightningSend send;
  InProgressLightningSendStatus(LightningSend this.send);
  InProgressLightningSendStatus._(LightningSend this.send);
  static LiftRetVal<InProgressLightningSendStatus> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final send_lifted = FfiConverterLightningSend.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final send = send_lifted.value;
    new_offset += send_lifted.bytesRead;
    return LiftRetVal(InProgressLightningSendStatus._(send), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterLightningSend.allocationSize(send) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 2);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterLightningSend.write(
      send,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class PaidLightningSendStatus extends LightningSendStatus {
  final String paymentHash;
  final String preimage;
  PaidLightningSendStatus({
    required String this.paymentHash,
    required String this.preimage,
  });
  PaidLightningSendStatus._(String this.paymentHash, String this.preimage);
  static LiftRetVal<PaidLightningSendStatus> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final paymentHash_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final paymentHash = paymentHash_lifted.value;
    new_offset += paymentHash_lifted.bytesRead;
    final preimage_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final preimage = preimage_lifted.value;
    new_offset += preimage_lifted.bytesRead;
    return LiftRetVal(
      PaidLightningSendStatus._(paymentHash, preimage),
      new_offset,
    );
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterString.allocationSize(paymentHash) +
        FfiConverterString.allocationSize(preimage) +
        4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 3);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterString.write(
      paymentHash,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterString.write(
      preimage,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

enum Network { bitcoin, testnet, signet, regtest }

class FfiConverterNetwork {
  static LiftRetVal<Network> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    switch (index) {
      case 1:
        return LiftRetVal(Network.bitcoin, 4);
      case 2:
        return LiftRetVal(Network.testnet, 4);
      case 3:
        return LiftRetVal(Network.signet, 4);
      case 4:
        return LiftRetVal(Network.regtest, 4);
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static Network lift(RustBuffer buffer) {
    return FfiConverterNetwork.read(buffer.asUint8List()).value;
  }

  static RustBuffer lower(Network input) {
    return toRustBuffer(createUint8ListFromInt(input.index + 1));
  }

  static int allocationSize(Network _value) {
    return 4;
  }

  static int write(Network value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.index + 1);
    return 4;
  }
}

abstract class OnchainUtxo {
  RustBuffer lower();
  int allocationSize();
  int write(Uint8List buf);
}

class FfiConverterOnchainUtxo {
  static OnchainUtxo lift(RustBuffer buffer) {
    return FfiConverterOnchainUtxo.read(buffer.asUint8List()).value;
  }

  static LiftRetVal<OnchainUtxo> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    final subview = Uint8List.view(buf.buffer, buf.offsetInBytes + 4);
    switch (index) {
      case 1:
        final lifted = LocalOnchainUtxo.read(subview);
        return LiftRetVal<OnchainUtxo>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 2:
        final lifted = ExitOnchainUtxo.read(subview);
        return LiftRetVal<OnchainUtxo>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static RustBuffer lower(OnchainUtxo value) {
    return value.lower();
  }

  static int allocationSize(OnchainUtxo value) {
    return value.allocationSize();
  }

  static int write(OnchainUtxo value, Uint8List buf) {
    return value.write(buf) - buf.offsetInBytes;
  }
}

class LocalOnchainUtxo extends OnchainUtxo {
  final OutPoint outpoint;
  final int amountSats;
  final int? confirmationHeight;
  LocalOnchainUtxo({
    required OutPoint this.outpoint,
    required int this.amountSats,
    required int? this.confirmationHeight,
  });
  LocalOnchainUtxo._(
    OutPoint this.outpoint,
    int this.amountSats,
    int? this.confirmationHeight,
  );
  static LiftRetVal<LocalOnchainUtxo> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final outpoint_lifted = FfiConverterOutPoint.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final outpoint = outpoint_lifted.value;
    new_offset += outpoint_lifted.bytesRead;
    final amountSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final amountSats = amountSats_lifted.value;
    new_offset += amountSats_lifted.bytesRead;
    final confirmationHeight_lifted = FfiConverterOptionalUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final confirmationHeight = confirmationHeight_lifted.value;
    new_offset += confirmationHeight_lifted.bytesRead;
    return LiftRetVal(
      LocalOnchainUtxo._(outpoint, amountSats, confirmationHeight),
      new_offset,
    );
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterOutPoint.allocationSize(outpoint) +
        FfiConverterUInt64.allocationSize(amountSats) +
        FfiConverterOptionalUInt32.allocationSize(confirmationHeight) +
        4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 1);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterOutPoint.write(
      outpoint,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      amountSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterOptionalUInt32.write(
      confirmationHeight,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class ExitOnchainUtxo extends OnchainUtxo {
  final String vtxoId;
  final int amountSats;
  final int height;
  ExitOnchainUtxo({
    required String this.vtxoId,
    required int this.amountSats,
    required int this.height,
  });
  ExitOnchainUtxo._(String this.vtxoId, int this.amountSats, int this.height);
  static LiftRetVal<ExitOnchainUtxo> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final vtxoId_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final vtxoId = vtxoId_lifted.value;
    new_offset += vtxoId_lifted.bytesRead;
    final amountSats_lifted = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final amountSats = amountSats_lifted.value;
    new_offset += amountSats_lifted.bytesRead;
    final height_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final height = height_lifted.value;
    new_offset += height_lifted.bytesRead;
    return LiftRetVal(
      ExitOnchainUtxo._(vtxoId, amountSats, height),
      new_offset,
    );
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterString.allocationSize(vtxoId) +
        FfiConverterUInt64.allocationSize(amountSats) +
        FfiConverterUInt32.allocationSize(height) +
        4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 2);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterString.write(
      vtxoId,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt64.write(
      amountSats,
      Uint8List.view(buf.buffer, new_offset),
    );
    new_offset += FfiConverterUInt32.write(
      height,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

abstract class RecoveryStatus {
  RustBuffer lower();
  int allocationSize();
  int write(Uint8List buf);
}

class FfiConverterRecoveryStatus {
  static RecoveryStatus lift(RustBuffer buffer) {
    return FfiConverterRecoveryStatus.read(buffer.asUint8List()).value;
  }

  static LiftRetVal<RecoveryStatus> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    final subview = Uint8List.view(buf.buffer, buf.offsetInBytes + 4);
    switch (index) {
      case 1:
        final lifted = NotRunRecoveryStatus.read(subview);
        return LiftRetVal<RecoveryStatus>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 2:
        final lifted = FailedRecoveryStatus.read(subview);
        return LiftRetVal<RecoveryStatus>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 3:
        final lifted = CompletedRecoveryStatus.read(subview);
        return LiftRetVal<RecoveryStatus>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static RustBuffer lower(RecoveryStatus value) {
    return value.lower();
  }

  static int allocationSize(RecoveryStatus value) {
    return value.allocationSize();
  }

  static int write(RecoveryStatus value, Uint8List buf) {
    return value.write(buf) - buf.offsetInBytes;
  }
}

class NotRunRecoveryStatus extends RecoveryStatus {
  NotRunRecoveryStatus();
  NotRunRecoveryStatus._();
  static LiftRetVal<NotRunRecoveryStatus> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    return LiftRetVal(NotRunRecoveryStatus._(), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 1);
    int new_offset = buf.offsetInBytes + 4;
    return new_offset;
  }
}

class FailedRecoveryStatus extends RecoveryStatus {
  final String message;
  FailedRecoveryStatus(String this.message);
  FailedRecoveryStatus._(String this.message);
  static LiftRetVal<FailedRecoveryStatus> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final message_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final message = message_lifted.value;
    new_offset += message_lifted.bytesRead;
    return LiftRetVal(FailedRecoveryStatus._(message), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterString.allocationSize(message) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 2);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterString.write(
      message,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class CompletedRecoveryStatus extends RecoveryStatus {
  final RecoveryReport report;
  CompletedRecoveryStatus(RecoveryReport this.report);
  CompletedRecoveryStatus._(RecoveryReport this.report);
  static LiftRetVal<CompletedRecoveryStatus> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final report_lifted = FfiConverterRecoveryReport.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final report = report_lifted.value;
    new_offset += report_lifted.bytesRead;
    return LiftRetVal(CompletedRecoveryStatus._(report), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterRecoveryReport.allocationSize(report) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 3);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterRecoveryReport.write(
      report,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

enum RoundFlowKind {
  delegatedPending,
  pending,
  ongoing,
  awaitingConfirmations,
  failed,
  canceled,
}

class FfiConverterRoundFlowKind {
  static LiftRetVal<RoundFlowKind> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    switch (index) {
      case 1:
        return LiftRetVal(RoundFlowKind.delegatedPending, 4);
      case 2:
        return LiftRetVal(RoundFlowKind.pending, 4);
      case 3:
        return LiftRetVal(RoundFlowKind.ongoing, 4);
      case 4:
        return LiftRetVal(RoundFlowKind.awaitingConfirmations, 4);
      case 5:
        return LiftRetVal(RoundFlowKind.failed, 4);
      case 6:
        return LiftRetVal(RoundFlowKind.canceled, 4);
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static RoundFlowKind lift(RustBuffer buffer) {
    return FfiConverterRoundFlowKind.read(buffer.asUint8List()).value;
  }

  static RustBuffer lower(RoundFlowKind input) {
    return toRustBuffer(createUint8ListFromInt(input.index + 1));
  }

  static int allocationSize(RoundFlowKind _value) {
    return 4;
  }

  static int write(RoundFlowKind value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.index + 1);
    return 4;
  }
}

abstract class VtxoLockHolder {
  RustBuffer lower();
  int allocationSize();
  int write(Uint8List buf);
}

class FfiConverterVtxoLockHolder {
  static VtxoLockHolder lift(RustBuffer buffer) {
    return FfiConverterVtxoLockHolder.read(buffer.asUint8List()).value;
  }

  static LiftRetVal<VtxoLockHolder> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    final subview = Uint8List.view(buf.buffer, buf.offsetInBytes + 4);
    switch (index) {
      case 1:
        final lifted = ActionVtxoLockHolder.read(subview);
        return LiftRetVal<VtxoLockHolder>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 2:
        final lifted = MovementVtxoLockHolder.read(subview);
        return LiftRetVal<VtxoLockHolder>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static RustBuffer lower(VtxoLockHolder value) {
    return value.lower();
  }

  static int allocationSize(VtxoLockHolder value) {
    return value.allocationSize();
  }

  static int write(VtxoLockHolder value, Uint8List buf) {
    return value.write(buf) - buf.offsetInBytes;
  }
}

class ActionVtxoLockHolder extends VtxoLockHolder {
  final String id;
  ActionVtxoLockHolder(String this.id);
  ActionVtxoLockHolder._(String this.id);
  static LiftRetVal<ActionVtxoLockHolder> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final id_lifted = FfiConverterString.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final id = id_lifted.value;
    new_offset += id_lifted.bytesRead;
    return LiftRetVal(ActionVtxoLockHolder._(id), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterString.allocationSize(id) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 1);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterString.write(
      id,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class MovementVtxoLockHolder extends VtxoLockHolder {
  final int id;
  MovementVtxoLockHolder(int this.id);
  MovementVtxoLockHolder._(int this.id);
  static LiftRetVal<MovementVtxoLockHolder> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final id_lifted = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final id = id_lifted.value;
    new_offset += id_lifted.bytesRead;
    return LiftRetVal(MovementVtxoLockHolder._(id), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterUInt32.allocationSize(id) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 2);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterUInt32.write(
      id,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

abstract class VtxoState {
  RustBuffer lower();
  int allocationSize();
  int write(Uint8List buf);
}

class FfiConverterVtxoState {
  static VtxoState lift(RustBuffer buffer) {
    return FfiConverterVtxoState.read(buffer.asUint8List()).value;
  }

  static LiftRetVal<VtxoState> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    final subview = Uint8List.view(buf.buffer, buf.offsetInBytes + 4);
    switch (index) {
      case 1:
        final lifted = SpendableVtxoState.read(subview);
        return LiftRetVal<VtxoState>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 2:
        final lifted = LockedVtxoState.read(subview);
        return LiftRetVal<VtxoState>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 3:
        final lifted = SpentVtxoState.read(subview);
        return LiftRetVal<VtxoState>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 4:
        final lifted = ExitedVtxoState.read(subview);
        return LiftRetVal<VtxoState>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static RustBuffer lower(VtxoState value) {
    return value.lower();
  }

  static int allocationSize(VtxoState value) {
    return value.allocationSize();
  }

  static int write(VtxoState value, Uint8List buf) {
    return value.write(buf) - buf.offsetInBytes;
  }
}

class SpendableVtxoState extends VtxoState {
  SpendableVtxoState();
  SpendableVtxoState._();
  static LiftRetVal<SpendableVtxoState> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    return LiftRetVal(SpendableVtxoState._(), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 1);
    int new_offset = buf.offsetInBytes + 4;
    return new_offset;
  }
}

class LockedVtxoState extends VtxoState {
  final VtxoLockHolder? holder;
  LockedVtxoState(VtxoLockHolder? this.holder);
  LockedVtxoState._(VtxoLockHolder? this.holder);
  static LiftRetVal<LockedVtxoState> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final holder_lifted = FfiConverterOptionalVtxoLockHolder.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final holder = holder_lifted.value;
    new_offset += holder_lifted.bytesRead;
    return LiftRetVal(LockedVtxoState._(holder), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterOptionalVtxoLockHolder.allocationSize(holder) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 2);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterOptionalVtxoLockHolder.write(
      holder,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class SpentVtxoState extends VtxoState {
  SpentVtxoState();
  SpentVtxoState._();
  static LiftRetVal<SpentVtxoState> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    return LiftRetVal(SpentVtxoState._(), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 3);
    int new_offset = buf.offsetInBytes + 4;
    return new_offset;
  }
}

class ExitedVtxoState extends VtxoState {
  ExitedVtxoState();
  ExitedVtxoState._();
  static LiftRetVal<ExitedVtxoState> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    return LiftRetVal(ExitedVtxoState._(), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 4);
    int new_offset = buf.offsetInBytes + 4;
    return new_offset;
  }
}

abstract class WalletNotification {
  RustBuffer lower();
  int allocationSize();
  int write(Uint8List buf);
}

class FfiConverterWalletNotification {
  static WalletNotification lift(RustBuffer buffer) {
    return FfiConverterWalletNotification.read(buffer.asUint8List()).value;
  }

  static LiftRetVal<WalletNotification> read(Uint8List buf) {
    final index = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    final subview = Uint8List.view(buf.buffer, buf.offsetInBytes + 4);
    switch (index) {
      case 1:
        final lifted = MovementCreatedWalletNotification.read(subview);
        return LiftRetVal<WalletNotification>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 2:
        final lifted = MovementUpdatedWalletNotification.read(subview);
        return LiftRetVal<WalletNotification>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      case 3:
        final lifted = ChannelLaggingWalletNotification.read(subview);
        return LiftRetVal<WalletNotification>(
          lifted.value,
          lifted.bytesRead - subview.offsetInBytes + 4,
        );
      default:
        throw UniffiInternalError(
          UniffiInternalError.unexpectedEnumCase,
          "Unable to determine enum variant",
        );
    }
  }

  static RustBuffer lower(WalletNotification value) {
    return value.lower();
  }

  static int allocationSize(WalletNotification value) {
    return value.allocationSize();
  }

  static int write(WalletNotification value, Uint8List buf) {
    return value.write(buf) - buf.offsetInBytes;
  }
}

class MovementCreatedWalletNotification extends WalletNotification {
  final Movement movement;
  MovementCreatedWalletNotification(Movement this.movement);
  MovementCreatedWalletNotification._(Movement this.movement);
  static LiftRetVal<MovementCreatedWalletNotification> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final movement_lifted = FfiConverterMovement.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final movement = movement_lifted.value;
    new_offset += movement_lifted.bytesRead;
    return LiftRetVal(
      MovementCreatedWalletNotification._(movement),
      new_offset,
    );
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterMovement.allocationSize(movement) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 1);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterMovement.write(
      movement,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class MovementUpdatedWalletNotification extends WalletNotification {
  final Movement movement;
  MovementUpdatedWalletNotification(Movement this.movement);
  MovementUpdatedWalletNotification._(Movement this.movement);
  static LiftRetVal<MovementUpdatedWalletNotification> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    final movement_lifted = FfiConverterMovement.read(
      Uint8List.view(buf.buffer, new_offset),
    );
    final movement = movement_lifted.value;
    new_offset += movement_lifted.bytesRead;
    return LiftRetVal(
      MovementUpdatedWalletNotification._(movement),
      new_offset,
    );
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return FfiConverterMovement.allocationSize(movement) + 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 2);
    int new_offset = buf.offsetInBytes + 4;
    new_offset += FfiConverterMovement.write(
      movement,
      Uint8List.view(buf.buffer, new_offset),
    );
    return new_offset;
  }
}

class ChannelLaggingWalletNotification extends WalletNotification {
  ChannelLaggingWalletNotification();
  ChannelLaggingWalletNotification._();
  static LiftRetVal<ChannelLaggingWalletNotification> read(Uint8List buf) {
    int new_offset = buf.offsetInBytes;
    return LiftRetVal(ChannelLaggingWalletNotification._(), new_offset);
  }

  @override
  RustBuffer lower() {
    final buf = Uint8List(allocationSize());
    write(buf);
    return toRustBuffer(buf);
  }

  @override
  int allocationSize() {
    return 4;
  }

  @override
  int write(Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, 3);
    int new_offset = buf.offsetInBytes + 4;
    return new_offset;
  }
}

abstract class NotificationHolderInterface {
  void cancelNextNotificationWait();
  Future<WalletNotification?> nextNotification();
}

final _NotificationHolderFinalizer = Finalizer<Pointer<Void>>((ptr) {
  rustCall((status) => uniffi_bark_ffi_fn_free_notificationholder(ptr, status));
});

class NotificationHolder implements NotificationHolderInterface {
  late final Pointer<Void> _ptr;
  NotificationHolder._(this._ptr) {
    _NotificationHolderFinalizer.attach(this, _ptr, detach: this);
  }
  factory NotificationHolder.lift(Pointer<Void> ptr) {
    return NotificationHolder._(ptr);
  }
  static Pointer<Void> lower(NotificationHolder value) {
    return value.uniffiClonePointer();
  }

  Pointer<Void> uniffiClonePointer() {
    return rustCall(
      (status) => uniffi_bark_ffi_fn_clone_notificationholder(_ptr, status),
    );
  }

  static int allocationSize(NotificationHolder value) {
    return 8;
  }

  static LiftRetVal<NotificationHolder> read(Uint8List buf) {
    final handle = buf.buffer.asByteData(buf.offsetInBytes).getInt64(0);
    final pointer = Pointer<Void>.fromAddress(handle);
    return LiftRetVal(NotificationHolder.lift(pointer), 8);
  }

  static int write(NotificationHolder value, Uint8List buf) {
    final handle = lower(value);
    buf.buffer.asByteData(buf.offsetInBytes).setInt64(0, handle.address);
    return 8;
  }

  void dispose() {
    _NotificationHolderFinalizer.detach(this);
    rustCall(
      (status) => uniffi_bark_ffi_fn_free_notificationholder(_ptr, status),
    );
  }

  void cancelNextNotificationWait() {
    return rustCall((status) {
      uniffi_bark_ffi_fn_method_notificationholder_cancel_next_notification_wait(
        uniffiClonePointer(),
        status,
      );
    }, null);
  }

  Future<WalletNotification?> nextNotification() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_notificationholder_next_notification(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterOptionalWalletNotification.lift,
      errorExceptionErrorHandler,
    );
  }
}

abstract class CustomOnchainWalletCallbacks {
  int getBalance();
  String prepareTx(List<Destination> destinations, int feeRateSatPerVb);
  String prepareDrainTx(String address, int feeRateSatPerVb);
  String finishPsbt(String psbtBase64);
  bool isMine(String scriptPubkeyHex);
  void registerTx(String txHex);
  void evictTx(String txid);
  String makeSignedP2aCpfp(CpfpParams params);
  void storeSignedP2aCpfp(String txHex);
  void sync_();
}

class FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks {
  static final _handleMap = UniffiHandleMap<CustomOnchainWalletCallbacks>();
  static bool _vtableInitialized = false;
  static CustomOnchainWalletCallbacks lift(Pointer<Void> handle) {
    return _handleMap.get(handle.address);
  }

  static Pointer<Void> lower(CustomOnchainWalletCallbacks value) {
    _ensureVTableInitialized();
    final handle = _handleMap.insert(value);
    return Pointer<Void>.fromAddress(handle);
  }

  static void _ensureVTableInitialized() {
    if (!_vtableInitialized) {
      initCustomOnchainWalletCallbacksVTable();
      _vtableInitialized = true;
    }
  }

  static LiftRetVal<CustomOnchainWalletCallbacks> read(Uint8List buf) {
    final handle = buf.buffer.asByteData(buf.offsetInBytes).getInt64(0);
    final pointer = Pointer<Void>.fromAddress(handle);
    return LiftRetVal(lift(pointer), 8);
  }

  static int write(CustomOnchainWalletCallbacks value, Uint8List buf) {
    final handle = lower(value);
    buf.buffer.asByteData(buf.offsetInBytes).setInt64(0, handle.address);
    return 8;
  }

  static int allocationSize(CustomOnchainWalletCallbacks value) {
    return 8;
  }
}

typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod0 =
    Void Function(Uint64, Pointer<Uint64>, Pointer<RustCallStatus>);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod0Dart =
    void Function(int, Pointer<Uint64>, Pointer<RustCallStatus>);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod1 =
    Void Function(
      Uint64,
      RustBuffer,
      Uint64,
      Pointer<RustBuffer>,
      Pointer<RustCallStatus>,
    );
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod1Dart =
    void Function(
      int,
      RustBuffer,
      int,
      Pointer<RustBuffer>,
      Pointer<RustCallStatus>,
    );
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod2 =
    Void Function(
      Uint64,
      RustBuffer,
      Uint64,
      Pointer<RustBuffer>,
      Pointer<RustCallStatus>,
    );
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod2Dart =
    void Function(
      int,
      RustBuffer,
      int,
      Pointer<RustBuffer>,
      Pointer<RustCallStatus>,
    );
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod3 =
    Void Function(
      Uint64,
      RustBuffer,
      Pointer<RustBuffer>,
      Pointer<RustCallStatus>,
    );
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod3Dart =
    void Function(
      int,
      RustBuffer,
      Pointer<RustBuffer>,
      Pointer<RustCallStatus>,
    );
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod4 =
    Void Function(Uint64, RustBuffer, Pointer<Int8>, Pointer<RustCallStatus>);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod4Dart =
    void Function(int, RustBuffer, Pointer<Int8>, Pointer<RustCallStatus>);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod5 =
    Void Function(Uint64, RustBuffer, Pointer<Void>, Pointer<RustCallStatus>);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod5Dart =
    void Function(int, RustBuffer, Pointer<Void>, Pointer<RustCallStatus>);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod6 =
    Void Function(Uint64, RustBuffer, Pointer<Void>, Pointer<RustCallStatus>);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod6Dart =
    void Function(int, RustBuffer, Pointer<Void>, Pointer<RustCallStatus>);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod7 =
    Void Function(
      Uint64,
      RustBuffer,
      Pointer<RustBuffer>,
      Pointer<RustCallStatus>,
    );
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod7Dart =
    void Function(
      int,
      RustBuffer,
      Pointer<RustBuffer>,
      Pointer<RustCallStatus>,
    );
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod8 =
    Void Function(Uint64, RustBuffer, Pointer<Void>, Pointer<RustCallStatus>);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod8Dart =
    void Function(int, RustBuffer, Pointer<Void>, Pointer<RustCallStatus>);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod9 =
    Void Function(Uint64, Pointer<Void>, Pointer<RustCallStatus>);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod9Dart =
    void Function(int, Pointer<Void>, Pointer<RustCallStatus>);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksFree =
    Void Function(Uint64);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksFreeDart =
    void Function(int);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksClone =
    Uint64 Function(Uint64);
typedef UniffiCallbackInterfaceCustomOnchainWalletCallbacksCloneDart =
    int Function(int);

final class UniffiVTableCallbackInterfaceCustomOnchainWalletCallbacks
    extends Struct {
  external Pointer<
    NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksFree>
  >
  uniffiFree;
  external Pointer<
    NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksClone>
  >
  uniffiClone;
  external Pointer<
    NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod0>
  >
  getBalance;
  external Pointer<
    NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod1>
  >
  prepareTx;
  external Pointer<
    NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod2>
  >
  prepareDrainTx;
  external Pointer<
    NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod3>
  >
  finishPsbt;
  external Pointer<
    NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod4>
  >
  isMine;
  external Pointer<
    NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod5>
  >
  registerTx;
  external Pointer<
    NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod6>
  >
  evictTx;
  external Pointer<
    NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod7>
  >
  makeSignedP2aCpfp;
  external Pointer<
    NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod8>
  >
  storeSignedP2aCpfp;
  external Pointer<
    NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod9>
  >
  sync_;
}

void customOnchainWalletCallbacksGetBalance(
  int uniffiHandle,
  Pointer<Uint64> outReturn,
  Pointer<RustCallStatus> callStatus,
) {
  final status = callStatus.ref;
  try {
    final obj = FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks
        ._handleMap
        .get(uniffiHandle);
    final result = obj.getBalance();
    outReturn.value = FfiConverterUInt64.lower(result);
  } catch (e) {
    status.code = CALL_UNEXPECTED_ERROR;
    status.errorBuf = FfiConverterString.lower(e.toString());
  }
}

final Pointer<
  NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod0>
>
customOnchainWalletCallbacksGetBalancePointer =
    Pointer.fromFunction<
      UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod0
    >(customOnchainWalletCallbacksGetBalance);
void customOnchainWalletCallbacksPrepareTx(
  int uniffiHandle,
  RustBuffer destinations,
  int feeRateSatPerVb,
  Pointer<RustBuffer> outReturn,
  Pointer<RustCallStatus> callStatus,
) {
  final status = callStatus.ref;
  try {
    final obj = FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks
        ._handleMap
        .get(uniffiHandle);
    final arg0 = FfiConverterSequenceDestination.lift(destinations);
    final arg1 = FfiConverterUInt64.lift(feeRateSatPerVb);
    final result = obj.prepareTx(arg0, arg1);
    outReturn.ref = FfiConverterString.lower(result);
    status.code = CALL_SUCCESS;
  } catch (e) {
    status.code = CALL_UNEXPECTED_ERROR;
    status.errorBuf = FfiConverterString.lower(e.toString());
  }
}

final Pointer<
  NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod1>
>
customOnchainWalletCallbacksPrepareTxPointer =
    Pointer.fromFunction<
      UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod1
    >(customOnchainWalletCallbacksPrepareTx);
void customOnchainWalletCallbacksPrepareDrainTx(
  int uniffiHandle,
  RustBuffer address,
  int feeRateSatPerVb,
  Pointer<RustBuffer> outReturn,
  Pointer<RustCallStatus> callStatus,
) {
  final status = callStatus.ref;
  try {
    final obj = FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks
        ._handleMap
        .get(uniffiHandle);
    final arg0 = FfiConverterString.lift(address);
    final arg1 = FfiConverterUInt64.lift(feeRateSatPerVb);
    final result = obj.prepareDrainTx(arg0, arg1);
    outReturn.ref = FfiConverterString.lower(result);
    status.code = CALL_SUCCESS;
  } catch (e) {
    status.code = CALL_UNEXPECTED_ERROR;
    status.errorBuf = FfiConverterString.lower(e.toString());
  }
}

final Pointer<
  NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod2>
>
customOnchainWalletCallbacksPrepareDrainTxPointer =
    Pointer.fromFunction<
      UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod2
    >(customOnchainWalletCallbacksPrepareDrainTx);
void customOnchainWalletCallbacksFinishPsbt(
  int uniffiHandle,
  RustBuffer psbtBase64,
  Pointer<RustBuffer> outReturn,
  Pointer<RustCallStatus> callStatus,
) {
  final status = callStatus.ref;
  try {
    final obj = FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks
        ._handleMap
        .get(uniffiHandle);
    final arg0 = FfiConverterString.lift(psbtBase64);
    final result = obj.finishPsbt(arg0);
    outReturn.ref = FfiConverterString.lower(result);
    status.code = CALL_SUCCESS;
  } catch (e) {
    status.code = CALL_UNEXPECTED_ERROR;
    status.errorBuf = FfiConverterString.lower(e.toString());
  }
}

final Pointer<
  NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod3>
>
customOnchainWalletCallbacksFinishPsbtPointer =
    Pointer.fromFunction<
      UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod3
    >(customOnchainWalletCallbacksFinishPsbt);
void customOnchainWalletCallbacksIsMine(
  int uniffiHandle,
  RustBuffer scriptPubkeyHex,
  Pointer<Int8> outReturn,
  Pointer<RustCallStatus> callStatus,
) {
  final status = callStatus.ref;
  try {
    final obj = FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks
        ._handleMap
        .get(uniffiHandle);
    final arg0 = FfiConverterString.lift(scriptPubkeyHex);
    final result = obj.isMine(arg0);
    outReturn.value = result ? 1 : 0;
  } catch (e) {
    status.code = CALL_UNEXPECTED_ERROR;
    status.errorBuf = FfiConverterString.lower(e.toString());
  }
}

final Pointer<
  NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod4>
>
customOnchainWalletCallbacksIsMinePointer =
    Pointer.fromFunction<
      UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod4
    >(customOnchainWalletCallbacksIsMine);
void customOnchainWalletCallbacksRegisterTx(
  int uniffiHandle,
  RustBuffer txHex,
  Pointer<Void> outReturn,
  Pointer<RustCallStatus> callStatus,
) {
  final status = callStatus.ref;
  try {
    final obj = FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks
        ._handleMap
        .get(uniffiHandle);
    final arg0 = FfiConverterString.lift(txHex);
    obj.registerTx(arg0);
    status.code = CALL_SUCCESS;
  } catch (e) {
    status.code = CALL_UNEXPECTED_ERROR;
    status.errorBuf = FfiConverterString.lower(e.toString());
  }
}

final Pointer<
  NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod5>
>
customOnchainWalletCallbacksRegisterTxPointer =
    Pointer.fromFunction<
      UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod5
    >(customOnchainWalletCallbacksRegisterTx);
void customOnchainWalletCallbacksEvictTx(
  int uniffiHandle,
  RustBuffer txid,
  Pointer<Void> outReturn,
  Pointer<RustCallStatus> callStatus,
) {
  final status = callStatus.ref;
  try {
    final obj = FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks
        ._handleMap
        .get(uniffiHandle);
    final arg0 = FfiConverterString.lift(txid);
    obj.evictTx(arg0);
    status.code = CALL_SUCCESS;
  } catch (e) {
    status.code = CALL_UNEXPECTED_ERROR;
    status.errorBuf = FfiConverterString.lower(e.toString());
  }
}

final Pointer<
  NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod6>
>
customOnchainWalletCallbacksEvictTxPointer =
    Pointer.fromFunction<
      UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod6
    >(customOnchainWalletCallbacksEvictTx);
void customOnchainWalletCallbacksMakeSignedP2aCpfp(
  int uniffiHandle,
  RustBuffer params,
  Pointer<RustBuffer> outReturn,
  Pointer<RustCallStatus> callStatus,
) {
  final status = callStatus.ref;
  try {
    final obj = FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks
        ._handleMap
        .get(uniffiHandle);
    final arg0 = FfiConverterCpfpParams.lift(params);
    final result = obj.makeSignedP2aCpfp(arg0);
    outReturn.ref = FfiConverterString.lower(result);
    status.code = CALL_SUCCESS;
  } catch (e) {
    status.code = CALL_UNEXPECTED_ERROR;
    status.errorBuf = FfiConverterString.lower(e.toString());
  }
}

final Pointer<
  NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod7>
>
customOnchainWalletCallbacksMakeSignedP2aCpfpPointer =
    Pointer.fromFunction<
      UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod7
    >(customOnchainWalletCallbacksMakeSignedP2aCpfp);
void customOnchainWalletCallbacksStoreSignedP2aCpfp(
  int uniffiHandle,
  RustBuffer txHex,
  Pointer<Void> outReturn,
  Pointer<RustCallStatus> callStatus,
) {
  final status = callStatus.ref;
  try {
    final obj = FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks
        ._handleMap
        .get(uniffiHandle);
    final arg0 = FfiConverterString.lift(txHex);
    obj.storeSignedP2aCpfp(arg0);
    status.code = CALL_SUCCESS;
  } catch (e) {
    status.code = CALL_UNEXPECTED_ERROR;
    status.errorBuf = FfiConverterString.lower(e.toString());
  }
}

final Pointer<
  NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod8>
>
customOnchainWalletCallbacksStoreSignedP2aCpfpPointer =
    Pointer.fromFunction<
      UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod8
    >(customOnchainWalletCallbacksStoreSignedP2aCpfp);
void customOnchainWalletCallbacksSync(
  int uniffiHandle,
  Pointer<Void> outReturn,
  Pointer<RustCallStatus> callStatus,
) {
  final status = callStatus.ref;
  try {
    final obj = FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks
        ._handleMap
        .get(uniffiHandle);
    obj.sync_();
    status.code = CALL_SUCCESS;
  } catch (e) {
    status.code = CALL_UNEXPECTED_ERROR;
    status.errorBuf = FfiConverterString.lower(e.toString());
  }
}

final Pointer<
  NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod9>
>
customOnchainWalletCallbacksSyncPointer =
    Pointer.fromFunction<
      UniffiCallbackInterfaceCustomOnchainWalletCallbacksMethod9
    >(customOnchainWalletCallbacksSync);
void customOnchainWalletCallbacksFreeCallback(int handle) {
  try {
    FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks._handleMap.remove(
      handle,
    );
  } catch (e) {}
}

final Pointer<
  NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksFree>
>
customOnchainWalletCallbacksFreePointer =
    Pointer.fromFunction<
      UniffiCallbackInterfaceCustomOnchainWalletCallbacksFree
    >(customOnchainWalletCallbacksFreeCallback);
int customOnchainWalletCallbacksCloneCallback(int handle) {
  try {
    final obj = FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks
        ._handleMap
        .get(handle);
    final newHandle = FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks
        ._handleMap
        .insert(obj);
    return newHandle;
  } catch (e) {
    return 0;
  }
}

final Pointer<
  NativeFunction<UniffiCallbackInterfaceCustomOnchainWalletCallbacksClone>
>
customOnchainWalletCallbacksClonePointer =
    Pointer.fromFunction<
      UniffiCallbackInterfaceCustomOnchainWalletCallbacksClone
    >(customOnchainWalletCallbacksCloneCallback, 0);
late final Pointer<UniffiVTableCallbackInterfaceCustomOnchainWalletCallbacks>
customOnchainWalletCallbacksVTable;
void initCustomOnchainWalletCallbacksVTable() {
  if (FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks
      ._vtableInitialized) {
    return;
  }
  customOnchainWalletCallbacksVTable =
      calloc<UniffiVTableCallbackInterfaceCustomOnchainWalletCallbacks>();
  customOnchainWalletCallbacksVTable.ref.uniffiFree =
      customOnchainWalletCallbacksFreePointer;
  customOnchainWalletCallbacksVTable.ref.uniffiClone =
      customOnchainWalletCallbacksClonePointer;
  customOnchainWalletCallbacksVTable.ref.getBalance =
      customOnchainWalletCallbacksGetBalancePointer;
  customOnchainWalletCallbacksVTable.ref.prepareTx =
      customOnchainWalletCallbacksPrepareTxPointer;
  customOnchainWalletCallbacksVTable.ref.prepareDrainTx =
      customOnchainWalletCallbacksPrepareDrainTxPointer;
  customOnchainWalletCallbacksVTable.ref.finishPsbt =
      customOnchainWalletCallbacksFinishPsbtPointer;
  customOnchainWalletCallbacksVTable.ref.isMine =
      customOnchainWalletCallbacksIsMinePointer;
  customOnchainWalletCallbacksVTable.ref.registerTx =
      customOnchainWalletCallbacksRegisterTxPointer;
  customOnchainWalletCallbacksVTable.ref.evictTx =
      customOnchainWalletCallbacksEvictTxPointer;
  customOnchainWalletCallbacksVTable.ref.makeSignedP2aCpfp =
      customOnchainWalletCallbacksMakeSignedP2aCpfpPointer;
  customOnchainWalletCallbacksVTable.ref.storeSignedP2aCpfp =
      customOnchainWalletCallbacksStoreSignedP2aCpfpPointer;
  customOnchainWalletCallbacksVTable.ref.sync_ =
      customOnchainWalletCallbacksSyncPointer;
  rustCall((status) {
    uniffi_bark_ffi_fn_init_callback_vtable_customonchainwalletcallbacks(
      customOnchainWalletCallbacksVTable,
    );
    checkCallStatus(NullRustCallStatusErrorHandler(), status);
  });
  FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks._vtableInitialized =
      true;
}

abstract class BarkLogger {
  void log(LogLevel level, String target, String message);
}

class FfiConverterCallbackInterfaceBarkLogger {
  static final _handleMap = UniffiHandleMap<BarkLogger>();
  static bool _vtableInitialized = false;
  static BarkLogger lift(Pointer<Void> handle) {
    return _handleMap.get(handle.address);
  }

  static Pointer<Void> lower(BarkLogger value) {
    _ensureVTableInitialized();
    final handle = _handleMap.insert(value);
    return Pointer<Void>.fromAddress(handle);
  }

  static void _ensureVTableInitialized() {
    if (!_vtableInitialized) {
      initBarkLoggerVTable();
      _vtableInitialized = true;
    }
  }

  static LiftRetVal<BarkLogger> read(Uint8List buf) {
    final handle = buf.buffer.asByteData(buf.offsetInBytes).getInt64(0);
    final pointer = Pointer<Void>.fromAddress(handle);
    return LiftRetVal(lift(pointer), 8);
  }

  static int write(BarkLogger value, Uint8List buf) {
    final handle = lower(value);
    buf.buffer.asByteData(buf.offsetInBytes).setInt64(0, handle.address);
    return 8;
  }

  static int allocationSize(BarkLogger value) {
    return 8;
  }
}

typedef UniffiCallbackInterfaceBarkLoggerMethod0 =
    Void Function(
      Uint64,
      Int32,
      RustBuffer,
      RustBuffer,
      Pointer<Void>,
      Pointer<RustCallStatus>,
    );
typedef UniffiCallbackInterfaceBarkLoggerMethod0Dart =
    void Function(
      int,
      int,
      RustBuffer,
      RustBuffer,
      Pointer<Void>,
      Pointer<RustCallStatus>,
    );
typedef UniffiCallbackInterfaceBarkLoggerFree = Void Function(Uint64);
typedef UniffiCallbackInterfaceBarkLoggerFreeDart = void Function(int);
typedef UniffiCallbackInterfaceBarkLoggerClone = Uint64 Function(Uint64);
typedef UniffiCallbackInterfaceBarkLoggerCloneDart = int Function(int);

final class UniffiVTableCallbackInterfaceBarkLogger extends Struct {
  external Pointer<NativeFunction<UniffiCallbackInterfaceBarkLoggerFree>>
  uniffiFree;
  external Pointer<NativeFunction<UniffiCallbackInterfaceBarkLoggerClone>>
  uniffiClone;
  external Pointer<NativeFunction<UniffiCallbackInterfaceBarkLoggerMethod0>>
  log;
}

void barkLoggerLog(
  int uniffiHandle,
  int level,
  RustBuffer target,
  RustBuffer message,
  Pointer<Void> outReturn,
  Pointer<RustCallStatus> callStatus,
) {
  final status = callStatus.ref;
  try {
    final obj = FfiConverterCallbackInterfaceBarkLogger._handleMap.get(
      uniffiHandle,
    );
    final arg0 = FfiConverterLogLevel.read(createUint8ListFromInt(level)).value;
    final arg1 = FfiConverterString.lift(target);
    final arg2 = FfiConverterString.lift(message);
    obj.log(arg0, arg1, arg2);
    status.code = CALL_SUCCESS;
  } catch (e) {
    status.code = CALL_UNEXPECTED_ERROR;
    status.errorBuf = FfiConverterString.lower(e.toString());
  }
}

final Pointer<NativeFunction<UniffiCallbackInterfaceBarkLoggerMethod0>>
barkLoggerLogPointer =
    Pointer.fromFunction<UniffiCallbackInterfaceBarkLoggerMethod0>(
      barkLoggerLog,
    );
void barkLoggerFreeCallback(int handle) {
  try {
    FfiConverterCallbackInterfaceBarkLogger._handleMap.remove(handle);
  } catch (e) {}
}

final Pointer<NativeFunction<UniffiCallbackInterfaceBarkLoggerFree>>
barkLoggerFreePointer =
    Pointer.fromFunction<UniffiCallbackInterfaceBarkLoggerFree>(
      barkLoggerFreeCallback,
    );
int barkLoggerCloneCallback(int handle) {
  try {
    final obj = FfiConverterCallbackInterfaceBarkLogger._handleMap.get(handle);
    final newHandle = FfiConverterCallbackInterfaceBarkLogger._handleMap.insert(
      obj,
    );
    return newHandle;
  } catch (e) {
    return 0;
  }
}

final Pointer<NativeFunction<UniffiCallbackInterfaceBarkLoggerClone>>
barkLoggerClonePointer =
    Pointer.fromFunction<UniffiCallbackInterfaceBarkLoggerClone>(
      barkLoggerCloneCallback,
      0,
    );
late final Pointer<UniffiVTableCallbackInterfaceBarkLogger> barkLoggerVTable;
void initBarkLoggerVTable() {
  if (FfiConverterCallbackInterfaceBarkLogger._vtableInitialized) {
    return;
  }
  barkLoggerVTable = calloc<UniffiVTableCallbackInterfaceBarkLogger>();
  barkLoggerVTable.ref.uniffiFree = barkLoggerFreePointer;
  barkLoggerVTable.ref.uniffiClone = barkLoggerClonePointer;
  barkLoggerVTable.ref.log = barkLoggerLogPointer;
  rustCall((status) {
    uniffi_bark_ffi_fn_init_callback_vtable_barklogger(barkLoggerVTable);
    checkCallStatus(NullRustCallStatusErrorHandler(), status);
  });
  FfiConverterCallbackInterfaceBarkLogger._vtableInitialized = true;
}

abstract class OnchainWalletInterface {
  Future<OnchainBalance> balance();
  Future<void> evictTx({required String txid});
  Future<FeeRates> feeRates();
  Future<int> initialScan({required int? birthdayHeight});
  Future<String> newAddress();
  Future<String> send({
    required String address,
    required int amountSats,
    required int feeRateSatPerVb,
  });
  Future<int> sync_();
  Future<int> tipHeight();
  Future<List<WalletTransaction>> transactions();
  Future<List<OnchainUtxo>> utxos();
}

final _OnchainWalletFinalizer = Finalizer<Pointer<Void>>((ptr) {
  rustCall((status) => uniffi_bark_ffi_fn_free_onchainwallet(ptr, status));
});

class OnchainWallet implements OnchainWalletInterface {
  late final Pointer<Void> _ptr;
  OnchainWallet._(this._ptr) {
    _OnchainWalletFinalizer.attach(this, _ptr, detach: this);
  }
  OnchainWallet.custom({required CustomOnchainWalletCallbacks callbacks})
    : _ptr = rustCall(
        (status) => uniffi_bark_ffi_fn_constructor_onchainwallet_custom(
          FfiConverterCallbackInterfaceCustomOnchainWalletCallbacks.lower(
            callbacks,
          ),
          status,
        ),
        errorExceptionErrorHandler,
      ) {
    _OnchainWalletFinalizer.attach(this, _ptr, detach: this);
  }
  static Future<OnchainWallet> default_({
    required Network network,
    required String mnemonic,
    required Config config,
    required String datadir,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_constructor_onchainwallet_default(
        FfiConverterNetwork.lower(network),
        FfiConverterString.lower(mnemonic),
        FfiConverterConfig.lower(config),
        FfiConverterString.lower(datadir),
      ),
      ffi_bark_ffi_rust_future_poll_u64,
      ffi_bark_ffi_rust_future_complete_u64,
      ffi_bark_ffi_rust_future_free_u64,
      (int handle) => OnchainWallet._(Pointer<Void>.fromAddress(handle)),
      errorExceptionErrorHandler,
    );
  }

  factory OnchainWallet.lift(Pointer<Void> ptr) {
    return OnchainWallet._(ptr);
  }
  static Pointer<Void> lower(OnchainWallet value) {
    return value.uniffiClonePointer();
  }

  Pointer<Void> uniffiClonePointer() {
    return rustCall(
      (status) => uniffi_bark_ffi_fn_clone_onchainwallet(_ptr, status),
    );
  }

  static int allocationSize(OnchainWallet value) {
    return 8;
  }

  static LiftRetVal<OnchainWallet> read(Uint8List buf) {
    final handle = buf.buffer.asByteData(buf.offsetInBytes).getInt64(0);
    final pointer = Pointer<Void>.fromAddress(handle);
    return LiftRetVal(OnchainWallet.lift(pointer), 8);
  }

  static int write(OnchainWallet value, Uint8List buf) {
    final handle = lower(value);
    buf.buffer.asByteData(buf.offsetInBytes).setInt64(0, handle.address);
    return 8;
  }

  void dispose() {
    _OnchainWalletFinalizer.detach(this);
    rustCall((status) => uniffi_bark_ffi_fn_free_onchainwallet(_ptr, status));
  }

  Future<OnchainBalance> balance() {
    return uniffiRustCallAsync(
      () =>
          uniffi_bark_ffi_fn_method_onchainwallet_balance(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterOnchainBalance.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<void> evictTx({required String txid}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_onchainwallet_evict_tx(
        uniffiClonePointer(),
        FfiConverterString.lower(txid),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<FeeRates> feeRates() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_onchainwallet_fee_rates(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterFeeRates.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<int> initialScan({required int? birthdayHeight}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_onchainwallet_initial_scan(
        uniffiClonePointer(),
        FfiConverterOptionalUInt32.lower(birthdayHeight),
      ),
      ffi_bark_ffi_rust_future_poll_u64,
      ffi_bark_ffi_rust_future_complete_u64,
      ffi_bark_ffi_rust_future_free_u64,
      FfiConverterUInt64.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<String> newAddress() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_onchainwallet_new_address(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterString.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<String> send({
    required String address,
    required int amountSats,
    required int feeRateSatPerVb,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_onchainwallet_send(
        uniffiClonePointer(),
        FfiConverterString.lower(address),
        FfiConverterUInt64.lower(amountSats),
        FfiConverterUInt64.lower(feeRateSatPerVb),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterString.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<int> sync_() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_onchainwallet_sync(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_u64,
      ffi_bark_ffi_rust_future_complete_u64,
      ffi_bark_ffi_rust_future_free_u64,
      FfiConverterUInt64.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<int> tipHeight() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_onchainwallet_tip_height(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_u32,
      ffi_bark_ffi_rust_future_complete_u32,
      ffi_bark_ffi_rust_future_free_u32,
      FfiConverterUInt32.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<WalletTransaction>> transactions() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_onchainwallet_transactions(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceWalletTransaction.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<OnchainUtxo>> utxos() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_onchainwallet_utxos(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceOnchainUtxo.lift,
      errorExceptionErrorHandler,
    );
  }
}

abstract class WalletInterface {
  Future<int?> allExitsClaimableAtHeight();
  Future<List<Vtxo>> allVtxos();
  Future<void> allowLightningSendToExit({required String paymentHash});
  Future<ArkInfo?> arkInfo();
  Future<void> attemptLightningReceiveExit({required String paymentHash});
  Future<Balance> balance();
  Future<PendingBoard> boardAll();
  Future<PendingBoard> boardAmount({required int amountSats});
  Future<BoardFundingInfo> boardFundingAddress();
  Future<PendingBoard> boardPsbt({
    required String psbtBase64,
    required int keypairIndex,
    required int expiryHeight,
  });
  Future<LightningInvoice> bolt11Invoice({
    required int amountSats,
    required String? description,
    required String? token,
  });
  Future<LightningInvoice> bolt11InvoiceForAddress({
    required int amountSats,
    required String claimDestination,
    required String? description,
    required String? token,
  });
  Future<String> broadcastTx({required String txHex});
  Future<void> cancelAllPendingRounds();
  Future<ExitCancelResult> cancelExit({required String vtxoId});
  Future<void> cancelLightningReceive({required String paymentHash});
  Future<void> cancelPendingRound({required int roundId});
  Future<LightningSendStatus> checkLightningPayment({
    required String paymentHash,
    required bool wait,
  });
  Future<int> claimableLightningReceiveBalanceSats();
  Future<Config> config();
  Future<ExitClaimTransaction> drainExits({
    required List<String> vtxoIds,
    required bool drainAll,
    required String address,
    required int? feeRateSatPerVb,
  });
  Future<FeeEstimate> estimateArkoorPaymentFee({required int amountSats});
  Future<FeeEstimate> estimateBoardFee({required int amountSats});
  Future<EmergencyExitFeeEstimate> estimateEmergencyExitFee({
    required List<String> vtxoIds,
    required int? feeRateSatPerVb,
    required String? destination,
  });
  Future<FeeEstimate> estimateLightningReceiveFee({required int amountSats});
  Future<FeeEstimate> estimateLightningSendFee({required int amountSats});
  Future<FeeEstimate> estimateOffboardAllFee({required String address});
  Future<FeeEstimate> estimateOffboardFee({
    required String address,
    required List<String> vtxoIds,
  });
  Future<FeeEstimate> estimateRefreshFee({required List<String> vtxoIds});
  Future<FeeEstimate> estimateSendOnchainFee({
    required String address,
    required int amountSats,
  });
  String fingerprint();
  Future<ExitTransactionStatus?> getExitStatus({
    required String vtxoId,
    required bool includeHistory,
    required bool includeTransactions,
  });
  Future<List<ExitVtxo>> getExitVtxos();
  Future<List<Vtxo>> getExpiringVtxos({required int thresholdBlocks});
  Future<int?> getFirstExpiringVtxoBlockheight();
  Future<int?> getNextRequiredRefreshBlockheight();
  Future<Vtxo> getVtxoById({required String vtxoId});
  Future<List<Vtxo>> getVtxosToRefresh();
  Future<bool> hasPendingExits();
  Future<List<Movement>> history();
  Future<List<Movement>> historyByPaymentMethod({
    required String paymentMethodType,
    required String paymentMethodValue,
  });
  Future<void> importVtxo({
    required String vtxoBase64,
    required ImportVtxoArgs? args,
  });
  Future<List<String>> importVtxos({
    required List<String> encodedVtxos,
    required ImportVtxoArgs? args,
  });
  Future<bool> isInvoicePaid({required String paymentHash});
  Future<LightningReceive> lightningReceiveState({required String paymentHash});
  Future<LightningSendStatus> lightningSendState({required String paymentHash});
  Future<List<ExitVtxo>> listClaimableExits();
  Future<void> lockVtxos({
    required List<String> vtxoIds,
    required VtxoLockHolder? holder,
  });
  String mailboxAuthorization({required int expirySecs});
  String mailboxIdentifier();
  Future<void> maintenance();
  Future<void> maintenanceDelegated();
  Future<String?> maintenanceRefresh();
  Future<Network> network();
  Future<String> newAddress();
  Future<AddressWithIndex> newAddressWithIndex();
  Future<int> nextRoundStartTime();
  NotificationHolder notifications();
  Future<OffboardResult> offboardAll({required String bitcoinAddress});
  Future<OffboardResult> offboardVtxos({
    required List<String> vtxoIds,
    required String bitcoinAddress,
  });
  Future<LightningSendStatus> payLightningAddress({
    required String lightningAddress,
    required int amountSats,
    required String? comment,
    required bool wait,
  });
  Future<LightningSendStatus> payLightningInvoice({
    required String invoice,
    required int? amountSats,
    required bool wait,
  });
  Future<LightningSendStatus> payLightningOffer({
    required String offer,
    required int? amountSats,
    required bool wait,
  });
  Future<LightningSendStatus> payLnurl({
    required String lnurl,
    required int amountSats,
    required String? comment,
    required bool wait,
  });
  Future<String> peekAddress({required int index});
  Future<List<Vtxo>> pendingBoardVtxos();
  Future<List<PendingBoard>> pendingBoards();
  Future<int> pendingExitsTotalSats();
  Future<List<LightningReceive>> pendingLightningReceives();
  Future<List<Vtxo>> pendingLightningSendVtxos();
  Future<List<LightningSend>> pendingLightningSends();
  Future<List<Vtxo>> pendingRoundInputVtxos();
  Future<List<RoundState>> pendingRoundStates();
  Future<List<ExitProgressStatus>> progressExits({
    required int? feeRateSatPerVb,
  });
  Future<void> progressPendingRounds();
  Future<WalletProperties> properties();
  Future<RecoveryReport> recoverVtxos({
    required List<String> vtxoIds,
    required int? gapLimit,
  });
  RecoveryReport? recoveryReport();
  RecoveryStatus recoveryStatus();
  Future<void> refreshServer();
  Future<String?> refreshVtxos({required List<String> vtxoIds});
  Future<RoundState?> refreshVtxosDelegated({required List<String> vtxoIds});
  Future<RoundState?> refreshVtxosScheduled({
    required List<String> vtxoIds,
    required int scheduledHeight,
  });
  Future<void> runDaemon();
  Future<void> sendArkoorPayment({
    required String arkAddress,
    required int amountSats,
  });
  Future<String> sendOnchain({
    required String address,
    required int amountSats,
  });
  Future<String> signExitClaimInputs({required String psbtBase64});
  Future<List<Vtxo>> spendableVtxos();
  Future<void> startExitForEntireWallet();
  Future<void> startExitForVtxos({required List<String> vtxoIds});
  Future<void> startExitForVtxosIncludingNonStandard({
    required List<String> vtxoIds,
  });
  Future<void> stopDaemon();
  Future<void> stopDaemonWait();
  Future<List<LightningSend>> stuckFailedLightningSends();
  Future<void> sync_();
  Future<void> syncExits();
  Future<void> syncForceExitedVtxos();
  Future<void> syncPendingBoards();
  Future<List<LightningReceive>> tryClaimAllLightningReceives({
    required bool wait,
  });
  Future<LightningReceive> tryClaimLightningReceive({
    required String paymentHash,
    required bool wait,
  });
  Future<void> unlockVtxos({
    required List<String> vtxoIds,
    required VtxoLockHolder? expectedHolder,
  });
  Future<bool> validateArkoorAddress({required String address});
  Future<String> vtxoEncoded({required String vtxoId});
  Future<List<Vtxo>> vtxos();
}

final _WalletFinalizer = Finalizer<Pointer<Void>>((ptr) {
  rustCall((status) => uniffi_bark_ffi_fn_free_wallet(ptr, status));
});

class Wallet implements WalletInterface {
  late final Pointer<Void> _ptr;
  Wallet._(this._ptr) {
    _WalletFinalizer.attach(this, _ptr, detach: this);
  }
  static Future<Wallet> open({
    required Network network,
    required String mnemonicOrSeed,
    required Config config,
    required WalletOpenArgs args,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_constructor_wallet_open(
        FfiConverterNetwork.lower(network),
        FfiConverterString.lower(mnemonicOrSeed),
        FfiConverterConfig.lower(config),
        FfiConverterWalletOpenArgs.lower(args),
      ),
      ffi_bark_ffi_rust_future_poll_u64,
      ffi_bark_ffi_rust_future_complete_u64,
      ffi_bark_ffi_rust_future_free_u64,
      (int handle) => Wallet._(Pointer<Void>.fromAddress(handle)),
      errorExceptionErrorHandler,
    );
  }

  factory Wallet.lift(Pointer<Void> ptr) {
    return Wallet._(ptr);
  }
  static Pointer<Void> lower(Wallet value) {
    return value.uniffiClonePointer();
  }

  Pointer<Void> uniffiClonePointer() {
    return rustCall((status) => uniffi_bark_ffi_fn_clone_wallet(_ptr, status));
  }

  static int allocationSize(Wallet value) {
    return 8;
  }

  static LiftRetVal<Wallet> read(Uint8List buf) {
    final handle = buf.buffer.asByteData(buf.offsetInBytes).getInt64(0);
    final pointer = Pointer<Void>.fromAddress(handle);
    return LiftRetVal(Wallet.lift(pointer), 8);
  }

  static int write(Wallet value, Uint8List buf) {
    final handle = lower(value);
    buf.buffer.asByteData(buf.offsetInBytes).setInt64(0, handle.address);
    return 8;
  }

  void dispose() {
    _WalletFinalizer.detach(this);
    rustCall((status) => uniffi_bark_ffi_fn_free_wallet(_ptr, status));
  }

  Future<int?> allExitsClaimableAtHeight() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_all_exits_claimable_at_height(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterOptionalUInt32.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<Vtxo>> allVtxos() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_all_vtxos(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceVtxo.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<void> allowLightningSendToExit({required String paymentHash}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_allow_lightning_send_to_exit(
        uniffiClonePointer(),
        FfiConverterString.lower(paymentHash),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<ArkInfo?> arkInfo() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_ark_info(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterOptionalArkInfo.lift,
      null,
    );
  }

  Future<void> attemptLightningReceiveExit({required String paymentHash}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_attempt_lightning_receive_exit(
        uniffiClonePointer(),
        FfiConverterString.lower(paymentHash),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<Balance> balance() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_balance(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterBalance.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<PendingBoard> boardAll() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_board_all(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterPendingBoard.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<PendingBoard> boardAmount({required int amountSats}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_board_amount(
        uniffiClonePointer(),
        FfiConverterUInt64.lower(amountSats),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterPendingBoard.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<BoardFundingInfo> boardFundingAddress() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_board_funding_address(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterBoardFundingInfo.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<PendingBoard> boardPsbt({
    required String psbtBase64,
    required int keypairIndex,
    required int expiryHeight,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_board_psbt(
        uniffiClonePointer(),
        FfiConverterString.lower(psbtBase64),
        FfiConverterUInt32.lower(keypairIndex),
        FfiConverterUInt32.lower(expiryHeight),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterPendingBoard.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<LightningInvoice> bolt11Invoice({
    required int amountSats,
    required String? description,
    required String? token,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_bolt11_invoice(
        uniffiClonePointer(),
        FfiConverterUInt64.lower(amountSats),
        FfiConverterOptionalString.lower(description),
        FfiConverterOptionalString.lower(token),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterLightningInvoice.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<LightningInvoice> bolt11InvoiceForAddress({
    required int amountSats,
    required String claimDestination,
    required String? description,
    required String? token,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_bolt11_invoice_for_address(
        uniffiClonePointer(),
        FfiConverterUInt64.lower(amountSats),
        FfiConverterString.lower(claimDestination),
        FfiConverterOptionalString.lower(description),
        FfiConverterOptionalString.lower(token),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterLightningInvoice.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<String> broadcastTx({required String txHex}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_broadcast_tx(
        uniffiClonePointer(),
        FfiConverterString.lower(txHex),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterString.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<void> cancelAllPendingRounds() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_cancel_all_pending_rounds(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<ExitCancelResult> cancelExit({required String vtxoId}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_cancel_exit(
        uniffiClonePointer(),
        FfiConverterString.lower(vtxoId),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterExitCancelResult.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<void> cancelLightningReceive({required String paymentHash}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_cancel_lightning_receive(
        uniffiClonePointer(),
        FfiConverterString.lower(paymentHash),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<void> cancelPendingRound({required int roundId}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_cancel_pending_round(
        uniffiClonePointer(),
        FfiConverterUInt32.lower(roundId),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<LightningSendStatus> checkLightningPayment({
    required String paymentHash,
    required bool wait,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_check_lightning_payment(
        uniffiClonePointer(),
        FfiConverterString.lower(paymentHash),
        FfiConverterBool.lower(wait),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterLightningSendStatus.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<int> claimableLightningReceiveBalanceSats() {
    return uniffiRustCallAsync(
      () =>
          uniffi_bark_ffi_fn_method_wallet_claimable_lightning_receive_balance_sats(
            uniffiClonePointer(),
          ),
      ffi_bark_ffi_rust_future_poll_u64,
      ffi_bark_ffi_rust_future_complete_u64,
      ffi_bark_ffi_rust_future_free_u64,
      FfiConverterUInt64.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<Config> config() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_config(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterConfig.lift,
      null,
    );
  }

  Future<ExitClaimTransaction> drainExits({
    required List<String> vtxoIds,
    required bool drainAll,
    required String address,
    required int? feeRateSatPerVb,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_drain_exits(
        uniffiClonePointer(),
        FfiConverterSequenceString.lower(vtxoIds),
        FfiConverterBool.lower(drainAll),
        FfiConverterString.lower(address),
        FfiConverterOptionalUInt64.lower(feeRateSatPerVb),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterExitClaimTransaction.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<FeeEstimate> estimateArkoorPaymentFee({required int amountSats}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_estimate_arkoor_payment_fee(
        uniffiClonePointer(),
        FfiConverterUInt64.lower(amountSats),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterFeeEstimate.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<FeeEstimate> estimateBoardFee({required int amountSats}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_estimate_board_fee(
        uniffiClonePointer(),
        FfiConverterUInt64.lower(amountSats),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterFeeEstimate.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<EmergencyExitFeeEstimate> estimateEmergencyExitFee({
    required List<String> vtxoIds,
    required int? feeRateSatPerVb,
    required String? destination,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_estimate_emergency_exit_fee(
        uniffiClonePointer(),
        FfiConverterSequenceString.lower(vtxoIds),
        FfiConverterOptionalUInt64.lower(feeRateSatPerVb),
        FfiConverterOptionalString.lower(destination),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterEmergencyExitFeeEstimate.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<FeeEstimate> estimateLightningReceiveFee({required int amountSats}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_estimate_lightning_receive_fee(
        uniffiClonePointer(),
        FfiConverterUInt64.lower(amountSats),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterFeeEstimate.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<FeeEstimate> estimateLightningSendFee({required int amountSats}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_estimate_lightning_send_fee(
        uniffiClonePointer(),
        FfiConverterUInt64.lower(amountSats),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterFeeEstimate.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<FeeEstimate> estimateOffboardAllFee({required String address}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_estimate_offboard_all_fee(
        uniffiClonePointer(),
        FfiConverterString.lower(address),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterFeeEstimate.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<FeeEstimate> estimateOffboardFee({
    required String address,
    required List<String> vtxoIds,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_estimate_offboard_fee(
        uniffiClonePointer(),
        FfiConverterString.lower(address),
        FfiConverterSequenceString.lower(vtxoIds),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterFeeEstimate.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<FeeEstimate> estimateRefreshFee({required List<String> vtxoIds}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_estimate_refresh_fee(
        uniffiClonePointer(),
        FfiConverterSequenceString.lower(vtxoIds),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterFeeEstimate.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<FeeEstimate> estimateSendOnchainFee({
    required String address,
    required int amountSats,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_estimate_send_onchain_fee(
        uniffiClonePointer(),
        FfiConverterString.lower(address),
        FfiConverterUInt64.lower(amountSats),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterFeeEstimate.lift,
      errorExceptionErrorHandler,
    );
  }

  String fingerprint() {
    return rustCallWithLifter(
      (status) => uniffi_bark_ffi_fn_method_wallet_fingerprint(
        uniffiClonePointer(),
        status,
      ),
      FfiConverterString.lift,
      null,
    );
  }

  Future<ExitTransactionStatus?> getExitStatus({
    required String vtxoId,
    required bool includeHistory,
    required bool includeTransactions,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_get_exit_status(
        uniffiClonePointer(),
        FfiConverterString.lower(vtxoId),
        FfiConverterBool.lower(includeHistory),
        FfiConverterBool.lower(includeTransactions),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterOptionalExitTransactionStatus.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<ExitVtxo>> getExitVtxos() {
    return uniffiRustCallAsync(
      () =>
          uniffi_bark_ffi_fn_method_wallet_get_exit_vtxos(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceExitVtxo.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<Vtxo>> getExpiringVtxos({required int thresholdBlocks}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_get_expiring_vtxos(
        uniffiClonePointer(),
        FfiConverterUInt32.lower(thresholdBlocks),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceVtxo.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<int?> getFirstExpiringVtxoBlockheight() {
    return uniffiRustCallAsync(
      () =>
          uniffi_bark_ffi_fn_method_wallet_get_first_expiring_vtxo_blockheight(
            uniffiClonePointer(),
          ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterOptionalUInt32.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<int?> getNextRequiredRefreshBlockheight() {
    return uniffiRustCallAsync(
      () =>
          uniffi_bark_ffi_fn_method_wallet_get_next_required_refresh_blockheight(
            uniffiClonePointer(),
          ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterOptionalUInt32.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<Vtxo> getVtxoById({required String vtxoId}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_get_vtxo_by_id(
        uniffiClonePointer(),
        FfiConverterString.lower(vtxoId),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterVtxo.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<Vtxo>> getVtxosToRefresh() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_get_vtxos_to_refresh(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceVtxo.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<bool> hasPendingExits() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_has_pending_exits(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_i8,
      ffi_bark_ffi_rust_future_complete_i8,
      ffi_bark_ffi_rust_future_free_i8,
      FfiConverterBool.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<Movement>> history() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_history(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceMovement.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<Movement>> historyByPaymentMethod({
    required String paymentMethodType,
    required String paymentMethodValue,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_history_by_payment_method(
        uniffiClonePointer(),
        FfiConverterString.lower(paymentMethodType),
        FfiConverterString.lower(paymentMethodValue),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceMovement.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<void> importVtxo({
    required String vtxoBase64,
    required ImportVtxoArgs? args,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_import_vtxo(
        uniffiClonePointer(),
        FfiConverterString.lower(vtxoBase64),
        FfiConverterOptionalImportVtxoArgs.lower(args),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<List<String>> importVtxos({
    required List<String> encodedVtxos,
    required ImportVtxoArgs? args,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_import_vtxos(
        uniffiClonePointer(),
        FfiConverterSequenceString.lower(encodedVtxos),
        FfiConverterOptionalImportVtxoArgs.lower(args),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceString.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<bool> isInvoicePaid({required String paymentHash}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_is_invoice_paid(
        uniffiClonePointer(),
        FfiConverterString.lower(paymentHash),
      ),
      ffi_bark_ffi_rust_future_poll_i8,
      ffi_bark_ffi_rust_future_complete_i8,
      ffi_bark_ffi_rust_future_free_i8,
      FfiConverterBool.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<LightningReceive> lightningReceiveState({
    required String paymentHash,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_lightning_receive_state(
        uniffiClonePointer(),
        FfiConverterString.lower(paymentHash),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterLightningReceive.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<LightningSendStatus> lightningSendState({
    required String paymentHash,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_lightning_send_state(
        uniffiClonePointer(),
        FfiConverterString.lower(paymentHash),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterLightningSendStatus.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<ExitVtxo>> listClaimableExits() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_list_claimable_exits(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceExitVtxo.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<void> lockVtxos({
    required List<String> vtxoIds,
    required VtxoLockHolder? holder,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_lock_vtxos(
        uniffiClonePointer(),
        FfiConverterSequenceString.lower(vtxoIds),
        FfiConverterOptionalVtxoLockHolder.lower(holder),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  String mailboxAuthorization({required int expirySecs}) {
    return rustCallWithLifter(
      (status) => uniffi_bark_ffi_fn_method_wallet_mailbox_authorization(
        uniffiClonePointer(),
        FfiConverterUInt32.lower(expirySecs),
        status,
      ),
      FfiConverterString.lift,
      errorExceptionErrorHandler,
    );
  }

  String mailboxIdentifier() {
    return rustCallWithLifter(
      (status) => uniffi_bark_ffi_fn_method_wallet_mailbox_identifier(
        uniffiClonePointer(),
        status,
      ),
      FfiConverterString.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<void> maintenance() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_maintenance(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<void> maintenanceDelegated() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_maintenance_delegated(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<String?> maintenanceRefresh() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_maintenance_refresh(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterOptionalString.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<Network> network() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_network(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterNetwork.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<String> newAddress() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_new_address(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterString.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<AddressWithIndex> newAddressWithIndex() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_new_address_with_index(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterAddressWithIndex.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<int> nextRoundStartTime() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_next_round_start_time(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_u64,
      ffi_bark_ffi_rust_future_complete_u64,
      ffi_bark_ffi_rust_future_free_u64,
      FfiConverterUInt64.lift,
      errorExceptionErrorHandler,
    );
  }

  NotificationHolder notifications() {
    return rustCallWithLifter(
      (status) => uniffi_bark_ffi_fn_method_wallet_notifications(
        uniffiClonePointer(),
        status,
      ),
      NotificationHolder.lift,
      null,
    );
  }

  Future<OffboardResult> offboardAll({required String bitcoinAddress}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_offboard_all(
        uniffiClonePointer(),
        FfiConverterString.lower(bitcoinAddress),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterOffboardResult.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<OffboardResult> offboardVtxos({
    required List<String> vtxoIds,
    required String bitcoinAddress,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_offboard_vtxos(
        uniffiClonePointer(),
        FfiConverterSequenceString.lower(vtxoIds),
        FfiConverterString.lower(bitcoinAddress),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterOffboardResult.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<LightningSendStatus> payLightningAddress({
    required String lightningAddress,
    required int amountSats,
    required String? comment,
    required bool wait,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_pay_lightning_address(
        uniffiClonePointer(),
        FfiConverterString.lower(lightningAddress),
        FfiConverterUInt64.lower(amountSats),
        FfiConverterOptionalString.lower(comment),
        FfiConverterBool.lower(wait),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterLightningSendStatus.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<LightningSendStatus> payLightningInvoice({
    required String invoice,
    required int? amountSats,
    required bool wait,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_pay_lightning_invoice(
        uniffiClonePointer(),
        FfiConverterString.lower(invoice),
        FfiConverterOptionalUInt64.lower(amountSats),
        FfiConverterBool.lower(wait),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterLightningSendStatus.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<LightningSendStatus> payLightningOffer({
    required String offer,
    required int? amountSats,
    required bool wait,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_pay_lightning_offer(
        uniffiClonePointer(),
        FfiConverterString.lower(offer),
        FfiConverterOptionalUInt64.lower(amountSats),
        FfiConverterBool.lower(wait),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterLightningSendStatus.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<LightningSendStatus> payLnurl({
    required String lnurl,
    required int amountSats,
    required String? comment,
    required bool wait,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_pay_lnurl(
        uniffiClonePointer(),
        FfiConverterString.lower(lnurl),
        FfiConverterUInt64.lower(amountSats),
        FfiConverterOptionalString.lower(comment),
        FfiConverterBool.lower(wait),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterLightningSendStatus.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<String> peekAddress({required int index}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_peek_address(
        uniffiClonePointer(),
        FfiConverterUInt32.lower(index),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterString.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<Vtxo>> pendingBoardVtxos() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_pending_board_vtxos(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceVtxo.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<PendingBoard>> pendingBoards() {
    return uniffiRustCallAsync(
      () =>
          uniffi_bark_ffi_fn_method_wallet_pending_boards(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequencePendingBoard.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<int> pendingExitsTotalSats() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_pending_exits_total_sats(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_u64,
      ffi_bark_ffi_rust_future_complete_u64,
      ffi_bark_ffi_rust_future_free_u64,
      FfiConverterUInt64.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<LightningReceive>> pendingLightningReceives() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_pending_lightning_receives(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceLightningReceive.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<Vtxo>> pendingLightningSendVtxos() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_pending_lightning_send_vtxos(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceVtxo.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<LightningSend>> pendingLightningSends() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_pending_lightning_sends(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceLightningSend.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<Vtxo>> pendingRoundInputVtxos() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_pending_round_input_vtxos(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceVtxo.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<RoundState>> pendingRoundStates() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_pending_round_states(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceRoundState.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<ExitProgressStatus>> progressExits({
    required int? feeRateSatPerVb,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_progress_exits(
        uniffiClonePointer(),
        FfiConverterOptionalUInt64.lower(feeRateSatPerVb),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceExitProgressStatus.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<void> progressPendingRounds() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_progress_pending_rounds(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<WalletProperties> properties() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_properties(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterWalletProperties.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<RecoveryReport> recoverVtxos({
    required List<String> vtxoIds,
    required int? gapLimit,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_recover_vtxos(
        uniffiClonePointer(),
        FfiConverterSequenceString.lower(vtxoIds),
        FfiConverterOptionalUInt32.lower(gapLimit),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterRecoveryReport.lift,
      errorExceptionErrorHandler,
    );
  }

  RecoveryReport? recoveryReport() {
    return rustCallWithLifter(
      (status) => uniffi_bark_ffi_fn_method_wallet_recovery_report(
        uniffiClonePointer(),
        status,
      ),
      FfiConverterOptionalRecoveryReport.lift,
      null,
    );
  }

  RecoveryStatus recoveryStatus() {
    return rustCallWithLifter(
      (status) => uniffi_bark_ffi_fn_method_wallet_recovery_status(
        uniffiClonePointer(),
        status,
      ),
      FfiConverterRecoveryStatus.lift,
      null,
    );
  }

  Future<void> refreshServer() {
    return uniffiRustCallAsync(
      () =>
          uniffi_bark_ffi_fn_method_wallet_refresh_server(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<String?> refreshVtxos({required List<String> vtxoIds}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_refresh_vtxos(
        uniffiClonePointer(),
        FfiConverterSequenceString.lower(vtxoIds),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterOptionalString.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<RoundState?> refreshVtxosDelegated({required List<String> vtxoIds}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_refresh_vtxos_delegated(
        uniffiClonePointer(),
        FfiConverterSequenceString.lower(vtxoIds),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterOptionalRoundState.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<RoundState?> refreshVtxosScheduled({
    required List<String> vtxoIds,
    required int scheduledHeight,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_refresh_vtxos_scheduled(
        uniffiClonePointer(),
        FfiConverterSequenceString.lower(vtxoIds),
        FfiConverterUInt32.lower(scheduledHeight),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterOptionalRoundState.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<void> runDaemon() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_run_daemon(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<void> sendArkoorPayment({
    required String arkAddress,
    required int amountSats,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_send_arkoor_payment(
        uniffiClonePointer(),
        FfiConverterString.lower(arkAddress),
        FfiConverterUInt64.lower(amountSats),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<String> sendOnchain({
    required String address,
    required int amountSats,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_send_onchain(
        uniffiClonePointer(),
        FfiConverterString.lower(address),
        FfiConverterUInt64.lower(amountSats),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterString.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<String> signExitClaimInputs({required String psbtBase64}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_sign_exit_claim_inputs(
        uniffiClonePointer(),
        FfiConverterString.lower(psbtBase64),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterString.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<Vtxo>> spendableVtxos() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_spendable_vtxos(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceVtxo.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<void> startExitForEntireWallet() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_start_exit_for_entire_wallet(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<void> startExitForVtxos({required List<String> vtxoIds}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_start_exit_for_vtxos(
        uniffiClonePointer(),
        FfiConverterSequenceString.lower(vtxoIds),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<void> startExitForVtxosIncludingNonStandard({
    required List<String> vtxoIds,
  }) {
    return uniffiRustCallAsync(
      () =>
          uniffi_bark_ffi_fn_method_wallet_start_exit_for_vtxos_including_non_standard(
            uniffiClonePointer(),
            FfiConverterSequenceString.lower(vtxoIds),
          ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<void> stopDaemon() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_stop_daemon(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<void> stopDaemonWait() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_stop_daemon_wait(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<List<LightningSend>> stuckFailedLightningSends() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_stuck_failed_lightning_sends(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceLightningSend.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<void> sync_() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_sync(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<void> syncExits() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_sync_exits(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<void> syncForceExitedVtxos() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_sync_force_exited_vtxos(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<void> syncPendingBoards() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_sync_pending_boards(
        uniffiClonePointer(),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<List<LightningReceive>> tryClaimAllLightningReceives({
    required bool wait,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_try_claim_all_lightning_receives(
        uniffiClonePointer(),
        FfiConverterBool.lower(wait),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceLightningReceive.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<LightningReceive> tryClaimLightningReceive({
    required String paymentHash,
    required bool wait,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_try_claim_lightning_receive(
        uniffiClonePointer(),
        FfiConverterString.lower(paymentHash),
        FfiConverterBool.lower(wait),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterLightningReceive.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<void> unlockVtxos({
    required List<String> vtxoIds,
    required VtxoLockHolder? expectedHolder,
  }) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_unlock_vtxos(
        uniffiClonePointer(),
        FfiConverterSequenceString.lower(vtxoIds),
        FfiConverterOptionalVtxoLockHolder.lower(expectedHolder),
      ),
      ffi_bark_ffi_rust_future_poll_void,
      ffi_bark_ffi_rust_future_complete_void,
      ffi_bark_ffi_rust_future_free_void,
      (_) {},
      errorExceptionErrorHandler,
    );
  }

  Future<bool> validateArkoorAddress({required String address}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_validate_arkoor_address(
        uniffiClonePointer(),
        FfiConverterString.lower(address),
      ),
      ffi_bark_ffi_rust_future_poll_i8,
      ffi_bark_ffi_rust_future_complete_i8,
      ffi_bark_ffi_rust_future_free_i8,
      FfiConverterBool.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<String> vtxoEncoded({required String vtxoId}) {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_vtxo_encoded(
        uniffiClonePointer(),
        FfiConverterString.lower(vtxoId),
      ),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterString.lift,
      errorExceptionErrorHandler,
    );
  }

  Future<List<Vtxo>> vtxos() {
    return uniffiRustCallAsync(
      () => uniffi_bark_ffi_fn_method_wallet_vtxos(uniffiClonePointer()),
      ffi_bark_ffi_rust_future_poll_rust_buffer,
      ffi_bark_ffi_rust_future_complete_rust_buffer,
      ffi_bark_ffi_rust_future_free_rust_buffer,
      FfiConverterSequenceVtxo.lift,
      errorExceptionErrorHandler,
    );
  }
}

class UniffiInternalError implements Exception {
  static const int bufferOverflow = 0;
  static const int incompleteData = 1;
  static const int unexpectedOptionalTag = 2;
  static const int unexpectedEnumCase = 3;
  static const int unexpectedNullPointer = 4;
  static const int unexpectedRustCallStatusCode = 5;
  static const int unexpectedRustCallError = 6;
  static const int unexpectedStaleHandle = 7;
  static const int rustPanic = 8;
  final int errorCode;
  final String? panicMessage;
  const UniffiInternalError(this.errorCode, this.panicMessage);
  static UniffiInternalError panicked(String message) {
    return UniffiInternalError(rustPanic, message);
  }

  @override
  String toString() {
    switch (errorCode) {
      case bufferOverflow:
        return "UniFfi::BufferOverflow";
      case incompleteData:
        return "UniFfi::IncompleteData";
      case unexpectedOptionalTag:
        return "UniFfi::UnexpectedOptionalTag";
      case unexpectedEnumCase:
        return "UniFfi::UnexpectedEnumCase";
      case unexpectedNullPointer:
        return "UniFfi::UnexpectedNullPointer";
      case unexpectedRustCallStatusCode:
        return "UniFfi::UnexpectedRustCallStatusCode";
      case unexpectedRustCallError:
        return "UniFfi::UnexpectedRustCallError";
      case unexpectedStaleHandle:
        return "UniFfi::UnexpectedStaleHandle";
      case rustPanic:
        return "UniFfi::rustPanic: $panicMessage";
      default:
        return "UniFfi::UnknownError: $errorCode";
    }
  }
}

const int CALL_SUCCESS = 0;
const int CALL_ERROR = 1;
const int CALL_UNEXPECTED_ERROR = 2;

final class RustCallStatus extends Struct {
  @Int8()
  external int code;
  external RustBuffer errorBuf;
}

void checkCallStatus(
  UniffiRustCallStatusErrorHandler errorHandler,
  Pointer<RustCallStatus> status,
) {
  if (status.ref.code == CALL_SUCCESS) {
    return;
  } else if (status.ref.code == CALL_ERROR) {
    throw errorHandler.lift(status.ref.errorBuf);
  } else if (status.ref.code == CALL_UNEXPECTED_ERROR) {
    if (status.ref.errorBuf.len > 0) {
      throw UniffiInternalError.panicked(
        FfiConverterString.lift(status.ref.errorBuf),
      );
    } else {
      throw UniffiInternalError.panicked("Rust panic");
    }
  } else {
    throw UniffiInternalError.panicked(
      "Unexpected RustCallStatus code: \${status.ref.code}",
    );
  }
}

T rustCall<T>(
  T Function(Pointer<RustCallStatus>) callback, [
  UniffiRustCallStatusErrorHandler? errorHandler,
]) {
  final status = calloc<RustCallStatus>();
  try {
    final result = callback(status);
    checkCallStatus(errorHandler ?? NullRustCallStatusErrorHandler(), status);
    return result;
  } finally {
    calloc.free(status);
  }
}

T rustCallWithLifter<T, F>(
  F Function(Pointer<RustCallStatus>) ffiCall,
  T Function(F) lifter, [
  UniffiRustCallStatusErrorHandler? errorHandler,
]) {
  final status = calloc<RustCallStatus>();
  try {
    final rawResult = ffiCall(status);
    checkCallStatus(errorHandler ?? NullRustCallStatusErrorHandler(), status);
    return lifter(rawResult);
  } finally {
    calloc.free(status);
  }
}

class NullRustCallStatusErrorHandler extends UniffiRustCallStatusErrorHandler {
  @override
  Exception lift(RustBuffer errorBuf) {
    errorBuf.free();
    return UniffiInternalError.panicked("Unexpected CALL_ERROR");
  }
}

abstract class UniffiRustCallStatusErrorHandler {
  Exception lift(RustBuffer errorBuf);
}

final class RustBuffer extends Struct {
  @Uint64()
  external int capacity;
  @Uint64()
  external int len;
  external Pointer<Uint8> data;
  static RustBuffer alloc(int size) {
    return rustCall((status) => ffi_bark_ffi_rustbuffer_alloc(size, status));
  }

  static RustBuffer fromBytes(ForeignBytes bytes) {
    return rustCall(
      (status) => ffi_bark_ffi_rustbuffer_from_bytes(bytes, status),
    );
  }

  void free() {
    rustCall((status) => ffi_bark_ffi_rustbuffer_free(this, status));
  }

  RustBuffer reserve(int additionalCapacity) {
    return rustCall(
      (status) =>
          ffi_bark_ffi_rustbuffer_reserve(this, additionalCapacity, status),
    );
  }

  Uint8List asUint8List() {
    final dataList = data.asTypedList(len);
    final byteData = ByteData.sublistView(dataList);
    return Uint8List.view(byteData.buffer);
  }

  @override
  String toString() {
    return "RustBuffer{capacity: \$capacity, len: \$len, data: \$data}";
  }
}

RustBuffer toRustBuffer(Uint8List data) {
  final length = data.length;
  final Pointer<Uint8> frameData = calloc<Uint8>(length);
  final pointerList = frameData.asTypedList(length);
  pointerList.setAll(0, data);
  final bytes = calloc<ForeignBytes>();
  bytes.ref.len = length;
  bytes.ref.data = frameData;
  return RustBuffer.fromBytes(bytes.ref);
}

final class ForeignBytes extends Struct {
  @Int32()
  external int len;
  external Pointer<Uint8> data;
  void free() {
    calloc.free(data);
  }
}

class LiftRetVal<T> {
  final T value;
  final int bytesRead;
  const LiftRetVal(this.value, this.bytesRead);
  LiftRetVal<T> copyWithOffset(int offset) {
    return LiftRetVal(value, bytesRead + offset);
  }
}

abstract class FfiConverter<D, F> {
  const FfiConverter();
  D lift(F value);
  F lower(D value);
  D read(ByteData buffer, int offset);
  void write(D value, ByteData buffer, int offset);
  int size(D value);
}

mixin FfiConverterPrimitive<T> on FfiConverter<T, T> {
  @override
  T lift(T value) => value;
  @override
  T lower(T value) => value;
}
Uint8List createUint8ListFromInt(int value) {
  int length = value.bitLength ~/ 8 + 1;
  if (length != 4 && length != 8) {
    length = (value < 0x100000000) ? 4 : 8;
  }
  Uint8List uint8List = Uint8List(length);
  for (int i = length - 1; i >= 0; i--) {
    uint8List[i] = value & 0xFF;
    value >>= 8;
  }
  return uint8List;
}

class FfiConverterOptionalRoundState {
  static RoundState? lift(RustBuffer buf) {
    return FfiConverterOptionalRoundState.read(buf.asUint8List()).value;
  }

  static LiftRetVal<RoundState?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterRoundState.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<RoundState?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([RoundState? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterRoundState.allocationSize(value) + 1;
  }

  static RustBuffer lower(RoundState? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalRoundState.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalRoundState.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(RoundState? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterRoundState.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterOptionalWalletNotification {
  static WalletNotification? lift(RustBuffer buf) {
    return FfiConverterOptionalWalletNotification.read(buf.asUint8List()).value;
  }

  static LiftRetVal<WalletNotification?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterWalletNotification.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<WalletNotification?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([WalletNotification? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterWalletNotification.allocationSize(value) + 1;
  }

  static RustBuffer lower(WalletNotification? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalWalletNotification.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalWalletNotification.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(WalletNotification? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterWalletNotification.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterOptionalUInt16 {
  static int? lift(RustBuffer buf) {
    return FfiConverterOptionalUInt16.read(buf.asUint8List()).value;
  }

  static LiftRetVal<int?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterUInt16.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<int?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([int? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterUInt16.allocationSize(value) + 1;
  }

  static RustBuffer lower(int? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalUInt16.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalUInt16.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(int? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterUInt16.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterUInt64 {
  static int lift(int value) => value;
  static LiftRetVal<int> read(Uint8List buf) {
    return LiftRetVal(buf.buffer.asByteData(buf.offsetInBytes).getUint64(0), 8);
  }

  static int lower(int value) {
    if (value < 0) {
      throw ArgumentError("Value out of range for u64: " + value.toString());
    }
    return value;
  }

  static int allocationSize([int value = 0]) {
    return 8;
  }

  static int write(int value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setUint64(0, lower(value));
    return 8;
  }
}

class FfiConverterUInt32 {
  static int lift(int value) => value;
  static LiftRetVal<int> read(Uint8List buf) {
    return LiftRetVal(buf.buffer.asByteData(buf.offsetInBytes).getUint32(0), 4);
  }

  static int lower(int value) {
    if (value < 0 || value > 4294967295) {
      throw ArgumentError("Value out of range for u32: " + value.toString());
    }
    return value;
  }

  static int allocationSize([int value = 0]) {
    return 4;
  }

  static int write(int value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setUint32(0, lower(value));
    return 4;
  }
}

class FfiConverterOptionalImportVtxoArgs {
  static ImportVtxoArgs? lift(RustBuffer buf) {
    return FfiConverterOptionalImportVtxoArgs.read(buf.asUint8List()).value;
  }

  static LiftRetVal<ImportVtxoArgs?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterImportVtxoArgs.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<ImportVtxoArgs?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([ImportVtxoArgs? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterImportVtxoArgs.allocationSize(value) + 1;
  }

  static RustBuffer lower(ImportVtxoArgs? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalImportVtxoArgs.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalImportVtxoArgs.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(ImportVtxoArgs? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterImportVtxoArgs.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterOptionalRecoveryReport {
  static RecoveryReport? lift(RustBuffer buf) {
    return FfiConverterOptionalRecoveryReport.read(buf.asUint8List()).value;
  }

  static LiftRetVal<RecoveryReport?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterRecoveryReport.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<RecoveryReport?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([RecoveryReport? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterRecoveryReport.allocationSize(value) + 1;
  }

  static RustBuffer lower(RecoveryReport? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalRecoveryReport.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalRecoveryReport.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(RecoveryReport? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterRecoveryReport.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterSequenceString {
  static List<String> lift(RustBuffer buf) {
    return FfiConverterSequenceString.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<String>> read(Uint8List buf) {
    List<String> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterString.read(Uint8List.view(buf.buffer, offset));
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<String> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterString.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<String> value) {
    return value
            .map((l) => FfiConverterString.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<String> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterSequenceDestination {
  static List<Destination> lift(RustBuffer buf) {
    return FfiConverterSequenceDestination.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<Destination>> read(Uint8List buf) {
    List<Destination> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterDestination.read(
        Uint8List.view(buf.buffer, offset),
      );
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<Destination> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterDestination.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<Destination> value) {
    return value
            .map((l) => FfiConverterDestination.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<Destination> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterSequenceVtxo {
  static List<Vtxo> lift(RustBuffer buf) {
    return FfiConverterSequenceVtxo.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<Vtxo>> read(Uint8List buf) {
    List<Vtxo> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterVtxo.read(Uint8List.view(buf.buffer, offset));
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<Vtxo> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterVtxo.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<Vtxo> value) {
    return value
            .map((l) => FfiConverterVtxo.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<Vtxo> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterOptionalString {
  static String? lift(RustBuffer buf) {
    return FfiConverterOptionalString.read(buf.asUint8List()).value;
  }

  static LiftRetVal<String?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterString.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<String?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([String? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterString.allocationSize(value) + 1;
  }

  static RustBuffer lower(String? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalString.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalString.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(String? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterString.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterOptionalVtxoLockHolder {
  static VtxoLockHolder? lift(RustBuffer buf) {
    return FfiConverterOptionalVtxoLockHolder.read(buf.asUint8List()).value;
  }

  static LiftRetVal<VtxoLockHolder?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterVtxoLockHolder.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<VtxoLockHolder?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([VtxoLockHolder? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterVtxoLockHolder.allocationSize(value) + 1;
  }

  static RustBuffer lower(VtxoLockHolder? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalVtxoLockHolder.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalVtxoLockHolder.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(VtxoLockHolder? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterVtxoLockHolder.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterSequenceLightningReceive {
  static List<LightningReceive> lift(RustBuffer buf) {
    return FfiConverterSequenceLightningReceive.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<LightningReceive>> read(Uint8List buf) {
    List<LightningReceive> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterLightningReceive.read(
        Uint8List.view(buf.buffer, offset),
      );
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<LightningReceive> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterLightningReceive.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<LightningReceive> value) {
    return value
            .map((l) => FfiConverterLightningReceive.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<LightningReceive> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterSequencePendingBoard {
  static List<PendingBoard> lift(RustBuffer buf) {
    return FfiConverterSequencePendingBoard.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<PendingBoard>> read(Uint8List buf) {
    List<PendingBoard> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterPendingBoard.read(
        Uint8List.view(buf.buffer, offset),
      );
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<PendingBoard> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterPendingBoard.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<PendingBoard> value) {
    return value
            .map((l) => FfiConverterPendingBoard.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<PendingBoard> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterOptionalExitCancelFailure {
  static ExitCancelFailure? lift(RustBuffer buf) {
    return FfiConverterOptionalExitCancelFailure.read(buf.asUint8List()).value;
  }

  static LiftRetVal<ExitCancelFailure?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterExitCancelFailure.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<ExitCancelFailure?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([ExitCancelFailure? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterExitCancelFailure.allocationSize(value) + 1;
  }

  static RustBuffer lower(ExitCancelFailure? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalExitCancelFailure.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalExitCancelFailure.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(ExitCancelFailure? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterExitCancelFailure.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterSequenceMovement {
  static List<Movement> lift(RustBuffer buf) {
    return FfiConverterSequenceMovement.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<Movement>> read(Uint8List buf) {
    List<Movement> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterMovement.read(Uint8List.view(buf.buffer, offset));
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<Movement> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterMovement.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<Movement> value) {
    return value
            .map((l) => FfiConverterMovement.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<Movement> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterSequenceOnchainUtxo {
  static List<OnchainUtxo> lift(RustBuffer buf) {
    return FfiConverterSequenceOnchainUtxo.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<OnchainUtxo>> read(Uint8List buf) {
    List<OnchainUtxo> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterOnchainUtxo.read(
        Uint8List.view(buf.buffer, offset),
      );
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<OnchainUtxo> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterOnchainUtxo.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<OnchainUtxo> value) {
    return value
            .map((l) => FfiConverterOnchainUtxo.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<OnchainUtxo> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterOptionalInt64 {
  static int? lift(RustBuffer buf) {
    return FfiConverterOptionalInt64.read(buf.asUint8List()).value;
  }

  static LiftRetVal<int?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterInt64.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<int?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([int? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterInt64.allocationSize(value) + 1;
  }

  static RustBuffer lower(int? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalInt64.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalInt64.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(int? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterInt64.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterSequenceWalletTransaction {
  static List<WalletTransaction> lift(RustBuffer buf) {
    return FfiConverterSequenceWalletTransaction.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<WalletTransaction>> read(Uint8List buf) {
    List<WalletTransaction> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterWalletTransaction.read(
        Uint8List.view(buf.buffer, offset),
      );
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<WalletTransaction> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterWalletTransaction.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<WalletTransaction> value) {
    return value
            .map((l) => FfiConverterWalletTransaction.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<WalletTransaction> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterOptionalUInt64 {
  static int? lift(RustBuffer buf) {
    return FfiConverterOptionalUInt64.read(buf.asUint8List()).value;
  }

  static LiftRetVal<int?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterUInt64.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<int?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([int? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterUInt64.allocationSize(value) + 1;
  }

  static RustBuffer lower(int? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalUInt64.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalUInt64.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(int? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterUInt64.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterString {
  static String lift(RustBuffer buf) {
    return utf8.decoder.convert(buf.asUint8List());
  }

  static RustBuffer lower(String value) {
    return toRustBuffer(Utf8Encoder().convert(value));
  }

  static LiftRetVal<String> read(Uint8List buf) {
    final end = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0) + 4;
    return LiftRetVal(utf8.decoder.convert(buf, 4, end), end);
  }

  static int allocationSize([String value = ""]) {
    return utf8.encoder.convert(value).length + 4;
  }

  static int write(String value, Uint8List buf) {
    final list = utf8.encoder.convert(value);
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, list.length);
    buf.setAll(4, list);
    return list.length + 4;
  }
}

class FfiConverterOptionalBlockRef {
  static BlockRef? lift(RustBuffer buf) {
    return FfiConverterOptionalBlockRef.read(buf.asUint8List()).value;
  }

  static LiftRetVal<BlockRef?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterBlockRef.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<BlockRef?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([BlockRef? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterBlockRef.allocationSize(value) + 1;
  }

  static RustBuffer lower(BlockRef? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalBlockRef.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalBlockRef.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(BlockRef? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterBlockRef.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterSequenceExitVtxo {
  static List<ExitVtxo> lift(RustBuffer buf) {
    return FfiConverterSequenceExitVtxo.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<ExitVtxo>> read(Uint8List buf) {
    List<ExitVtxo> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterExitVtxo.read(Uint8List.view(buf.buffer, offset));
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<ExitVtxo> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterExitVtxo.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<ExitVtxo> value) {
    return value
            .map((l) => FfiConverterExitVtxo.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<ExitVtxo> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterOptionalUInt32 {
  static int? lift(RustBuffer buf) {
    return FfiConverterOptionalUInt32.read(buf.asUint8List()).value;
  }

  static LiftRetVal<int?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterUInt32.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<int?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([int? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterUInt32.allocationSize(value) + 1;
  }

  static RustBuffer lower(int? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalUInt32.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalUInt32.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(int? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterUInt32.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterOptionalExitTransactionStatus {
  static ExitTransactionStatus? lift(RustBuffer buf) {
    return FfiConverterOptionalExitTransactionStatus.read(
      buf.asUint8List(),
    ).value;
  }

  static LiftRetVal<ExitTransactionStatus?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterExitTransactionStatus.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<ExitTransactionStatus?>(
      result.value,
      result.bytesRead + 1,
    );
  }

  static int allocationSize([ExitTransactionStatus? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterExitTransactionStatus.allocationSize(value) + 1;
  }

  static RustBuffer lower(ExitTransactionStatus? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalExitTransactionStatus.allocationSize(
      value,
    );
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalExitTransactionStatus.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(ExitTransactionStatus? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterExitTransactionStatus.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterSequenceLightningSend {
  static List<LightningSend> lift(RustBuffer buf) {
    return FfiConverterSequenceLightningSend.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<LightningSend>> read(Uint8List buf) {
    List<LightningSend> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterLightningSend.read(
        Uint8List.view(buf.buffer, offset),
      );
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<LightningSend> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterLightningSend.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<LightningSend> value) {
    return value
            .map((l) => FfiConverterLightningSend.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<LightningSend> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterOptionalSequenceExitState {
  static List<ExitState>? lift(RustBuffer buf) {
    return FfiConverterOptionalSequenceExitState.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<ExitState>?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterSequenceExitState.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<List<ExitState>?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([List<ExitState>? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterSequenceExitState.allocationSize(value) + 1;
  }

  static RustBuffer lower(List<ExitState>? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalSequenceExitState.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalSequenceExitState.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(List<ExitState>? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterSequenceExitState.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterSequenceExitState {
  static List<ExitState> lift(RustBuffer buf) {
    return FfiConverterSequenceExitState.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<ExitState>> read(Uint8List buf) {
    List<ExitState> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterExitState.read(
        Uint8List.view(buf.buffer, offset),
      );
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<ExitState> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterExitState.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<ExitState> value) {
    return value
            .map((l) => FfiConverterExitState.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<ExitState> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterSequenceExitProgressStatus {
  static List<ExitProgressStatus> lift(RustBuffer buf) {
    return FfiConverterSequenceExitProgressStatus.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<ExitProgressStatus>> read(Uint8List buf) {
    List<ExitProgressStatus> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterExitProgressStatus.read(
        Uint8List.view(buf.buffer, offset),
      );
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<ExitProgressStatus> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterExitProgressStatus.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<ExitProgressStatus> value) {
    return value
            .map((l) => FfiConverterExitProgressStatus.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<ExitProgressStatus> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterInt64 {
  static int lift(int value) => value;
  static LiftRetVal<int> read(Uint8List buf) {
    return LiftRetVal(buf.buffer.asByteData(buf.offsetInBytes).getInt64(0), 8);
  }

  static int lower(int value) {
    if (value < -9223372036854775808 || value > 9223372036854775807) {
      throw ArgumentError("Value out of range for i64: " + value.toString());
    }
    return value;
  }

  static int allocationSize([int value = 0]) {
    return 8;
  }

  static int write(int value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt64(0, lower(value));
    return 8;
  }
}

class FfiConverterOptionalArkInfo {
  static ArkInfo? lift(RustBuffer buf) {
    return FfiConverterOptionalArkInfo.read(buf.asUint8List()).value;
  }

  static LiftRetVal<ArkInfo?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterArkInfo.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<ArkInfo?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([ArkInfo? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterArkInfo.allocationSize(value) + 1;
  }

  static RustBuffer lower(ArkInfo? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalArkInfo.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalArkInfo.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(ArkInfo? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterArkInfo.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterOptionalOnchainWallet {
  static OnchainWallet? lift(RustBuffer buf) {
    return FfiConverterOptionalOnchainWallet.read(buf.asUint8List()).value;
  }

  static LiftRetVal<OnchainWallet?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = OnchainWallet.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<OnchainWallet?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([OnchainWallet? value]) {
    if (value == null) {
      return 1;
    }
    return OnchainWallet.allocationSize(value) + 1;
  }

  static RustBuffer lower(OnchainWallet? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalOnchainWallet.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalOnchainWallet.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(OnchainWallet? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return OnchainWallet.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterOptionalUInt8 {
  static int? lift(RustBuffer buf) {
    return FfiConverterOptionalUInt8.read(buf.asUint8List()).value;
  }

  static LiftRetVal<int?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterUInt8.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<int?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([int? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterUInt8.allocationSize(value) + 1;
  }

  static RustBuffer lower(int? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalUInt8.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalUInt8.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(int? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterUInt8.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterUInt8 {
  static int lift(int value) => value;
  static LiftRetVal<int> read(Uint8List buf) {
    return LiftRetVal(buf.buffer.asByteData(buf.offsetInBytes).getUint8(0), 1);
  }

  static int lower(int value) {
    if (value < 0 || value > 255) {
      throw ArgumentError("Value out of range for u8: " + value.toString());
    }
    return value;
  }

  static int allocationSize([int value = 0]) {
    return 1;
  }

  static int write(int value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setUint8(0, lower(value));
    return 1;
  }
}

class FfiConverterOptionalBool {
  static bool? lift(RustBuffer buf) {
    return FfiConverterOptionalBool.read(buf.asUint8List()).value;
  }

  static LiftRetVal<bool?> read(Uint8List buf) {
    if (ByteData.view(buf.buffer, buf.offsetInBytes).getInt8(0) == 0) {
      return LiftRetVal(null, 1);
    }
    final result = FfiConverterBool.read(
      Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
    );
    return LiftRetVal<bool?>(result.value, result.bytesRead + 1);
  }

  static int allocationSize([bool? value]) {
    if (value == null) {
      return 1;
    }
    return FfiConverterBool.allocationSize(value) + 1;
  }

  static RustBuffer lower(bool? value) {
    if (value == null) {
      return toRustBuffer(Uint8List.fromList([0]));
    }
    final length = FfiConverterOptionalBool.allocationSize(value);
    final Pointer<Uint8> frameData = calloc<Uint8>(length);
    final buf = frameData.asTypedList(length);
    FfiConverterOptionalBool.write(value, buf);
    final bytes = calloc<ForeignBytes>();
    bytes.ref.len = length;
    bytes.ref.data = frameData;
    return RustBuffer.fromBytes(bytes.ref);
  }

  static int write(bool? value, Uint8List buf) {
    if (value == null) {
      buf[0] = 0;
      return 1;
    }
    buf[0] = 1;
    return FfiConverterBool.write(
          value,
          Uint8List.view(buf.buffer, buf.offsetInBytes + 1),
        ) +
        1;
  }
}

class FfiConverterSequenceRoundState {
  static List<RoundState> lift(RustBuffer buf) {
    return FfiConverterSequenceRoundState.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<RoundState>> read(Uint8List buf) {
    List<RoundState> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterRoundState.read(
        Uint8List.view(buf.buffer, offset),
      );
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<RoundState> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterRoundState.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<RoundState> value) {
    return value
            .map((l) => FfiConverterRoundState.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<RoundState> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterUInt16 {
  static int lift(int value) => value;
  static LiftRetVal<int> read(Uint8List buf) {
    return LiftRetVal(buf.buffer.asByteData(buf.offsetInBytes).getUint16(0), 2);
  }

  static int lower(int value) {
    if (value < 0 || value > 65535) {
      throw ArgumentError("Value out of range for u16: " + value.toString());
    }
    return value;
  }

  static int allocationSize([int value = 0]) {
    return 2;
  }

  static int write(int value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setUint16(0, lower(value));
    return 2;
  }
}

class FfiConverterSequencePpmExpiryFeeEntry {
  static List<PpmExpiryFeeEntry> lift(RustBuffer buf) {
    return FfiConverterSequencePpmExpiryFeeEntry.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<PpmExpiryFeeEntry>> read(Uint8List buf) {
    List<PpmExpiryFeeEntry> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterPpmExpiryFeeEntry.read(
        Uint8List.view(buf.buffer, offset),
      );
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<PpmExpiryFeeEntry> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterPpmExpiryFeeEntry.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<PpmExpiryFeeEntry> value) {
    return value
            .map((l) => FfiConverterPpmExpiryFeeEntry.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<PpmExpiryFeeEntry> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterSequenceExitTx {
  static List<ExitTx> lift(RustBuffer buf) {
    return FfiConverterSequenceExitTx.read(buf.asUint8List()).value;
  }

  static LiftRetVal<List<ExitTx>> read(Uint8List buf) {
    List<ExitTx> res = [];
    final length = buf.buffer.asByteData(buf.offsetInBytes).getInt32(0);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < length; i++) {
      final ret = FfiConverterExitTx.read(Uint8List.view(buf.buffer, offset));
      offset += ret.bytesRead;
      res.add(ret.value);
    }
    return LiftRetVal(res, offset - buf.offsetInBytes);
  }

  static int write(List<ExitTx> value, Uint8List buf) {
    buf.buffer.asByteData(buf.offsetInBytes).setInt32(0, value.length);
    int offset = buf.offsetInBytes + 4;
    for (var i = 0; i < value.length; i++) {
      offset += FfiConverterExitTx.write(
        value[i],
        Uint8List.view(buf.buffer, offset),
      );
    }
    return offset - buf.offsetInBytes;
  }

  static int allocationSize(List<ExitTx> value) {
    return value
            .map((l) => FfiConverterExitTx.allocationSize(l))
            .fold(0, (a, b) => a + b) +
        4;
  }

  static RustBuffer lower(List<ExitTx> value) {
    final buf = Uint8List(allocationSize(value));
    write(value, buf);
    return toRustBuffer(buf);
  }
}

class FfiConverterBool {
  static bool lift(int value) {
    return value == 1;
  }

  static int lower(bool value) {
    return value ? 1 : 0;
  }

  static LiftRetVal<bool> read(Uint8List buf) {
    return LiftRetVal(FfiConverterBool.lift(buf.first), 1);
  }

  static RustBuffer lowerIntoRustBuffer(bool value) {
    return toRustBuffer(Uint8List.fromList([FfiConverterBool.lower(value)]));
  }

  static int allocationSize([bool value = false]) {
    return 1;
  }

  static int write(bool value, Uint8List buf) {
    buf.setAll(0, [value ? 1 : 0]);
    return allocationSize();
  }
}

const int UNIFFI_RUST_FUTURE_POLL_READY = 0;
const int UNIFFI_RUST_FUTURE_POLL_MAYBE_READY = 1;
typedef UniffiRustFutureContinuationCallback = Void Function(Uint64, Int8);
final _uniffiRustFutureContinuationHandles = UniffiHandleMap<Completer<int>>();
Future<T> uniffiRustCallAsync<T, F>(
  Pointer<Void> Function() rustFutureFunc,
  void Function(
    Pointer<Void>,
    Pointer<NativeFunction<UniffiRustFutureContinuationCallback>>,
    Pointer<Void>,
  )
  pollFunc,
  F Function(Pointer<Void>, Pointer<RustCallStatus>) completeFunc,
  void Function(Pointer<Void>) freeFunc,
  T Function(F) liftFunc, [
  UniffiRustCallStatusErrorHandler? errorHandler,
]) async {
  final rustFuture = rustFutureFunc();
  final completer = Completer<int>();
  final handle = _uniffiRustFutureContinuationHandles.insert(completer);
  final callbackData = Pointer<Void>.fromAddress(handle);
  late final NativeCallable<UniffiRustFutureContinuationCallback> callback;
  void repoll() {
    pollFunc(rustFuture, callback.nativeFunction, callbackData);
  }

  void onResponse(int data, int pollResult) {
    if (pollResult == UNIFFI_RUST_FUTURE_POLL_READY) {
      final readyCompleter = _uniffiRustFutureContinuationHandles.maybeRemove(
        data,
      );
      if (readyCompleter != null && !readyCompleter.isCompleted) {
        readyCompleter.complete(pollResult);
      }
    } else if (pollResult == UNIFFI_RUST_FUTURE_POLL_MAYBE_READY) {
      repoll();
    } else {
      final errorCompleter = _uniffiRustFutureContinuationHandles.maybeRemove(
        data,
      );
      if (errorCompleter != null && !errorCompleter.isCompleted) {
        errorCompleter.completeError(
          UniffiInternalError.panicked(
            "Unexpected poll result from Rust future: \$pollResult",
          ),
        );
      }
    }
  }

  callback = NativeCallable<UniffiRustFutureContinuationCallback>.listener(
    onResponse,
  );
  try {
    repoll();
    await completer.future;
    final status = calloc<RustCallStatus>();
    try {
      final result = completeFunc(rustFuture, status);
      checkCallStatus(errorHandler ?? NullRustCallStatusErrorHandler(), status);
      return liftFunc(result);
    } finally {
      calloc.free(status);
    }
  } finally {
    callback.close();
    _uniffiRustFutureContinuationHandles.maybeRemove(handle);
    freeFunc(rustFuture);
  }
}

typedef UniffiForeignFutureFree = Void Function(Uint64);
typedef UniffiForeignFutureFreeDart = void Function(int);

class _UniffiForeignFutureState {
  bool cancelled = false;
}

final _uniffiForeignFutureHandleMap =
    UniffiHandleMap<_UniffiForeignFutureState>();
void _uniffiForeignFutureFree(int handle) {
  final state = _uniffiForeignFutureHandleMap.maybeRemove(handle);
  if (state != null) {
    state.cancelled = true;
  }
}

final Pointer<NativeFunction<UniffiForeignFutureFree>>
_uniffiForeignFutureFreePointer = Pointer.fromFunction<UniffiForeignFutureFree>(
  _uniffiForeignFutureFree,
);

final class UniffiForeignFuture extends Struct {
  @Uint64()
  external int handle;
  external Pointer<NativeFunction<UniffiForeignFutureFree>> free;
}

class UniffiHandleMap<T> {
  final Map<int, T> _map = {};
  int _counter = 1;
  int insert(T obj) {
    final handle = _counter;
    _counter += 2;
    _map[handle] = obj;
    return handle;
  }

  T get(int handle) {
    final obj = _map[handle];
    if (obj == null) {
      throw UniffiInternalError(
        UniffiInternalError.unexpectedStaleHandle,
        "Handle not found",
      );
    }
    return obj;
  }

  void remove(int handle) {
    if (maybeRemove(handle) == null) {
      throw UniffiInternalError(
        UniffiInternalError.unexpectedStaleHandle,
        "Handle not found",
      );
    }
  }

  T? maybeRemove(int handle) {
    return _map.remove(handle);
  }
}

const _uniffiAssetId = "package:bark_bitcoin/uniffi:bark_ffi";
int defaultVtxoKeyGapLimit() {
  return rustCallWithLifter(
    (status) => uniffi_bark_ffi_fn_func_default_vtxo_key_gap_limit(status),
    FfiConverterUInt32.lift,
    null,
  );
}

String extractTxFromPsbt({required String psbtBase64}) {
  return rustCallWithLifter(
    (status) => uniffi_bark_ffi_fn_func_extract_tx_from_psbt(
      FfiConverterString.lower(psbtBase64),
      status,
    ),
    FfiConverterString.lift,
    errorExceptionErrorHandler,
  );
}

String generateMnemonic() {
  return rustCallWithLifter(
    (status) => uniffi_bark_ffi_fn_func_generate_mnemonic(status),
    FfiConverterString.lift,
    errorExceptionErrorHandler,
  );
}

int maxVtxoKeyGapLimit() {
  return rustCallWithLifter(
    (status) => uniffi_bark_ffi_fn_func_max_vtxo_key_gap_limit(status),
    FfiConverterUInt32.lift,
    null,
  );
}

bool validateArkAddress({required String address}) {
  return rustCallWithLifter(
    (status) => uniffi_bark_ffi_fn_func_validate_ark_address(
      FfiConverterString.lower(address),
      status,
    ),
    FfiConverterBool.lift,
    errorExceptionErrorHandler,
  );
}

bool validateMnemonic({required String mnemonic}) {
  return rustCallWithLifter(
    (status) => uniffi_bark_ffi_fn_func_validate_mnemonic(
      FfiConverterString.lower(mnemonic),
      status,
    ),
    FfiConverterBool.lift,
    errorExceptionErrorHandler,
  );
}

void setLogger({required BarkLogger logger, required LogLevel maxLevel}) {
  return rustCall((status) {
    uniffi_bark_ffi_fn_func_set_logger(
      FfiConverterCallbackInterfaceBarkLogger.lower(logger),
      FfiConverterLogLevel.lower(maxLevel),
      status,
    );
  }, errorExceptionErrorHandler);
}

Future<void> initWallet({
  required Network network,
  required String mnemonicOrSeed,
  required Config config,
  required String datadir,
  required bool allowUnreachableServer,
}) {
  return uniffiRustCallAsync(
    () => uniffi_bark_ffi_fn_func_init_wallet(
      FfiConverterNetwork.lower(network),
      FfiConverterString.lower(mnemonicOrSeed),
      FfiConverterConfig.lower(config),
      FfiConverterString.lower(datadir),
      FfiConverterBool.lower(allowUnreachableServer),
    ),
    ffi_bark_ffi_rust_future_poll_void,
    ffi_bark_ffi_rust_future_complete_void,
    ffi_bark_ffi_rust_future_free_void,
    (_) {},
    errorExceptionErrorHandler,
  );
}

@Native<Pointer<Void> Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_clone_notificationholder(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Void Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external void uniffi_bark_ffi_fn_free_notificationholder(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Void Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external void
uniffi_bark_ffi_fn_method_notificationholder_cancel_next_notification_wait(
  Pointer<Void> ptr,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_notificationholder_next_notification(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_clone_customonchainwalletcallbacks(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Void Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external void uniffi_bark_ffi_fn_free_customonchainwalletcallbacks(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Void Function(
    Pointer<UniffiVTableCallbackInterfaceCustomOnchainWalletCallbacks>,
  )
>(assetId: _uniffiAssetId)
external void
uniffi_bark_ffi_fn_init_callback_vtable_customonchainwalletcallbacks(
  Pointer<UniffiVTableCallbackInterfaceCustomOnchainWalletCallbacks> vtable,
);

@Native<Uint64 Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external int uniffi_bark_ffi_fn_method_customonchainwalletcallbacks_get_balance(
  Pointer<Void> ptr,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  RustBuffer Function(
    Pointer<Void>,
    RustBuffer,
    Uint64,
    Pointer<RustCallStatus>,
  )
>(assetId: _uniffiAssetId)
external RustBuffer
uniffi_bark_ffi_fn_method_customonchainwalletcallbacks_prepare_tx(
  Pointer<Void> ptr,
  RustBuffer destinations,
  int fee_rate_sat_per_vb,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  RustBuffer Function(
    Pointer<Void>,
    RustBuffer,
    Uint64,
    Pointer<RustCallStatus>,
  )
>(assetId: _uniffiAssetId)
external RustBuffer
uniffi_bark_ffi_fn_method_customonchainwalletcallbacks_prepare_drain_tx(
  Pointer<Void> ptr,
  RustBuffer address,
  int fee_rate_sat_per_vb,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  RustBuffer Function(Pointer<Void>, RustBuffer, Pointer<RustCallStatus>)
>(assetId: _uniffiAssetId)
external RustBuffer
uniffi_bark_ffi_fn_method_customonchainwalletcallbacks_finish_psbt(
  Pointer<Void> ptr,
  RustBuffer psbt_base64,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Int8 Function(Pointer<Void>, RustBuffer, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external int uniffi_bark_ffi_fn_method_customonchainwalletcallbacks_is_mine(
  Pointer<Void> ptr,
  RustBuffer script_pubkey_hex,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Void Function(Pointer<Void>, RustBuffer, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external void
uniffi_bark_ffi_fn_method_customonchainwalletcallbacks_register_tx(
  Pointer<Void> ptr,
  RustBuffer tx_hex,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Void Function(Pointer<Void>, RustBuffer, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external void uniffi_bark_ffi_fn_method_customonchainwalletcallbacks_evict_tx(
  Pointer<Void> ptr,
  RustBuffer txid,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  RustBuffer Function(Pointer<Void>, RustBuffer, Pointer<RustCallStatus>)
>(assetId: _uniffiAssetId)
external RustBuffer
uniffi_bark_ffi_fn_method_customonchainwalletcallbacks_make_signed_p2a_cpfp(
  Pointer<Void> ptr,
  RustBuffer params,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Void Function(Pointer<Void>, RustBuffer, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external void
uniffi_bark_ffi_fn_method_customonchainwalletcallbacks_store_signed_p2a_cpfp(
  Pointer<Void> ptr,
  RustBuffer tx_hex,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Void Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external void uniffi_bark_ffi_fn_method_customonchainwalletcallbacks_sync(
  Pointer<Void> ptr,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Pointer<Void> Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_clone_barklogger(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Void Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external void uniffi_bark_ffi_fn_free_barklogger(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Void Function(Pointer<UniffiVTableCallbackInterfaceBarkLogger>)>(
  assetId: _uniffiAssetId,
)
external void uniffi_bark_ffi_fn_init_callback_vtable_barklogger(
  Pointer<UniffiVTableCallbackInterfaceBarkLogger> vtable,
);

@Native<
  Void Function(
    Pointer<Void>,
    RustBuffer,
    RustBuffer,
    RustBuffer,
    Pointer<RustCallStatus>,
  )
>(assetId: _uniffiAssetId)
external void uniffi_bark_ffi_fn_method_barklogger_log(
  Pointer<Void> ptr,
  RustBuffer level,
  RustBuffer target,
  RustBuffer message,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Pointer<Void> Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_clone_onchainwallet(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Void Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external void uniffi_bark_ffi_fn_free_onchainwallet(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Pointer<Void> Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_constructor_onchainwallet_custom(
  Pointer<Void> callbacks,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Pointer<Void> Function(RustBuffer, RustBuffer, RustBuffer, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_constructor_onchainwallet_default(
  RustBuffer network,
  RustBuffer mnemonic,
  RustBuffer config,
  RustBuffer datadir,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_onchainwallet_balance(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_onchainwallet_evict_tx(
  Pointer<Void> ptr,
  RustBuffer txid,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_onchainwallet_fee_rates(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_onchainwallet_initial_scan(
  Pointer<Void> ptr,
  RustBuffer birthday_height,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_onchainwallet_new_address(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, Uint64, Uint64)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_onchainwallet_send(
  Pointer<Void> ptr,
  RustBuffer address,
  int amount_sats,
  int fee_rate_sat_per_vb,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_onchainwallet_sync(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_onchainwallet_tip_height(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_onchainwallet_transactions(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_onchainwallet_utxos(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_clone_wallet(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Void Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external void uniffi_bark_ffi_fn_free_wallet(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Pointer<Void> Function(RustBuffer, RustBuffer, RustBuffer, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_constructor_wallet_open(
  RustBuffer network,
  RustBuffer mnemonic_or_seed,
  RustBuffer config,
  RustBuffer args,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_all_exits_claimable_at_height(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_all_vtxos(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_allow_lightning_send_to_exit(
  Pointer<Void> ptr,
  RustBuffer payment_hash,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_ark_info(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_attempt_lightning_receive_exit(
  Pointer<Void> ptr,
  RustBuffer payment_hash,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_balance(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_board_all(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, Uint64)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_board_amount(
  Pointer<Void> ptr,
  int amount_sats,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_board_funding_address(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, Uint32, Uint32)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_board_psbt(
  Pointer<Void> ptr,
  RustBuffer psbt_base64,
  int keypair_index,
  int expiry_height,
);

@Native<Pointer<Void> Function(Pointer<Void>, Uint64, RustBuffer, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_bolt11_invoice(
  Pointer<Void> ptr,
  int amount_sats,
  RustBuffer description,
  RustBuffer token,
);

@Native<
  Pointer<Void> Function(
    Pointer<Void>,
    Uint64,
    RustBuffer,
    RustBuffer,
    RustBuffer,
  )
>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_bolt11_invoice_for_address(
  Pointer<Void> ptr,
  int amount_sats,
  RustBuffer claim_destination,
  RustBuffer description,
  RustBuffer token,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_broadcast_tx(
  Pointer<Void> ptr,
  RustBuffer tx_hex,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_cancel_all_pending_rounds(Pointer<Void> ptr);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_cancel_exit(
  Pointer<Void> ptr,
  RustBuffer vtxo_id,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_cancel_lightning_receive(
  Pointer<Void> ptr,
  RustBuffer payment_hash,
);

@Native<Pointer<Void> Function(Pointer<Void>, Uint32)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_cancel_pending_round(
  Pointer<Void> ptr,
  int round_id,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, Int8)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_check_lightning_payment(
  Pointer<Void> ptr,
  RustBuffer payment_hash,
  int wait,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_claimable_lightning_receive_balance_sats(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_config(
  Pointer<Void> ptr,
);

@Native<
  Pointer<Void> Function(
    Pointer<Void>,
    RustBuffer,
    Int8,
    RustBuffer,
    RustBuffer,
  )
>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_drain_exits(
  Pointer<Void> ptr,
  RustBuffer vtxo_ids,
  int drain_all,
  RustBuffer address,
  RustBuffer fee_rate_sat_per_vb,
);

@Native<Pointer<Void> Function(Pointer<Void>, Uint64)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_estimate_arkoor_payment_fee(
  Pointer<Void> ptr,
  int amount_sats,
);

@Native<Pointer<Void> Function(Pointer<Void>, Uint64)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_estimate_board_fee(
  Pointer<Void> ptr,
  int amount_sats,
);

@Native<
  Pointer<Void> Function(Pointer<Void>, RustBuffer, RustBuffer, RustBuffer)
>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_estimate_emergency_exit_fee(
  Pointer<Void> ptr,
  RustBuffer vtxo_ids,
  RustBuffer fee_rate_sat_per_vb,
  RustBuffer destination,
);

@Native<Pointer<Void> Function(Pointer<Void>, Uint64)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_estimate_lightning_receive_fee(
  Pointer<Void> ptr,
  int amount_sats,
);

@Native<Pointer<Void> Function(Pointer<Void>, Uint64)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_estimate_lightning_send_fee(
  Pointer<Void> ptr,
  int amount_sats,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_estimate_offboard_all_fee(
  Pointer<Void> ptr,
  RustBuffer address,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_estimate_offboard_fee(
  Pointer<Void> ptr,
  RustBuffer address,
  RustBuffer vtxo_ids,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_estimate_refresh_fee(
  Pointer<Void> ptr,
  RustBuffer vtxo_ids,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, Uint64)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_estimate_send_onchain_fee(
  Pointer<Void> ptr,
  RustBuffer address,
  int amount_sats,
);

@Native<RustBuffer Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external RustBuffer uniffi_bark_ffi_fn_method_wallet_fingerprint(
  Pointer<Void> ptr,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, Int8, Int8)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_get_exit_status(
  Pointer<Void> ptr,
  RustBuffer vtxo_id,
  int include_history,
  int include_transactions,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_get_exit_vtxos(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, Uint32)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_get_expiring_vtxos(
  Pointer<Void> ptr,
  int threshold_blocks,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_get_first_expiring_vtxo_blockheight(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_get_next_required_refresh_blockheight(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_get_vtxo_by_id(
  Pointer<Void> ptr,
  RustBuffer vtxo_id,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_get_vtxos_to_refresh(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_has_pending_exits(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_history(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_history_by_payment_method(
  Pointer<Void> ptr,
  RustBuffer payment_method_type,
  RustBuffer payment_method_value,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_import_vtxo(
  Pointer<Void> ptr,
  RustBuffer vtxo_base64,
  RustBuffer args,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_import_vtxos(
  Pointer<Void> ptr,
  RustBuffer encoded_vtxos,
  RustBuffer args,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_is_invoice_paid(
  Pointer<Void> ptr,
  RustBuffer payment_hash,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_lightning_receive_state(
  Pointer<Void> ptr,
  RustBuffer payment_hash,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_lightning_send_state(
  Pointer<Void> ptr,
  RustBuffer payment_hash,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_list_claimable_exits(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_lock_vtxos(
  Pointer<Void> ptr,
  RustBuffer vtxo_ids,
  RustBuffer holder,
);

@Native<RustBuffer Function(Pointer<Void>, Uint32, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external RustBuffer uniffi_bark_ffi_fn_method_wallet_mailbox_authorization(
  Pointer<Void> ptr,
  int expiry_secs,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<RustBuffer Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external RustBuffer uniffi_bark_ffi_fn_method_wallet_mailbox_identifier(
  Pointer<Void> ptr,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_maintenance(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_maintenance_delegated(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_maintenance_refresh(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_network(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_new_address(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_new_address_with_index(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_next_round_start_time(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_notifications(
  Pointer<Void> ptr,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_offboard_all(
  Pointer<Void> ptr,
  RustBuffer bitcoin_address,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_offboard_vtxos(
  Pointer<Void> ptr,
  RustBuffer vtxo_ids,
  RustBuffer bitcoin_address,
);

@Native<
  Pointer<Void> Function(Pointer<Void>, RustBuffer, Uint64, RustBuffer, Int8)
>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_pay_lightning_address(
  Pointer<Void> ptr,
  RustBuffer lightning_address,
  int amount_sats,
  RustBuffer comment,
  int wait,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, RustBuffer, Int8)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_pay_lightning_invoice(
  Pointer<Void> ptr,
  RustBuffer invoice,
  RustBuffer amount_sats,
  int wait,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, RustBuffer, Int8)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_pay_lightning_offer(
  Pointer<Void> ptr,
  RustBuffer offer,
  RustBuffer amount_sats,
  int wait,
);

@Native<
  Pointer<Void> Function(Pointer<Void>, RustBuffer, Uint64, RustBuffer, Int8)
>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_pay_lnurl(
  Pointer<Void> ptr,
  RustBuffer lnurl,
  int amount_sats,
  RustBuffer comment,
  int wait,
);

@Native<Pointer<Void> Function(Pointer<Void>, Uint32)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_peek_address(
  Pointer<Void> ptr,
  int index,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_pending_board_vtxos(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_pending_boards(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_pending_exits_total_sats(Pointer<Void> ptr);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_pending_lightning_receives(Pointer<Void> ptr);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_pending_lightning_send_vtxos(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_pending_lightning_sends(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_pending_round_input_vtxos(Pointer<Void> ptr);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_pending_round_states(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_progress_exits(
  Pointer<Void> ptr,
  RustBuffer fee_rate_sat_per_vb,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_progress_pending_rounds(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_properties(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_recover_vtxos(
  Pointer<Void> ptr,
  RustBuffer vtxo_ids,
  RustBuffer gap_limit,
);

@Native<RustBuffer Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external RustBuffer uniffi_bark_ffi_fn_method_wallet_recovery_report(
  Pointer<Void> ptr,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<RustBuffer Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external RustBuffer uniffi_bark_ffi_fn_method_wallet_recovery_status(
  Pointer<Void> ptr,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_refresh_server(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_refresh_vtxos(
  Pointer<Void> ptr,
  RustBuffer vtxo_ids,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_refresh_vtxos_delegated(
  Pointer<Void> ptr,
  RustBuffer vtxo_ids,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, Uint32)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_refresh_vtxos_scheduled(
  Pointer<Void> ptr,
  RustBuffer vtxo_ids,
  int scheduled_height,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_run_daemon(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, Uint64)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_send_arkoor_payment(
  Pointer<Void> ptr,
  RustBuffer ark_address,
  int amount_sats,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, Uint64)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_send_onchain(
  Pointer<Void> ptr,
  RustBuffer address,
  int amount_sats,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_sign_exit_claim_inputs(
  Pointer<Void> ptr,
  RustBuffer psbt_base64,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_spendable_vtxos(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_start_exit_for_entire_wallet(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_start_exit_for_vtxos(
  Pointer<Void> ptr,
  RustBuffer vtxo_ids,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_start_exit_for_vtxos_including_non_standard(
  Pointer<Void> ptr,
  RustBuffer vtxo_ids,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_stop_daemon(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_stop_daemon_wait(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_stuck_failed_lightning_sends(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_sync(Pointer<Void> ptr);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_sync_exits(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_sync_force_exited_vtxos(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_sync_pending_boards(
  Pointer<Void> ptr,
);

@Native<Pointer<Void> Function(Pointer<Void>, Int8)>(assetId: _uniffiAssetId)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_try_claim_all_lightning_receives(
  Pointer<Void> ptr,
  int wait,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, Int8)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void>
uniffi_bark_ffi_fn_method_wallet_try_claim_lightning_receive(
  Pointer<Void> ptr,
  RustBuffer payment_hash,
  int wait,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_unlock_vtxos(
  Pointer<Void> ptr,
  RustBuffer vtxo_ids,
  RustBuffer expected_holder,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_validate_arkoor_address(
  Pointer<Void> ptr,
  RustBuffer address,
);

@Native<Pointer<Void> Function(Pointer<Void>, RustBuffer)>(
  assetId: _uniffiAssetId,
)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_vtxo_encoded(
  Pointer<Void> ptr,
  RustBuffer vtxo_id,
);

@Native<Pointer<Void> Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_method_wallet_vtxos(
  Pointer<Void> ptr,
);

@Native<Uint32 Function(Pointer<RustCallStatus>)>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_fn_func_default_vtxo_key_gap_limit(
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<RustBuffer Function(RustBuffer, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external RustBuffer uniffi_bark_ffi_fn_func_extract_tx_from_psbt(
  RustBuffer psbt_base64,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<RustBuffer Function(Pointer<RustCallStatus>)>(assetId: _uniffiAssetId)
external RustBuffer uniffi_bark_ffi_fn_func_generate_mnemonic(
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Uint32 Function(Pointer<RustCallStatus>)>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_fn_func_max_vtxo_key_gap_limit(
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Int8 Function(RustBuffer, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external int uniffi_bark_ffi_fn_func_validate_ark_address(
  RustBuffer address,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Int8 Function(RustBuffer, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external int uniffi_bark_ffi_fn_func_validate_mnemonic(
  RustBuffer mnemonic,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Void Function(Pointer<Void>, RustBuffer, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external void uniffi_bark_ffi_fn_func_set_logger(
  Pointer<Void> logger,
  RustBuffer max_level,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Pointer<Void> Function(RustBuffer, RustBuffer, RustBuffer, RustBuffer, Int8)
>(assetId: _uniffiAssetId)
external Pointer<Void> uniffi_bark_ffi_fn_func_init_wallet(
  RustBuffer network,
  RustBuffer mnemonic_or_seed,
  RustBuffer config,
  RustBuffer datadir,
  int allow_unreachable_server,
);

@Native<RustBuffer Function(Uint64, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external RustBuffer ffi_bark_ffi_rustbuffer_alloc(
  int size,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<RustBuffer Function(ForeignBytes, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external RustBuffer ffi_bark_ffi_rustbuffer_from_bytes(
  ForeignBytes bytes,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Void Function(RustBuffer, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external void ffi_bark_ffi_rustbuffer_free(
  RustBuffer buf,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<RustBuffer Function(RustBuffer, Uint64, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external RustBuffer ffi_bark_ffi_rustbuffer_reserve(
  RustBuffer buf,
  int additional,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Void Function(
    Pointer<Void>,
    Pointer<NativeFunction<UniffiRustFutureContinuationCallback>>,
    Pointer<Void>,
  )
>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_poll_u8(
  Pointer<Void> handle,
  Pointer<NativeFunction<UniffiRustFutureContinuationCallback>> callback,
  Pointer<Void> callback_data,
);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_cancel_u8(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_free_u8(Pointer<Void> handle);

@Native<Uint8 Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external int ffi_bark_ffi_rust_future_complete_u8(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Void Function(
    Pointer<Void>,
    Pointer<NativeFunction<UniffiRustFutureContinuationCallback>>,
    Pointer<Void>,
  )
>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_poll_i8(
  Pointer<Void> handle,
  Pointer<NativeFunction<UniffiRustFutureContinuationCallback>> callback,
  Pointer<Void> callback_data,
);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_cancel_i8(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_free_i8(Pointer<Void> handle);

@Native<Int8 Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external int ffi_bark_ffi_rust_future_complete_i8(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Void Function(
    Pointer<Void>,
    Pointer<NativeFunction<UniffiRustFutureContinuationCallback>>,
    Pointer<Void>,
  )
>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_poll_u16(
  Pointer<Void> handle,
  Pointer<NativeFunction<UniffiRustFutureContinuationCallback>> callback,
  Pointer<Void> callback_data,
);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_cancel_u16(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_free_u16(Pointer<Void> handle);

@Native<Uint16 Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external int ffi_bark_ffi_rust_future_complete_u16(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Void Function(
    Pointer<Void>,
    Pointer<NativeFunction<UniffiRustFutureContinuationCallback>>,
    Pointer<Void>,
  )
>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_poll_i16(
  Pointer<Void> handle,
  Pointer<NativeFunction<UniffiRustFutureContinuationCallback>> callback,
  Pointer<Void> callback_data,
);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_cancel_i16(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_free_i16(Pointer<Void> handle);

@Native<Int16 Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external int ffi_bark_ffi_rust_future_complete_i16(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Void Function(
    Pointer<Void>,
    Pointer<NativeFunction<UniffiRustFutureContinuationCallback>>,
    Pointer<Void>,
  )
>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_poll_u32(
  Pointer<Void> handle,
  Pointer<NativeFunction<UniffiRustFutureContinuationCallback>> callback,
  Pointer<Void> callback_data,
);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_cancel_u32(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_free_u32(Pointer<Void> handle);

@Native<Uint32 Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external int ffi_bark_ffi_rust_future_complete_u32(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Void Function(
    Pointer<Void>,
    Pointer<NativeFunction<UniffiRustFutureContinuationCallback>>,
    Pointer<Void>,
  )
>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_poll_i32(
  Pointer<Void> handle,
  Pointer<NativeFunction<UniffiRustFutureContinuationCallback>> callback,
  Pointer<Void> callback_data,
);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_cancel_i32(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_free_i32(Pointer<Void> handle);

@Native<Int32 Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external int ffi_bark_ffi_rust_future_complete_i32(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Void Function(
    Pointer<Void>,
    Pointer<NativeFunction<UniffiRustFutureContinuationCallback>>,
    Pointer<Void>,
  )
>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_poll_u64(
  Pointer<Void> handle,
  Pointer<NativeFunction<UniffiRustFutureContinuationCallback>> callback,
  Pointer<Void> callback_data,
);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_cancel_u64(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_free_u64(Pointer<Void> handle);

@Native<Uint64 Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external int ffi_bark_ffi_rust_future_complete_u64(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Void Function(
    Pointer<Void>,
    Pointer<NativeFunction<UniffiRustFutureContinuationCallback>>,
    Pointer<Void>,
  )
>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_poll_i64(
  Pointer<Void> handle,
  Pointer<NativeFunction<UniffiRustFutureContinuationCallback>> callback,
  Pointer<Void> callback_data,
);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_cancel_i64(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_free_i64(Pointer<Void> handle);

@Native<Int64 Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external int ffi_bark_ffi_rust_future_complete_i64(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Void Function(
    Pointer<Void>,
    Pointer<NativeFunction<UniffiRustFutureContinuationCallback>>,
    Pointer<Void>,
  )
>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_poll_f32(
  Pointer<Void> handle,
  Pointer<NativeFunction<UniffiRustFutureContinuationCallback>> callback,
  Pointer<Void> callback_data,
);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_cancel_f32(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_free_f32(Pointer<Void> handle);

@Native<Float Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external double ffi_bark_ffi_rust_future_complete_f32(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Void Function(
    Pointer<Void>,
    Pointer<NativeFunction<UniffiRustFutureContinuationCallback>>,
    Pointer<Void>,
  )
>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_poll_f64(
  Pointer<Void> handle,
  Pointer<NativeFunction<UniffiRustFutureContinuationCallback>> callback,
  Pointer<Void> callback_data,
);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_cancel_f64(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_free_f64(Pointer<Void> handle);

@Native<Double Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external double ffi_bark_ffi_rust_future_complete_f64(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Void Function(
    Pointer<Void>,
    Pointer<NativeFunction<UniffiRustFutureContinuationCallback>>,
    Pointer<Void>,
  )
>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_poll_rust_buffer(
  Pointer<Void> handle,
  Pointer<NativeFunction<UniffiRustFutureContinuationCallback>> callback,
  Pointer<Void> callback_data,
);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_cancel_rust_buffer(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_free_rust_buffer(Pointer<Void> handle);

@Native<RustBuffer Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external RustBuffer ffi_bark_ffi_rust_future_complete_rust_buffer(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<
  Void Function(
    Pointer<Void>,
    Pointer<NativeFunction<UniffiRustFutureContinuationCallback>>,
    Pointer<Void>,
  )
>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_poll_void(
  Pointer<Void> handle,
  Pointer<NativeFunction<UniffiRustFutureContinuationCallback>> callback,
  Pointer<Void> callback_data,
);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_cancel_void(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>)>(assetId: _uniffiAssetId)
external void ffi_bark_ffi_rust_future_free_void(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>, Pointer<RustCallStatus>)>(
  assetId: _uniffiAssetId,
)
external void ffi_bark_ffi_rust_future_complete_void(
  Pointer<Void> handle,
  Pointer<RustCallStatus> uniffiStatus,
);

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_func_default_vtxo_key_gap_limit();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_func_extract_tx_from_psbt();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_func_generate_mnemonic();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_func_max_vtxo_key_gap_limit();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_func_validate_ark_address();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_func_validate_mnemonic();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_func_set_logger();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_func_init_wallet();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_notificationholder_cancel_next_notification_wait();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_notificationholder_next_notification();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_get_balance();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_prepare_tx();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_prepare_drain_tx();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_finish_psbt();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_is_mine();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_register_tx();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_evict_tx();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_make_signed_p2a_cpfp();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_store_signed_p2a_cpfp();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_sync();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_barklogger_log();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_onchainwallet_balance();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_onchainwallet_evict_tx();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_onchainwallet_fee_rates();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_onchainwallet_initial_scan();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_onchainwallet_new_address();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_onchainwallet_send();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_onchainwallet_sync();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_onchainwallet_tip_height();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_onchainwallet_transactions();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_onchainwallet_utxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_all_exits_claimable_at_height();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_all_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_allow_lightning_send_to_exit();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_ark_info();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_attempt_lightning_receive_exit();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_balance();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_board_all();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_board_amount();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_board_funding_address();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_board_psbt();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_bolt11_invoice();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_bolt11_invoice_for_address();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_broadcast_tx();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_cancel_all_pending_rounds();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_cancel_exit();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_cancel_lightning_receive();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_cancel_pending_round();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_check_lightning_payment();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_claimable_lightning_receive_balance_sats();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_config();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_drain_exits();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_estimate_arkoor_payment_fee();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_estimate_board_fee();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_estimate_emergency_exit_fee();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_estimate_lightning_receive_fee();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_estimate_lightning_send_fee();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_estimate_offboard_all_fee();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_estimate_offboard_fee();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_estimate_refresh_fee();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_estimate_send_onchain_fee();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_fingerprint();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_get_exit_status();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_get_exit_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_get_expiring_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_get_first_expiring_vtxo_blockheight();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_get_next_required_refresh_blockheight();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_get_vtxo_by_id();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_get_vtxos_to_refresh();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_has_pending_exits();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_history();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_history_by_payment_method();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_import_vtxo();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_import_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_is_invoice_paid();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_lightning_receive_state();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_lightning_send_state();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_list_claimable_exits();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_lock_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_mailbox_authorization();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_mailbox_identifier();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_maintenance();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_maintenance_delegated();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_maintenance_refresh();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_network();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_new_address();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_new_address_with_index();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_next_round_start_time();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_notifications();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_offboard_all();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_offboard_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_pay_lightning_address();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_pay_lightning_invoice();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_pay_lightning_offer();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_pay_lnurl();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_peek_address();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_pending_board_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_pending_boards();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_pending_exits_total_sats();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_pending_lightning_receives();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_pending_lightning_send_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_pending_lightning_sends();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_pending_round_input_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_pending_round_states();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_progress_exits();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_progress_pending_rounds();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_properties();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_recover_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_recovery_report();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_recovery_status();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_refresh_server();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_refresh_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_refresh_vtxos_delegated();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_refresh_vtxos_scheduled();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_run_daemon();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_send_arkoor_payment();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_send_onchain();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_sign_exit_claim_inputs();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_spendable_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_start_exit_for_entire_wallet();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_start_exit_for_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_start_exit_for_vtxos_including_non_standard();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_stop_daemon();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_stop_daemon_wait();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_stuck_failed_lightning_sends();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_sync();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_sync_exits();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_sync_force_exited_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_sync_pending_boards();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_try_claim_all_lightning_receives();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int
uniffi_bark_ffi_checksum_method_wallet_try_claim_lightning_receive();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_unlock_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_validate_arkoor_address();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_vtxo_encoded();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_method_wallet_vtxos();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_constructor_onchainwallet_custom();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_constructor_onchainwallet_default();

@Native<Uint16 Function()>(assetId: _uniffiAssetId)
external int uniffi_bark_ffi_checksum_constructor_wallet_open();

@Native<Uint32 Function()>(assetId: _uniffiAssetId)
external int ffi_bark_ffi_uniffi_contract_version();

void _checkApiVersion() {
  final bindingsVersion = 30;
  final scaffoldingVersion = ffi_bark_ffi_uniffi_contract_version();
  if (bindingsVersion != scaffoldingVersion) {
    throw UniffiInternalError.panicked(
      "UniFFI contract version mismatch: bindings version \$bindingsVersion, scaffolding version \$scaffoldingVersion",
    );
  }
}

void _checkApiChecksums() {
  if (uniffi_bark_ffi_checksum_func_default_vtxo_key_gap_limit() != 3344) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_func_extract_tx_from_psbt() != 8893) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_func_generate_mnemonic() != 65033) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_func_max_vtxo_key_gap_limit() != 15808) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_func_validate_ark_address() != 43084) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_func_validate_mnemonic() != 33507) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_func_set_logger() != 16477) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_func_init_wallet() != 41495) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_notificationholder_cancel_next_notification_wait() !=
      45269) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_notificationholder_next_notification() !=
      25507) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_get_balance() !=
      22074) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_prepare_tx() !=
      41818) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_prepare_drain_tx() !=
      43328) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_finish_psbt() !=
      24435) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_is_mine() !=
      18867) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_register_tx() !=
      17970) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_evict_tx() !=
      36298) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_make_signed_p2a_cpfp() !=
      46075) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_store_signed_p2a_cpfp() !=
      64815) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_customonchainwalletcallbacks_sync() !=
      29018) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_barklogger_log() != 30279) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_onchainwallet_balance() != 39213) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_onchainwallet_evict_tx() != 26786) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_onchainwallet_fee_rates() != 30741) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_onchainwallet_initial_scan() != 19010) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_onchainwallet_new_address() != 7405) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_onchainwallet_send() != 30495) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_onchainwallet_sync() != 4373) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_onchainwallet_tip_height() != 12254) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_onchainwallet_transactions() != 566) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_onchainwallet_utxos() != 44926) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_all_exits_claimable_at_height() !=
      59034) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_all_vtxos() != 62209) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_allow_lightning_send_to_exit() !=
      56991) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_ark_info() != 54388) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_attempt_lightning_receive_exit() !=
      6368) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_balance() != 37345) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_board_all() != 5667) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_board_amount() != 54692) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_board_funding_address() != 8961) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_board_psbt() != 28300) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_bolt11_invoice() != 54959) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_bolt11_invoice_for_address() !=
      56368) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_broadcast_tx() != 46367) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_cancel_all_pending_rounds() !=
      53455) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_cancel_exit() != 63172) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_cancel_lightning_receive() !=
      49444) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_cancel_pending_round() != 13433) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_check_lightning_payment() !=
      50033) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_claimable_lightning_receive_balance_sats() !=
      7743) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_config() != 23594) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_drain_exits() != 45364) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_estimate_arkoor_payment_fee() !=
      35980) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_estimate_board_fee() != 55967) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_estimate_emergency_exit_fee() !=
      44713) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_estimate_lightning_receive_fee() !=
      33637) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_estimate_lightning_send_fee() !=
      11290) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_estimate_offboard_all_fee() !=
      24629) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_estimate_offboard_fee() != 37073) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_estimate_refresh_fee() != 18182) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_estimate_send_onchain_fee() !=
      1027) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_fingerprint() != 51021) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_get_exit_status() != 33054) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_get_exit_vtxos() != 20147) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_get_expiring_vtxos() != 39689) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_get_first_expiring_vtxo_blockheight() !=
      33536) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_get_next_required_refresh_blockheight() !=
      58530) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_get_vtxo_by_id() != 34050) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_get_vtxos_to_refresh() != 52553) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_has_pending_exits() != 19790) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_history() != 10552) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_history_by_payment_method() !=
      11845) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_import_vtxo() != 26027) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_import_vtxos() != 13727) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_is_invoice_paid() != 5699) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_lightning_receive_state() !=
      27834) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_lightning_send_state() != 53422) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_list_claimable_exits() != 58660) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_lock_vtxos() != 13415) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_mailbox_authorization() != 25098) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_mailbox_identifier() != 15231) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_maintenance() != 33161) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_maintenance_delegated() != 31668) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_maintenance_refresh() != 34548) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_network() != 2007) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_new_address() != 65478) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_new_address_with_index() !=
      37344) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_next_round_start_time() != 20748) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_notifications() != 8597) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_offboard_all() != 7986) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_offboard_vtxos() != 64605) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_pay_lightning_address() != 43061) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_pay_lightning_invoice() != 26921) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_pay_lightning_offer() != 25462) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_pay_lnurl() != 1459) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_peek_address() != 31847) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_pending_board_vtxos() != 53566) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_pending_boards() != 61501) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_pending_exits_total_sats() !=
      38418) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_pending_lightning_receives() !=
      26676) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_pending_lightning_send_vtxos() !=
      62766) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_pending_lightning_sends() !=
      8847) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_pending_round_input_vtxos() !=
      54307) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_pending_round_states() != 11480) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_progress_exits() != 6255) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_progress_pending_rounds() !=
      43537) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_properties() != 9773) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_recover_vtxos() != 56476) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_recovery_report() != 10331) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_recovery_status() != 14132) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_refresh_server() != 41162) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_refresh_vtxos() != 52101) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_refresh_vtxos_delegated() !=
      61476) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_refresh_vtxos_scheduled() !=
      50488) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_run_daemon() != 9520) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_send_arkoor_payment() != 32252) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_send_onchain() != 42570) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_sign_exit_claim_inputs() !=
      12930) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_spendable_vtxos() != 22755) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_start_exit_for_entire_wallet() !=
      6525) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_start_exit_for_vtxos() != 56154) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_start_exit_for_vtxos_including_non_standard() !=
      27907) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_stop_daemon() != 7109) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_stop_daemon_wait() != 1734) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_stuck_failed_lightning_sends() !=
      31613) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_sync() != 2151) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_sync_exits() != 12141) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_sync_force_exited_vtxos() !=
      25363) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_sync_pending_boards() != 63453) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_try_claim_all_lightning_receives() !=
      14560) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_try_claim_lightning_receive() !=
      43209) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_unlock_vtxos() != 11806) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_validate_arkoor_address() !=
      30498) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_vtxo_encoded() != 25637) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_method_wallet_vtxos() != 33207) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_constructor_onchainwallet_custom() != 33645) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_constructor_onchainwallet_default() != 61714) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
  if (uniffi_bark_ffi_checksum_constructor_wallet_open() != 45531) {
    throw UniffiInternalError.panicked("UniFFI API checksum mismatch");
  }
}

void ensureInitialized() {
  _checkApiVersion();
  _checkApiChecksums();
}

@Deprecated("Use ensureInitialized instead")
void initialize() {
  ensureInitialized();
}
