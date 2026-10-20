import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';

/// Wallet Health 엔진·감지 테스트가 함께 쓰는 입력 만들기
final testNow = DateTime(2026, 10, 20, 12);

const btc = 100000000;

SafetyTx tx(
  String txid, {
  TransactionType type = TransactionType.sent,
  int height = 0,
  int amount = 1000,
  DateTime? timestamp,
  DateTime? createdAt,
  Set<String> paid = const {},
}) => (
  txid: txid,
  type: type,
  blockHeight: height,
  amount: amount,
  timestamp: timestamp ?? DateTime(2026, 9, 1),
  createdAt: createdAt ?? DateTime(2026, 10, 1),
  ownReceiveOutputs: paid,
);

SafetyWalletSnapshot wallet(
  int id, {
  SafetyWalletKind kind = SafetyWalletKind.hot,
  int balance = 0,
  bool settled = true,
  DateTime? lastResyncAt,
  List<SafetyTx> txs = const [],
  Set<String> pendingSpentBy = const {},
  Map<String, IncidentTxState> tracked = const {},
  bool backupVerified = false,
  bool passphrase = false,
  bool hasMfp = true,
  String? descriptorHash,
  MultisigConfigStatus? multisigConfig,
  List<String> reused = const [],
  List<String> dust = const [],
  bool? receiveHistory,
  bool? utxoHistory,
}) => SafetyWalletSnapshot(
  id: id,
  kind: kind,
  balanceSats: balance,
  isSettled: settled,
  lastResyncAt: lastResyncAt,
  txs: txs,
  pendingSpentByTxids: pendingSpentBy,
  trackedTxStates: tracked,
  backupVerified: backupVerified,
  passphraseOnSigning: passphrase,
  hasMfp: hasMfp,
  descriptorHash: descriptorHash ?? 'descriptor-$id',
  multisigConfig: multisigConfig,
  reusedAddressesWithUtxo: reused,
  unlockedDustUtxoIds: dust,
  hasReceiveHistory: receiveHistory ?? txs.any((t) => t.type == TransactionType.received),
  hasUtxoHistory: utxoHistory ?? txs.any((t) => t.type == TransactionType.received),
);

SafetyInputs inputs({
  List<SafetyWalletSnapshot> wallets = const [],
  SafetyState state = const SafetyState(),
  bool appLock = true,
  AppUpdateStatus update = AppUpdateStatus.upToDate,
  ServerCertObservation? cert,
  bool connected = true,
  int height = 1000,
  int tags = 0,
  int memos = 0,
  DateTime? now,
}) => SafetyInputs(
  now: now ?? testNow,
  wallets: wallets,
  state: state,
  appLockEnabled: appLock,
  appUpdate: update,
  serverCert: cert,
  isConnected: connected,
  currentBlockHeight: height,
  labelTagCount: tags,
  labelMemoCount: memos,
);

/// [known]은 기준점 때 있던 txid(앞부분으로 저장)
WalletBaseline baseline({
  int height = 1000,
  Set<String> known = const {},
  Set<String> pendingSent = const {},
  Set<String> unexpectedSelf = const {},
}) => WalletBaseline(
  height: height,
  at: DateTime(2026, 10, 1),
  knownTxids: {for (final txid in known) SafetyState.txidPrefix(txid)},
  pendingSentAtBaseline: pendingSent,
  unexpectedSelfTxids: unexpectedSelf,
);
