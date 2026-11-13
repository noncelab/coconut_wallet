// 미확정 거래 서명 확인 테스트 공용 도구. 서버(ElectrumService)만 가짜이고 서명은 모두 실제 키로 만든다.
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/state/state_manager_interface.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_util.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';

import '../../../repository/realm/test_realm_manager.dart';

const walletId = 1;
const _locktime = 1792646340;

Seed _seed(int byte) => Seed.fromEntropy(Uint8List.fromList(List.filled(16, byte)));

KeyStore _publicKey(KeyStore key) =>
    KeyStore.fromExtendedPublicKey(key.extendedPublicKey.serialize(), key.masterFingerprint);

/// 서버(ElectrumService)만 가짜. 주소 기록·UTXO 목록·거래 원문·블록 시각을 정해진 값으로 돌려준다
class FakeElectrum implements ElectrumService {
  final Map<String, String> rawByHash = {};
  final Map<String, List<GetTxHistoryRes>> historyByAddress = {};
  final Map<String, List<ListUnspentRes>> unspentByAddress = {};

  /// 거래 원문 응답을 바꾼다(다른 거래 돌려주기, 연결 끊김 등). null이면 [rawByHash]
  Future<String> Function(String txHash)? transactionSource;

  @override
  Future<List<GetTxHistoryRes>> getHistory(AddressType addressType, String address) async =>
      historyByAddress[address] ?? [];

  @override
  Future<List<ListUnspentRes>> getUnspentList(AddressType addressType, String address) async =>
      unspentByAddress[address] ?? [];

  @override
  Future<String> getTransaction(String txHash, {bool? verbose, Duration timeout = const Duration(seconds: 5)}) async {
    if (transactionSource case final source?) return source(txHash);
    return rawByHash[txHash] ?? (throw StateError('unavailable $txHash'));
  }

  /// ElectrumService.getPreviousTransactions와 같은 규칙: 넘겨받은 거래를 먼저 쓰고, 받은 거래는 번호가 맞을 때만 쓴다
  @override
  Future<List<Transaction>> getPreviousTransactions(
    Transaction transaction, {
    List<Transaction>? existingTxList,
  }) async {
    final byHash = {for (final tx in existingTxList ?? const <Transaction>[]) tx.transactionHash: tx};
    for (final input in transaction.inputs) {
      if (byHash.containsKey(input.transactionHash)) continue;
      try {
        final tx = Transaction.parse(await getTransaction(input.transactionHash));
        if (tx.transactionHash == input.transactionHash) byHash[input.transactionHash] = tx;
      } catch (_) {}
    }
    return [
      for (final input in transaction.inputs)
        if (byHash[input.transactionHash] case final tx?) tx,
    ];
  }

  @override
  Future<Map<int, BlockTimestamp>> fetchBlocksByHeight(Set<int> heights) async => {
    for (final height in heights) height: BlockTimestamp(height, DateTime(2026, 11, 1)),
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class NoopState implements StateManagerInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// 한 지갑과 그 키로 서명하는 도구(핫 지갑·볼트·하드웨어 지갑 모두 PSBT에 서명해 돌려준다)
class WalletSigner {
  WalletSigner(this.name, this.item, this.purpose, this.addressType, this._sign, {this.scriptPathPolicy});

  final String name;
  final WalletItemBase item;
  final String purpose;
  final AddressType addressType;
  final String Function(String psbt) _sign;
  final Policy? scriptPathPolicy;

  String address(int index, {bool isChange = false}) => item.walletBase.getAddress(index, isChange: isChange);

  String path(int index, {bool isChange = false}) => '$purpose/${isChange ? 1 : 0}/$index';

  /// [coins]를 모두 써서 [recipients]에게 보내는, 이 지갑 키로 서명한 거래. [sendMax]면 잔돈 없이 전부 보낸다
  Transaction pay(
    List<UtxoState> coins,
    Map<String, int> recipients, {
    double feeRate = 2,
    int changeIndex = 0,
    bool sendMax = false,
  }) {
    final unsigned =
        TransactionBuilder(
          availableUtxos: coins,
          recipients: recipients,
          feeRate: feeRate,
          changeDerivationPath: path(changeIndex, isChange: true),
          walletItemBase: item,
          isFeeSubtractedFromAmount: sendMax,
          isUtxoFixed: true,
          scriptPathPolicy: scriptPathPolicy,
        ).build().transaction!;
    return sign(unsigned);
  }

  /// 앱이 만든 서명 전 거래(수수료 올리기·빨리 받기 결과 등)에 이 지갑 키로 서명한다
  Transaction sign(Transaction unsigned) =>
      Psbt.parse(_sign(Psbt.fromTransaction(unsigned, item.walletBase).serialize())).getSignedTransaction(addressType);

  /// 이 지갑 주소들로 들어온 확정 입금 거래 하나와 그 코인들
  ({Transaction funding, List<UtxoState> coins}) funded(List<int> amounts, int tag, {List<int>? indexes}) {
    final funding = fundingTransaction([
      for (final (i, amount) in amounts.indexed) (address(indexes?[i] ?? 0), amount),
    ], tag);
    return (
      funding: funding,
      coins: [
        for (final (i, amount) in amounts.indexed)
          UtxoState(
            transactionHash: funding.transactionHash,
            index: i,
            amount: amount,
            derivationPath: path(indexes?[i] ?? 0),
            blockHeight: 100,
            to: address(indexes?[i] ?? 0),
            timestamp: DateTime(2026, 11, 1),
          ),
      ],
    );
  }
}

/// 이 테스트와 상관없는 곳에서 확정된 입금 거래(입력은 임의의 값)
Transaction fundingTransaction(List<(String, int)> outputs, int tag) {
  final input = TransactionInput.forPayment(tag.toRadixString(16).padLeft(64, '0'), 0)
    ..witnessList = ['30${'11' * 69}01', '02${'22' * 32}'];
  return Transaction.withInputsAndOutputs(
    [input],
    [for (final (address, amount) in outputs) TransactionOutput.forPayment(amount, address)],
    AddressType.p2wpkh,
  );
}

/// 서명은 그대로 두고 출력만 [to] 하나로 바꾼 거래(수수료는 1,000 sats 더 냄). 원래 서명은 바뀐 거래에 맞지 않는다
Transaction redirected(Transaction tx, String to) {
  final forged = Transaction.parse(tx.serialize());
  final total = forged.outputs.fold(0, (sum, output) => sum + output.amount);
  forged.outputs
    ..clear()
    ..add(TransactionOutput.forPayment(total - 1000, to));
  return forged;
}

/// [redirected]에 더해 서명 바이트를 엉뚱한 값으로 바꾼 거래(공개키·스크립트·제어 블록은 그대로)
Transaction withGarbageSignatures(Transaction tx, String to, AddressType type) {
  final forged = redirected(tx, to);
  for (final input in forged.inputs) {
    final witness = input.witnessList;
    // 서명 자리: P2WPKH [서명, 공개키], P2WSH [빈 값, 서명들, 스크립트], Taproot [서명] 또는 [서명들, 스크립트, 제어 블록]
    final slots =
        type == AddressType.p2wpkh
            ? [0]
            : type == AddressType.p2wsh
            ? [for (var i = 1; i < witness.length - 1; i++) i]
            : witness.length == 1
            ? [0]
            : [for (var i = 0; i < witness.length - 2; i++) i];
    for (final i in slots) {
      final item = witness[i];
      if (item.isNotEmpty) witness[i] = '${'11' * (item.length ~/ 2 - 1)}${item.substring(item.length - 2)}';
    }
  }
  return forged;
}

/// [redirected]에 더해 증인 데이터(서명)를 모두 뺀 거래
Transaction withoutWitness(Transaction tx, String to) {
  final forged = redirected(tx, to);
  for (final input in forged.inputs) {
    input.witnessList = [];
  }
  return forged;
}

/// P2WPKH 입력 하나에 [key]로 SIGHASH_ALL 서명을 넣는다(여러 사람이 각자 자기 입력에 서명하는 거래용)
void signP2wpkhInput(Transaction tx, int index, TransactionOutput prevout, HDWallet key) {
  final sigHash = Codec.decodeHex(tx.getSigHash(index, prevout, AddressType.p2wpkh));
  final signature = Converter.rawToDerSignature(Ecc.signEcdsa(sigHash, key.privateKey!));
  // rawToDerSignature가 SIGHASH_ALL 바이트까지 붙인다
  tx.inputs[index].witnessList = [Codec.encodeHex(signature), Codec.encodeHex(key.publicKey)];
}

SinglesigWalletItem singlesigItem(String descriptor, WalletImportSource source, {SingleSignatureVault? hot}) =>
    SinglesigWalletItem(
      id: walletId,
      name: 'Single',
      colorIndex: 0,
      iconIndex: 0,
      descriptor: descriptor,
      walletImportSource: source,
      hotWalletMetadata:
          hot == null
              ? null
              : HotWalletMetadata(
                walletId: walletId,
                secureStorageKey: 'unused',
                masterFingerprint: hot.keyStore.masterFingerprint,
                derivationPath: hot.derivationPath,
                accountIndex: 0,
                backupVerified: true,
                enterPassphraseWhenSigning: false,
                createdAt: DateTime(2026),
              ),
    );

/// 이 기기 지갑이 될 수 있는 모든 유형과 서명 도구. [base]로 시드를 정한다
List<WalletSigner> walletSigners(int base) {
  final single = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, base + 1)));
  final cosigners = [for (var i = 2; i <= 4; i++) KeyStore.fromSeed(_seed(base + i), AddressType.p2wsh)];
  final multisig = MultisignatureVault.fromKeyStoreList(cosigners, 2);
  final multisigItem = MultisigWalletItem(
    id: walletId,
    name: 'Multisig',
    colorIndex: 0,
    iconIndex: 0,
    descriptor: multisig.descriptor,
    signers: [for (var i = 0; i < 3; i++) MultisigSigner(name: 'S$i', iconIndex: i, colorIndex: i, memo: '')],
    requiredSignatureCount: 2,
  );
  String Function(String) pair(int a, int b) =>
      (psbt) =>
          cosigners[b].addSignatureToPsbt(cosigners[a].addSignatureToPsbt(psbt, AddressType.p2wsh), AddressType.p2wsh);
  final parent = KeyStore.fromSeed(_seed(base + 5), AddressType.p2tr);
  final beneficiary = KeyStore.fromSeed(_seed(base + 6), AddressType.p2tr);
  final publicPolicy = InheritancePolicy(_publicKey(beneficiary), _locktime);
  final taproot = TaprootWallet.fromKeyStoreList([_publicKey(parent)], [publicPolicy]);
  final scriptPathItem = TaprootWalletItem(
    id: walletId,
    name: 'Inheritance',
    colorIndex: 0,
    iconIndex: 0,
    descriptor: taproot.descriptor,
    keyPathSeedInfos: [],
    scriptPathSeedInfos: [
      TaprootScriptPathSeedInfo(
        miniscript: publicPolicy.toMiniscript(),
        extendedPublicKeys: [beneficiary.extendedPublicKey.serialize()],
      ),
    ],
  );
  return [
    WalletSigner(
      'p2wpkh 핫 지갑',
      singlesigItem(single.descriptor, WalletImportSource.coconutVault, hot: single),
      "m/84'/1'/0'",
      AddressType.p2wpkh,
      single.addSignatureToPsbt,
    ),
    WalletSigner(
      'p2wpkh 보기 전용 + 볼트 PSBT',
      singlesigItem(single.descriptor, WalletImportSource.coconutVault),
      "m/84'/1'/0'",
      AddressType.p2wpkh,
      single.addSignatureToPsbt,
    ),
    for (final (a, b) in [(0, 1), (0, 2), (1, 2)])
      WalletSigner('p2wsh 2-of-3 (키 ${a + 1}+${b + 1})', multisigItem, "m/48'/1'/0'/2'", AddressType.p2wsh, pair(a, b)),
    WalletSigner(
      'p2tr 키 경로',
      TaprootWalletItem(
        id: walletId,
        name: 'Taproot',
        colorIndex: 0,
        iconIndex: 0,
        descriptor: taproot.descriptor,
        keyPathSeedInfos: [_publicKey(parent).extendedPublicKey.serialize()],
        scriptPathSeedInfos: [],
      ),
      "m/86'/1'/0'",
      AddressType.p2tr,
      TaprootVault.fromKeyStoreList([parent], [publicPolicy]).addSignatureToPsbt,
    ),
    WalletSigner(
      'p2tr 스크립트 경로',
      scriptPathItem,
      "m/86'/1'/0'",
      AddressType.p2tr,
      TaprootVault.fromKeyStoreList(
        [_publicKey(parent)],
        [InheritancePolicy(beneficiary, _locktime)],
      ).addSignatureToPsbt,
      scriptPathPolicy: scriptPathItem.defaultPolicy,
    ),
  ];
}

GetTxHistoryRes history(Transaction tx, int height) => GetTxHistoryRes(height: height, txHash: tx.transactionHash);

/// 이 기기의 지갑(Realm에 주소 등록)과 같은 서버를 보는 실제 동기화. 주소 하나의 이벤트를 ScriptSyncService와 같은 순서로
/// 처리한다: 거래 동기화 → 그 결과의 거래가 모두 끝나면 UTXO 조회
class SyncedWallet {
  SyncedWallet(this.realm, this.item, {required this.purpose, int addressCount = 100}) {
    realm.realm.write(() {
      realm.realm.add(RealmWalletBase(walletId, 0, 0, item.descriptor, item.name, item.walletType.name));
      var id = 1;
      for (final isChange in [false, true]) {
        for (var i = 0; i < addressCount; i++) {
          realm.realm.add(
            RealmWalletAddress(
              id++,
              walletId,
              item.walletBase.getAddress(i, isChange: isChange),
              i,
              isChange,
              '$purpose/${isChange ? 1 : 0}/$i',
              false,
              0,
              0,
              0,
            ),
          );
        }
      }
    });
    addresses = AddressRepository(realm);
    utxos = UtxoRepository(realm);
    txs = TransactionRepository(realm);
  }

  final TestRealmManager realm;
  final WalletItemBase item;
  final String purpose;
  final server = FakeElectrum();

  /// 앱을 다시 켜면 처리 상태가 비워진다
  ScriptCallbackService callbacks = ScriptCallbackService();
  late final AddressRepository addresses;
  late final UtxoRepository utxos;
  late final TransactionRepository txs;
  var utxoFetches = 0;

  String address(int index, {bool isChange = false}) => item.walletBase.getAddress(index, isChange: isChange);

  void publish(Iterable<Transaction> transactions) {
    for (final tx in transactions) {
      server.rawByHash[tx.transactionHash] = tx.serialize();
    }
  }

  /// [tx]에서 이 주소로 가는 출력들의 서버 UTXO 응답
  List<ListUnspentRes> unspent(Transaction tx, int height, {int index = 0, bool isChange = false}) => [
    for (final (i, output) in tx.outputs.indexed)
      if (output.getAddress() == address(index, isChange: isChange))
        ListUnspentRes(height: height, txHash: tx.transactionHash, txPos: i, value: output.amount),
  ];

  /// 서버가 이 주소에 [historyList]·[unspentList]를 돌려주게 하고, 그 주소의 상태를 만든다
  ScriptStatus _serve(List<GetTxHistoryRes> historyList, List<ListUnspentRes> unspentList, int index, bool isChange) {
    final target = address(index, isChange: isChange);
    server.historyByAddress[target] = historyList;
    server.unspentByAddress[target] = unspentList;
    return ScriptStatus(
      scriptPubKey: target,
      status: historyList.map((h) => '${h.txHash}:${h.height}').join(','),
      timestamp: DateTime.now(),
      derivationPath: '$purpose/${isChange ? 1 : 0}/$index',
      address: target,
      index: index,
      isChange: isChange,
    );
  }

  TransactionSyncService _transactionSync() =>
      TransactionSyncService(server, txs, TransactionRecordService(server, addresses), NoopState(), utxos, callbacks);

  UtxoSyncService _utxoSync() => UtxoSyncService(server, NoopState(), utxos, txs, addresses);

  Future<void> sync(
    List<GetTxHistoryRes> historyList, {
    List<ListUnspentRes> unspentList = const [],
    int index = 0,
    bool isChange = false,
  }) async {
    final status = _serve(historyList, unspentList, index, isChange);
    callbacks.registerFetchUtxosCallback(getScriptKey(walletId, status.derivationPath), () async {
      utxoFetches++;
      await _utxoSync().fetchScriptUtxo(item, status);
    });
    final result = await _transactionSync().fetchScriptTransaction(item, status, now: DateTime(2026, 11, 11));
    await callbacks.registerTransactionDependency(item, status, result.txHashes);
  }

  /// 주소 하나의 거래 동기화만 전체 동기화처럼 돌린다(UTXO 조회 없음). 다른 처리 사이에 끼워 넣는 순서를 만들 때 쓴다
  Future<void> syncTransactionsOnly(List<GetTxHistoryRes> historyList, {int index = 0, bool isChange = false}) =>
      _transactionSync().fetchScriptTransaction(
        item,
        _serve(historyList, const [], index, isChange),
        inBatchProcess: true,
        now: DateTime(2026, 11, 11),
      );

  /// 전체 동기화(ScriptSyncService.syncBatchScriptStatusList)의 거래·UTXO 단계와 같은 순서로 여러 주소를 처리한다:
  /// 모든 주소의 거래 → 모든 주소의 UTXO → 보내는 중 코인 만들기 → 기록 없는 코인 정리. 잔액·구독 단계는 없다
  Future<void> syncBatch(
    List<({List<GetTxHistoryRes> history, List<ListUnspentRes> unspent, int index, bool isChange})> scripts,
  ) async {
    final statuses = [for (final s in scripts) _serve(s.history, s.unspent, s.index, s.isChange)];
    final transactionSync = _transactionSync();
    await Future.wait(
      statuses.map(
        (status) =>
            transactionSync.fetchScriptTransaction(item, status, inBatchProcess: true, now: DateTime(2026, 11, 11)),
      ),
    );
    final utxoSync = _utxoSync();
    await Future.wait(statuses.map((status) => utxoSync.fetchScriptUtxo(item, status, inBatchProcess: true)));
    await utxoSync.createOutgoingUtxos(item);
    await utxoSync.cleanupOrphanedUtxos(item);
  }

  UtxoState? coin(String txHash, int index) => utxos.getUtxoState(walletId, getUtxoId(txHash, index));

  /// 보낼 수 있는 금액(확정·잠기지 않은 코인 합)
  int get spendable => utxos
      .getUtxoStateList(walletId)
      .where((utxo) => utxo.status == UtxoStatus.unspent)
      .fold(0, (sum, utxo) => sum + utxo.amount);

  /// 거래 기록·코인 상태·RBF/CPFP 기록 전체
  Map<String, Object> snapshot() => {
    'records': {
      for (final record in txs.getTransactionRecordList(walletId))
        record.transactionHash: '${record.transactionType.name}:${record.amount}:${record.blockHeight}',
    },
    'utxos': {
      for (final utxo in utxos.getUtxoStateList(walletId))
        utxo.utxoId: '${utxo.status.name}:${utxo.spentByTransactionHash}:${utxo.amount}',
    },
    'rbf': [for (final h in realm.realm.all<RealmRbfHistory>()) '${h.originalTransactionHash}>${h.transactionHash}']
      ..sort(),
    'cpfp': [
      for (final h in realm.realm.all<RealmCpfpHistory>()) '${h.parentTransactionHash}>${h.childTransactionHash}',
    ]..sort(),
  };

  /// [txHash]를 가리키는 기록이 하나도 없는지(거래·코인·RBF/CPFP 기록)
  bool leavesNoTrace(String txHash) =>
      realm.realm.all<RealmTransaction>().every((tx) => tx.transactionHash != txHash) &&
      realm.realm.all<RealmUtxo>().every(
        (utxo) => utxo.transactionHash != txHash && utxo.spentByTransactionHash != txHash,
      ) &&
      realm.realm.all<RealmRbfHistory>().every(
        (h) => h.transactionHash != txHash && h.originalTransactionHash != txHash,
      ) &&
      realm.realm.all<RealmCpfpHistory>().every(
        (h) => h.parentTransactionHash != txHash && h.childTransactionHash != txHash,
      );
}

/// [walletSigners]의 Taproot 지갑과 같은 시드의 키(남의 입력이 섞인 거래에 직접 서명할 때 쓴다)
({KeyStore parent, KeyStore beneficiary}) taprootKeys(int base) => (
  parent: KeyStore.fromSeed(_seed(base + 5), AddressType.p2tr),
  beneficiary: KeyStore.fromSeed(_seed(base + 6), AddressType.p2tr),
);

Uint8List _evenY(HDWallet key) => key.publicKey[0] == 0x03 ? Ecc.privateNegate(key.privateKey!)! : key.privateKey!;

Uint8List _leafHash(String script, String controlBlock) {
  final bytes = Codec.decodeHex(script);
  return Hash.taggedHash('TapLeaf', [
    Codec.decodeHex(controlBlock)[0] & 0xfe,
    ...Codec.encodeVariableInteger(bytes.length),
    ...bytes,
  ]);
}

/// 섞인 거래의 내 Taproot 스크립트 경로 입력에 [leafKey]로 SIGHASH_DEFAULT 서명을 넣는다.
/// [script]·[controlBlock]은 같은 코인의 실제 스크립트 경로 지출에서 가져온다(거래가 아니라 코인 주소에 달림)
void signTaprootScriptPathInput(
  Transaction tx,
  int index,
  List<TransactionOutput> prevouts,
  HDWallet leafKey,
  String script,
  String controlBlock,
) {
  final sigHash = tx.getTaprootSigHash(
    index,
    prevouts,
    isTapscript: true,
    tapleafHash: _leafHash(script, controlBlock),
    keyVersion: 0,
    codesepPos: 0xffffffff,
  );
  final signature = Ecc.signSchnorr(Codec.decodeHex(sigHash), _evenY(leafKey), auxRand: Uint8List(32));
  tx.inputs[index].witnessList = [Codec.encodeHex(signature), script, controlBlock];
}

/// 섞인 거래의 내 Taproot 키 경로 입력에 서명한다. 출력 키는 내부 키에 TapTweak(내부 키, 머클 루트 = 잎 하나)을 더한 것
void signTaprootKeyPathInput(
  Transaction tx,
  int index,
  List<TransactionOutput> prevouts,
  HDWallet internalKey,
  String script,
  String controlBlock,
) {
  final tweak = Hash.hashTapTweak(
    'TapTweak',
    Codec.decodeHex(controlBlock).sublist(1, 33),
    _leafHash(script, controlBlock),
  );
  var secret = Ecc.privateAdd(_evenY(internalKey), tweak)!;
  if (Ecc.pointFromScalar(secret, true)![0] == 0x03) secret = Ecc.privateNegate(secret)!;
  final sigHash = tx.getTaprootSigHash(index, prevouts);
  tx.inputs[index].witnessList = [
    Codec.encodeHex(Ecc.signSchnorr(Codec.decodeHex(sigHash), secret, auxRand: Uint8List(32))),
  ];
}

/// 서명 바이트는 그대로 두고 첫 입력 서명의 해시 유형만 SIGHASH_NONE(0x02)으로 바꾼 거래(증인은 거래 번호에 들지 않아 번호가 같다)
Transaction withSighashNone(Transaction tx, AddressType type) {
  final forged = Transaction.parse(tx.serialize());
  final witness = forged.inputs.first.witnessList;
  final index = type == AddressType.p2wsh ? 1 : 0;
  final signature = witness[index];
  witness[index] = signature.length == 128 ? '${signature}02' : '${signature.substring(0, signature.length - 2)}02';
  return forged;
}
