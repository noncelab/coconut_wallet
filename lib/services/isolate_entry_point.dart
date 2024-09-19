import 'dart:convert';
import 'dart:isolate';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_lib/objectbox_entity.dart';
import 'package:flutter/services.dart';

void isolateEntryPoint(List<dynamic> args) async {
  final SendPort sendPort = args[0];
  final Map<String, dynamic> isolateData = args[1];
  final RootIsolateToken rootIsolateToken = args[2];

  /// Isolate (3) - initialize repository
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

  String dbDirectoryPath = isolateData['dbDirectoryPath'];
  BitcoinNetwork bitcoinNetwork = isolateData['bitcoinNetwork'];

  Repository.initialize(dbDirectoryPath);
  BitcoinNetwork.setNetwork(bitcoinNetwork);

  /// create WalletListItem
  List<SingleSignatureWallet> wallets = [];
  List<WalletFetchResult> fetchResults = [];
  int count = isolateData['count'];
  for (int i = 0; i < count; i++) {
    wallets
        .add(SingleSignatureWallet.fromDescriptor(isolateData['descriptor$i']));

    // get fetch result data
    List<TransactionEntity> txEntityList =
        (isolateData['txEntityList$i'] as List<String>)
            .map((entity) => TransactionEntity.fromJson(jsonDecode(entity)))
            .toList();

    List<UtxoEntity> utxoEntityList =
        (isolateData['utxoEntityList$i'] as List<String>)
            .map((entity) => UtxoEntity.fromJson(jsonDecode(entity)))
            .toList();

    Map<int, BlockHeaderEntity> blockEntityMap =
        (isolateData['blockEntityMap$i'] as Map<int, String>).map(
            (key, value) =>
                MapEntry(key, BlockHeaderEntity.fromJson(jsonDecode(value))));

    String balanceEntityString = isolateData['balanceEntity$i'];
    BalanceEntity balanceEntity =
        BalanceEntity.fromJson(jsonDecode(balanceEntityString));

    Map<int, Map<int, int>> addressBalanceMap =
        isolateData['addressBalanceMap$i'];
    Map<int, List<int>> usedIndexList = isolateData['usedIndexList$i'];
    Map<int, int> maxGapMap = isolateData['maxGapMap$i'];
    int initialReceiveIndex = isolateData['initialReceiveIndex$i'];
    int initialChangeIndex = isolateData['initialChangeIndex$i'];
    final isolateResult = WalletFetchResult(
      txEntityList: txEntityList,
      utxoEntityList: utxoEntityList,
      blockEntityMap: blockEntityMap,
      balanceEntity: balanceEntity,
      addressBalanceMap: addressBalanceMap,
      usedIndexList: usedIndexList,
      maxGapMap: maxGapMap,
      initialReceiveIndex: initialReceiveIndex,
      initialChangeIndex: initialChangeIndex,
    );
    fetchResults.add(isolateResult);
  }

  try {
    /// Isolate (4) - repositorySync
    for (int i = 0; i < count; i++) {
      await Repository().sync(wallets[i], fetchResults[i]);
    }

    /// Isolate (5) - repository close / return wallet
    Repository().close();
    sendPort.send(wallets);
  } catch (e) {
    Repository().close();
    sendPort.send(e);
  }
}
