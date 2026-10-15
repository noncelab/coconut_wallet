import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/node_connection_status.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/electrum_server_provider.dart';
import 'package:coconut_wallet/providers/view_model/settings/electrum_server_view_model.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// 모킹할 클래스 목록
// .mocks.dart 생성:
//   fvm dart run build_runner build --delete-conflicting-outputs --build-filter="test/view_model/*.mocks.dart"
// (전체 재생성 `make ready`)
@GenerateMocks([NodeProvider, ElectrumServerProvider])
import 'electrum_server_view_model_test.mocks.dart';

/// 일렉트럼 서버 화면을 벗어날 때 실제 연결에 어떤 조치를 취하는지 검증한다.
/// 이 화면은 임시 프로브로만 서버를 확인하고 소켓은 건드리지 않으므로,
/// 이탈 시점의 판정이 유일하게 실제 연결을 움직이는 지점이다.
///
/// 미검증 - _isEndpointChangedSinceEntry의 pinnedCertFingerprint 비교
/// host/port/ssl은 그대로인데 지문만 바뀌는 경우(TOFU로 인증서를 새로 신뢰 승인)를 덮는 테스트가 없어서,
/// 그 비교를 지워도 아래 테스트는 전부 통과한다. 검증하려면 checkServerConnection이 처음에는
/// untrustedCertificateError를 반환하고 trustPendingCertificateAndConnect() 이후에는 성공하도록
/// 단계적으로 응답하는 스텁 추가가 필요하다.
void main() {
  late MockNodeProvider nodeProvider;
  late MockElectrumServerProvider electrumServerProvider;

  final initialServer = ElectrumServer.custom('initial.example.com', 50002, true);
  final otherServer = ElectrumServer.custom('other.example.com', 50002, true);

  setUpAll(() {
    provideDummy<Result<bool>>(Result.success(true));
    provideDummy<Result<String>>(Result.success(''));
  });

  setUp(() {
    NetworkType.setNetworkType(NetworkType.regtest);

    nodeProvider = MockNodeProvider();
    electrumServerProvider = MockElectrumServerProvider();

    when(electrumServerProvider.getElectrumServer()).thenReturn(initialServer);
    when(electrumServerProvider.getUserServers()).thenAnswer((_) async => <ElectrumServer>[]);
    when(
      electrumServerProvider.setCustomElectrumServer(
        any,
        any,
        any,
        pinnedCertFingerprint: anyNamed('pinnedCertFingerprint'),
      ),
    ).thenAnswer((_) async {});
    when(
      electrumServerProvider.addUserServer(any, any, any, pinnedCertFingerprint: anyNamed('pinnedCertFingerprint')),
    ).thenAnswer((_) async {});
    when(electrumServerProvider.setSelectedDefaultServer(any)).thenAnswer((_) async {});

    when(nodeProvider.hasConnectionError).thenReturn(false);
    when(
      nodeProvider.state,
    ).thenReturn(const NodeProviderState(nodeSyncState: NodeSyncState.completed, registeredWallets: {}));
    when(nodeProvider.checkServerConnection(any)).thenAnswer((_) async => Result.success(true));
    when(nodeProvider.changeServer(any)).thenAnswer((_) async => Result.success(true));
    when(nodeProvider.applyServerChange()).thenAnswer((_) async => Result.success(true));
    when(nodeProvider.reconnectIfNeeded()).thenAnswer((_) async => Result.success(true));
  });

  /// 생성자에서 시작한 프로브들이 끝나 nodeConnectionStatus가 확정될 때까지 기다린다.
  Future<ElectrumServerViewModel> createViewModel() async {
    final viewModel = ElectrumServerViewModel(nodeProvider, electrumServerProvider);
    await pumpEventQueue();
    return viewModel;
  }

  test('엔드포인트가 바뀌었으면 이탈 시 서버 변경을 반영한다', () async {
    final viewModel = await createViewModel();

    final changed = await viewModel.changeServerAndUpdateState(otherServer);
    expect(changed, isTrue);

    viewModel.dispose();

    verify(nodeProvider.applyServerChange()).called(1);
    verifyNever(nodeProvider.reconnectIfNeeded());
  });

  test('엔드포인트가 그대로여도 화면 연결이 정상이면 이탈 시 재연결을 확인한다', () async {
    final viewModel = await createViewModel();
    expect(viewModel.nodeConnectionStatus, NodeConnectionStatus.connected);

    viewModel.dispose();

    verify(nodeProvider.reconnectIfNeeded()).called(1);
    verifyNever(nodeProvider.applyServerChange());
  });

  test('화면 연결 자체가 실패면 이탈 시 아무것도 하지 않는다', () async {
    when(nodeProvider.checkServerConnection(any)).thenAnswer((_) async => Result.failure(ErrorCodes.networkError));

    final viewModel = await createViewModel();
    expect(viewModel.nodeConnectionStatus, NodeConnectionStatus.failed);

    viewModel.dispose();

    verifyNever(nodeProvider.reconnectIfNeeded());
    verifyNever(nodeProvider.applyServerChange());
  });

  test('서버 주소를 편집하다 만 상태(waiting)면 이탈 시 아무것도 하지 않는다', () async {
    final viewModel = await createViewModel();
    viewModel.setNodeConnectionStatus(NodeConnectionStatus.waiting);

    viewModel.dispose();

    verifyNever(nodeProvider.reconnectIfNeeded());
    verifyNever(nodeProvider.applyServerChange());
  });

  test('바꿨다가 원래 서버로 되돌렸으면 이탈 시 연결을 건드리지 않는다', () async {
    final viewModel = await createViewModel();

    await viewModel.changeServerAndUpdateState(otherServer);
    await viewModel.changeServerAndUpdateState(initialServer);

    viewModel.dispose();

    verifyNever(nodeProvider.applyServerChange());
  });
}
