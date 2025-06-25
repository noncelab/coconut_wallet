import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/converter/utxo.dart';

/// UTXO 모킹을 위한 유틸리티 클래스
class UtxoMock {
  static const String _baseDerivationPath = "m/84'/0'/0'/0/";

  /// derivationPath 생성 유틸리티 메서드
  static String _buildDerivationPath(int addressIndex) {
    return '$_baseDerivationPath$addressIndex';
  }

  /// 테스트용 기본 RealmUtxo 객체 생성 메서드
  static RealmUtxo createMockUtxo({
    String? id,
    required int walletId,
    required String address,
    int amount = 1000000,
    DateTime? timestamp,
    String transactionHash = 'mock_tx_hash',
    int index = 0,
    int addressIndex = 0,
    int blockHeight = 0,
    UtxoStatus status = UtxoStatus.unspent,
    String? spentByTransactionHash,
  }) {
    final utxoId = id ?? getUtxoId(transactionHash, index);
    final derivationPath = _buildDerivationPath(addressIndex);

    return RealmUtxo(
      utxoId,
      walletId,
      address,
      amount,
      timestamp ?? DateTime.now(),
      transactionHash,
      index,
      derivationPath,
      blockHeight,
      utxoStatusToString(status),
      spentByTransactionHash: spentByTransactionHash,
    );
  }

  /// 사용 가능한(unspent) UTXO 생성 메서드
  static RealmUtxo createUnspentRealmUtxo({
    required int walletId,
    required String address,
    int amount = 1000000,
    DateTime? timestamp,
    String transactionHash = 'unspent_tx_hash',
    int index = 0,
    int addressIndex = 0,
    int blockHeight = 100, // 컨펌된 블록 높이
  }) {
    return createMockUtxo(
      walletId: walletId,
      address: address,
      amount: amount,
      timestamp: timestamp,
      transactionHash: transactionHash,
      index: index,
      addressIndex: addressIndex,
      blockHeight: blockHeight,
      status: UtxoStatus.unspent,
    );
  }

  /// 출금 중인(outgoing) UTXO 생성 메서드
  static RealmUtxo createOutgoingRealmUtxo({
    required int walletId,
    required String address,
    int amount = 1000000,
    DateTime? timestamp,
    String transactionHash = 'outgoing_tx_hash',
    int index = 0,
    int addressIndex = 0,
    int blockHeight = 0, // 미확인 상태
    String? spentByTransactionHash,
  }) {
    return createMockUtxo(
      walletId: walletId,
      address: address,
      amount: amount,
      timestamp: timestamp,
      transactionHash: transactionHash,
      index: index,
      addressIndex: addressIndex,
      blockHeight: blockHeight,
      status: UtxoStatus.outgoing,
      spentByTransactionHash: spentByTransactionHash,
    );
  }

  /// 입금 중인(incoming) UTXO 생성 메서드
  static RealmUtxo createIncomingRealmUtxo({
    required int walletId,
    required String address,
    int amount = 1000000,
    DateTime? timestamp,
    String transactionHash = 'incoming_tx_hash',
    int index = 0,
    int addressIndex = 0,
    int blockHeight = 0, // 미확인 상태
  }) {
    return createMockUtxo(
      walletId: walletId,
      address: address,
      amount: amount,
      timestamp: timestamp,
      transactionHash: transactionHash,
      index: index,
      addressIndex: addressIndex,
      blockHeight: blockHeight,
      status: UtxoStatus.incoming,
    );
  }

  /// RBF 테스트를 위한 UTXO 생성 메서드
  static RealmUtxo createRbfableUtxo({
    required int walletId,
    required String address,
    int amount = 1000000,
    DateTime? timestamp,
    String transactionHash = 'rbfable_tx_hash',
    int index = 0,
    int addressIndex = 0,
    required String spentByTransactionHash,
  }) {
    return createMockUtxo(
      walletId: walletId,
      address: address,
      amount: amount,
      timestamp: timestamp,
      transactionHash: transactionHash,
      index: index,
      addressIndex: addressIndex,
      blockHeight: 0, // 미확인 상태
      status: UtxoStatus.outgoing,
      spentByTransactionHash: spentByTransactionHash,
    );
  }

  /// 기본 UTXO 상태 객체 생성 메서드
  static UtxoState createMockUtxoState({
    String id = 'mock_utxo_id',
    int walletId = 1,
    String transactionHash = 'mock_tx_hash',
    int index = 0,
    String address = 'mock_address',
    int amount = 1000,
    UtxoStatus status = UtxoStatus.unspent,
    String? spentByTransactionHash,
    int blockHeight = 0,
  }) {
    return UtxoState(
      derivationPath: _buildDerivationPath(index),
      blockHeight: blockHeight,
      timestamp: DateTime.now(),
      transactionHash: transactionHash,
      index: index,
      to: address,
      amount: amount,
      status: status,
      spentByTransactionHash: spentByTransactionHash,
    );
  }

  /// 미사용 UTXO 객체 생성
  static UtxoState createUnspentUtxo({
    String id = 'unspent_utxo_id',
    int walletId = 1,
    String transactionHash = 'unspent_tx_hash',
    int index = 0,
  }) {
    return createMockUtxoState(
      id: id,
      walletId: walletId,
      transactionHash: transactionHash,
      index: index,
      status: UtxoStatus.unspent,
    );
  }

  /// 송금중인 UTXO 객체 생성 (RBF 테스트용)
  static UtxoState createOutgoingUtxo({
    String id = 'outgoing_utxo_id',
    int walletId = 1,
    String transactionHash = 'outgoing_tx_hash',
    int index = 0,
    String? spentByTransactionHash = 'spent_by_tx_hash',
  }) {
    return createMockUtxoState(
      id: id,
      walletId: walletId,
      transactionHash: transactionHash,
      index: index,
      status: UtxoStatus.outgoing,
      spentByTransactionHash: spentByTransactionHash,
    );
  }

  /// 수신중인 UTXO 객체 생성 (RBF 테스트용)
  static UtxoState createIncomingUtxo({
    String id = 'incoming_utxo_id',
    int walletId = 1,
    String transactionHash = 'incoming_tx_hash',
    int index = 0,
  }) {
    return createMockUtxoState(
      id: id,
      walletId: walletId,
      transactionHash: transactionHash,
      index: index,
      status: UtxoStatus.incoming,
    );
  }
}
