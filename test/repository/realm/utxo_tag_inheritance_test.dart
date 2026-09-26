import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/realm/realm_utxo_mock.dart';
import 'test_realm_manager.dart';

void main() {
  late TestRealmManager realmManager;
  late UtxoRepository repository;

  setUp(() {
    realmManager = TestRealmManager();
    repository = UtxoRepository(realmManager);
  });

  tearDown(() => realmManager.dispose());

  void addTag(String id, List<String> utxoIds, {int walletId = 1}) {
    realmManager.realm.write(() {
      realmManager.realm.add(RealmUtxoTag(id, walletId, id, 0, DateTime(2026), utxoIdList: utxoIds));
    });
  }

  List<String> attachedIds(String tagId) => realmManager.realm.find<RealmUtxoTag>(tagId)!.utxoIdList.toList();

  Map<String, List<String>> associations() => {
    for (final tag in realmManager.realm.all<RealmUtxoTag>()) tag.id: tag.utxoIdList.toList(),
  };

  test('inherits captured tags when sync removes the source before applying', () async {
    // Given
    addTag('saved', ['source']);
    realmManager.realm.write(() => realmManager.realm.add(RealmUtxoMock.getMock(id: 'source')));
    final capturedTagIds = repository.getUtxoTagsByTxHash(1, 'source').value.map((tag) => tag.id).toList();
    await repository.deleteUtxoList(1, ['source']);
    expect(attachedIds('saved'), isEmpty);

    // When
    final result = await repository.applyInheritedTags(
      1,
      sourceUtxoIds: ['source'],
      targetUtxoIds: ['target'],
      tagIds: capturedTagIds,
    );

    // Then
    expect(result.isSuccess, isTrue);
    expect(repository.getUtxoTagsByTxHash(1, 'target').value.map((tag) => tag.id), capturedTagIds);
    expect(attachedIds('saved'), ['target']);
  });

  test('inherits the selected union once on every target and preserves unrelated associations', () async {
    // Given
    addTag('first', ['source-a', 'source-b', 'unrelated', 'target-a']);
    addTag('second', ['source-b']);
    addTag('declined', ['source-a', 'unrelated']);
    addTag('target-only', ['target-a']);
    addTag('other-wallet', ['source-a', 'target-a'], walletId: 2);

    // When
    final result = await repository.applyInheritedTags(
      1,
      sourceUtxoIds: ['source-a', 'source-b', 'source-a'],
      targetUtxoIds: ['target-a', 'target-b', 'target-a'],
      tagIds: ['first', 'second', 'first', 'second', 'first', 'second'],
    );

    // Then
    expect(result.isSuccess, isTrue);
    expect(associations(), {
      'first': ['unrelated', 'target-a', 'target-b'],
      'second': ['target-a', 'target-b'],
      'declined': ['unrelated'],
      'target-only': ['target-a'],
      'other-wallet': ['source-a', 'target-a'],
    });
  });

  test('declining inheritance clears consumed references without changing target tags', () async {
    // Given
    addTag('saved', ['source', 'unrelated']);
    addTag('target-only', ['target']);

    // When
    final result = await repository.applyInheritedTags(
      1,
      sourceUtxoIds: ['source'],
      targetUtxoIds: ['target'],
      tagIds: [],
    );

    // Then
    expect(result.isSuccess, isTrue);
    expect(associations(), {
      'saved': ['unrelated'],
      'target-only': ['target'],
    });
  });

  test('clears consumed references when the transaction has no own outputs', () async {
    // Given
    addTag('saved', ['source', 'unrelated']);

    // When
    final result = await repository.applyInheritedTags(
      1,
      sourceUtxoIds: ['source'],
      targetUtxoIds: [],
      tagIds: ['saved'],
    );

    // Then
    expect(result.isSuccess, isTrue);
    expect(attachedIds('saved'), ['unrelated']);
  });

  test('rejects six selected tags before removing any source references', () async {
    // Given
    for (var index = 0; index < 6; index++) {
      addTag('tag-$index', ['source-$index']);
    }
    final before = associations();

    // When
    final result = await repository.applyInheritedTags(
      1,
      sourceUtxoIds: List.generate(6, (index) => 'source-$index'),
      targetUtxoIds: ['target'],
      tagIds: List.generate(6, (index) => 'tag-$index'),
    );

    // Then
    expect(result.isFailure, isTrue);
    expect(associations(), before);
  });

  test('accepts five distinct tags including one already attached to the target', () async {
    // Given
    for (var index = 0; index < 5; index++) {
      addTag('tag-$index', ['source', if (index == 0) 'target']);
    }

    // When
    final result = await repository.applyInheritedTags(
      1,
      sourceUtxoIds: ['source'],
      targetUtxoIds: ['target'],
      tagIds: List.generate(5, (index) => 'tag-$index'),
    );

    // Then
    expect(result.isSuccess, isTrue);
    expect(associations().values, everyElement(['target']));
    expect(repository.getUtxoTagsByTxHash(1, 'target').value, hasLength(5));
  });

  test('rejects overflow on a later target without modifying an earlier target or any source', () async {
    // Given
    addTag('selected', ['source']);
    for (var index = 0; index < 5; index++) {
      addTag('existing-$index', ['target-full']);
    }
    final before = associations();

    // When
    final result = await repository.applyInheritedTags(
      1,
      sourceUtxoIds: ['source'],
      targetUtxoIds: ['target-empty', 'target-full'],
      tagIds: ['selected'],
    );

    // Then
    expect(result.isFailure, isTrue);
    expect(associations(), before);
  });

  test('rejects a selected tag from another wallet without changing either wallet', () async {
    // Given
    addTag('saved', ['source']);
    addTag('foreign', ['source'], walletId: 2);
    final before = associations();

    // When
    final result = await repository.applyInheritedTags(
      1,
      sourceUtxoIds: ['source'],
      targetUtxoIds: ['target'],
      tagIds: ['saved', 'foreign'],
    );

    // Then
    expect(result.isFailure, isTrue);
    expect(associations(), before);
  });

  test('rejects a tag deleted after capture without recreating it or losing remaining source tags', () async {
    // Given
    addTag('saved', ['source']);
    addTag('deleted', ['source']);
    final capturedTagIds = repository.getUtxoTagsByTxHash(1, 'source').value.map((tag) => tag.id).toList();
    expect(repository.deleteUtxoTag('deleted').isSuccess, isTrue);
    final before = associations();

    // When
    final result = await repository.applyInheritedTags(
      1,
      sourceUtxoIds: ['source'],
      targetUtxoIds: ['target'],
      tagIds: capturedTagIds,
    );

    // Then
    expect(result.isFailure, isTrue);
    expect(associations(), before);
    expect(realmManager.realm.find<RealmUtxoTag>('deleted'), isNull);
  });

  test('repeating an inheritance application keeps target associations unique', () async {
    // Given
    addTag('saved', ['source', 'unrelated']);
    expect(
      (await repository.applyInheritedTags(
        1,
        sourceUtxoIds: ['source'],
        targetUtxoIds: ['target'],
        tagIds: ['saved'],
      )).isSuccess,
      isTrue,
    );

    // When
    final result = await repository.applyInheritedTags(
      1,
      sourceUtxoIds: ['source'],
      targetUtxoIds: ['target'],
      tagIds: ['saved'],
    );

    // Then
    expect(result.isSuccess, isTrue);
    expect(attachedIds('saved'), ['unrelated', 'target']);
  });
}
