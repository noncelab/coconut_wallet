import 'dart:convert';

import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/coconut_wallet_add_qr_scan_data_handler.dart';
import 'package:flutter_test/flutter_test.dart';

const _parentTaprootXpub =
    "tpubDDMbU29QrSafD2Ui4yGv31Xp3PPSMvudreoohYjR8xLTng7hbsjYwUTeRhiKULFqX16M5M8zZh9siw5i6RRyisc6LtWjr1FwBYTiZUGGYJN";
const _childTaprootXpub =
    "tpubDCp2emt17Ng6ujD8BC6ScL4vfwhN3nAJQ8kCqLjRQHxcFhWt6YK5Ws6UcKD6HgLCZuwU8DryKo7h2gpieLa7Q9YF1AqfL9XiF7349nHaLi8";
const _inheritanceMiniscript = "and_v(v:pk([70C4E9DE/86'/1'/0']$_childTaprootXpub/<0;1>/*),older(500000000))";
const _oneParentDescriptor = "tr([9B1441E4/86'/1'/0']$_parentTaprootXpub/<0;1>/*,{$_inheritanceMiniscript})#w0hf4lu5";

void main() {
  group('CoconutWalletAddQrScanDataHandler', () {
    test('Taproot JSON 스캔 데이터를 WatchOnlyWallet으로 완료한다', () {
      final handler = CoconutWalletAddQrScanDataHandler();
      final data = jsonEncode({
        'name': 'Taproot Wallet',
        'colorIndex': 0,
        'iconIndex': 0,
        'descriptor': _oneParentDescriptor,
        'keyPathSeedInfos': [_parentTaprootXpub],
        'scriptPathSeedInfos': [
          {
            'miniscript': _inheritanceMiniscript,
            'extendedPublicKeys': [_childTaprootXpub],
          },
        ],
      });

      expect(handler.validateFormat(data), true);
      expect(handler.joinData(data), true);
      expect(handler.isCompleted(), true);
      expect(handler.progress, 1.0);
      expect(handler.result, isA<WatchOnlyWallet>());

      final wallet = handler.result as WatchOnlyWallet;
      expect(wallet.isTaproot, true);
      expect(wallet.walletType.name, 'taproot');
      expect(wallet.keyPathSeedInfos, [_parentTaprootXpub]);
      expect(wallet.scriptPathSeedInfos!.first.miniscript, _inheritanceMiniscript);
    });

    test('지원하지 않는 Taproot JSON은 완료하지 않는다', () {
      final handler = CoconutWalletAddQrScanDataHandler();
      final data = jsonEncode({
        'name': 'Invalid Taproot Wallet',
        'colorIndex': 0,
        'iconIndex': 0,
        'descriptor': _oneParentDescriptor,
        'keyPathSeedInfos': <String>[],
        'scriptPathSeedInfos': [],
      });

      expect(handler.validateFormat(data), true);
      expect(handler.joinData(data), false);
      expect(handler.isCompleted(), false);
      expect(handler.result, isNull);
    });
  });
}
