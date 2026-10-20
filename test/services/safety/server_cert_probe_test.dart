import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/safety/server_cert_probe.dart';
import 'package:coconut_wallet/utils/certificate_util.dart';
import 'package:flutter_test/flutter_test.dart';

import 'safety_fakes.dart';

class _Certificate extends Fake implements X509Certificate {
  @override
  Uint8List get der => Uint8List.fromList([1, 2, 3]);
  @override
  DateTime get endValidity => DateTime(2027);
}

class _Socket extends Fake implements RawSecureSocket {
  X509Certificate? certificate = _Certificate();
  int destroyed = 0;
  @override
  X509Certificate? get peerCertificate => certificate;
  @override
  Future<RawSecureSocket> close() async {
    destroyed++;
    return this;
  }
}

void main() {
  late SafetyNodeFake node;
  late _Socket socket;
  late ServerCertProbe probe;
  var connections = 0;
  var badCertificate = false;
  var throws = false;
  setUp(() {
    NetworkType.setNetworkType(NetworkType.mainnet);
    node = SafetyNodeFake();
    socket = _Socket();
    connections = 0;
    badCertificate = false;
    throws = false;
    probe = ServerCertProbe(
      connect: (host, port, {required timeout, required onBadCertificate}) async {
        connections++;
        expect(host, node.host);
        expect(port, node.port);
        expect(timeout, const Duration(seconds: 5));
        if (throws) throw const SocketException('unavailable');
        if (badCertificate) expect(onBadCertificate(socket.certificate!), isTrue);
        return socket;
      },
    );
  });
  tearDown(() {
    probe.dispose();
    node.dispose();
  });

  test('built-in TLS server is not applicable and is never contacted', () async {
    node.host = 'electrum.coconut.onl';
    node.port = 443;
    expect((await probe.probe(node))!.applicable, isFalse);
    expect(connections, 0);
  });
  test('plain TCP server is not applicable', () async {
    node.ssl = false;
    expect((await probe.probe(node))!.applicable, isFalse);
    expect(connections, 0);
  });
  test('observes CA certificate, expiry and configured pin then destroys connection', () async {
    final observation = (await probe.probe(node))!;
    expect(observation.applicable, isTrue);
    expect(observation.caValid, isTrue);
    expect(observation.pinned, 'pin');
    expect(observation.actual, CertificateUtil.sha256Fingerprint(socket.certificate!));
    expect(observation.endValidity, DateTime(2027));
    expect(socket.destroyed, 1);
  });
  test('untrusted certificate is only observed; mismatched pin is left for engine', () async {
    badCertificate = true;
    final observation = (await probe.probe(node))!;
    expect(observation.caValid, isFalse);
    expect(observation.actual, isNot(observation.pinned));
    expect(node.pinnedCertFingerprint, 'pin');
    expect(socket.destroyed, 1);
  });
  test('custom server without a configured pin is outside the check scope', () async {
    node.pinnedCertFingerprint = null;
    expect((await probe.probe(node))!.applicable, isFalse);
    expect(connections, 0);
  });
  test('connection failure returns unknown', () async {
    throws = true;
    final observation = (await probe.probe(node))!;
    expect(observation.applicable, isTrue);
    expect(observation.actual, isNull);
  });
  test('missing peer certificate still closes the socket', () async {
    socket.certificate = null;
    expect((await probe.probe(node))!.actual, isNull);
    expect(socket.destroyed, 1);
  });
  test('dispose returns unknown immediately and closes a connection that finishes later', () async {
    final connection = Completer<RawSecureSocket>();
    probe = ServerCertProbe(connect: (_, __, {required timeout, required onBadCertificate}) => connection.future);
    final pending = probe.probe(node);
    probe.dispose();
    expect((await pending.timeout(const Duration(seconds: 1)))!.actual, isNull);
    connection.complete(socket);
    await Future<void>.delayed(Duration.zero);
    expect(socket.destroyed, 1);
  });
  test('whole TCP and stalled TLS handshake times out and closes the transport', () async {
    final peer = await SafetySilentTlsPeer.start();
    addTearDown(peer.close);
    node.host = '127.0.0.1';
    node.port = peer.port;
    probe = ServerCertProbe();
    final elapsed = Stopwatch()..start();
    final pending = probe.probe(node);
    await peer.accepted.future.timeout(const Duration(seconds: 2));
    final observation = (await pending.timeout(const Duration(seconds: 6)))!;
    expect(elapsed.elapsed, lessThan(const Duration(seconds: 6)));
    expect(observation.applicable, isTrue);
    expect(observation.actual, isNull);
    expect(observation.caValid, isFalse);
    expect(node.pinnedCertFingerprint, 'pin');
    await peer.disconnected.future.timeout(const Duration(seconds: 1));
  });
  test('a replacement probe cancels stalled TLS and dispose closes the replacement', () async {
    final firstPeer = await SafetySilentTlsPeer.start();
    final secondPeer = await SafetySilentTlsPeer.start();
    addTearDown(firstPeer.close);
    addTearDown(secondPeer.close);
    node.host = '127.0.0.1';
    node.port = firstPeer.port;
    probe = ServerCertProbe();
    final first = probe.probe(node);
    await firstPeer.accepted.future.timeout(const Duration(seconds: 2));
    node.port = secondPeer.port;
    final second = probe.probe(node);
    expect((await first.timeout(const Duration(seconds: 1)))!.actual, isNull);
    await firstPeer.disconnected.future.timeout(const Duration(seconds: 1));
    await secondPeer.accepted.future.timeout(const Duration(seconds: 2));
    probe.dispose();
    expect((await second.timeout(const Duration(seconds: 1)))!.actual, isNull);
    await secondPeer.disconnected.future.timeout(const Duration(seconds: 1));
    expect(node.pinnedCertFingerprint, 'pin');
  });
}
