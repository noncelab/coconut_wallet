import 'package:coconut_wallet/ccos/features/ark/ark_wallet_backend.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';

/// 받는 방법. 결제 요청은 아크 주소와 라이트닝 인보이스를 함께 담은 BIP321
enum ArkReceiveFormat { paymentRequest, lightningInvoice, arkAddress }

class ArkReceiveViewModel extends ChangeNotifier {
  ArkReceiveViewModel(this._wallet) {
    _wallet.addListener(_onWalletChanged);
  }

  final ArkWalletProvider _wallet;

  int? _amountSats;
  ArkLightningInvoice? _invoice;
  ArkReceiveFormat _format = ArkReceiveFormat.arkAddress;
  bool _isCreatingInvoice = false;
  bool _invoiceFailed = false;

  int? get amountSats => _amountSats;
  ArkLightningInvoice? get invoice => _invoice;
  ArkReceiveFormat get format => _format;
  bool get isCreatingInvoice => _isCreatingInvoice;
  bool get invoiceFailed => _invoiceFailed;
  String? get arkAddress => _wallet.arkAddress;

  List<ArkReceiveFormat> get availableFormats =>
      _invoice == null ? const [ArkReceiveFormat.arkAddress] : ArkReceiveFormat.values;

  String? valueOf(ArkReceiveFormat format) {
    final address = arkAddress;
    final invoice = _invoice;
    return switch (format) {
      ArkReceiveFormat.arkAddress => address,
      ArkReceiveFormat.lightningInvoice => invoice == null ? null : 'lightning:${invoice.invoice}'.toUpperCase(),
      ArkReceiveFormat.paymentRequest =>
        invoice == null || address == null
            ? null
            : 'bitcoin:?ark=$address&lightning=${invoice.invoice}&amount=${_btc(invoice.amountSats)}',
    };
  }

  String? get qrData => valueOf(_format);

  void select(ArkReceiveFormat format) {
    if (!availableFormats.contains(format)) return;
    _format = format;
    notifyListeners();
  }

  /// 인보이스에 담아 보내는 사람에게 보이는 라이트닝 메모
  String get invoiceMemo => _invoiceMemo;
  String _invoiceMemo = '';

  Future<void> setAmount(int? amountSats, {String memo = ''}) async {
    if (amountSats == null || amountSats <= 0) {
      _clearInvoice();
      notifyListeners();
      return;
    }
    _amountSats = amountSats;
    _invoiceMemo = memo.trim();
    _isCreatingInvoice = true;
    _invoiceFailed = false;
    notifyListeners();
    try {
      _invoice = await _wallet.createInvoice(amountSats, description: _invoiceMemo.isEmpty ? null : _invoiceMemo);
      _format = ArkReceiveFormat.paymentRequest;
    } catch (error) {
      Logger.error('ArkReceiveViewModel: invoice failed: $error');
      _invoice = null;
      _invoiceFailed = true;
      _format = ArkReceiveFormat.arkAddress;
    } finally {
      _isCreatingInvoice = false;
      notifyListeners();
    }
  }

  void _onWalletChanged() {
    final invoice = _invoice;
    if (invoice == null || !_wallet.isInvoicePaid(invoice.paymentHash)) return;
    _clearInvoice();
    notifyListeners();
  }

  void _clearInvoice() {
    _amountSats = null;
    _invoiceMemo = '';
    _invoice = null;
    _invoiceFailed = false;
    _format = ArkReceiveFormat.arkAddress;
  }

  static String _btc(int sats) {
    final whole = sats ~/ 100000000;
    final fraction = (sats % 100000000).toString().padLeft(8, '0').replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? '$whole' : '$whole.$fraction';
  }

  @override
  void dispose() {
    _wallet.removeListener(_onWalletChanged);
    super.dispose();
  }
}
