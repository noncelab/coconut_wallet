import 'dart:convert';
import 'dart:io';

import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_server_config.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_vtxo.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_backend.dart';
import 'package:coconut_wallet/services/security/hot_wallet_lifecycle_lock.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

String _masterFingerprint(({Uint8List mnemonic, String networkType}) input) {
  Seed? seed;
  try {
    NetworkType.setNetworkType(NetworkType.getNetworkType(input.networkType));
    seed = Seed.fromMnemonic(input.mnemonic, passphrase: Uint8List(0));
    final vault = SingleSignatureVault.fromSeed(seed);
    try {
      return vault.keyStore.masterFingerprint.toLowerCase();
    } finally {
      vault.keyStore.wipeSeed();
    }
  } finally {
    seed?.wipe();
    input.mnemonic.fillRange(0, input.mnemonic.length, 0);
  }
}

/// 결제 호출 전후 내역을 비교해 그 호출이 만든 거래 id. bark 결제 호출은 거래 id를 돌려주지 않음
int? newestCreatedMovementId(Set<int> before, Iterable<int> after) {
  final created = after.where((id) => !before.contains(id));
  return created.isEmpty ? null : created.reduce((a, b) => a > b ? a : b);
}

class ArkWalletLockedException implements Exception {
  ArkWalletLockedException(this.fingerprint);

  final String fingerprint;

  @override
  String toString() => 'Ark wallet $fingerprint is not open';
}

/// bark 아크 지갑. 지갑은 12단어(패스프레이즈 없음)의 마스터 지문으로 구분
class ArkWalletService implements ArkWalletBackend {
  static final ArkWalletService _instance = ArkWalletService._();
  factory ArkWalletService() => _instance;
  ArkWalletService._();

  final Map<String, bark.Wallet> _openWallets = {};
  final Map<String, HotWalletLifecycleLock> _locks = {};
  Directory? _baseDir;

  @override
  bool isOpen(String fingerprint) => _openWallets.containsKey(_key(fingerprint));

  /// 사본으로 계산하므로 [mnemonic]은 그대로 둠
  @override
  Future<String> fingerprintOf(Uint8List mnemonic) => compute(_masterFingerprint, (
    mnemonic: Uint8List.fromList(mnemonic),
    networkType: NetworkType.currentNetworkType.toString(),
  ));

  Future<bool> exists(String fingerprint) async => (await _datadir(fingerprint)).exists();

  Future<T> withWallet<T>(String fingerprint, Future<T> Function(bark.Wallet wallet) action) {
    return _lock(fingerprint).synchronized(() async {
      final wallet = _openWallets[_key(fingerprint)];
      if (wallet == null) throw ArkWalletLockedException(fingerprint);
      return action(wallet);
    });
  }

  /// 서버 없이 만들 수 있음. [restore]면 서버에 닿을 때 bark 복구를 함께 돌리고, 못 돌렸으면 복구 대기로 표시
  @override
  Future<void> create(String fingerprint, Uint8List mnemonic, {required bool restore}) {
    return _lock(fingerprint).synchronized(() async {
      final datadir = await _datadir(fingerprint);
      if (await datadir.exists()) await _deleteLocked(fingerprint);
      final runRecovery = restore && await canReachServer();
      await _open(fingerprint, mnemonic, create: true, runRecovery: runRecovery);
      if (!restore) return;
      final status = _openWallets[_key(fingerprint)]!.recoveryStatus();
      Logger.log('ArkWalletService: seed recovery of $fingerprint: ${status.runtimeType}');
      if (status is! bark.CompletedRecoveryStatus) await File(_recoveryPendingPath(datadir)).create();
    });
  }

  @override
  Future<void> open(String fingerprint, Uint8List mnemonic) {
    return _lock(fingerprint).synchronized(() async {
      if (isOpen(fingerprint)) return;
      await _open(fingerprint, mnemonic, create: false, runRecovery: false);
    });
  }

  @override
  Future<bool> isRecoveryPending(String fingerprint) async =>
      File(_recoveryPendingPath(await _datadir(fingerprint))).exists();

  @override
  Future<ArkBalance> balance(String fingerprint) =>
      withWallet(fingerprint, (wallet) async => ArkBalance.fromBark(await wallet.balance()));

  @override
  Future<void> sync(String fingerprint) => withWallet(fingerprint, (wallet) async {
    await wallet.maintenanceDelegated();
    await wallet.syncExits();
  });

  @override
  Future<List<ArkVtxo>> vtxos(String fingerprint) =>
      withWallet(fingerprint, (wallet) async => (await wallet.vtxos()).map(ArkVtxo.fromBark).toList());

  @override
  Future<int?> tipHeight() async {
    final response = await http
        .get(Uri.parse('${ArkServerConfig.esploraUrl.replaceFirst(RegExp(r'/+$'), '')}/blocks/tip/height'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    return int.tryParse(response.body.trim());
  }

  @override
  Future<List<String>> expiringVtxoIds(String fingerprint, int withinBlocks) => withWallet(
    fingerprint,
    (wallet) async => (await wallet.getExpiringVtxos(thresholdBlocks: withinBlocks)).map((vtxo) => vtxo.id).toList(),
  );

  @override
  Future<Set<String>> renewingVtxoIds(String fingerprint) =>
      withWallet(fingerprint, (wallet) async => (await wallet.pendingRoundInputVtxos()).map((vtxo) => vtxo.id).toSet());

  @override
  Future<int> estimateRenewFee(String fingerprint, List<String> vtxoIds) =>
      withWallet(fingerprint, (wallet) async => (await wallet.estimateRefreshFee(vtxoIds: vtxoIds)).feeSats);

  @override
  Future<int?> vtxoLifetime(String fingerprint) =>
      withWallet(fingerprint, (wallet) async => (await wallet.arkInfo())?.vtxoLifetime);

  @override
  Future<void> renew(String fingerprint, List<String> vtxoIds) =>
      withWallet(fingerprint, (wallet) => wallet.refreshVtxosDelegated(vtxoIds: vtxoIds));

  @override
  Future<List<ArkMovement>> history(String fingerprint) =>
      withWallet(fingerprint, (wallet) async => (await wallet.history()).map(ArkMovement.fromBark).toList());

  @override
  Future<String> newArkAddress(String fingerprint) => withWallet(fingerprint, (wallet) => wallet.newAddress());

  @override
  Future<ArkLightningInvoice> createLightningInvoice(String fingerprint, int amountSats, {String? description}) =>
      withWallet(fingerprint, (wallet) async {
        final fee = await wallet.estimateLightningReceiveFee(amountSats: amountSats);
        final invoice = await wallet.bolt11Invoice(amountSats: amountSats, description: description, token: null);
        return ArkLightningInvoice(
          invoice: invoice.invoice,
          paymentHash: invoice.paymentHash,
          amountSats: invoice.amountSats,
          feeSats: fee.feeSats,
        );
      });

  @override
  Future<int> estimateSendFee(String fingerprint, ArkPaymentRail rail, int amountSats) =>
      withWallet(fingerprint, (wallet) async {
        final estimate = switch (rail) {
          ArkPaymentRail.ark => await wallet.estimateArkoorPaymentFee(amountSats: amountSats),
          ArkPaymentRail.lightningInvoice ||
          ArkPaymentRail.lightningAddress => await wallet.estimateLightningSendFee(amountSats: amountSats),
          ArkPaymentRail.onchain => throw UnsupportedError('on-chain sends come in step 4'),
        };
        return estimate.feeSats;
      });

  @override
  Future<int?> send(
    String fingerprint,
    ArkPaymentRail rail,
    String destination,
    int amountSats, {
    bool invoiceHasAmount = false,
  }) => withWallet(fingerprint, (wallet) async {
    final before = (await wallet.history()).map((movement) => movement.id).toSet();
    Object? error;
    try {
      switch (rail) {
        case ArkPaymentRail.ark:
          await wallet.sendArkoorPayment(arkAddress: destination, amountSats: amountSats);
        case ArkPaymentRail.lightningInvoice:
          await wallet.payLightningInvoice(
            invoice: destination,
            amountSats: invoiceHasAmount ? null : amountSats,
            wait: false,
          );
        case ArkPaymentRail.lightningAddress:
          await wallet.payLightningAddress(
            lightningAddress: destination,
            amountSats: amountSats,
            comment: null,
            wait: false,
          );
        case ArkPaymentRail.onchain:
          throw UnsupportedError('on-chain sends come in step 4');
      }
    } catch (e) {
      error = e;
    }
    final movementId = newestCreatedMovementId(before, (await wallet.history()).map((movement) => movement.id));
    if (error != null) throw ArkPaymentException(error, movementId: movementId);
    return movementId;
  });

  @override
  Future<List<String>> listFingerprints() async {
    final base = await _base();
    if (!await base.exists()) return [];
    return [
      await for (final entity in base.list())
        if (entity is Directory) entity.uri.pathSegments.where((segment) => segment.isNotEmpty).last,
    ];
  }

  Future<void> delete(String fingerprint) => _lock(fingerprint).synchronized(() => _deleteLocked(fingerprint));

  @override
  Future<void> wipeAll() async {
    for (final fingerprint in _openWallets.keys.toList()) {
      await _lock(fingerprint).synchronized(() async {
        final wallet = _openWallets.remove(fingerprint);
        if (wallet != null) await _close(wallet);
      });
    }
    final base = await _base();
    if (await base.exists()) await base.delete(recursive: true);
  }

  /// 연결만 받고 멈춘 서버도 걸러 냄
  static Future<bool> canReachServer() async {
    final uri = Uri.tryParse(ArkServerConfig.serverUrl);
    if (uri == null || uri.host.isEmpty) return true;
    Socket? socket;
    try {
      const limit = Duration(seconds: 5);
      socket =
          uri.scheme == 'https'
              ? await SecureSocket.connect(uri.host, uri.port, timeout: limit)
              : await Socket.connect(uri.host, uri.port, timeout: limit);
      socket.write('HEAD / HTTP/1.1\r\nHost: ${uri.host}\r\nConnection: close\r\n\r\n');
      await socket.first.timeout(limit);
      return true;
    } catch (error) {
      Logger.error('ArkWalletService: Ark server unreachable: $error');
      return false;
    } finally {
      socket?.destroy();
    }
  }

  Future<void> _open(String fingerprint, Uint8List mnemonic, {required bool create, required bool runRecovery}) async {
    final datadir = await _datadir(fingerprint);
    await datadir.create(recursive: true);
    final wallet = await bark.Wallet.open(
      network: _network(),
      mnemonicOrSeed: utf8.decode(mnemonic),
      config: bark.Config(
        serverAddress: ArkServerConfig.serverUrl,
        esploraAddress: ArkServerConfig.esploraUrl,
        daemonManualSync: true,
      ),
      args: bark.WalletOpenArgs(
        datadir: datadir.path,
        createIfNotExists: create,
        createWithoutServer: create,
        skipRecovery: !runRecovery,
      ),
    );
    _openWallets[_key(fingerprint)] = wallet;
    Logger.log('ArkWalletService: ${create ? 'created' : 'opened'} Ark wallet $fingerprint');
  }

  Future<void> _deleteLocked(String fingerprint) async {
    final wallet = _openWallets.remove(_key(fingerprint));
    if (wallet != null) await _close(wallet);
    final datadir = await _datadir(fingerprint);
    if (await datadir.exists()) await datadir.delete(recursive: true);
  }

  Future<void> _close(bark.Wallet wallet) async {
    try {
      await wallet.stopDaemonWait();
    } catch (error) {
      Logger.error('ArkWalletService: failed to stop daemon: $error');
    }
    wallet.dispose();
  }

  bark.Network _network() {
    final network = NetworkType.currentNetworkType;
    if (network == NetworkType.mainnet) return bark.Network.bitcoin;
    if (network == NetworkType.testnet) return bark.Network.testnet;
    return bark.Network.regtest;
  }

  String _recoveryPendingPath(Directory datadir) => '${datadir.path}/coconut_recovery_pending';

  String _key(String fingerprint) => fingerprint.toLowerCase();

  HotWalletLifecycleLock _lock(String fingerprint) => _locks.putIfAbsent(_key(fingerprint), HotWalletLifecycleLock.new);

  Future<Directory> _base() async => _baseDir ??= Directory('${(await getApplicationSupportDirectory()).path}/bark');

  Future<Directory> _datadir(String fingerprint) async => Directory('${(await _base()).path}/${_key(fingerprint)}');
}
