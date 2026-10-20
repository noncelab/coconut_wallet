import 'dart:async';

import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vpn_detector/vpn_detector.dart';

class _Connectivity extends Mock implements Connectivity {
  final changes = StreamController<List<ConnectivityResult>>.broadcast(sync: true);
  List<ConnectivityResult> current = [ConnectivityResult.none];

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;
}

class _VpnDetector extends Mock implements VpnDetector {
  final changes = StreamController<VpnStatus>.broadcast(sync: true);

  @override
  Future<VpnStatus> isVpnActive() async => VpnStatus.notActive;

  @override
  Stream<VpnStatus> get onVpnStatusChanged => changes.stream;
}

void main() {
  late _Connectivity connectivity;
  late _VpnDetector vpn;
  late ConnectivityProvider provider;

  setUp(() async {
    connectivity = _Connectivity();
    vpn = _VpnDetector();
    provider = ConnectivityProvider(connectivity: connectivity, vpnDetector: vpn);
    await provider.refreshConnectivity();
  });

  tearDown(() async {
    provider.dispose();
    await connectivity.changes.close();
    await vpn.changes.close();
  });

  for (final transport in [
    ConnectivityResult.wifi,
    ConnectivityResult.ethernet,
    ConnectivityResult.mobile,
    ConnectivityResult.vpn,
    ConnectivityResult.other,
  ]) {
    test('$transport 경로는 네트워크 연결로 인정한다', () {
      expect(provider.isInternetOff, isTrue);

      connectivity.changes.add([transport]);

      expect(provider.isInternetOn, isTrue);
    });
  }

  test('VPN 감지가 남아도 경로가 사라지면 오프라인이다', () {
    connectivity.changes.add([ConnectivityResult.wifi, ConnectivityResult.vpn]);
    expect(provider.isInternetOn, isTrue);
    expect(provider.isVpnActive, isTrue);

    connectivity.changes.add([ConnectivityResult.none]);

    expect(provider.isInternetOff, isTrue);
    expect(provider.isVpnActive, isTrue);
  });

  for (final transport in [ConnectivityResult.vpn, ConnectivityResult.other]) {
    test('앱 복귀 시 $transport 경로도 다시 읽는다', () async {
      connectivity.current = [transport];

      await provider.refreshConnectivity();

      expect(provider.isInternetOn, isTrue);
    });
  }

  test('VPN 감지만 활성화되고 경로가 없으면 연결로 간주하지 않는다', () {
    vpn.changes.add(VpnStatus.active);

    expect(provider.isVpnActive, isTrue);
    expect(provider.isInternetOff, isTrue);
  });
}
