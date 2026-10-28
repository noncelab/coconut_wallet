import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/view_model/settings/block_explorer_view_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _ExplorerProvider extends Fake implements BlockExplorerProvider {
  @override
  bool get useDefaultExplorer => false;
  @override
  String get customExplorerUrl => 'https://example.com';

  final savedDefaults = <bool>[];
  final savedUrls = <String>[];
  Completer<void>? saveGate;
  final saveStarted = Completer<void>();

  @override
  Future<void> setUseDefaultExplorer(bool value) async {
    savedDefaults.add(value);
    saveStarted.complete();
    await saveGate?.future;
  }

  @override
  Future<void> setCustomExplorerUrl(String url) async => savedUrls.add(url);
}

class _DelayedAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  final response = Completer<ResponseBody>();
  bool cancelled = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    cancelFuture?.then((_) => cancelled = true);
    started.complete();
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _ExplorerProvider provider;
  late _DelayedAdapter adapter;
  late BlockExplorerViewModel model;

  setUp(() {
    provider = _ExplorerProvider();
    adapter = _DelayedAdapter();
    model = BlockExplorerViewModel(provider, dio: Dio()..httpClientAdapter = adapter);
    model.onCustomUrlChanged('https://example.org');
  });

  test('URL 수정 후 기본 탐색기를 켜면 변경 여부가 같아도 화면을 갱신한다', () {
    addTearDown(model.dispose);
    expect(model.hasChanges, isTrue);
    var notifications = 0;
    model.addListener(() => notifications++);

    model.toggleDefaultExplorer(true);

    expect(model.hasChanges, isTrue);
    expect(model.isDefaultExplorerEnabled, isTrue);
    expect(model.showCustomUrlTextField, isFalse);
    expect(notifications, 1);
  });

  for (final status in [200, 500]) {
    test('화면 종료 후 $status 응답은 저장하거나 알리지 않는다', () async {
      var notifications = 0;
      model.addListener(() => notifications++);
      final pending = model.saveChanges();
      await adapter.started.future;
      final beforeDispose = notifications;
      model.dispose();
      adapter.response.complete(ResponseBody.fromString('', status));
      await pending;
      expect(adapter.cancelled, isTrue);
      expect(notifications, beforeDispose);
      expect(provider.savedDefaults, isEmpty);
      expect(provider.savedUrls, isEmpty);
    });
  }

  test('연결 성공 후 설정 저장 중 화면을 닫아도 오류가 없다', () async {
    provider.saveGate = Completer<void>();
    final pending = model.saveChanges();
    await adapter.started.future;
    adapter.response.complete(ResponseBody.fromString('', 200));
    await provider.saveStarted.future;
    expect(provider.savedDefaults, [false]);
    model.dispose();
    provider.saveGate!.complete();
    await pending;
    expect(provider.savedUrls, ['https://example.org']);
  });

  test('열린 화면에서는 연결 성공 후 설정을 저장한다', () async {
    addTearDown(model.dispose);
    final pending = model.saveChanges();
    await adapter.started.future;
    adapter.response.complete(ResponseBody.fromString('', 200));
    await pending;
    expect(model.isConnectionSuccessful, isTrue);
    expect(model.hasChanges, isFalse);
    expect(provider.savedUrls, ['https://example.org']);
  });

  test('열린 화면에서 연결 실패 시 저장하지 않는다', () async {
    addTearDown(model.dispose);
    final pending = model.saveChanges();
    await adapter.started.future;
    adapter.response.complete(ResponseBody.fromString('', 500));
    await pending;
    expect(model.isConnecting, isFalse);
    expect(model.isConnectionSuccessful, isFalse);
    expect(model.hasChanges, isTrue);
    expect(provider.savedUrls, isEmpty);
  });
}
