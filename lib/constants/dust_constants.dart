import 'package:coconut_lib/coconut_lib.dart';

class DustThresholds {
  static const int taproot = 330;
  static const int p2wpkh = 294;
  static const int p2wsh = 330;
  static const int p2pkh = 546;
  static const int p2sh = 888;
  static const int p2wpkhInP2sh = 273;

  static Map<AddressType, int> thresholds = {
    AddressType.p2wpkh: p2wpkh,
    AddressType.p2wsh: p2wsh,
    AddressType.p2pkh: p2pkh,
    AddressType.p2sh: p2sh,
    AddressType.p2wpkhInP2sh: p2wpkhInP2sh,
  };
}
