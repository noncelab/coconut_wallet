import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:crypto/crypto.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_board.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_exit.dart';
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

/// 출금 수수료 지갑의 12단어. 아크 12단어에서 HMAC으로 따로 뽑아 아크 키와 섞이지 않게
String deriveExitFeeMnemonic(Uint8List mnemonic) {
  final digest = Hmac(sha256, utf8.encode('coconut-ark-exit-fee-wallet')).convert(mnemonic).bytes;
  final seed = Seed.fromEntropy(Uint8List.fromList(digest.sublist(0, 16)));
  try {
    return utf8.decode(seed.mnemonic);
  } finally {
    seed.wipe();
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

  /// 서버 없이 출금할 때 출금 거래 수수료(CPFP)를 내는 bark 온체인 지갑, 아크 지갑과 함께 열림
  final Map<String, bark.OnchainWallet> _exitFeeWallets = {};
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
    try {
      await wallet.maintenanceDelegated();
    } finally {
      await wallet.syncExits();
      await _closeClaimedExits(wallet);
    }
  });

  /// 모두 받은 출금의 bark 거래 내역 완료 처리
  Future<void> _closeClaimedExits(bark.Wallet wallet) async {
    final exits = await wallet.getExitVtxos();
    if (exits.isEmpty || !exits.every((exit) => exit.state is bark.ClaimedExitState)) return;
    await wallet.progressExits(feeRateSatPerVb: 1);
  }

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
  Future<ArkBoardTerms> boardTerms(String fingerprint) => withWallet(fingerprint, (wallet) async {
    final info = await wallet.arkInfo();
    if (info == null) throw StateError('The Ark server is not reachable');
    return ArkBoardTerms(
      minAmountSats: info.minBoardAmountSats,
      maxAmountSats: info.maxVtxoAmountSats,
      requiredConfirmations: info.requiredBoardConfirmations,
    );
  });

  @override
  Future<ArkBoardFunding> boardFunding(String fingerprint) => withWallet(fingerprint, (wallet) async {
    final info = await wallet.boardFundingAddress();
    return ArkBoardFunding(address: info.address, expiryHeight: info.expiryHeight, keypairIndex: info.keypairIndex);
  });

  @override
  Future<int> estimateBoardFee(String fingerprint, int amountSats) =>
      withWallet(fingerprint, (wallet) async => (await wallet.estimateBoardFee(amountSats: amountSats)).feeSats);

  @override
  Future<void> board(String fingerprint, {required String unsignedPsbtBase64, required ArkBoardFunding funding}) =>
      withWallet(
        fingerprint,
        (wallet) => wallet.boardPsbt(
          psbtBase64: unsignedPsbtBase64,
          keypairIndex: funding.keypairIndex,
          expiryHeight: funding.expiryHeight,
        ),
      );

  @override
  Future<String> broadcastTx(String fingerprint, String txHex) =>
      withWallet(fingerprint, (wallet) => wallet.broadcastTx(txHex: txHex));

  @override
  Future<int> estimateExportFee(String fingerprint, String address, {int? amountSats}) =>
      withWallet(fingerprint, (wallet) async {
        final estimate =
            amountSats == null
                ? await wallet.estimateOffboardAllFee(address: address)
                : await wallet.estimateSendOnchainFee(address: address, amountSats: amountSats);
        return estimate.feeSats;
      });

  @override
  Future<String> export(String fingerprint, String address, {int? amountSats}) => withWallet(
    fingerprint,
    (wallet) async =>
        amountSats == null
            ? (await wallet.offboardAll(bitcoinAddress: address)).txid
            : await wallet.sendOnchain(address: address, amountSats: amountSats),
  );

  bark.OnchainWallet _exitFeeWallet(String fingerprint) =>
      _exitFeeWallets[_key(fingerprint)] ?? (throw StateError('No exit fee wallet for $fingerprint'));

  /// 지금 권장 온체인 수수료율(sat/vB), 수수료 지갑이 체인에서 읽음
  Future<int> _exitFeeRate(String fingerprint) async {
    final rates = await _exitFeeWallet(fingerprint).feeRates();
    return max(1, (rates.regularSatPerKwu * 4 / 1000).ceil());
  }

  @override
  Future<ArkExitQuote> estimateExit(String fingerprint) => withWallet(fingerprint, (wallet) async {
    final feeWallet = _exitFeeWallet(fingerprint);
    final tip = await feeWallet.tipHeight();
    final vtxos = [
      for (final vtxo in await wallet.vtxos())
        if (vtxo.state is! bark.LockedVtxoState && vtxo.expiryHeight > tip) vtxo,
    ];
    final feeRate = await _exitFeeRate(fingerprint);
    // 더스트 한도보다 작은 VTXO처럼 체인에 올릴 수 없는 것은 하나씩 걸러 냄
    final exitable = <bark.Vtxo>[];
    for (final vtxo in vtxos) {
      try {
        await wallet.estimateEmergencyExitFee(vtxoIds: [vtxo.id], feeRateSatPerVb: feeRate, destination: null);
        exitable.add(vtxo);
      } catch (error) {
        Logger.error('ArkWalletService: VTXO ${vtxo.id} cannot exit on its own: $error');
      }
    }
    final leftOut = vtxos.where((vtxo) => !exitable.contains(vtxo)).fold(0, (sum, vtxo) => sum + vtxo.amountSats);
    vtxos
      ..clear()
      ..addAll(exitable);
    final ids = [for (final vtxo in vtxos) vtxo.id];
    final estimate =
        ids.isEmpty
            ? null
            : await wallet.estimateEmergencyExitFee(vtxoIds: ids, feeRateSatPerVb: feeRate, destination: null);
    return ArkExitQuote(
      vtxoIds: ids,
      amountSats: vtxos.fold(0, (sum, vtxo) => sum + vtxo.amountSats),
      feeSats: estimate?.totalFeeSats ?? 0,
      txCount: estimate?.txsToBroadcast ?? 0,
      feeRateSatPerVb: feeRate,
      firstExpiryHeight: vtxos.isEmpty ? null : vtxos.map((vtxo) => vtxo.expiryHeight).reduce(min),
      broadcastFeeSats: estimate?.exitBroadcastFeeSats ?? 0,
      claimFeeSats: estimate?.claimFeeSats ?? 0,
      exitDelta: (await wallet.arkInfo())?.vtxoExitDelta ?? 0,
      leftOutSats: leftOut,
    );
  });

  @override
  Future<String> exitFeeAddress(String fingerprint) =>
      withWallet(fingerprint, (_) => _exitFeeWallet(fingerprint).newAddress());

  @override
  ArkExitSteps exitSteps(String fingerprint) => _BarkExitSteps(this, fingerprint);

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
        _exitFeeWallets.remove(fingerprint)?.dispose();
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
    final config = bark.Config(
      serverAddress: ArkServerConfig.serverUrl,
      esploraAddress: ArkServerConfig.esploraUrl,
      daemonManualSync: true,
    );
    final exitFeeWallet = await bark.OnchainWallet.default_(
      network: _network(),
      mnemonic: deriveExitFeeMnemonic(mnemonic),
      config: config,
      datadir: datadir.path,
    );
    final wallet = await bark.Wallet.open(
      network: _network(),
      mnemonicOrSeed: utf8.decode(mnemonic),
      config: config,
      args: bark.WalletOpenArgs(
        datadir: datadir.path,
        onchain: exitFeeWallet,
        createIfNotExists: create,
        createWithoutServer: create,
        skipRecovery: !runRecovery,
      ),
    );
    _openWallets[_key(fingerprint)] = wallet;
    _exitFeeWallets[_key(fingerprint)] = exitFeeWallet;
    Logger.log('ArkWalletService: ${create ? 'created' : 'opened'} Ark wallet $fingerprint');
  }

  Future<void> _deleteLocked(String fingerprint) async {
    final wallet = _openWallets.remove(_key(fingerprint));
    if (wallet != null) await _close(wallet);
    _exitFeeWallets.remove(_key(fingerprint))?.dispose();
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

/// bark로 출금 단계를 넘김
class _BarkExitSteps implements ArkExitSteps {
  _BarkExitSteps(this._service, this._fingerprint);

  final ArkWalletService _service;
  final String _fingerprint;

  Future<T> _withFeeWallet<T>(Future<T> Function(bark.Wallet wallet, bark.OnchainWallet feeWallet) action) =>
      _service.withWallet(_fingerprint, (wallet) => action(wallet, _service._exitFeeWallet(_fingerprint)));

  @override
  Future<int> exitFeeConfirmedSats() => _withFeeWallet((_, feeWallet) async {
    await feeWallet.sync_();
    return (await feeWallet.balance()).confirmedSats;
  });

  @override
  Future<int> exitFeePendingSats() => _withFeeWallet((_, feeWallet) async {
    await feeWallet.sync_();
    return (await feeWallet.balance()).pendingSats;
  });

  @override
  Future<void> startExit(List<String> vtxoIds) =>
      _withFeeWallet((wallet, _) => wallet.startExitForVtxos(vtxoIds: vtxoIds));

  @override
  Future<ArkExitProgress> progressExit(List<String> vtxoIds, int feeRateSatPerVb) => _withFeeWallet((
    wallet,
    feeWallet,
  ) async {
    await feeWallet.sync_();
    await wallet.syncExits();
    for (final status in await wallet.progressExits(feeRateSatPerVb: feeRateSatPerVb)) {
      if (status.error != null) Logger.error('ArkWalletService: exit of ${status.vtxoId}: ${status.error}');
    }
    final exits = {for (final exit in await wallet.getExitVtxos()) exit.vtxoId: exit};
    final mine = [for (final id in vtxoIds) exits[id]];
    final txs = [
      for (final exit in mine)
        if (exit?.state case final bark.ProcessingExitState processing) ...processing.transactions,
    ];
    return ArkExitProgress(
      spent: mine.any((exit) => exit?.state is bark.VtxoAlreadySpentExitState || exit?.state is bark.CanceledExitState),
      onChain: mine.every(
        (exit) =>
            exit != null &&
            (exit.state is bark.AwaitingDeltaExitState ||
                exit.state is bark.ClaimableExitState ||
                exit.state is bark.ClaimInProgressExitState ||
                exit.state is bark.ClaimedExitState),
      ),
      allClaimable: mine.every((exit) => exit?.isClaimable ?? false),
      claimableHeight: await wallet.allExitsClaimableAtHeight(),
      txDone: txs.where((tx) => tx.status is bark.ConfirmedExitTxStatus).length,
      txTotal: txs.length,
    );
  });

  @override
  Future<({String txid, int feeSats})> claimExit(String address, int feeRateSatPerVb) =>
      _withFeeWallet((wallet, _) async {
        final claim = await wallet.drainExits(
          vtxoIds: const [],
          drainAll: true,
          address: address,
          feeRateSatPerVb: feeRateSatPerVb,
        );
        final signed = await wallet.signExitClaimInputs(psbtBase64: claim.psbtBase64);
        final txid = await wallet.broadcastTx(txHex: bark.extractTxFromPsbt(psbtBase64: signed));
        return (txid: txid, feeSats: claim.feeSats);
      });

  /// 확정된 남은 수수료를 모두 [address]로. 1,000 sats보다 적게 남으면 보내지 않음
  @override
  Future<int> returnExitFee(String address, int feeRateSatPerVb) => _withFeeWallet((_, feeWallet) async {
    await feeWallet.sync_();
    final confirmed = [
      for (final utxo in await feeWallet.utxos())
        if (utxo is bark.LocalOnchainUtxo && utxo.confirmationHeight != null) utxo,
    ];
    final total = confirmed.fold<int>(0, (sum, utxo) => sum + utxo.amountSats);
    // 입력 하나 약 68vB, 출력과 기본 약 54vB로 넉넉히 잡음
    final amount = total - feeRateSatPerVb * (68 * confirmed.length + 54);
    if (amount < 1000) return 0;
    await feeWallet.send(address: address, amountSats: amount, feeRateSatPerVb: feeRateSatPerVb);
    return amount;
  });
}
