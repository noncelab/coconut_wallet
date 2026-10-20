import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/wallet_add_analytics.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/hot_wallet_create_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_actions.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/wallet_name_util.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// 목적지 선택 화면의 섹션 순서. 이 기기에 키가 있는 목적지(기존 핫월렛·새 핫월렛)는 다른 모든 선택지 뒤(lead 결정)
enum AssistDestinationKind { watchOnlyWallet, vaultNewWallet, manualAddress, otherWallet, newHotWallet }

class AssistDestination {
  const AssistDestination(
    this.kind, {
    this.wallet,
    this.address,
    this.cannotVerifySeed = false,
    this.isRescueDestination = false,
  });

  final AssistDestinationKind kind;
  final WalletItemBase? wallet;

  /// 비상 목적지가 주소로 정해진 경우만
  final String? address;

  /// MFP가 없어 사고 지갑과 같은 시드인지 알 수 없음
  final bool cannotVerifySeed;
  final bool isRescueDestination;

  /// 이 기기에 키가 있는 목적지. "이 기기에서 키가 나갔다면…" 경고 대상
  bool get onThisDevice => kind == AssistDestinationKind.newHotWallet || (wallet?.hasLocalKey ?? false);

  /// 기본 선택·자동 이동에 써도 되는지. MFP 없는 지갑·이 기기 지갑은 절대 미리 고르지 않는다
  bool get canPreselect => !cannotVerifySeed && !onThisDevice && kind != AssistDestinationKind.vaultNewWallet;
}

/// 목적지를 받을 수 없는 이유
enum DestinationProblem {
  /// 형식이 틀렸거나 지금 네트워크 주소가 아님
  invalidAddress,

  /// 고른 지갑이 지워졌거나 이제는 제외 대상(같은 시드·사용 주의·위급 사건·검증 불일치 등)
  excludedWallet,

  /// 주소의 주인이 사고 지갑이거나 제외 대상 지갑
  excludedOwner,
}

/// [SafetyAssist.openConfirm]이 넘기기 직전에 목적지를 거절함. 화면은 목적지 선택으로 돌아간다
class AssistDestinationRejected implements Exception {
  const AssistDestinationRejected(this.problem);
  final DestinationProblem problem;

  @override
  String toString() => 'AssistDestinationRejected(${problem.name})';
}

/// Premium Safety Assist: 목적지 고르기와 기존 보내기 확인 파이프라인으로 넘기기.
/// 서명·전송하지 않는다. 확인 화면(sendConfirm) 이후는 기존 흐름 그대로다
abstract final class SafetyAssist {
  /// 사고 지갑 자신, 같은 MFP·같은 계정 키(또는 같은 디스크립터) 지갑, [cautionWalletIds]는 빠진다.
  /// [safetyState]를 주면 [unsafeWalletIds] 규칙(사용 주의·위급 사건·검증 불일치)도 적용한다(구출·비상 이동 공통 규칙).
  /// 비상 목적지가 있으면 맨 위, 같은 섹션 안에서는 MFP 있는 지갑이 먼저
  static List<AssistDestination> destinations({
    required WalletItemBase incidentWallet,
    required List<WalletItemBase> wallets,
    Set<int> cautionWalletIds = const {},
    RescueDestination? rescueDestination,
    SafetyState? safetyState,
  }) {
    final excluded = {...cautionWalletIds, if (safetyState != null) ...unsafeWalletIds(safetyState, wallets)};
    final incidentFingerprints = fingerprintsOf(incidentWallet);
    final incidentKeys = _accountKeysOf(incidentWallet);
    final candidates = [
      for (final w in wallets)
        if (w.id != incidentWallet.id &&
            w.descriptor != incidentWallet.descriptor &&
            !excluded.contains(w.id) &&
            (w.hotWalletMetadata?.lifecycleState ?? HotWalletLifecycleState.active) == HotWalletLifecycleState.active &&
            !fingerprintsOf(w).any(incidentFingerprints.contains) &&
            // MFP 없이 같은 확장 공개키로 추가한 지갑도 같은 주소를 만든다(버전 바이트와 무관하게 키로 비교)
            !_accountKeysOf(w).any(incidentKeys.contains))
          AssistDestination(
            w.hasLocalKey ? AssistDestinationKind.otherWallet : AssistDestinationKind.watchOnlyWallet,
            wallet: w,
            cannotVerifySeed: incidentFingerprints.isEmpty || fingerprintsOf(w).isEmpty,
            isRescueDestination: rescueDestination?.walletId == w.id,
          ),
    ];
    // 비상 목적지는 맨 위로. 단 이 기기 지갑이면 제자리(이 기기 목적지는 언제나 다른 선택지 뒤)
    bool lifted(AssistDestination d) => d.isRescueDestination && !d.onThisDevice;
    List<AssistDestination> section(AssistDestinationKind kind) => [
      for (final d in candidates)
        if (d.kind == kind && !lifted(d) && d.isRescueDestination) d,
      for (final d in candidates)
        if (d.kind == kind && !d.isRescueDestination && !d.cannotVerifySeed) d,
      for (final d in candidates)
        if (d.kind == kind && !d.isRescueDestination && d.cannotVerifySeed) d,
    ];
    final rescueAddress = rescueDestination?.walletId == null ? rescueDestination?.address : null;

    return [
      ...candidates.where(lifted),
      if (rescueAddress != null)
        AssistDestination(AssistDestinationKind.manualAddress, address: rescueAddress, isRescueDestination: true),
      ...section(AssistDestinationKind.watchOnlyWallet),
      const AssistDestination(AssistDestinationKind.vaultNewWallet),
      const AssistDestination(AssistDestinationKind.manualAddress),
      ...section(AssistDestinationKind.otherWallet),
      const AssistDestination(AssistDestinationKind.newHotWallet),
    ];
  }

  /// 목적지로 쓰면 안 되는 지갑: 사용 주의, 자기 위급 사건이 열린 지갑, 지금 디스크립터 기준 검증이 불일치인 지갑
  /// (보기 전용·탭루트 mismatch·confirmedMismatch, 다중서명 BSMS 불일치 = 바꿔치기 위험). 검증 안 한 지갑은 고를 수 있다.
  /// 해시는 엔진과 같은 규칙(지갑 디스크립터의 [WalletVerification.descriptorHash]). 디스크립터가 바뀐 기록은 무시
  /// 제외 지갑과 같은 시드(MFP)·같은 계정 키를 쓰는 지갑(예: 사용 주의 핫월렛의 보기 전용 사본)도 함께 뺀다
  static Set<int> unsafeWalletIds(SafetyState state, List<WalletItemBase> wallets) {
    final direct = {
      ...state.cautionWalletIds,
      for (final i in state.incidents)
        if (i.isCritical) i.walletId,
      for (final w in wallets)
        if (_verificationMismatch(state, w)) w.id,
    };
    final unsafe = wallets.where((w) => direct.contains(w.id)).toList();
    final fingerprints = {for (final w in unsafe) ...fingerprintsOf(w)};
    final keys = {for (final w in unsafe) ..._accountKeysOf(w)};
    return {
      ...direct,
      for (final w in wallets)
        if (fingerprintsOf(w).any(fingerprints.contains) || _accountKeysOf(w).any(keys.contains)) w.id,
    };
  }

  static bool _verificationMismatch(SafetyState state, WalletItemBase wallet) {
    final hash = WalletVerification.descriptorHash(wallet.descriptor);
    if (wallet.walletType == WalletType.multiSignature) {
      final bsms = state.bsms[wallet.id];
      return bsms != null && bsms.configHash == hash && !bsms.matched;
    }
    final verification = state.watchOnlyVerifications[wallet.id];
    return !wallet.hasLocalKey &&
        verification != null &&
        verification.descriptorHash == hash &&
        verification.result != VerificationResult.match;
  }

  /// 지갑의 모든 서명자 MFP(대문자). 확장 공개키로만 추가해 MFP가 없으면 빈 집합
  static Set<String> fingerprintsOf(WalletItemBase wallet) => {
    for (final k in _keyStoresOf(wallet))
      if (k.masterFingerprint.toUpperCase() != WalletAddService.masterFingerprintPlaceholder)
        k.masterFingerprint.toUpperCase(),
  };

  /// 서명자마다 계정 확장 공개키의 공개키(hex)
  static Set<String> _accountKeysOf(WalletItemBase wallet) => {
    for (final k in _keyStoresOf(wallet)) Codec.encodeHex(k.extendedPublicKey.publicKey),
  };

  static List<KeyStore> _keyStoresOf(WalletItemBase wallet) {
    final base = wallet.walletBase;
    return switch (base) {
      SingleSignatureWalletBase() => [base.keyStore],
      MultisignatureWalletBase() => base.keyStoreList,
      TaprootWalletBase() => [
        ...base.keyStoreList,
        for (final policy in base.policyList)
          if (policy is InheritancePolicy) policy.beneficiaryKeyStore,
      ],
      _ => const <KeyStore>[],
    };
  }

  /// 목적지 지갑의 지금 받기 주소(아직 생성 전이면 다음 인덱스를 직접 도출)
  static String receiveAddressOf(WalletProvider walletProvider, WalletItemBase wallet) {
    try {
      return walletProvider.getReceiveAddress(wallet.id).address;
    } on StateError {
      return wallet.walletBase.getAddress(wallet.receiveUsedIndex + 1);
    }
  }

  /// 수수료 올리기(FeeBumpingViewModel.prepareToSend)와 같은 순서로 [SendInfoProvider]를 채우고
  /// 기존 보내기 확인 화면을 연다. 핫월렛은 거기서 직접 서명, 보기 전용은 PSBT QR → 서명 스캔 → 전송
  /// 목적지가 고른 지갑이면 [destinationWalletId]를 준다(지워졌거나 제외 대상으로 바뀌었는지 넘기기 직전에 다시 본다).
  /// 지금 지갑 목록·안전 상태로 [checkDestination]을 통과하지 못하면 아무것도 채우지 않고 [AssistDestinationRejected]
  static Future<void> openConfirm(
    BuildContext context, {
    required WalletItemBase wallet,
    required SweepPlan plan,
    required String destination,
    int? destinationWalletId,
    SendEntryPoint entryPoint = SendEntryPoint.home,
  }) async {
    final walletProvider = context.read<WalletProvider>();
    final txProvider = context.read<TransactionProvider>();
    final sendInfo = context.read<SendInfoProvider>();
    final problem = checkDestination(
      walletProvider,
      incidentWallet: wallet,
      address: destination,
      walletId: destinationWalletId,
      safetyState: context.read<SafetyProvider?>()?.state,
    );
    if (problem != null) throw AssistDestinationRejected(problem);
    // 20% 상한은 넘기는 곳에서도 지킨다. 예외는 확인한 대체 하한뿐(두 번 누르기는 검토 화면이 받는다)
    if (SweepFee.isExcessive(plan) && !SweepFee.isFloorExempt(plan)) throw StateError('Sweep fee is over the cap');

    final transaction = SweepBuilder.build(plan, wallet: wallet, destination: AssistAddress.normalize(destination));
    if (transaction.outputs.length != 1) throw StateError('Sweep must have exactly one output');
    if (destinationWalletId != null) _destinationByTxid[transaction.transactionHash] = destinationWalletId;

    // 충돌 거래 기록이 있어야 전송 직전 "이미 확정됨" 확인(broadcasting_screen)이 동작한다
    final conflictTxid =
        plan.conflicts
            .map((c) => c.txid)
            .where((txid) => txProvider.getTransactionRecord(wallet.id, txid) != null)
            .firstOrNull;

    sendInfo.clear();
    sendInfo.setWalletId(wallet.id);
    sendInfo.setSendEntryPoint(entryPoint);
    sendInfo.setIsMultisig(wallet.walletType == WalletType.multiSignature);
    sendInfo.setTransaction(transaction);
    sendInfo.setFeeBumpingType(conflictTxid == null ? null : FeeBumpingType.rbf);
    sendInfo.setWalletImportSource(wallet.walletImportSource);
    sendInfo.setFeeRate(plan.feeRate);
    sendInfo.setIsMaxMode(true);
    if (conflictTxid != null) txProvider.initTransaction(wallet.id, conflictTxid);

    await Navigator.pushNamed(context, AppRouteNames.sendConfirm, arguments: const SendConfirmRouteArgs());
  }

  /// 이 기기에 새 핫월렛을 만든다(12단어, 패스프레이즈 없음, 백업 필요 상태 → 기존 백업 경고 대상).
  /// 기기 비밀번호가 없어 막히면 null. 만든 니모닉은 메모리에서 바로 지운다
  static Future<int?> createHotWallet(BuildContext context, {HotWalletCreateViewModel? viewModel}) async {
    if (!await WalletAddActions.prepareHotWallet(context, restore: false)) return null;
    if (!context.mounted) return null;
    final walletProvider = context.read<WalletProvider>();
    final analytics = context.read<AnalyticsService>();
    final creator = viewModel ?? HotWalletCreateViewModel(walletProvider);
    try {
      final result = await creator.createWallet(
        walletName: WalletNameUtil.findAvailableDefaultName(
          existingNames: walletProvider.walletItemList.map((w) => w.name),
          // 자동으로 만든 지갑은 "새 지갑"(겹치면 번호), 검토 화면의 받는 지갑 카드에도 이 이름이 보인다
          firstName: t.safety_guide.move.new_wallet,
          numberedName: (number) => '${t.safety_guide.move.new_wallet} $number',
        ),
        colorIndex: 0,
        iconIndex: 0,
        mnemonicWordCount: 12,
        passphrase: '',
        enterPassphraseWhenSigning: false,
      );
      result.clearSensitiveBytes();
      analytics.logHotWalletAddCompleted(isRestore: false);
      return result.walletId;
    } finally {
      if (viewModel == null) creator.dispose();
    }
  }

  /// 목적지를 지금 지갑 목록·안전 상태로 다시 확인한다(저장해 둔 비상 주소, 열어 둔 검토 화면 모두). 문제없으면 null.
  /// 지금 네트워크 주소인지, 고른 지갑이 아직 고를 수 있는지([destinations] 규칙), 주소의 주인이 사고·제외 지갑인지 본다
  static DestinationProblem? checkDestination(
    WalletProvider walletProvider, {
    required WalletItemBase incidentWallet,
    required String address,
    int? walletId,
    SafetyState? safetyState,
  }) {
    final normalized = AssistAddress.normalize(address);
    if (!AssistAddress.isValidForCurrentNetwork(normalized)) return DestinationProblem.invalidAddress;
    final wallets = walletProvider.walletItemList;
    final allowed = {
      for (final d in destinations(incidentWallet: incidentWallet, wallets: wallets, safetyState: safetyState))
        if (d.wallet != null) d.wallet!.id,
    };
    if (walletId != null && !allowed.contains(walletId)) return DestinationProblem.excludedWallet;
    for (final w in wallets) {
      if (!allowed.contains(w.id) && walletProvider.containsAddress(w.id, normalized)) {
        return DestinationProblem.excludedOwner;
      }
    }
    return null;
  }

  /// 저장된 비상 목적지(지갑·주소)를 지금 지갑 목록·안전 상태로 다시 확인해 보낼 주소를 돌려준다(Track I·Assist 공통 마지막 확인).
  /// 지갑이 지워졌거나 제외 대상이 됐거나, 주소의 주인(모두)이 제외 지갑이면 null. 다른 주소로 바꾸지 않는다
  static ({String address, WalletItemBase? wallet})? verifiedTarget(
    WalletProvider walletProvider, {
    required WalletItemBase source,
    required RescueDestination destination,
    required SafetyState? state,
  }) {
    final walletId = destination.walletId;
    final wallet = walletId == null ? null : walletProvider.walletItemList.where((w) => w.id == walletId).firstOrNull;
    if (walletId != null && wallet == null) return null;
    final address = wallet != null ? receiveAddressOf(walletProvider, wallet) : destination.address;
    if (address == null) return null;
    final problem = checkDestination(
      walletProvider,
      incidentWallet: source,
      address: address,
      walletId: walletId,
      safetyState: state,
    );
    return problem == null ? (address: AssistAddress.normalize(address), wallet: wallet) : null;
  }

  /// 직접 입력·저장된 주소가 제외 지갑(사고·같은 시드·사용 주의·위급 사건·검증 불일치)에서 나온 주소인지,
  /// 각 지갑의 받기·잔돈 주소를 앞에서부터 [depth]개씩 직접 도출해 확인한다(Grok §5: 만들어 둔 주소 목록 밖도).
  /// 무거워서 별도 isolate에서 돌리고 확인할 때 한 번만 부른다. 핫월렛·보기 전용 모두(공개키로 도출)
  /// ponytail: 받기·잔돈 앞 [depth]개(기본 1,000)보다 뒤 인덱스 주소는 못 잡는다(lead 승인 한계). 필요하면 지갑이 쓴 최대 인덱스 + 여유로
  static Future<bool> derivesFromExcludedWallet(
    WalletProvider walletProvider, {
    required WalletItemBase incidentWallet,
    required String address,
    SafetyState? safetyState,
    int depth = 1000,
  }) {
    final allowed = {
      for (final d in destinations(
        incidentWallet: incidentWallet,
        wallets: walletProvider.walletItemList,
        safetyState: safetyState,
      ))
        if (d.wallet != null) d.wallet!.id,
    };
    final excluded = <(WalletType, String)>[
      (incidentWallet.walletType, incidentWallet.descriptor),
      for (final w in walletProvider.walletItemList)
        if (!allowed.contains(w.id) && w.id != incidentWallet.id) (w.walletType, w.descriptor),
    ];
    final normalized = AssistAddress.normalize(address);
    final network = NetworkType.currentNetworkType.toString();
    return Isolate.run(() => derivesFrom(excluded, normalized, depth: depth, network: network));
  }

  /// [derivesFromExcludedWallet]의 계산(같은 isolate에서 바로 쓸 수도 있다)
  @visibleForTesting
  static bool derivesFrom(List<(WalletType, String)> wallets, String address, {required int depth, String? network}) {
    if (network != null) NetworkType.setNetworkType(NetworkType.getNetworkType(network));
    for (final (type, descriptor) in wallets) {
      final WalletBase base = switch (type) {
        WalletType.singleSignature => SingleSignatureWallet.fromDescriptor(descriptor),
        WalletType.multiSignature => MultisignatureWallet.fromDescriptor(descriptor),
        WalletType.taproot => TaprootWallet.fromDescriptor(descriptor),
      };
      for (var i = 0; i < depth; i++) {
        if (base.getAddress(i) == address || base.getAddress(i, isChange: true) == address) return true;
      }
    }
    return false;
  }

  // ponytail: 전송 직후(동기화 전)엔 거래 기록이 없어 이번 실행 동안만 txid → 목적지 지갑을 기억한다.
  // 앱을 다시 켜면 동기화된 거래 출력으로 찾는다. 오래 남겨야 하면 SafetyState에 저장
  static final Map<String, int> _destinationByTxid = {};

  /// 이 대응 거래([txid], [walletId]가 보냄)를 받은 백업 안 된 핫월렛("거래를 보냈어요"의 "지금 백업하기" 대상).
  /// 실제 받는 주소의 주인으로 찾는다(대응을 언제 시작했는지와 무관)
  static WalletItemBase? unbackedHotWalletFor(
    WalletProvider walletProvider, {
    required int walletId,
    required String txid,
  }) {
    final wallets = walletProvider.walletItemList;
    final record = walletProvider.getTransactionRecord(walletId, txid);
    final owners = <int>[
      if (_destinationByTxid[txid] case final id?) id,
      if (record != null)
        for (final output in record.outputAddressList)
          for (final w in wallets)
            if (w.id != walletId && walletProvider.containsAddress(w.id, output.address)) w.id,
    ];
    for (final id in owners) {
      final w = wallets.where((w) => w.id == id).firstOrNull;
      if (w?.hotWalletMetadata?.backupVerified == false) return w;
    }
    return null;
  }

  /// 기존 니모닉 백업 흐름(지갑 정보 화면의 백업과 같은 인자)
  static Future<void> openBackup(BuildContext context, int walletId) async {
    final metadata = context.read<WalletProvider>().getWalletById(walletId).hotWalletMetadata;
    if (metadata == null) return;
    await Navigator.pushNamed(
      context,
      AppRouteNames.hotWalletMnemonicBackupGuide,
      arguments: HotWalletMnemonicBackupGuideRouteArgs(
        walletId: walletId,
        secureStorageKey: metadata.secureStorageKey,
        enterPassphraseWhenSigning: metadata.enterPassphraseWhenSigning,
        showWalletCreatedIntro: false,
        continueToAppLockGuide: false,
        returnToPreviousOnExit: true,
      ),
    );
  }
}

/// 직접 입력·저장된 주소 정리와 네트워크 확인
abstract final class AssistAddress {
  static String normalize(String address) => AddressValidator.normalizeAddress(address.trim());

  /// 기존 검사 + bech32 HRP가 지금 네트워크인지(기존 검사는 testnet에서 bcrt1을 통과시킨다, AH7)
  static bool isValidForCurrentNetwork(String normalized) {
    final network = NetworkType.currentNetworkType;
    if (AddressValidator.validateAddress(normalized, network) != null) return false;
    if (!isBech32(normalized)) return true;
    final hrp =
        network == NetworkType.mainnet
            ? 'bc1'
            : network == NetworkType.regtest
            ? 'bcrt1'
            : 'tb1';
    return normalized.startsWith(hrp);
  }
}
