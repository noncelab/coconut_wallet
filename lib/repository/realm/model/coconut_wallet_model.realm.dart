// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coconut_wallet_model.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

// ignore_for_file: type=lint
class RealmWalletBase extends _RealmWalletBase
    with RealmEntity, RealmObjectBase, RealmObject {
  static var _defaultsSet = false;

  RealmWalletBase(
    int id,
    int colorIndex,
    int iconIndex,
    String descriptor,
    String name,
    String walletType, {
    int usedReceiveIndex = -1,
    int usedChangeIndex = -1,
    int generatedReceiveIndex = -1,
    int generatedChangeIndex = -1,
    int? balance,
    int? txCount,
    bool isLatestTxBlockHeightZero = false,
  }) {
    if (!_defaultsSet) {
      _defaultsSet = RealmObjectBase.setDefaults<RealmWalletBase>({
        'usedReceiveIndex': -1,
        'usedChangeIndex': -1,
        'generatedReceiveIndex': -1,
        'generatedChangeIndex': -1,
        'isLatestTxBlockHeightZero': false,
      });
    }
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'colorIndex', colorIndex);
    RealmObjectBase.set(this, 'iconIndex', iconIndex);
    RealmObjectBase.set(this, 'descriptor', descriptor);
    RealmObjectBase.set(this, 'name', name);
    RealmObjectBase.set(this, 'walletType', walletType);
    RealmObjectBase.set(this, 'usedReceiveIndex', usedReceiveIndex);
    RealmObjectBase.set(this, 'usedChangeIndex', usedChangeIndex);
    RealmObjectBase.set(this, 'generatedReceiveIndex', generatedReceiveIndex);
    RealmObjectBase.set(this, 'generatedChangeIndex', generatedChangeIndex);
    RealmObjectBase.set(this, 'balance', balance);
    RealmObjectBase.set(this, 'txCount', txCount);
    RealmObjectBase.set(
        this, 'isLatestTxBlockHeightZero', isLatestTxBlockHeightZero);
  }

  RealmWalletBase._();

  @override
  int get id => RealmObjectBase.get<int>(this, 'id') as int;
  @override
  set id(int value) => RealmObjectBase.set(this, 'id', value);

  @override
  int get colorIndex => RealmObjectBase.get<int>(this, 'colorIndex') as int;
  @override
  set colorIndex(int value) => RealmObjectBase.set(this, 'colorIndex', value);

  @override
  int get iconIndex => RealmObjectBase.get<int>(this, 'iconIndex') as int;
  @override
  set iconIndex(int value) => RealmObjectBase.set(this, 'iconIndex', value);

  @override
  String get descriptor =>
      RealmObjectBase.get<String>(this, 'descriptor') as String;
  @override
  set descriptor(String value) =>
      RealmObjectBase.set(this, 'descriptor', value);

  @override
  String get name => RealmObjectBase.get<String>(this, 'name') as String;
  @override
  set name(String value) => RealmObjectBase.set(this, 'name', value);

  @override
  String get walletType =>
      RealmObjectBase.get<String>(this, 'walletType') as String;
  @override
  set walletType(String value) =>
      RealmObjectBase.set(this, 'walletType', value);

  @override
  int get usedReceiveIndex =>
      RealmObjectBase.get<int>(this, 'usedReceiveIndex') as int;
  @override
  set usedReceiveIndex(int value) =>
      RealmObjectBase.set(this, 'usedReceiveIndex', value);

  @override
  int get usedChangeIndex =>
      RealmObjectBase.get<int>(this, 'usedChangeIndex') as int;
  @override
  set usedChangeIndex(int value) =>
      RealmObjectBase.set(this, 'usedChangeIndex', value);

  @override
  int get generatedReceiveIndex =>
      RealmObjectBase.get<int>(this, 'generatedReceiveIndex') as int;
  @override
  set generatedReceiveIndex(int value) =>
      RealmObjectBase.set(this, 'generatedReceiveIndex', value);

  @override
  int get generatedChangeIndex =>
      RealmObjectBase.get<int>(this, 'generatedChangeIndex') as int;
  @override
  set generatedChangeIndex(int value) =>
      RealmObjectBase.set(this, 'generatedChangeIndex', value);

  @override
  int? get balance => RealmObjectBase.get<int>(this, 'balance') as int?;
  @override
  set balance(int? value) => RealmObjectBase.set(this, 'balance', value);

  @override
  int? get txCount => RealmObjectBase.get<int>(this, 'txCount') as int?;
  @override
  set txCount(int? value) => RealmObjectBase.set(this, 'txCount', value);

  @override
  bool get isLatestTxBlockHeightZero =>
      RealmObjectBase.get<bool>(this, 'isLatestTxBlockHeightZero') as bool;
  @override
  set isLatestTxBlockHeightZero(bool value) =>
      RealmObjectBase.set(this, 'isLatestTxBlockHeightZero', value);

  @override
  Stream<RealmObjectChanges<RealmWalletBase>> get changes =>
      RealmObjectBase.getChanges<RealmWalletBase>(this);

  @override
  Stream<RealmObjectChanges<RealmWalletBase>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<RealmWalletBase>(this, keyPaths);

  @override
  RealmWalletBase freeze() =>
      RealmObjectBase.freezeObject<RealmWalletBase>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'colorIndex': colorIndex.toEJson(),
      'iconIndex': iconIndex.toEJson(),
      'descriptor': descriptor.toEJson(),
      'name': name.toEJson(),
      'walletType': walletType.toEJson(),
      'usedReceiveIndex': usedReceiveIndex.toEJson(),
      'usedChangeIndex': usedChangeIndex.toEJson(),
      'generatedReceiveIndex': generatedReceiveIndex.toEJson(),
      'generatedChangeIndex': generatedChangeIndex.toEJson(),
      'balance': balance.toEJson(),
      'txCount': txCount.toEJson(),
      'isLatestTxBlockHeightZero': isLatestTxBlockHeightZero.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmWalletBase value) => value.toEJson();
  static RealmWalletBase _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'colorIndex': EJsonValue colorIndex,
        'iconIndex': EJsonValue iconIndex,
        'descriptor': EJsonValue descriptor,
        'name': EJsonValue name,
        'walletType': EJsonValue walletType,
      } =>
        RealmWalletBase(
          fromEJson(id),
          fromEJson(colorIndex),
          fromEJson(iconIndex),
          fromEJson(descriptor),
          fromEJson(name),
          fromEJson(walletType),
          usedReceiveIndex:
              fromEJson(ejson['usedReceiveIndex'], defaultValue: -1),
          usedChangeIndex:
              fromEJson(ejson['usedChangeIndex'], defaultValue: -1),
          generatedReceiveIndex:
              fromEJson(ejson['generatedReceiveIndex'], defaultValue: -1),
          generatedChangeIndex:
              fromEJson(ejson['generatedChangeIndex'], defaultValue: -1),
          balance: fromEJson(ejson['balance']),
          txCount: fromEJson(ejson['txCount']),
          isLatestTxBlockHeightZero: fromEJson(
              ejson['isLatestTxBlockHeightZero'],
              defaultValue: false),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmWalletBase._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
        ObjectType.realmObject, RealmWalletBase, 'RealmWalletBase', [
      SchemaProperty('id', RealmPropertyType.int, primaryKey: true),
      SchemaProperty('colorIndex', RealmPropertyType.int),
      SchemaProperty('iconIndex', RealmPropertyType.int),
      SchemaProperty('descriptor', RealmPropertyType.string),
      SchemaProperty('name', RealmPropertyType.string),
      SchemaProperty('walletType', RealmPropertyType.string),
      SchemaProperty('usedReceiveIndex', RealmPropertyType.int),
      SchemaProperty('usedChangeIndex', RealmPropertyType.int),
      SchemaProperty('generatedReceiveIndex', RealmPropertyType.int),
      SchemaProperty('generatedChangeIndex', RealmPropertyType.int),
      SchemaProperty('balance', RealmPropertyType.int, optional: true),
      SchemaProperty('txCount', RealmPropertyType.int, optional: true),
      SchemaProperty('isLatestTxBlockHeightZero', RealmPropertyType.bool),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmMultisigWallet extends _RealmMultisigWallet
    with RealmEntity, RealmObjectBase, RealmObject {
  RealmMultisigWallet(
    int id,
    String signersInJsonSerialization,
    int requiredSignatureCount, {
    RealmWalletBase? walletBase,
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'walletBase', walletBase);
    RealmObjectBase.set(
        this, 'signersInJsonSerialization', signersInJsonSerialization);
    RealmObjectBase.set(this, 'requiredSignatureCount', requiredSignatureCount);
  }

  RealmMultisigWallet._();

  @override
  int get id => RealmObjectBase.get<int>(this, 'id') as int;
  @override
  set id(int value) => RealmObjectBase.set(this, 'id', value);

  @override
  RealmWalletBase? get walletBase =>
      RealmObjectBase.get<RealmWalletBase>(this, 'walletBase')
          as RealmWalletBase?;
  @override
  set walletBase(covariant RealmWalletBase? value) =>
      RealmObjectBase.set(this, 'walletBase', value);

  @override
  String get signersInJsonSerialization =>
      RealmObjectBase.get<String>(this, 'signersInJsonSerialization') as String;
  @override
  set signersInJsonSerialization(String value) =>
      RealmObjectBase.set(this, 'signersInJsonSerialization', value);

  @override
  int get requiredSignatureCount =>
      RealmObjectBase.get<int>(this, 'requiredSignatureCount') as int;
  @override
  set requiredSignatureCount(int value) =>
      RealmObjectBase.set(this, 'requiredSignatureCount', value);

  @override
  Stream<RealmObjectChanges<RealmMultisigWallet>> get changes =>
      RealmObjectBase.getChanges<RealmMultisigWallet>(this);

  @override
  Stream<RealmObjectChanges<RealmMultisigWallet>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<RealmMultisigWallet>(this, keyPaths);

  @override
  RealmMultisigWallet freeze() =>
      RealmObjectBase.freezeObject<RealmMultisigWallet>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'walletBase': walletBase.toEJson(),
      'signersInJsonSerialization': signersInJsonSerialization.toEJson(),
      'requiredSignatureCount': requiredSignatureCount.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmMultisigWallet value) => value.toEJson();
  static RealmMultisigWallet _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'signersInJsonSerialization': EJsonValue signersInJsonSerialization,
        'requiredSignatureCount': EJsonValue requiredSignatureCount,
      } =>
        RealmMultisigWallet(
          fromEJson(id),
          fromEJson(signersInJsonSerialization),
          fromEJson(requiredSignatureCount),
          walletBase: fromEJson(ejson['walletBase']),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmMultisigWallet._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
        ObjectType.realmObject, RealmMultisigWallet, 'RealmMultisigWallet', [
      SchemaProperty('id', RealmPropertyType.int, primaryKey: true),
      SchemaProperty('walletBase', RealmPropertyType.object,
          optional: true, linkTarget: 'RealmWalletBase'),
      SchemaProperty('signersInJsonSerialization', RealmPropertyType.string),
      SchemaProperty('requiredSignatureCount', RealmPropertyType.int),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmTransaction extends _RealmTransaction
    with RealmEntity, RealmObjectBase, RealmObject {
  RealmTransaction(
    int id,
    String transactionHash,
    int walletId,
    int vSize, {
    DateTime? timestamp,
    int? blockHeight,
    String? transactionType,
    String? memo,
    int? amount,
    int? fee,
    Iterable<String> inputAddressList = const [],
    Iterable<String> outputAddressList = const [],
    String? note,
    DateTime? createdAt,
    String? replaceByTransactionHash,
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'transactionHash', transactionHash);
    RealmObjectBase.set(this, 'walletId', walletId);
    RealmObjectBase.set(this, 'timestamp', timestamp);
    RealmObjectBase.set(this, 'blockHeight', blockHeight);
    RealmObjectBase.set(this, 'transactionType', transactionType);
    RealmObjectBase.set(this, 'memo', memo);
    RealmObjectBase.set(this, 'amount', amount);
    RealmObjectBase.set(this, 'fee', fee);
    RealmObjectBase.set(this, 'vSize', vSize);
    RealmObjectBase.set<RealmList<String>>(
        this, 'inputAddressList', RealmList<String>(inputAddressList));
    RealmObjectBase.set<RealmList<String>>(
        this, 'outputAddressList', RealmList<String>(outputAddressList));
    RealmObjectBase.set(this, 'note', note);
    RealmObjectBase.set(this, 'createdAt', createdAt);
    RealmObjectBase.set(
        this, 'replaceByTransactionHash', replaceByTransactionHash);
  }

  RealmTransaction._();

  @override
  int get id => RealmObjectBase.get<int>(this, 'id') as int;
  @override
  set id(int value) => RealmObjectBase.set(this, 'id', value);

  @override
  String get transactionHash =>
      RealmObjectBase.get<String>(this, 'transactionHash') as String;
  @override
  set transactionHash(String value) =>
      RealmObjectBase.set(this, 'transactionHash', value);

  @override
  int get walletId => RealmObjectBase.get<int>(this, 'walletId') as int;
  @override
  set walletId(int value) => RealmObjectBase.set(this, 'walletId', value);

  @override
  DateTime? get timestamp =>
      RealmObjectBase.get<DateTime>(this, 'timestamp') as DateTime?;
  @override
  set timestamp(DateTime? value) =>
      RealmObjectBase.set(this, 'timestamp', value);

  @override
  int? get blockHeight => RealmObjectBase.get<int>(this, 'blockHeight') as int?;
  @override
  set blockHeight(int? value) =>
      RealmObjectBase.set(this, 'blockHeight', value);

  @override
  String? get transactionType =>
      RealmObjectBase.get<String>(this, 'transactionType') as String?;
  @override
  set transactionType(String? value) =>
      RealmObjectBase.set(this, 'transactionType', value);

  @override
  String? get memo => RealmObjectBase.get<String>(this, 'memo') as String?;
  @override
  set memo(String? value) => RealmObjectBase.set(this, 'memo', value);

  @override
  int? get amount => RealmObjectBase.get<int>(this, 'amount') as int?;
  @override
  set amount(int? value) => RealmObjectBase.set(this, 'amount', value);

  @override
  int? get fee => RealmObjectBase.get<int>(this, 'fee') as int?;
  @override
  set fee(int? value) => RealmObjectBase.set(this, 'fee', value);

  @override
  int get vSize => RealmObjectBase.get<int>(this, 'vSize') as int;
  @override
  set vSize(int value) => RealmObjectBase.set(this, 'vSize', value);

  @override
  RealmList<String> get inputAddressList =>
      RealmObjectBase.get<String>(this, 'inputAddressList')
          as RealmList<String>;
  @override
  set inputAddressList(covariant RealmList<String> value) =>
      throw RealmUnsupportedSetError();

  @override
  RealmList<String> get outputAddressList =>
      RealmObjectBase.get<String>(this, 'outputAddressList')
          as RealmList<String>;
  @override
  set outputAddressList(covariant RealmList<String> value) =>
      throw RealmUnsupportedSetError();

  @override
  String? get note => RealmObjectBase.get<String>(this, 'note') as String?;
  @override
  set note(String? value) => RealmObjectBase.set(this, 'note', value);

  @override
  DateTime? get createdAt =>
      RealmObjectBase.get<DateTime>(this, 'createdAt') as DateTime?;
  @override
  set createdAt(DateTime? value) =>
      RealmObjectBase.set(this, 'createdAt', value);

  @override
  String? get replaceByTransactionHash =>
      RealmObjectBase.get<String>(this, 'replaceByTransactionHash') as String?;
  @override
  set replaceByTransactionHash(String? value) =>
      RealmObjectBase.set(this, 'replaceByTransactionHash', value);

  @override
  Stream<RealmObjectChanges<RealmTransaction>> get changes =>
      RealmObjectBase.getChanges<RealmTransaction>(this);

  @override
  Stream<RealmObjectChanges<RealmTransaction>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<RealmTransaction>(this, keyPaths);

  @override
  RealmTransaction freeze() =>
      RealmObjectBase.freezeObject<RealmTransaction>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'transactionHash': transactionHash.toEJson(),
      'walletId': walletId.toEJson(),
      'timestamp': timestamp.toEJson(),
      'blockHeight': blockHeight.toEJson(),
      'transactionType': transactionType.toEJson(),
      'memo': memo.toEJson(),
      'amount': amount.toEJson(),
      'fee': fee.toEJson(),
      'vSize': vSize.toEJson(),
      'inputAddressList': inputAddressList.toEJson(),
      'outputAddressList': outputAddressList.toEJson(),
      'note': note.toEJson(),
      'createdAt': createdAt.toEJson(),
      'replaceByTransactionHash': replaceByTransactionHash.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmTransaction value) => value.toEJson();
  static RealmTransaction _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'transactionHash': EJsonValue transactionHash,
        'walletId': EJsonValue walletId,
        'vSize': EJsonValue vSize,
      } =>
        RealmTransaction(
          fromEJson(id),
          fromEJson(transactionHash),
          fromEJson(walletId),
          fromEJson(vSize),
          timestamp: fromEJson(ejson['timestamp']),
          blockHeight: fromEJson(ejson['blockHeight']),
          transactionType: fromEJson(ejson['transactionType']),
          memo: fromEJson(ejson['memo']),
          amount: fromEJson(ejson['amount']),
          fee: fromEJson(ejson['fee']),
          inputAddressList: fromEJson(ejson['inputAddressList']),
          outputAddressList: fromEJson(ejson['outputAddressList']),
          note: fromEJson(ejson['note']),
          createdAt: fromEJson(ejson['createdAt']),
          replaceByTransactionHash:
              fromEJson(ejson['replaceByTransactionHash']),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmTransaction._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
        ObjectType.realmObject, RealmTransaction, 'RealmTransaction', [
      SchemaProperty('id', RealmPropertyType.int, primaryKey: true),
      SchemaProperty('transactionHash', RealmPropertyType.string,
          indexType: RealmIndexType.regular),
      SchemaProperty('walletId', RealmPropertyType.int,
          indexType: RealmIndexType.regular),
      SchemaProperty('timestamp', RealmPropertyType.timestamp,
          optional: true, indexType: RealmIndexType.regular),
      SchemaProperty('blockHeight', RealmPropertyType.int, optional: true),
      SchemaProperty('transactionType', RealmPropertyType.string,
          optional: true),
      SchemaProperty('memo', RealmPropertyType.string, optional: true),
      SchemaProperty('amount', RealmPropertyType.int, optional: true),
      SchemaProperty('fee', RealmPropertyType.int, optional: true),
      SchemaProperty('vSize', RealmPropertyType.int),
      SchemaProperty('inputAddressList', RealmPropertyType.string,
          collectionType: RealmCollectionType.list),
      SchemaProperty('outputAddressList', RealmPropertyType.string,
          collectionType: RealmCollectionType.list),
      SchemaProperty('note', RealmPropertyType.string, optional: true),
      SchemaProperty('createdAt', RealmPropertyType.timestamp, optional: true),
      SchemaProperty('replaceByTransactionHash', RealmPropertyType.string,
          optional: true),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmIntegerId extends _RealmIntegerId
    with RealmEntity, RealmObjectBase, RealmObject {
  RealmIntegerId(
    String key,
    int value,
  ) {
    RealmObjectBase.set(this, 'key', key);
    RealmObjectBase.set(this, 'value', value);
  }

  RealmIntegerId._();

  @override
  String get key => RealmObjectBase.get<String>(this, 'key') as String;
  @override
  set key(String value) => RealmObjectBase.set(this, 'key', value);

  @override
  int get value => RealmObjectBase.get<int>(this, 'value') as int;
  @override
  set value(int value) => RealmObjectBase.set(this, 'value', value);

  @override
  Stream<RealmObjectChanges<RealmIntegerId>> get changes =>
      RealmObjectBase.getChanges<RealmIntegerId>(this);

  @override
  Stream<RealmObjectChanges<RealmIntegerId>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<RealmIntegerId>(this, keyPaths);

  @override
  RealmIntegerId freeze() => RealmObjectBase.freezeObject<RealmIntegerId>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'key': key.toEJson(),
      'value': value.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmIntegerId value) => value.toEJson();
  static RealmIntegerId _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'key': EJsonValue key,
        'value': EJsonValue value,
      } =>
        RealmIntegerId(
          fromEJson(key),
          fromEJson(value),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmIntegerId._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
        ObjectType.realmObject, RealmIntegerId, 'RealmIntegerId', [
      SchemaProperty('key', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('value', RealmPropertyType.int),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class TempBroadcastTimeRecord extends _TempBroadcastTimeRecord
    with RealmEntity, RealmObjectBase, RealmObject {
  TempBroadcastTimeRecord(
    String transactionHash,
    DateTime createdAt,
  ) {
    RealmObjectBase.set(this, 'transactionHash', transactionHash);
    RealmObjectBase.set(this, 'createdAt', createdAt);
  }

  TempBroadcastTimeRecord._();

  @override
  String get transactionHash =>
      RealmObjectBase.get<String>(this, 'transactionHash') as String;
  @override
  set transactionHash(String value) =>
      RealmObjectBase.set(this, 'transactionHash', value);

  @override
  DateTime get createdAt =>
      RealmObjectBase.get<DateTime>(this, 'createdAt') as DateTime;
  @override
  set createdAt(DateTime value) =>
      RealmObjectBase.set(this, 'createdAt', value);

  @override
  Stream<RealmObjectChanges<TempBroadcastTimeRecord>> get changes =>
      RealmObjectBase.getChanges<TempBroadcastTimeRecord>(this);

  @override
  Stream<RealmObjectChanges<TempBroadcastTimeRecord>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<TempBroadcastTimeRecord>(this, keyPaths);

  @override
  TempBroadcastTimeRecord freeze() =>
      RealmObjectBase.freezeObject<TempBroadcastTimeRecord>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'transactionHash': transactionHash.toEJson(),
      'createdAt': createdAt.toEJson(),
    };
  }

  static EJsonValue _toEJson(TempBroadcastTimeRecord value) => value.toEJson();
  static TempBroadcastTimeRecord _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'transactionHash': EJsonValue transactionHash,
        'createdAt': EJsonValue createdAt,
      } =>
        TempBroadcastTimeRecord(
          fromEJson(transactionHash),
          fromEJson(createdAt),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(TempBroadcastTimeRecord._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, TempBroadcastTimeRecord,
        'TempBroadcastTimeRecord', [
      SchemaProperty('transactionHash', RealmPropertyType.string,
          primaryKey: true),
      SchemaProperty('createdAt', RealmPropertyType.timestamp),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmUtxoTag extends _RealmUtxoTag
    with RealmEntity, RealmObjectBase, RealmObject {
  RealmUtxoTag(
    String id,
    int walletId,
    String name,
    int colorIndex,
    DateTime createAt, {
    Iterable<String> utxoIdList = const [],
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'walletId', walletId);
    RealmObjectBase.set(this, 'name', name);
    RealmObjectBase.set(this, 'colorIndex', colorIndex);
    RealmObjectBase.set<RealmList<String>>(
        this, 'utxoIdList', RealmList<String>(utxoIdList));
    RealmObjectBase.set(this, 'createAt', createAt);
  }

  RealmUtxoTag._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  int get walletId => RealmObjectBase.get<int>(this, 'walletId') as int;
  @override
  set walletId(int value) => RealmObjectBase.set(this, 'walletId', value);

  @override
  String get name => RealmObjectBase.get<String>(this, 'name') as String;
  @override
  set name(String value) => RealmObjectBase.set(this, 'name', value);

  @override
  int get colorIndex => RealmObjectBase.get<int>(this, 'colorIndex') as int;
  @override
  set colorIndex(int value) => RealmObjectBase.set(this, 'colorIndex', value);

  @override
  RealmList<String> get utxoIdList =>
      RealmObjectBase.get<String>(this, 'utxoIdList') as RealmList<String>;
  @override
  set utxoIdList(covariant RealmList<String> value) =>
      throw RealmUnsupportedSetError();

  @override
  DateTime get createAt =>
      RealmObjectBase.get<DateTime>(this, 'createAt') as DateTime;
  @override
  set createAt(DateTime value) => RealmObjectBase.set(this, 'createAt', value);

  @override
  Stream<RealmObjectChanges<RealmUtxoTag>> get changes =>
      RealmObjectBase.getChanges<RealmUtxoTag>(this);

  @override
  Stream<RealmObjectChanges<RealmUtxoTag>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<RealmUtxoTag>(this, keyPaths);

  @override
  RealmUtxoTag freeze() => RealmObjectBase.freezeObject<RealmUtxoTag>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'walletId': walletId.toEJson(),
      'name': name.toEJson(),
      'colorIndex': colorIndex.toEJson(),
      'utxoIdList': utxoIdList.toEJson(),
      'createAt': createAt.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmUtxoTag value) => value.toEJson();
  static RealmUtxoTag _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'walletId': EJsonValue walletId,
        'name': EJsonValue name,
        'colorIndex': EJsonValue colorIndex,
        'createAt': EJsonValue createAt,
      } =>
        RealmUtxoTag(
          fromEJson(id),
          fromEJson(walletId),
          fromEJson(name),
          fromEJson(colorIndex),
          fromEJson(createAt),
          utxoIdList: fromEJson(ejson['utxoIdList']),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmUtxoTag._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
        ObjectType.realmObject, RealmUtxoTag, 'RealmUtxoTag', [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('walletId', RealmPropertyType.int),
      SchemaProperty('name', RealmPropertyType.string),
      SchemaProperty('colorIndex', RealmPropertyType.int),
      SchemaProperty('utxoIdList', RealmPropertyType.string,
          collectionType: RealmCollectionType.list),
      SchemaProperty('createAt', RealmPropertyType.timestamp),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmWalletAddress extends _RealmWalletAddress
    with RealmEntity, RealmObjectBase, RealmObject {
  RealmWalletAddress(
    int id,
    int walletId,
    String address,
    int index,
    bool isChange,
    String derivationPath,
    bool isUsed,
    int confirmed,
    int unconfirmed,
    int total,
  ) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'walletId', walletId);
    RealmObjectBase.set(this, 'address', address);
    RealmObjectBase.set(this, 'index', index);
    RealmObjectBase.set(this, 'isChange', isChange);
    RealmObjectBase.set(this, 'derivationPath', derivationPath);
    RealmObjectBase.set(this, 'isUsed', isUsed);
    RealmObjectBase.set(this, 'confirmed', confirmed);
    RealmObjectBase.set(this, 'unconfirmed', unconfirmed);
    RealmObjectBase.set(this, 'total', total);
  }

  RealmWalletAddress._();

  @override
  int get id => RealmObjectBase.get<int>(this, 'id') as int;
  @override
  set id(int value) => RealmObjectBase.set(this, 'id', value);

  @override
  int get walletId => RealmObjectBase.get<int>(this, 'walletId') as int;
  @override
  set walletId(int value) => RealmObjectBase.set(this, 'walletId', value);

  @override
  String get address => RealmObjectBase.get<String>(this, 'address') as String;
  @override
  set address(String value) => RealmObjectBase.set(this, 'address', value);

  @override
  int get index => RealmObjectBase.get<int>(this, 'index') as int;
  @override
  set index(int value) => RealmObjectBase.set(this, 'index', value);

  @override
  bool get isChange => RealmObjectBase.get<bool>(this, 'isChange') as bool;
  @override
  set isChange(bool value) => RealmObjectBase.set(this, 'isChange', value);

  @override
  String get derivationPath =>
      RealmObjectBase.get<String>(this, 'derivationPath') as String;
  @override
  set derivationPath(String value) =>
      RealmObjectBase.set(this, 'derivationPath', value);

  @override
  bool get isUsed => RealmObjectBase.get<bool>(this, 'isUsed') as bool;
  @override
  set isUsed(bool value) => RealmObjectBase.set(this, 'isUsed', value);

  @override
  int get confirmed => RealmObjectBase.get<int>(this, 'confirmed') as int;
  @override
  set confirmed(int value) => RealmObjectBase.set(this, 'confirmed', value);

  @override
  int get unconfirmed => RealmObjectBase.get<int>(this, 'unconfirmed') as int;
  @override
  set unconfirmed(int value) => RealmObjectBase.set(this, 'unconfirmed', value);

  @override
  int get total => RealmObjectBase.get<int>(this, 'total') as int;
  @override
  set total(int value) => RealmObjectBase.set(this, 'total', value);

  @override
  Stream<RealmObjectChanges<RealmWalletAddress>> get changes =>
      RealmObjectBase.getChanges<RealmWalletAddress>(this);

  @override
  Stream<RealmObjectChanges<RealmWalletAddress>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<RealmWalletAddress>(this, keyPaths);

  @override
  RealmWalletAddress freeze() =>
      RealmObjectBase.freezeObject<RealmWalletAddress>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'walletId': walletId.toEJson(),
      'address': address.toEJson(),
      'index': index.toEJson(),
      'isChange': isChange.toEJson(),
      'derivationPath': derivationPath.toEJson(),
      'isUsed': isUsed.toEJson(),
      'confirmed': confirmed.toEJson(),
      'unconfirmed': unconfirmed.toEJson(),
      'total': total.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmWalletAddress value) => value.toEJson();
  static RealmWalletAddress _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'walletId': EJsonValue walletId,
        'address': EJsonValue address,
        'index': EJsonValue index,
        'isChange': EJsonValue isChange,
        'derivationPath': EJsonValue derivationPath,
        'isUsed': EJsonValue isUsed,
        'confirmed': EJsonValue confirmed,
        'unconfirmed': EJsonValue unconfirmed,
        'total': EJsonValue total,
      } =>
        RealmWalletAddress(
          fromEJson(id),
          fromEJson(walletId),
          fromEJson(address),
          fromEJson(index),
          fromEJson(isChange),
          fromEJson(derivationPath),
          fromEJson(isUsed),
          fromEJson(confirmed),
          fromEJson(unconfirmed),
          fromEJson(total),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmWalletAddress._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
        ObjectType.realmObject, RealmWalletAddress, 'RealmWalletAddress', [
      SchemaProperty('id', RealmPropertyType.int, primaryKey: true),
      SchemaProperty('walletId', RealmPropertyType.int,
          indexType: RealmIndexType.regular),
      SchemaProperty('address', RealmPropertyType.string,
          indexType: RealmIndexType.regular),
      SchemaProperty('index', RealmPropertyType.int,
          indexType: RealmIndexType.regular),
      SchemaProperty('isChange', RealmPropertyType.bool,
          indexType: RealmIndexType.regular),
      SchemaProperty('derivationPath', RealmPropertyType.string),
      SchemaProperty('isUsed', RealmPropertyType.bool),
      SchemaProperty('confirmed', RealmPropertyType.int),
      SchemaProperty('unconfirmed', RealmPropertyType.int),
      SchemaProperty('total', RealmPropertyType.int),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmWalletBalance extends _RealmWalletBalance
    with RealmEntity, RealmObjectBase, RealmObject {
  RealmWalletBalance(
    int id,
    int walletId,
    int total,
    int confirmed,
    int unconfirmed,
  ) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'walletId', walletId);
    RealmObjectBase.set(this, 'total', total);
    RealmObjectBase.set(this, 'confirmed', confirmed);
    RealmObjectBase.set(this, 'unconfirmed', unconfirmed);
  }

  RealmWalletBalance._();

  @override
  int get id => RealmObjectBase.get<int>(this, 'id') as int;
  @override
  set id(int value) => RealmObjectBase.set(this, 'id', value);

  @override
  int get walletId => RealmObjectBase.get<int>(this, 'walletId') as int;
  @override
  set walletId(int value) => RealmObjectBase.set(this, 'walletId', value);

  @override
  int get total => RealmObjectBase.get<int>(this, 'total') as int;
  @override
  set total(int value) => RealmObjectBase.set(this, 'total', value);

  @override
  int get confirmed => RealmObjectBase.get<int>(this, 'confirmed') as int;
  @override
  set confirmed(int value) => RealmObjectBase.set(this, 'confirmed', value);

  @override
  int get unconfirmed => RealmObjectBase.get<int>(this, 'unconfirmed') as int;
  @override
  set unconfirmed(int value) => RealmObjectBase.set(this, 'unconfirmed', value);

  @override
  Stream<RealmObjectChanges<RealmWalletBalance>> get changes =>
      RealmObjectBase.getChanges<RealmWalletBalance>(this);

  @override
  Stream<RealmObjectChanges<RealmWalletBalance>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<RealmWalletBalance>(this, keyPaths);

  @override
  RealmWalletBalance freeze() =>
      RealmObjectBase.freezeObject<RealmWalletBalance>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'walletId': walletId.toEJson(),
      'total': total.toEJson(),
      'confirmed': confirmed.toEJson(),
      'unconfirmed': unconfirmed.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmWalletBalance value) => value.toEJson();
  static RealmWalletBalance _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'walletId': EJsonValue walletId,
        'total': EJsonValue total,
        'confirmed': EJsonValue confirmed,
        'unconfirmed': EJsonValue unconfirmed,
      } =>
        RealmWalletBalance(
          fromEJson(id),
          fromEJson(walletId),
          fromEJson(total),
          fromEJson(confirmed),
          fromEJson(unconfirmed),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmWalletBalance._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
        ObjectType.realmObject, RealmWalletBalance, 'RealmWalletBalance', [
      SchemaProperty('id', RealmPropertyType.int, primaryKey: true),
      SchemaProperty('walletId', RealmPropertyType.int,
          indexType: RealmIndexType.regular),
      SchemaProperty('total', RealmPropertyType.int),
      SchemaProperty('confirmed', RealmPropertyType.int),
      SchemaProperty('unconfirmed', RealmPropertyType.int),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmBlockTimestamp extends _RealmBlockTimestamp
    with RealmEntity, RealmObjectBase, RealmObject {
  RealmBlockTimestamp(
    int blockHeight,
    DateTime timestamp,
  ) {
    RealmObjectBase.set(this, 'blockHeight', blockHeight);
    RealmObjectBase.set(this, 'timestamp', timestamp);
  }

  RealmBlockTimestamp._();

  @override
  int get blockHeight => RealmObjectBase.get<int>(this, 'blockHeight') as int;
  @override
  set blockHeight(int value) => RealmObjectBase.set(this, 'blockHeight', value);

  @override
  DateTime get timestamp =>
      RealmObjectBase.get<DateTime>(this, 'timestamp') as DateTime;
  @override
  set timestamp(DateTime value) =>
      RealmObjectBase.set(this, 'timestamp', value);

  @override
  Stream<RealmObjectChanges<RealmBlockTimestamp>> get changes =>
      RealmObjectBase.getChanges<RealmBlockTimestamp>(this);

  @override
  Stream<RealmObjectChanges<RealmBlockTimestamp>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<RealmBlockTimestamp>(this, keyPaths);

  @override
  RealmBlockTimestamp freeze() =>
      RealmObjectBase.freezeObject<RealmBlockTimestamp>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'blockHeight': blockHeight.toEJson(),
      'timestamp': timestamp.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmBlockTimestamp value) => value.toEJson();
  static RealmBlockTimestamp _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'blockHeight': EJsonValue blockHeight,
        'timestamp': EJsonValue timestamp,
      } =>
        RealmBlockTimestamp(
          fromEJson(blockHeight),
          fromEJson(timestamp),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmBlockTimestamp._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
        ObjectType.realmObject, RealmBlockTimestamp, 'RealmBlockTimestamp', [
      SchemaProperty('blockHeight', RealmPropertyType.int, primaryKey: true),
      SchemaProperty('timestamp', RealmPropertyType.timestamp),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmScriptStatus extends _RealmScriptStatus
    with RealmEntity, RealmObjectBase, RealmObject {
  RealmScriptStatus(
    String scriptPubKey,
    String status,
    int walletId,
    DateTime timestamp,
  ) {
    RealmObjectBase.set(this, 'scriptPubKey', scriptPubKey);
    RealmObjectBase.set(this, 'status', status);
    RealmObjectBase.set(this, 'walletId', walletId);
    RealmObjectBase.set(this, 'timestamp', timestamp);
  }

  RealmScriptStatus._();

  @override
  String get scriptPubKey =>
      RealmObjectBase.get<String>(this, 'scriptPubKey') as String;
  @override
  set scriptPubKey(String value) =>
      RealmObjectBase.set(this, 'scriptPubKey', value);

  @override
  String get status => RealmObjectBase.get<String>(this, 'status') as String;
  @override
  set status(String value) => RealmObjectBase.set(this, 'status', value);

  @override
  int get walletId => RealmObjectBase.get<int>(this, 'walletId') as int;
  @override
  set walletId(int value) => RealmObjectBase.set(this, 'walletId', value);

  @override
  DateTime get timestamp =>
      RealmObjectBase.get<DateTime>(this, 'timestamp') as DateTime;
  @override
  set timestamp(DateTime value) =>
      RealmObjectBase.set(this, 'timestamp', value);

  @override
  Stream<RealmObjectChanges<RealmScriptStatus>> get changes =>
      RealmObjectBase.getChanges<RealmScriptStatus>(this);

  @override
  Stream<RealmObjectChanges<RealmScriptStatus>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<RealmScriptStatus>(this, keyPaths);

  @override
  RealmScriptStatus freeze() =>
      RealmObjectBase.freezeObject<RealmScriptStatus>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'scriptPubKey': scriptPubKey.toEJson(),
      'status': status.toEJson(),
      'walletId': walletId.toEJson(),
      'timestamp': timestamp.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmScriptStatus value) => value.toEJson();
  static RealmScriptStatus _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'scriptPubKey': EJsonValue scriptPubKey,
        'status': EJsonValue status,
        'walletId': EJsonValue walletId,
        'timestamp': EJsonValue timestamp,
      } =>
        RealmScriptStatus(
          fromEJson(scriptPubKey),
          fromEJson(status),
          fromEJson(walletId),
          fromEJson(timestamp),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmScriptStatus._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
        ObjectType.realmObject, RealmScriptStatus, 'RealmScriptStatus', [
      SchemaProperty('scriptPubKey', RealmPropertyType.string,
          primaryKey: true),
      SchemaProperty('status', RealmPropertyType.string),
      SchemaProperty('walletId', RealmPropertyType.int,
          indexType: RealmIndexType.regular),
      SchemaProperty('timestamp', RealmPropertyType.timestamp),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmUtxo extends _RealmUtxo
    with RealmEntity, RealmObjectBase, RealmObject {
  RealmUtxo(
    String id,
    int walletId,
    String address,
    int amount,
    DateTime timestamp,
    String transactionHash,
    int index,
    String derivationPath,
    int blockHeight,
    String status, {
    String? spentByTransactionHash,
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'walletId', walletId);
    RealmObjectBase.set(this, 'address', address);
    RealmObjectBase.set(this, 'amount', amount);
    RealmObjectBase.set(this, 'timestamp', timestamp);
    RealmObjectBase.set(this, 'transactionHash', transactionHash);
    RealmObjectBase.set(this, 'index', index);
    RealmObjectBase.set(this, 'derivationPath', derivationPath);
    RealmObjectBase.set(this, 'blockHeight', blockHeight);
    RealmObjectBase.set(this, 'status', status);
    RealmObjectBase.set(this, 'spentByTransactionHash', spentByTransactionHash);
  }

  RealmUtxo._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  int get walletId => RealmObjectBase.get<int>(this, 'walletId') as int;
  @override
  set walletId(int value) => RealmObjectBase.set(this, 'walletId', value);

  @override
  String get address => RealmObjectBase.get<String>(this, 'address') as String;
  @override
  set address(String value) => RealmObjectBase.set(this, 'address', value);

  @override
  int get amount => RealmObjectBase.get<int>(this, 'amount') as int;
  @override
  set amount(int value) => RealmObjectBase.set(this, 'amount', value);

  @override
  DateTime get timestamp =>
      RealmObjectBase.get<DateTime>(this, 'timestamp') as DateTime;
  @override
  set timestamp(DateTime value) =>
      RealmObjectBase.set(this, 'timestamp', value);

  @override
  String get transactionHash =>
      RealmObjectBase.get<String>(this, 'transactionHash') as String;
  @override
  set transactionHash(String value) =>
      RealmObjectBase.set(this, 'transactionHash', value);

  @override
  int get index => RealmObjectBase.get<int>(this, 'index') as int;
  @override
  set index(int value) => RealmObjectBase.set(this, 'index', value);

  @override
  String get derivationPath =>
      RealmObjectBase.get<String>(this, 'derivationPath') as String;
  @override
  set derivationPath(String value) =>
      RealmObjectBase.set(this, 'derivationPath', value);

  @override
  int get blockHeight => RealmObjectBase.get<int>(this, 'blockHeight') as int;
  @override
  set blockHeight(int value) => RealmObjectBase.set(this, 'blockHeight', value);

  @override
  String get status => RealmObjectBase.get<String>(this, 'status') as String;
  @override
  set status(String value) => RealmObjectBase.set(this, 'status', value);

  @override
  String? get spentByTransactionHash =>
      RealmObjectBase.get<String>(this, 'spentByTransactionHash') as String?;
  @override
  set spentByTransactionHash(String? value) =>
      RealmObjectBase.set(this, 'spentByTransactionHash', value);

  @override
  Stream<RealmObjectChanges<RealmUtxo>> get changes =>
      RealmObjectBase.getChanges<RealmUtxo>(this);

  @override
  Stream<RealmObjectChanges<RealmUtxo>> changesFor([List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<RealmUtxo>(this, keyPaths);

  @override
  RealmUtxo freeze() => RealmObjectBase.freezeObject<RealmUtxo>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'walletId': walletId.toEJson(),
      'address': address.toEJson(),
      'amount': amount.toEJson(),
      'timestamp': timestamp.toEJson(),
      'transactionHash': transactionHash.toEJson(),
      'index': index.toEJson(),
      'derivationPath': derivationPath.toEJson(),
      'blockHeight': blockHeight.toEJson(),
      'status': status.toEJson(),
      'spentByTransactionHash': spentByTransactionHash.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmUtxo value) => value.toEJson();
  static RealmUtxo _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'walletId': EJsonValue walletId,
        'address': EJsonValue address,
        'amount': EJsonValue amount,
        'timestamp': EJsonValue timestamp,
        'transactionHash': EJsonValue transactionHash,
        'index': EJsonValue index,
        'derivationPath': EJsonValue derivationPath,
        'blockHeight': EJsonValue blockHeight,
        'status': EJsonValue status,
      } =>
        RealmUtxo(
          fromEJson(id),
          fromEJson(walletId),
          fromEJson(address),
          fromEJson(amount),
          fromEJson(timestamp),
          fromEJson(transactionHash),
          fromEJson(index),
          fromEJson(derivationPath),
          fromEJson(blockHeight),
          fromEJson(status),
          spentByTransactionHash: fromEJson(ejson['spentByTransactionHash']),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmUtxo._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, RealmUtxo, 'RealmUtxo', [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('walletId', RealmPropertyType.int,
          indexType: RealmIndexType.regular),
      SchemaProperty('address', RealmPropertyType.string,
          indexType: RealmIndexType.regular),
      SchemaProperty('amount', RealmPropertyType.int,
          indexType: RealmIndexType.regular),
      SchemaProperty('timestamp', RealmPropertyType.timestamp,
          indexType: RealmIndexType.regular),
      SchemaProperty('transactionHash', RealmPropertyType.string),
      SchemaProperty('index', RealmPropertyType.int),
      SchemaProperty('derivationPath', RealmPropertyType.string),
      SchemaProperty('blockHeight', RealmPropertyType.int),
      SchemaProperty('status', RealmPropertyType.string,
          indexType: RealmIndexType.regular),
      SchemaProperty('spentByTransactionHash', RealmPropertyType.string,
          optional: true),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmRbfHistory extends _RealmRbfHistory
    with RealmEntity, RealmObjectBase, RealmObject {
  RealmRbfHistory(
    int id,
    int walletId,
    String originalTransactionHash,
    String transactionHash,
    double feeRate,
    DateTime timestamp,
  ) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'walletId', walletId);
    RealmObjectBase.set(
        this, 'originalTransactionHash', originalTransactionHash);
    RealmObjectBase.set(this, 'transactionHash', transactionHash);
    RealmObjectBase.set(this, 'feeRate', feeRate);
    RealmObjectBase.set(this, 'timestamp', timestamp);
  }

  RealmRbfHistory._();

  @override
  int get id => RealmObjectBase.get<int>(this, 'id') as int;
  @override
  set id(int value) => RealmObjectBase.set(this, 'id', value);

  @override
  int get walletId => RealmObjectBase.get<int>(this, 'walletId') as int;
  @override
  set walletId(int value) => RealmObjectBase.set(this, 'walletId', value);

  @override
  String get originalTransactionHash =>
      RealmObjectBase.get<String>(this, 'originalTransactionHash') as String;
  @override
  set originalTransactionHash(String value) =>
      RealmObjectBase.set(this, 'originalTransactionHash', value);

  @override
  String get transactionHash =>
      RealmObjectBase.get<String>(this, 'transactionHash') as String;
  @override
  set transactionHash(String value) =>
      RealmObjectBase.set(this, 'transactionHash', value);

  @override
  double get feeRate => RealmObjectBase.get<double>(this, 'feeRate') as double;
  @override
  set feeRate(double value) => RealmObjectBase.set(this, 'feeRate', value);

  @override
  DateTime get timestamp =>
      RealmObjectBase.get<DateTime>(this, 'timestamp') as DateTime;
  @override
  set timestamp(DateTime value) =>
      RealmObjectBase.set(this, 'timestamp', value);

  @override
  Stream<RealmObjectChanges<RealmRbfHistory>> get changes =>
      RealmObjectBase.getChanges<RealmRbfHistory>(this);

  @override
  Stream<RealmObjectChanges<RealmRbfHistory>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<RealmRbfHistory>(this, keyPaths);

  @override
  RealmRbfHistory freeze() =>
      RealmObjectBase.freezeObject<RealmRbfHistory>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'walletId': walletId.toEJson(),
      'originalTransactionHash': originalTransactionHash.toEJson(),
      'transactionHash': transactionHash.toEJson(),
      'feeRate': feeRate.toEJson(),
      'timestamp': timestamp.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmRbfHistory value) => value.toEJson();
  static RealmRbfHistory _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'walletId': EJsonValue walletId,
        'originalTransactionHash': EJsonValue originalTransactionHash,
        'transactionHash': EJsonValue transactionHash,
        'feeRate': EJsonValue feeRate,
        'timestamp': EJsonValue timestamp,
      } =>
        RealmRbfHistory(
          fromEJson(id),
          fromEJson(walletId),
          fromEJson(originalTransactionHash),
          fromEJson(transactionHash),
          fromEJson(feeRate),
          fromEJson(timestamp),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmRbfHistory._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
        ObjectType.realmObject, RealmRbfHistory, 'RealmRbfHistory', [
      SchemaProperty('id', RealmPropertyType.int, primaryKey: true),
      SchemaProperty('walletId', RealmPropertyType.int,
          indexType: RealmIndexType.regular),
      SchemaProperty('originalTransactionHash', RealmPropertyType.string,
          indexType: RealmIndexType.regular),
      SchemaProperty('transactionHash', RealmPropertyType.string,
          indexType: RealmIndexType.regular),
      SchemaProperty('feeRate', RealmPropertyType.double),
      SchemaProperty('timestamp', RealmPropertyType.timestamp),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class RealmCpfpHistory extends _RealmCpfpHistory
    with RealmEntity, RealmObjectBase, RealmObject {
  RealmCpfpHistory(
    int id,
    int walletId,
    String parentTransactionHash,
    String childTransactionHash,
    double originalFee,
    double newFee,
    DateTime timestamp,
  ) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'walletId', walletId);
    RealmObjectBase.set(this, 'parentTransactionHash', parentTransactionHash);
    RealmObjectBase.set(this, 'childTransactionHash', childTransactionHash);
    RealmObjectBase.set(this, 'originalFee', originalFee);
    RealmObjectBase.set(this, 'newFee', newFee);
    RealmObjectBase.set(this, 'timestamp', timestamp);
  }

  RealmCpfpHistory._();

  @override
  int get id => RealmObjectBase.get<int>(this, 'id') as int;
  @override
  set id(int value) => RealmObjectBase.set(this, 'id', value);

  @override
  int get walletId => RealmObjectBase.get<int>(this, 'walletId') as int;
  @override
  set walletId(int value) => RealmObjectBase.set(this, 'walletId', value);

  @override
  String get parentTransactionHash =>
      RealmObjectBase.get<String>(this, 'parentTransactionHash') as String;
  @override
  set parentTransactionHash(String value) =>
      RealmObjectBase.set(this, 'parentTransactionHash', value);

  @override
  String get childTransactionHash =>
      RealmObjectBase.get<String>(this, 'childTransactionHash') as String;
  @override
  set childTransactionHash(String value) =>
      RealmObjectBase.set(this, 'childTransactionHash', value);

  @override
  double get originalFee =>
      RealmObjectBase.get<double>(this, 'originalFee') as double;
  @override
  set originalFee(double value) =>
      RealmObjectBase.set(this, 'originalFee', value);

  @override
  double get newFee => RealmObjectBase.get<double>(this, 'newFee') as double;
  @override
  set newFee(double value) => RealmObjectBase.set(this, 'newFee', value);

  @override
  DateTime get timestamp =>
      RealmObjectBase.get<DateTime>(this, 'timestamp') as DateTime;
  @override
  set timestamp(DateTime value) =>
      RealmObjectBase.set(this, 'timestamp', value);

  @override
  Stream<RealmObjectChanges<RealmCpfpHistory>> get changes =>
      RealmObjectBase.getChanges<RealmCpfpHistory>(this);

  @override
  Stream<RealmObjectChanges<RealmCpfpHistory>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<RealmCpfpHistory>(this, keyPaths);

  @override
  RealmCpfpHistory freeze() =>
      RealmObjectBase.freezeObject<RealmCpfpHistory>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'walletId': walletId.toEJson(),
      'parentTransactionHash': parentTransactionHash.toEJson(),
      'childTransactionHash': childTransactionHash.toEJson(),
      'originalFee': originalFee.toEJson(),
      'newFee': newFee.toEJson(),
      'timestamp': timestamp.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmCpfpHistory value) => value.toEJson();
  static RealmCpfpHistory _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'walletId': EJsonValue walletId,
        'parentTransactionHash': EJsonValue parentTransactionHash,
        'childTransactionHash': EJsonValue childTransactionHash,
        'originalFee': EJsonValue originalFee,
        'newFee': EJsonValue newFee,
        'timestamp': EJsonValue timestamp,
      } =>
        RealmCpfpHistory(
          fromEJson(id),
          fromEJson(walletId),
          fromEJson(parentTransactionHash),
          fromEJson(childTransactionHash),
          fromEJson(originalFee),
          fromEJson(newFee),
          fromEJson(timestamp),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(RealmCpfpHistory._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
        ObjectType.realmObject, RealmCpfpHistory, 'RealmCpfpHistory', [
      SchemaProperty('id', RealmPropertyType.int, primaryKey: true),
      SchemaProperty('walletId', RealmPropertyType.int,
          indexType: RealmIndexType.regular),
      SchemaProperty('parentTransactionHash', RealmPropertyType.string,
          indexType: RealmIndexType.regular),
      SchemaProperty('childTransactionHash', RealmPropertyType.string,
          indexType: RealmIndexType.regular),
      SchemaProperty('originalFee', RealmPropertyType.double),
      SchemaProperty('newFee', RealmPropertyType.double),
      SchemaProperty('timestamp', RealmPropertyType.timestamp),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}
