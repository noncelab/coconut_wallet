class ElectrumServer {
  final String host;
  final int port;
  final bool ssl;
  final bool isFloresta;
  final int rpcPort;

  const ElectrumServer(
    this.host,
    this.port,
    this.ssl, {
    this.isFloresta = false,
    this.rpcPort = 0,
  });

  factory ElectrumServer.custom(String host, int port, bool ssl, {bool isFloresta = false, int rpcPort = 0}) {
    return ElectrumServer(
      host,
      port,
      host.contains('.onion') ? false : ssl,
      isFloresta: isFloresta,
      rpcPort: rpcPort > 0 ? rpcPort : port,
    );
  }
}
