import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/services/network/socket/socket_factory.dart';
import 'package:coconut_wallet/services/network/socket/socket_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'test_long_socket_response.dart';
@GenerateMocks([SocketFactory, Socket, SecureSocket])
import 'socket_manager_test.mocks.dart';

void main() {
  group('SocketManager Tests', () {
    late MockSocketFactory mockSocketFactory;
    late MockSocket mockSocket;
    late MockSecureSocket mockSecureSocket;
    late SocketManager socketManager;
    late StreamController<Uint8List> streamController;

    setUp(() {
      mockSocketFactory = MockSocketFactory();
      mockSocket = MockSocket();
      mockSecureSocket = MockSecureSocket();
      streamController = StreamController<Uint8List>();

      // 일반 Socket mock 설정
      when(mockSocket.listen(any,
              onError: anyNamed('onError'),
              onDone: anyNamed('onDone'),
              cancelOnError: anyNamed('cancelOnError')))
          .thenAnswer((invocation) {
        final onData = invocation.positionalArguments[0] as Function(Uint8List);
        final onError = invocation.namedArguments[#onError] as Function?;
        final onDone = invocation.namedArguments[#onDone] as Function?;

        return streamController.stream.listen(
          onData,
          onError: (error) => onError?.call(error),
          onDone: () => onDone?.call(),
          cancelOnError: invocation.namedArguments[#cancelOnError],
        );
      });

      // SecureSocket mock 설정도 같은 스트림 컨트롤러 사용
      when(mockSecureSocket.listen(any,
              onError: anyNamed('onError'),
              onDone: anyNamed('onDone'),
              cancelOnError: anyNamed('cancelOnError')))
          .thenAnswer((invocation) {
        final onData = invocation.positionalArguments[0] as Function(Uint8List);
        final onError = invocation.namedArguments[#onError] as Function?;
        final onDone = invocation.namedArguments[#onDone] as Function?;

        return streamController.stream.listen(
          onData,
          onError: (error) => onError?.call(error),
          onDone: () => onDone?.call(),
          cancelOnError: invocation.namedArguments[#cancelOnError],
        );
      });

      // Socket 닫기 설정
      when(mockSocket.close()).thenAnswer((_) async => null);
      when(mockSecureSocket.close()).thenAnswer((_) async => null);

      // Socket 쓰기 설정
      when(mockSocket.writeln(any)).thenReturn(null);
      when(mockSecureSocket.writeln(any)).thenReturn(null);

      socketManager = SocketManager(
        factory: mockSocketFactory,
        maxConnectionAttempts: 3,
      );
    });

    tearDown(() {
      streamController.close();
    });

    test('초기 상태는 재연결 중이어야 함', () {
      expect(socketManager.connectionStatus, equals(SocketConnectionStatus.reconnecting));
    });

    group('연결 테스트', () {
      test('SSL 연결 성공 시 연결 상태가 연결됨이어야 함', () async {
        when(mockSocketFactory.createSecureSocket(any, any))
            .thenAnswer((_) async => mockSecureSocket);

        await socketManager.connect('localhost', 8080, ssl: true);

        expect(socketManager.connectionStatus, equals(SocketConnectionStatus.connected));
        verify(mockSocketFactory.createSecureSocket('localhost', 8080)).called(1);
      });

      test('일반 연결 성공 시 연결 상태가 연결됨이어야 함', () async {
        when(mockSocketFactory.createSocket(any, any)).thenAnswer((_) async => mockSocket);

        await socketManager.connect('localhost', 8080, ssl: false);

        expect(socketManager.connectionStatus, equals(SocketConnectionStatus.connected));
        verify(mockSocketFactory.createSocket('localhost', 8080)).called(1);
      });

      test('연결 실패 시 재연결 상태로 변경되어야 함', () async {
        when(mockSocketFactory.createSecureSocket(any, any))
            .thenThrow(const SocketException('연결 실패'));

        await socketManager.connect('localhost', 8080);

        expect(socketManager.connectionStatus, equals(SocketConnectionStatus.reconnecting));
      });

      test('최대 연결 시도 횟수 초과 시 연결 상태가 종료됨이어야 함', () async {
        when(mockSocketFactory.createSecureSocket(any, any))
            .thenThrow(const SocketException('연결 실패'));

        // 최대 시도 횟수는 3으로 설정되어 있음
        await socketManager.connect('localhost', 8080);
        await socketManager.connect('localhost', 8080);
        await socketManager.connect('localhost', 8080);
        await socketManager.connect('localhost', 8080);

        expect(socketManager.connectionStatus, equals(SocketConnectionStatus.terminated));
      });
    });

    group('데이터 송신 테스트', () {
      test('SSL 연결된 상태에서 데이터 전송이 성공해야 함', () async {
        when(mockSocketFactory.createSecureSocket(any, any))
            .thenAnswer((_) async => mockSecureSocket);

        await socketManager.connect('localhost', 8080, ssl: true);
        await socketManager.send('test data');

        verify(mockSecureSocket.writeln('test data')).called(1);
      });

      test('연결되지 않은 상태에서 데이터 전송 시 예외가 발생해야 함', () async {
        expect(() => socketManager.send('test data'), throwsA(isA<SocketException>()));
      });

      test('데이터 전송 중 오류 발생 시 재연결 상태로 변경되어야 함', () async {
        when(mockSocketFactory.createSecureSocket(any, any))
            .thenAnswer((_) async => mockSecureSocket);
        when(mockSecureSocket.writeln(any)).thenThrow(Exception('전송 오류'));

        await socketManager.connect('localhost', 8080, ssl: true);

        expect(() => socketManager.send('test data'), throwsException);
        expect(socketManager.connectionStatus, equals(SocketConnectionStatus.reconnecting));
      });
    });

    group('데이터 수신 테스트', () {
      test('JSON 데이터 수신 및 처리 테스트', () async {
        when(mockSocketFactory.createSecureSocket(any, any))
            .thenAnswer((_) async => mockSecureSocket);

        await socketManager.connect('localhost', 8080, ssl: true);

        final completer = Completer<dynamic>();
        socketManager.setCompleter(1, completer);

        // JSON 데이터 전송 시뮬레이션
        const jsonData = '{"id":1,"jsonrpc":"2.0","result":{"success":true}}';
        streamController.add(utf8.encode(jsonData));

        final result = await completer.future;
        expect(result['id'], equals(1));
        expect(result['result']['success'], equals(true));
      });

      test('스크립트 구독 콜백 테스트', () async {
        when(mockSocketFactory.createSecureSocket(any, any))
            .thenAnswer((_) async => mockSecureSocket);

        await socketManager.connect('localhost', 8080, ssl: true);

        final completer = Completer<String?>();
        socketManager.setSubscriptionCallback('script123', (script, status) {
          completer.complete(status);
        });

        // 구독 이벤트 데이터 전송 시뮬레이션
        const jsonData =
            '{"method":"blockchain.scripthash.subscribe","params":["script123","status123"]}';
        streamController.add(utf8.encode(jsonData));

        final status = await completer.future;
        expect(status, equals('status123'));
      });
    });

    group('복잡한 JSON 데이터 처리 테스트', () {
      test('중첩된 JSON 객체 처리 테스트', () async {
        when(mockSocketFactory.createSecureSocket(any, any))
            .thenAnswer((_) async => mockSecureSocket);

        await socketManager.connect('localhost', 8080, ssl: true);

        final completer = Completer<dynamic>();
        socketManager.setCompleter(6, completer);

        const response =
            '{"id":6,"jsonrpc":"2.0","result":{"blockhash":"5ac1d7097ad416628d0843393c56dec9db8fcd60aa5fc67c7ea0bc6ea038d3c7","blocktime":1730360700,"confirmations":36250,"hash":"2dca645bb4e4434b3e7a1502fa8c1ca942385aba99b5fff065f6183a898597d0"}}';

        streamController.add(utf8.encode(response));

        final result = await completer.future;
        expect(result['id'], equals(6));
        expect(result['result']['blockhash'],
            equals('5ac1d7097ad416628d0843393c56dec9db8fcd60aa5fc67c7ea0bc6ea038d3c7'));
      });

      test('여러 줄의 JSON 데이터 처리 테스트', () async {
        when(mockSocketFactory.createSecureSocket(any, any))
            .thenAnswer((_) async => mockSecureSocket);

        await socketManager.connect('localhost', 8080, ssl: true);

        final completer1 = Completer<dynamic>();
        final completer2 = Completer<dynamic>();
        socketManager.setCompleter(1, completer1);
        socketManager.setCompleter(2, completer2);

        const jsonData = '{"id":1,"result":true}\n{"id":2,"result":"success"}';
        streamController.add(utf8.encode(jsonData));

        final result1 = await completer1.future;
        final result2 = await completer2.future;

        expect(result1['id'], equals(1));
        expect(result1['result'], equals(true));
        expect(result2['id'], equals(2));
        expect(result2['result'], equals('success'));
      });

      // 부분적으로 수신되는 JSON 데이터 테스트 추가
      test('부분적으로 수신되는 JSON 데이터 처리 테스트', () async {
        when(mockSocketFactory.createSecureSocket(any, any))
            .thenAnswer((_) async => mockSecureSocket);

        await socketManager.connect('localhost', 8080, ssl: true);

        final completer = Completer<dynamic>();
        socketManager.setCompleter(3, completer);

        // JSON 데이터를 나누어 전송
        const jsonPart1 = '{"id":3,"jsonrpc":"2.0","resu';
        const jsonPart2 = 'lt":{"message":"partial data test"}}';

        streamController.add(utf8.encode(jsonPart1));
        // 약간의 지연 후 나머지 부분 전송
        await Future.delayed(const Duration(milliseconds: 50));
        streamController.add(utf8.encode(jsonPart2));

        final result = await completer.future;
        expect(result['id'], equals(3));
        expect(result['result']['message'], equals('partial data test'));
      });

      // 문자열 내 중괄호가 있는 경우 테스트
      test('문자열 내 중괄호가 있는 JSON 데이터 처리 테스트', () async {
        when(mockSocketFactory.createSecureSocket(any, any))
            .thenAnswer((_) async => mockSecureSocket);

        await socketManager.connect('localhost', 8080, ssl: true);

        final completer = Completer<dynamic>();
        socketManager.setCompleter(4, completer);

        // 문자열 내에 중괄호가 포함된 JSON
        const jsonData = '{"id":4,"result":"This is a string with { and } braces inside"}';
        streamController.add(utf8.encode(jsonData));

        final result = await completer.future;
        expect(result['id'], equals(4));
        expect(result['result'], equals('This is a string with { and } braces inside'));
      });
    });

    test('긴 데이터 수신 테스트', () async {
      when(mockSocketFactory.createSecureSocket(any, any))
          .thenAnswer((_) async => mockSecureSocket);

      await socketManager.connect('localhost', 8080, ssl: true);

      // 테스트에 사용할 ID 설정
      const testId = 6;
      final completer = Completer<dynamic>();
      socketManager.setCompleter(testId, completer);

      for (var response in longSocketResponseValue) {
        streamController.add(utf8.encode(response));
      }

      // completer가 완료될 때까지 대기
      final result = await completer.future;

      // 응답 검증
      expect(result['id'], equals(testId));

      // 결과의 특정 필드 검증
      final resultData = result['result'];
      expect(resultData['blockhash'],
          equals('5ac1d7097ad416628d0843393c56dec9db8fcd60aa5fc67c7ea0bc6ea038d3c7'));
      expect(resultData['blocktime'], equals(1730360700));
      expect(resultData['confirmations'], isNotNull);
      expect(resultData['hash'],
          equals('2dca645bb4e4434b3e7a1502fa8c1ca942385aba99b5fff065f6183a898597d0'));

      // 추가 복잡한 데이터 필드 검증
      expect(resultData['hex'], isNotNull);
      expect(resultData['hex'].length, greaterThan(1000)); // 긴 16진수 데이터 확인
      expect(resultData['in_active_chain'], isTrue);
      expect(resultData['size'], equals(3891));
      expect(resultData['time'], equals(1730360700));
      expect(resultData['txid'],
          equals('b3c3bd06ff9d2cda768a4946a4ed1d87a62700f618cfb4965b1e28c4fef3aa12'));
      expect(resultData['version'], equals(2));

      // vin 배열 검증
      expect(resultData['vin'], isA<List>());
      expect(resultData['vin'].length, equals(26)); // Bitcoin 트랜잭션 입력 개수 검증

      // vout 배열 검증
      expect(resultData['vout'], isA<List>());
      expect(resultData['vout'].length, equals(1)); // Bitcoin 트랜잭션 출력 개수 검증
      expect(resultData['vout'][0]['value'], equals(1.0)); // 출력 금액 검증
    });

    test('연결 종료 테스트', () async {
      when(mockSocketFactory.createSecureSocket(any, any))
          .thenAnswer((_) async => mockSecureSocket);

      await socketManager.connect('localhost', 8080, ssl: true);
      await socketManager.disconnect();

      verify(mockSecureSocket.close()).called(1);
      expect(socketManager.connectionStatus, equals(SocketConnectionStatus.terminated));
    });

    test('재연결 콜백 테스트', () async {
      when(mockSocketFactory.createSecureSocket(any, any))
          .thenAnswer((_) async => mockSecureSocket);

      bool callbackCalled = false;
      socketManager.onReconnect = () {
        callbackCalled = true;
      };

      // 처음 연결
      await socketManager.connect('localhost', 8080, ssl: true);

      // 오류 발생 시뮬레이션
      streamController.addError(Exception('연결 오류'));

      // 재연결 지연 시간 기다림
      await Future.delayed(const Duration(seconds: 2));

      expect(callbackCalled, isTrue);
    });

    test('구독 콜백 제거 테스트', () async {
      when(mockSocketFactory.createSecureSocket(any, any))
          .thenAnswer((_) async => mockSecureSocket);

      await socketManager.connect('localhost', 8080, ssl: true);

      int callCount = 0;
      socketManager.setSubscriptionCallback('script123', (script, status) {
        callCount++;
      });

      // 첫 번째 이벤트
      const jsonData1 =
          '{"method":"blockchain.scripthash.subscribe","params":["script123","status1"]}';
      streamController.add(utf8.encode(jsonData1));

      // 이벤트 처리 시간 기다림
      await Future.delayed(const Duration(milliseconds: 100));

      // 콜백 제거
      socketManager.removeSubscriptionCallback('script123');

      // 두 번째 이벤트 (콜백이 제거되어 처리되지 않아야 함)
      const jsonData2 =
          '{"method":"blockchain.scripthash.subscribe","params":["script123","status2"]}';
      streamController.add(utf8.encode(jsonData2));

      // 이벤트 처리 시간 기다림
      await Future.delayed(const Duration(milliseconds: 100));

      expect(callCount, equals(1));
    });

    test('onDone 콜백 호출 시 연결 상태가 종료됨으로 변경되어야 함', () async {
      when(mockSocketFactory.createSecureSocket(any, any))
          .thenAnswer((_) async => mockSecureSocket);

      await socketManager.connect('localhost', 8080, ssl: true);

      expect(socketManager.connectionStatus, equals(SocketConnectionStatus.connected));

      // onDone 콜백 트리거
      streamController.close();

      // 이벤트 처리 시간 기다림
      await Future.delayed(const Duration(milliseconds: 100));

      expect(socketManager.connectionStatus, equals(SocketConnectionStatus.terminated));
    });
  });
}
