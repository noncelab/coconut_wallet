import 'dart:async';
import 'dart:io';

import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/utils/certificate_util.dart';

typedef CertificateConnection =
    Future<RawSecureSocket> Function(
      String host,
      int port, {
      required Duration timeout,
      required bool Function(X509Certificate) onBadCertificate,
    });

class ServerCertProbe {
  ServerCertProbe({CertificateConnection? connect}) : _connect = connect;

  final CertificateConnection? _connect;
  void Function()? _cancel;
  bool _disposed = false;

  void cancel() => _cancel?.call();

  void dispose() {
    _disposed = true;
    cancel();
  }

  Future<ServerCertObservation?> probe(NodeProvider node) async {
    cancel();
    final host = node.host;
    final port = node.port;
    final pinned = node.pinnedCertFingerprint;
    if (!node.ssl ||
        pinned == null ||
        pinned.trim().isEmpty ||
        DefaultElectrumServer.findMatching(host, port, node.ssl) != null) {
      return const ServerCertObservation(applicable: false, caValid: false);
    }

    final unknown = ServerCertObservation(applicable: true, pinned: pinned, caValid: false);
    if (_disposed) return unknown;
    final cancelled = Completer<RawSecureSocket?>();
    ConnectionTask<RawSocket>? connecting;
    RawSocket? transport;
    RawSecureSocket? socket;
    var caValid = true;
    void close() {
      if (!cancelled.isCompleted) cancelled.complete(null);
      connecting?.cancel();
      transport?.close().ignore();
      socket?.close().ignore();
    }

    bool onBadCertificate(X509Certificate certificate) {
      caValid = false;
      return true; // 인증서만 관찰하며 지갑 데이터는 전송하지 않는다.
    }

    Future<RawSecureSocket?> connect() async {
      if (_connect != null) {
        socket = await _connect(host, port, timeout: const Duration(seconds: 5), onBadCertificate: onBadCertificate);
      } else {
        connecting = await RawSocket.startConnect(host, port);
        if (cancelled.isCompleted) connecting!.cancel();
        transport = await connecting!.socket;
        if (cancelled.isCompleted) {
          transport!.close().ignore();
          return null;
        }
        // ConnectionTask.cancel()만으로는 이미 연결된 TCP의 TLS 협상을 닫지 못한다.
        socket = await RawSecureSocket.secure(transport!, host: host, onBadCertificate: onBadCertificate);
      }
      if (cancelled.isCompleted) {
        socket?.close().ignore();
        return null;
      }
      return socket;
    }

    _cancel = close;
    final deadline = Timer(const Duration(seconds: 5), close);
    try {
      final connected = await Future.any<RawSecureSocket?>([connect(), cancelled.future]);
      final certificate = connected?.peerCertificate;
      if (certificate == null) return unknown;
      return ServerCertObservation(
        applicable: true,
        pinned: pinned,
        actual: CertificateUtil.sha256Fingerprint(certificate),
        endValidity: certificate.endValidity,
        caValid: caValid,
      );
    } catch (_) {
      return unknown;
    } finally {
      deadline.cancel();
      close();
      if (identical(_cancel, close)) _cancel = null;
    }
  }
}
