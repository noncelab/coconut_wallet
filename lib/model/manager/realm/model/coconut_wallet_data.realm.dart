// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coconut_wallet_data.dart';

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
    int? balance,
    int? txCount,
    bool isLatestTxBlockHeightZero = false,
  }) {
    if (!_defaultsSet) {
      _defaultsSet = RealmObjectBase.setDefaults<RealmWalletBase>({
        'isLatestTxBlockHeightZero': false,
      });
    }
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'colorIndex', colorIndex);
    RealmObjectBase.set(this, 'iconIndex', iconIndex);
    RealmObjectBase.set(this, 'descriptor', descriptor);
    RealmObjectBase.set(this, 'name', name);
    RealmObjectBase.set(this, 'walletType', walletType);
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
    String transactionHash, {
    RealmWalletBase? walletBase,
    DateTime? timestamp,
    int? blockHeight,
    String? transferType,
    String? memo,
    int? amount,
    int? fee,
    Iterable<String> inputAddressList = const [],
    Iterable<String> outputAddressList = const [],
    String? note,
    DateTime? createdAt,
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'transactionHash', transactionHash);
    RealmObjectBase.set(this, 'walletBase', walletBase);
    RealmObjectBase.set(this, 'timestamp', timestamp);
    RealmObjectBase.set(this, 'blockHeight', blockHeight);
    RealmObjectBase.set(this, 'transferType', transferType);
    RealmObjectBase.set(this, 'memo', memo);
    RealmObjectBase.set(this, 'amount', amount);
    RealmObjectBase.set(this, 'fee', fee);
    RealmObjectBase.set<RealmList<String>>(
        this, 'inputAddressList', RealmList<String>(inputAddressList));
    RealmObjectBase.set<RealmList<String>>(
        this, 'outputAddressList', RealmList<String>(outputAddressList));
    RealmObjectBase.set(this, 'note', note);
    RealmObjectBase.set(this, 'createdAt', createdAt);
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
  RealmWalletBase? get walletBase =>
      RealmObjectBase.get<RealmWalletBase>(this, 'walletBase')
          as RealmWalletBase?;
  @override
  set walletBase(covariant RealmWalletBase? value) =>
      RealmObjectBase.set(this, 'walletBase', value);

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
  String? get transferType =>
      RealmObjectBase.get<String>(this, 'transferType') as String?;
  @override
  set transferType(String? value) =>
      RealmObjectBase.set(this, 'transferType', value);

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
      'walletBase': walletBase.toEJson(),
      'timestamp': timestamp.toEJson(),
      'blockHeight': blockHeight.toEJson(),
      'transferType': transferType.toEJson(),
      'memo': memo.toEJson(),
      'amount': amount.toEJson(),
      'fee': fee.toEJson(),
      'inputAddressList': inputAddressList.toEJson(),
      'outputAddressList': outputAddressList.toEJson(),
      'note': note.toEJson(),
      'createdAt': createdAt.toEJson(),
    };
  }

  static EJsonValue _toEJson(RealmTransaction value) => value.toEJson();
  static RealmTransaction _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'transactionHash': EJsonValue transactionHash,
      } =>
        RealmTransaction(
          fromEJson(id),
          fromEJson(transactionHash),
          walletBase: fromEJson(ejson['walletBase']),
          timestamp: fromEJson(ejson['timestamp']),
          blockHeight: fromEJson(ejson['blockHeight']),
          transferType: fromEJson(ejson['transferType']),
          memo: fromEJson(ejson['memo']),
          amount: fromEJson(ejson['amount']),
          fee: fromEJson(ejson['fee']),
          inputAddressList: fromEJson(ejson['inputAddressList']),
          outputAddressList: fromEJson(ejson['outputAddressList']),
          note: fromEJson(ejson['note']),
          createdAt: fromEJson(ejson['createdAt']),
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
      SchemaProperty('transactionHash', RealmPropertyType.string),
      SchemaProperty('walletBase', RealmPropertyType.object,
          optional: true, linkTarget: 'RealmWalletBase'),
      SchemaProperty('timestamp', RealmPropertyType.timestamp,
          optional: true, indexType: RealmIndexType.regular),
      SchemaProperty('blockHeight', RealmPropertyType.int, optional: true),
      SchemaProperty('transferType', RealmPropertyType.string, optional: true),
      SchemaProperty('memo', RealmPropertyType.string, optional: true),
      SchemaProperty('amount', RealmPropertyType.int, optional: true),
      SchemaProperty('fee', RealmPropertyType.int, optional: true),
      SchemaProperty('inputAddressList', RealmPropertyType.string,
          collectionType: RealmCollectionType.list),
      SchemaProperty('outputAddressList', RealmPropertyType.string,
          collectionType: RealmCollectionType.list),
      SchemaProperty('note', RealmPropertyType.string, optional: true),
      SchemaProperty('createdAt', RealmPropertyType.timestamp, optional: true),
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
