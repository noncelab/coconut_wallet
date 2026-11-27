import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_board.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_exit.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_expiry_reminder.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_backend.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_vtxo.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_store.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeArkSecrets extends Fake implements HotWalletSecretRepository {
  final Map<String, Uint8List> stored = {};
  var _next = 0;

  @override
  String newSecretStorageKey() => 'hot_wallet_secret_${_next++}';

  @override
  Future<void> create({required String storageKey, required Uint8List mnemonic, required Uint8List passphrase}) async =>
      stored[storageKey] = Uint8List.fromList(mnemonic);

  @override
  Future<HotWalletPlaintext> unlockAfterAuthentication(String storageKey) async =>
      HotWalletPlaintext(mnemonic: Uint8List.fromList(stored[storageKey]!), passphrase: Uint8List(0));

  @override
  Future<void> delete(String storageKey) async => stored.remove(storageKey);

  @override
  Future<List<String>> getSecretStorageKeys() async => stored.keys.toList();
}

/// VTXO·갱신 쪽 가짜 bark
mixin FakeArkVtxos implements ArkWalletBackend {
  List<ArkVtxo> vtxoList = [];
  int? tip = 1000;
  List<String> expiring = [];
  Set<String> renewing = {};
  int renewFee = 0;
  int? lifetime;
  final List<List<String>> renewed = [];

  @override
  Future<List<ArkVtxo>> vtxos(String fingerprint) async => vtxoList;

  @override
  Future<int?> tipHeight() async => tip;

  @override
  Future<List<String>> expiringVtxoIds(String fingerprint, int withinBlocks) async => expiring;

  @override
  Future<Set<String>> renewingVtxoIds(String fingerprint) async => renewing;

  @override
  Future<int?> vtxoLifetime(String fingerprint) async => lifetime;

  @override
  Future<int> estimateRenewFee(String fingerprint, List<String> vtxoIds) async => renewFee;

  @override
  Future<void> renew(String fingerprint, List<String> vtxoIds) async {
    renewed.add(vtxoIds);
    renewing = {...renewing, ...vtxoIds};
  }
}

class FakeArkReminder implements ArkExpiryReminder {
  final List<DateTime?> calls = [];
  bool allowed = true;
  bool grantOnAsk = false;
  int asked = 0;

  @override
  Future<void> remindAt(DateTime? at) async => calls.add(at);

  @override
  Future<bool> isAllowed() async => allowed;

  @override
  Future<bool> askToAllow() async {
    asked++;
    if (grantOnAsk) allowed = true;
    return allowed;
  }
}

/// 채우기·내보내기 쪽 가짜 bark
mixin FakeArkMoves implements ArkWalletBackend {
  ArkBoardTerms terms = const ArkBoardTerms(minAmountSats: 1000, maxAmountSats: null, requiredConfirmations: 2);
  int fundingCalls = 0;
  int boardFee = 100;
  int exportFee = 50;
  Object? exportError;
  final List<(String, ArkBoardFunding)> boarded = [];
  final List<String> broadcasted = [];
  final List<(String, int?)> exported = [];

  @override
  Future<ArkBoardTerms> boardTerms(String fingerprint) async => terms;

  @override
  Future<ArkBoardFunding> boardFunding(String fingerprint) async {
    fundingCalls++;
    return ArkBoardFunding(address: 'bcrt1pboard$fundingCalls', expiryHeight: 5000, keypairIndex: fundingCalls);
  }

  @override
  Future<int> estimateBoardFee(String fingerprint, int amountSats) async => boardFee;

  @override
  Future<void> board(
    String fingerprint, {
    required String unsignedPsbtBase64,
    required ArkBoardFunding funding,
  }) async => boarded.add((unsignedPsbtBase64, funding));

  @override
  Future<String> broadcastTx(String fingerprint, String txHex) async {
    broadcasted.add(txHex);
    return 'txid-bark';
  }

  @override
  Future<int> estimateExportFee(String fingerprint, String address, {int? amountSats}) async => exportFee;

  @override
  Future<String> export(String fingerprint, String address, {int? amountSats}) async {
    if (exportError != null) throw exportError!;
    exported.add((address, amountSats));
    return 'txid-export';
  }
}

/// 서버 없이 출금 쪽 가짜 bark
class FakeArkExitSteps implements ArkExitSteps {
  int confirmed = 0;
  int pending = 0;
  ArkExitProgress progress = const ArkExitProgress(
    spent: false,
    onChain: false,
    allClaimable: false,
    claimableHeight: null,
    txDone: 0,
    txTotal: 2,
  );
  final List<String> calls = [];

  @override
  Future<int> exitFeeConfirmedSats() async => confirmed;

  @override
  Future<int> exitFeePendingSats() async => pending;

  @override
  Future<void> startExit(List<String> vtxoIds) async => calls.add('start');

  @override
  Future<ArkExitProgress> progressExit(List<String> vtxoIds, int feeRateSatPerVb) async {
    calls.add('progress');
    return progress;
  }

  @override
  Future<({String txid, int feeSats})> claimExit(String address, int feeRateSatPerVb) async {
    calls.add('claim');
    return (txid: 'claimtx', feeSats: 300);
  }

  @override
  Future<int> returnExitFee(String address, int feeRateSatPerVb) async {
    calls.add('return');
    return 0;
  }
}

mixin FakeArkExit implements ArkWalletBackend {
  final FakeArkExitSteps steps = FakeArkExitSteps();
  ArkExitQuote quote = const ArkExitQuote(
    vtxoIds: ['a'],
    amountSats: 30000,
    feeSats: 2000,
    txCount: 2,
    feeRateSatPerVb: 2,
    firstExpiryHeight: 5000,
  );

  @override
  Future<ArkExitQuote> estimateExit(String fingerprint) async => quote;

  @override
  Future<String> exitFeeAddress(String fingerprint) async => 'bcrt1qexitfee';

  @override
  ArkExitSteps exitSteps(String fingerprint) => steps;
}

ArkVtxo fakeVtxo(String id, {int sats = 1000, int expiry = 2000, bool locked = false}) =>
    ArkVtxo(id: id, amountSats: sats, expiryHeight: expiry, kind: 'Pubkey', isLocked: locked);

class FakeArkBackend with FakeArkVtxos, FakeArkMoves, FakeArkExit implements ArkWalletBackend {
  List<ArkMovement> movements = [];
  String address = 'tark1fakeaddress';
  int sendFee = 0;
  Object? sendFeeError;
  Object? sendError;
  int syncCount = 0;
  final List<(ArkPaymentRail, String, int)> sent = [];
  final List<int> invoiceAmounts = [];

  @override
  Future<void> sync(String fingerprint) async => syncCount++;

  @override
  Future<List<ArkMovement>> history(String fingerprint) async => movements;

  @override
  Future<String> newArkAddress(String fingerprint) async => address;

  final List<String?> invoiceDescriptions = [];
  String invoiceBody = 'fake';

  Completer<void>? invoiceGate;

  @override
  Future<ArkLightningInvoice> createLightningInvoice(String fingerprint, int amountSats, {String? description}) async {
    await invoiceGate?.future;
    invoiceAmounts.add(amountSats);
    invoiceDescriptions.add(description);
    return ArkLightningInvoice(
      invoice: 'lnbcrt${amountSats}n1$invoiceBody',
      paymentHash: 'hash-$amountSats',
      amountSats: amountSats,
      feeSats: 0,
    );
  }

  @override
  Future<int> estimateSendFee(String fingerprint, ArkPaymentRail rail, int amountSats) async {
    if (sendFeeError != null) throw sendFeeError!;
    return sendFee;
  }

  @override
  Future<int?> send(
    String fingerprint,
    ArkPaymentRail rail,
    String destination,
    int amountSats, {
    bool invoiceHasAmount = false,
  }) async {
    if (sendError != null) throw ArkPaymentException(sendError!);
    sent.add((rail, destination, amountSats));
    return 99;
  }

  final Set<String> wallets = {};
  final Set<String> opened = {};
  ArkBalance currentBalance = ArkBalance.zero;

  /// 주어지면 bark 생성이 이 완료를 기다림
  Completer<void>? createGate;
  bool failOpen = false;

  @override
  Future<String> fingerprintOf(Uint8List mnemonic) async => 'fp-${utf8.decode(mnemonic).split(' ').first}';

  @override
  Future<void> create(String fingerprint, Uint8List mnemonic, {required bool restore}) async {
    await createGate?.future;
    wallets.add(fingerprint);
    opened.add(fingerprint);
  }

  @override
  Future<void> open(String fingerprint, Uint8List mnemonic) async {
    if (failOpen) throw StateError('open failed');
    opened.add(fingerprint);
  }

  @override
  bool isOpen(String fingerprint) => opened.contains(fingerprint);

  @override
  Future<ArkBalance> balance(String fingerprint) async => currentBalance;

  @override
  Future<bool> isRecoveryPending(String fingerprint) async => false;

  @override
  Future<List<String>> listFingerprints() async => wallets.toList();

  @override
  Future<void> wipeAll() async {
    wallets.clear();
    opened.clear();
  }
}

Future<ArkWalletProvider> fakeArkWalletProvider({
  FakeArkBackend? backend,
  FakeArkSecrets? secrets,
  FakeArkReminder? reminder,
  bool keepPrefs = false,
}) async {
  if (!keepPrefs) SharedPreferences.setMockInitialValues({});
  // ignore: deprecated_member_use_from_same_package
  final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
  return ArkWalletProvider(
    store: ArkWalletStore(prefs, secrets ?? FakeArkSecrets()),
    backend: backend ?? FakeArkBackend(),
    generateMnemonic: () async => Uint8List.fromList(utf8.encode('${'zoo ' * 11}wrong')),
    autoSync: false,
    reminder: reminder,
  );
}

class FakeArkPrice extends Fake with ChangeNotifier implements PriceProvider {
  @override
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) => '₩ 0';
}

class FakeArkConnectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
}

/// 코코넛 지갑 목록, 채우기·내보내기 칸이 봄
class FakeArkWallets extends Fake with ChangeNotifier implements WalletProvider {
  List<WalletItemBase> wallets = [];
  final Map<int, WalletAddress> receiveAddresses = {};

  @override
  List<WalletItemBase> get walletItemList => wallets;

  @override
  WalletAddress getReceiveAddress(int walletId) => receiveAddresses[walletId]!;
}

/// 내 지갑 하나, 내보내기 주소 고르기에서 봄
class FakeArkWalletItem extends Fake implements WalletItemBase {
  FakeArkWalletItem(this.id, this.name);

  @override
  final int id;
  @override
  final String name;
  @override
  WalletType get walletType => WalletType.singleSignature;
}

/// 아크 지갑 홈에 필요한 코코넛 provider(법정화폐 환산, 지갑 목록)
List<SingleChildWidget> fakeArkPriceProviders({FakeArkWallets? wallets}) => [
  ChangeNotifierProvider<PriceProvider>.value(value: FakeArkPrice()),
  ChangeNotifierProvider<ConnectivityProvider>.value(value: FakeArkConnectivity()),
  ChangeNotifierProvider<WalletProvider>.value(value: wallets ?? FakeArkWallets()),
];
