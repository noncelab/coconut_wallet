import 'dart:io';

abstract class SocketFactory {
  Future<Socket> createSocket(String host, int port);

  Future<SecureSocket> createSecureSocket(String host, int port);
}

class DefaultSocketFactory implements SocketFactory {
  @override
  Future<Socket> createSocket(String host, int port) {
    return Socket.connect(host, port);
  }

  @override
  Future<SecureSocket> createSecureSocket(String host, int port) {
    var socket = SecureSocket.connect(host, port);
    return socket;
  }
}
