import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ur/bytewords.dart' as Bytewords;
import 'package:ur/cbor_lite.dart';
import 'package:ur/xoshiro256.dart';
import 'package:ur/fountain_encoder.dart';
import 'package:ur/fountain_decoder.dart';
import 'package:ur/fountain_utils.dart';
import 'package:ur/ur_encoder.dart';
import 'package:ur/ur_decoder.dart';
import 'package:ur/ur.dart';
import 'package:ur/random_sampler.dart' show RandomSampler;
import 'package:ur/utils.dart';

import 'test_utils.dart';

void main() {
  group('UR Tests', () {
    test('CRC32', () {
      expect(checkCRC32("Hello, world!", "ebe6c6e6"), isTrue);
      expect(checkCRC32("Wolf", "598c84dc"), isTrue);
    });

    test('Bytewords 1', () {
      var input = Uint8List.fromList([0, 1, 2, 128, 255]);
      expect(Bytewords.encodeStyle(Bytewords.Style.standard, input),
          equals("able acid also lava zoom jade need echo taxi"));
      expect(Bytewords.encodeStyle(Bytewords.Style.uri, input),
          equals("able-acid-also-lava-zoom-jade-need-echo-taxi"));
      expect(Bytewords.encodeStyle(Bytewords.Style.minimal, input), equals("aeadaolazmjendeoti"));

      expect(
          Bytewords.decodeStyle(
              Bytewords.Style.standard, "able acid also lava zoom jade need echo taxi"),
          equals(input));
      expect(
          Bytewords.decodeStyle(
              Bytewords.Style.uri, "able-acid-also-lava-zoom-jade-need-echo-taxi"),
          equals(input));
      expect(Bytewords.decodeStyle(Bytewords.Style.minimal, "aeadaolazmjendeoti"), equals(input));

      expect(
          () => Bytewords.decodeStyle(
              Bytewords.Style.standard, "able acid also lava zoom jade need echo wolf"),
          throwsA(isA<ArgumentError>()));
      expect(
          () => Bytewords.decodeStyle(
              Bytewords.Style.uri, "able-acid-also-lava-zoom-jade-need-echo-wolf"),
          throwsA(isA<ArgumentError>()));
      expect(() => Bytewords.decodeStyle(Bytewords.Style.minimal, "aeadaolazmjendeowf"),
          throwsA(isA<ArgumentError>()));

      expect(() => Bytewords.decodeStyle(Bytewords.Style.standard, "wolf"),
          throwsA(isA<ArgumentError>()));
      expect(
          () => Bytewords.decodeStyle(Bytewords.Style.standard, ""), throwsA(isA<ArgumentError>()));
    });

    test('Bytewords 2', () {
      Uint8List input = Uint8List.fromList([
        245,
        215,
        20,
        198,
        241,
        235,
        69,
        59,
        209,
        205,
        165,
        18,
        150,
        158,
        116,
        135,
        229,
        212,
        19,
        159,
        17,
        37,
        239,
        240,
        253,
        11,
        109,
        191,
        37,
        242,
        38,
        120,
        223,
        41,
        156,
        189,
        242,
        254,
        147,
        204,
        66,
        163,
        216,
        175,
        191,
        72,
        169,
        54,
        32,
        60,
        144,
        230,
        210,
        137,
        184,
        197,
        33,
        113,
        88,
        14,
        157,
        31,
        177,
        46,
        1,
        115,
        205,
        69,
        225,
        150,
        65,
        235,
        58,
        144,
        65,
        240,
        133,
        69,
        113,
        247,
        63,
        53,
        242,
        165,
        160,
        144,
        26,
        13,
        79,
        237,
        133,
        71,
        82,
        69,
        254,
        165,
        138,
        41,
        85,
        24
      ]);

      var encoded =
          "yank toys bulb skew when warm free fair tent swan open brag mint noon jury list view tiny brew note body data webs what zinc bald join runs data whiz days keys user diet news ruby whiz zone menu surf flew omit trip pose runs fund part even crux fern math visa tied loud redo silk curl jugs hard beta next cost puma drum acid junk swan free very mint flap warm fact math flap what limp free jugs yell fish epic whiz open numb math city belt glow wave limp fuel grim free zone open love diet gyro cats fizz holy city puff";

      var encodedMinimal =
          "yktsbbswwnwmfefrttsnonbgmtnnjyltvwtybwnebydawswtzcbdjnrsdawzdsksurdtnsrywzzemusffwottppersfdptencxfnmhvatdldroskcljshdbantctpadmadjksnfevymtfpwmftmhfpwtlpfejsylfhecwzonnbmhcybtgwwelpflgmfezeonledtgocsfzhycypf";

      expect(Bytewords.encodeStyle(Bytewords.Style.standard, input), equals(encoded));
      expect(Bytewords.encodeStyle(Bytewords.Style.minimal, input), equals(encodedMinimal));
      expect(Bytewords.decodeStyle(Bytewords.Style.standard, encoded), equals(input));
      expect(Bytewords.decodeStyle(Bytewords.Style.minimal, encodedMinimal), equals(input));
    });

    test('RNG 1', () {
      var rng = Xoshiro256.fromString("Wolf");
      var numbers = List<int>.generate(100, (_) => (rng.next() % BigInt.from(100)).toInt());

      var expectedNumbers = [
        42,
        81,
        85,
        8,
        82,
        84,
        76,
        73,
        70,
        88,
        2,
        74,
        40,
        48,
        77,
        54,
        88,
        7,
        5,
        88,
        37,
        25,
        82,
        13,
        69,
        59,
        30,
        39,
        11,
        82,
        19,
        99,
        45,
        87,
        30,
        15,
        32,
        22,
        89,
        44,
        92,
        77,
        29,
        78,
        4,
        92,
        44,
        68,
        92,
        69,
        1,
        42,
        89,
        50,
        37,
        84,
        63,
        34,
        32,
        3,
        17,
        62,
        40,
        98,
        82,
        89,
        24,
        43,
        85,
        39,
        15,
        3,
        99,
        29,
        20,
        42,
        27,
        10,
        85,
        66,
        50,
        35,
        69,
        70,
        70,
        74,
        30,
        13,
        72,
        54,
        11,
        5,
        70,
        55,
        91,
        52,
        10,
        43,
        43,
        52
      ];
      expect(numbers, equals(expectedNumbers));
    });

    test('RNG 2', () {
      var checksum = bytesToInt(crc32Bytes(Uint8List.fromList("Wolf".codeUnits)));
      var rng = Xoshiro256.fromCrc32(checksum);
      var numbers = List<int>.generate(100, (_) => (rng.next() % BigInt.from(100)).toInt());

      var expectedNumbers = [
        88,
        44,
        94,
        74,
        0,
        99,
        7,
        77,
        68,
        35,
        47,
        78,
        19,
        21,
        50,
        15,
        42,
        36,
        91,
        11,
        85,
        39,
        64,
        22,
        57,
        11,
        25,
        12,
        1,
        91,
        17,
        75,
        29,
        47,
        88,
        11,
        68,
        58,
        27,
        65,
        21,
        54,
        47,
        54,
        73,
        83,
        23,
        58,
        75,
        27,
        26,
        15,
        60,
        36,
        30,
        21,
        55,
        57,
        77,
        76,
        75,
        47,
        53,
        76,
        9,
        91,
        14,
        69,
        3,
        95,
        11,
        73,
        20,
        99,
        68,
        61,
        3,
        98,
        36,
        98,
        56,
        65,
        14,
        80,
        74,
        57,
        63,
        68,
        51,
        56,
        24,
        39,
        53,
        80,
        57,
        51,
        81,
        3,
        1,
        30
      ];
      expect(numbers, equals(expectedNumbers));
    });

    test('RNG 3', () {
      var rng = Xoshiro256.fromString("Wolf");
      var numbers = List<int>.generate(100, (_) => rng.nextInt(1, 10));

      var expectedNumbers = [
        6,
        5,
        8,
        4,
        10,
        5,
        7,
        10,
        4,
        9,
        10,
        9,
        7,
        7,
        1,
        1,
        2,
        9,
        9,
        2,
        6,
        4,
        5,
        7,
        8,
        5,
        4,
        2,
        3,
        8,
        7,
        4,
        5,
        1,
        10,
        9,
        3,
        10,
        2,
        6,
        8,
        5,
        7,
        9,
        3,
        1,
        5,
        2,
        7,
        1,
        4,
        4,
        4,
        4,
        9,
        4,
        5,
        5,
        6,
        9,
        5,
        1,
        2,
        8,
        3,
        3,
        2,
        8,
        4,
        3,
        2,
        1,
        10,
        8,
        9,
        3,
        10,
        8,
        5,
        5,
        6,
        7,
        10,
        5,
        8,
        9,
        4,
        6,
        4,
        2,
        10,
        2,
        1,
        7,
        9,
        6,
        7,
        4,
        2,
        5
      ];
      expect(numbers, equals(expectedNumbers));
    });

    test('Find Fragment Length', () {
      expect(FountainEncoder.findNominalFragmentLength(12345, 1005, 1955), equals(1764));
      expect(FountainEncoder.findNominalFragmentLength(12345, 1005, 30000), equals(12345));
    });

    test('Random Sampler', () {
      var probs = [1.0, 2.0, 4.0, 8.0];
      var sampler = RandomSampler(probs);
      var rng = Xoshiro256.fromString("Wolf");
      var samples = List<int>.generate(500, (_) => sampler.next(rng.nextDouble));
      var expectedSamples = [
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        0,
        2,
        3,
        3,
        3,
        3,
        1,
        2,
        2,
        1,
        3,
        3,
        2,
        3,
        3,
        1,
        1,
        2,
        1,
        1,
        3,
        1,
        3,
        1,
        2,
        0,
        2,
        1,
        0,
        3,
        3,
        3,
        1,
        3,
        3,
        3,
        3,
        1,
        3,
        2,
        3,
        2,
        2,
        3,
        3,
        3,
        3,
        2,
        3,
        3,
        0,
        3,
        3,
        3,
        3,
        1,
        2,
        3,
        3,
        2,
        2,
        2,
        1,
        2,
        2,
        1,
        2,
        3,
        1,
        3,
        0,
        3,
        2,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        2,
        3,
        1,
        3,
        3,
        2,
        0,
        2,
        2,
        3,
        1,
        1,
        2,
        3,
        2,
        3,
        3,
        3,
        3,
        2,
        3,
        3,
        3,
        3,
        3,
        2,
        3,
        1,
        2,
        1,
        1,
        3,
        1,
        3,
        2,
        2,
        3,
        3,
        3,
        1,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        2,
        3,
        2,
        3,
        3,
        1,
        2,
        3,
        3,
        1,
        3,
        2,
        3,
        3,
        3,
        2,
        3,
        1,
        3,
        0,
        3,
        2,
        1,
        1,
        3,
        1,
        3,
        2,
        3,
        3,
        3,
        3,
        2,
        0,
        3,
        3,
        1,
        3,
        0,
        2,
        1,
        3,
        3,
        1,
        1,
        3,
        1,
        2,
        3,
        3,
        3,
        0,
        2,
        3,
        2,
        0,
        1,
        3,
        3,
        3,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        2,
        3,
        3,
        3,
        3,
        2,
        3,
        3,
        2,
        0,
        2,
        3,
        3,
        3,
        3,
        2,
        1,
        1,
        1,
        2,
        1,
        3,
        3,
        3,
        2,
        2,
        3,
        3,
        1,
        2,
        3,
        0,
        3,
        2,
        3,
        3,
        3,
        3,
        0,
        2,
        2,
        3,
        2,
        2,
        3,
        3,
        3,
        3,
        1,
        3,
        2,
        3,
        3,
        3,
        3,
        3,
        2,
        2,
        3,
        1,
        3,
        0,
        2,
        1,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        1,
        3,
        3,
        3,
        3,
        2,
        2,
        2,
        3,
        1,
        1,
        3,
        2,
        2,
        0,
        3,
        2,
        1,
        2,
        1,
        0,
        3,
        3,
        3,
        2,
        2,
        3,
        2,
        1,
        2,
        0,
        0,
        3,
        3,
        2,
        3,
        3,
        2,
        3,
        3,
        3,
        3,
        3,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        1,
        1,
        3,
        2,
        2,
        3,
        1,
        1,
        0,
        1,
        3,
        2,
        3,
        3,
        2,
        3,
        3,
        2,
        3,
        3,
        2,
        2,
        2,
        2,
        3,
        2,
        2,
        2,
        2,
        2,
        1,
        2,
        3,
        3,
        2,
        2,
        2,
        2,
        3,
        3,
        2,
        0,
        2,
        1,
        3,
        3,
        3,
        3,
        0,
        3,
        3,
        3,
        3,
        2,
        2,
        3,
        1,
        3,
        3,
        3,
        2,
        3,
        3,
        3,
        2,
        3,
        3,
        3,
        3,
        2,
        3,
        2,
        1,
        3,
        3,
        3,
        3,
        2,
        2,
        0,
        1,
        2,
        3,
        2,
        0,
        3,
        3,
        3,
        3,
        3,
        3,
        1,
        3,
        3,
        2,
        3,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        2,
        2,
        3,
        3,
        2,
        2,
        2,
        1,
        3,
        3,
        3,
        3,
        1,
        2,
        3,
        2,
        3,
        3,
        2,
        3,
        2,
        3,
        3,
        3,
        2,
        3,
        1,
        2,
        3,
        2,
        1,
        1,
        3,
        3,
        2,
        3,
        3,
        2,
        3,
        3,
        0,
        0,
        1,
        3,
        3,
        2,
        3,
        3,
        3,
        3,
        1,
        3,
        3,
        0,
        3,
        2,
        3,
        3,
        1,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        0,
        3,
        3,
        2
      ];
      expect(samples, equals(expectedSamples));
    });

    test('Shuffle', () {
      var rng = Xoshiro256.fromString("Wolf");
      var values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      var result = [];
      for (var i = 0; i < 10; i++) {
        result.add(shuffled(List<int>.from(values), rng));
      }

      var expectedResult = [
        [6, 4, 9, 3, 10, 5, 7, 8, 1, 2],
        [10, 8, 6, 5, 1, 2, 3, 9, 7, 4],
        [6, 4, 5, 8, 9, 3, 2, 1, 7, 10],
        [7, 3, 5, 1, 10, 9, 4, 8, 2, 6],
        [8, 5, 7, 10, 2, 1, 4, 3, 9, 6],
        [4, 3, 5, 6, 10, 2, 7, 8, 9, 1],
        [5, 1, 3, 9, 4, 6, 2, 10, 7, 8],
        [2, 1, 10, 8, 9, 4, 7, 6, 3, 5],
        [6, 7, 10, 4, 8, 9, 2, 3, 1, 5],
        [10, 2, 1, 7, 9, 5, 6, 3, 4, 8]
      ];
      expect(result, equals(expectedResult));
    });

    test('Partition and join', () {
      var message = makeMessage(1024);
      var fragmentLen = FountainEncoder.findNominalFragmentLength(message.length, 10, 100);
      var fragments = FountainEncoder.partitionMessage(message, fragmentLen);
      var fragmentsHex = fragments.map((f) => dataToHex(f)).toList();

      var expectedFragments = [
        "916ec65cf77cadf55cd7f9cda1a1030026ddd42e905b77adc36e4f2d3ccba44f7f04f2de44f42d84c374a0e149136f25b01852545961d55f7f7a8cde6d0e2ec43f3b2dcb644a2209e8c9e34af5c4747984a5e873c9cf5f965e25ee29039f",
        "df8ca74f1c769fc07eb7ebaec46e0695aea6cbd60b3ec4bbff1b9ffe8a9e7240129377b9d3711ed38d412fbb4442256f1e6f595e0fc57fed451fb0a0101fb76b1fb1e1b88cfdfdaa946294a47de8fff173f021c0e6f65b05c0a494e50791",
        "270a0050a73ae69b6725505a2ec8a5791457c9876dd34aadd192a53aa0dc66b556c0c215c7ceb8248b717c22951e65305b56a3706e3e86eb01c803bbf915d80edcd64d4d41977fa6f78dc07eecd072aae5bc8a852397e06034dba6a0b570",
        "797c3a89b16673c94838d884923b8186ee2db5c98407cab15e13678d072b43e406ad49477c2e45e85e52ca82a94f6df7bbbe7afbed3a3a830029f29090f25217e48d1f42993a640a67916aa7480177354cc7440215ae41e4d02eae9a1912",
        "33a6d4922a792c1b7244aa879fefdb4628dc8b0923568869a983b8c661ffab9b2ed2c149e38d41fba090b94155adbed32f8b18142ff0d7de4eeef2b04adf26f2456b46775c6c20b37602df7da179e2332feba8329bbb8d727a138b4ba7a5",
        "03215eda2ef1e953d89383a382c11d3f2cad37a4ee59a91236a3e56dcf89f6ac81dd4159989c317bd649d9cbc617f73fe10033bd288c60977481a09b343d3f676070e67da757b86de27bfca74392bac2996f7822a7d8f71a489ec6180390",
        "089ea80a8fcd6526413ec6c9a339115f111d78ef21d456660aa85f790910ffa2dc58d6a5b93705caef1091474938bd312427021ad1eeafbd19e0d916ddb111fabd8dcab5ad6a6ec3a9c6973809580cb2c164e26686b5b98cfb017a337968",
        "c7daaa14ae5152a067277b1b3902677d979f8e39cc2aafb3bc06fcf69160a853e6869dcc09a11b5009f91e6b89e5b927ab1527a735660faa6012b420dd926d940d742be6a64fb01cdc0cff9faa323f02ba41436871a0eab851e7f5782d10",
        "fbefde2a7e9ae9dc1e5c2c48f74f6c824ce9ef3c89f68800d44587bedc4ab417cfb3e7447d90e1e417e6e05d30e87239d3a5d1d45993d4461e60a0192831640aa32dedde185a371ded2ae15f8a93dba8809482ce49225daadfbb0fec629e",
        "23880789bdf9ed73be57fa84d555134630e8d0f7df48349f29869a477c13ccca9cd555ac42ad7f568416c3d61959d0ed568b2b81c7771e9088ad7fd55fd4386bafbf5a528c30f107139249357368ffa980de2c76ddd9ce4191376be0e6b5",
        "170010067e2e75ebe2d2904aeb1f89d5dc98cd4a6f2faaa8be6d03354c990fd895a97feb54668473e9d942bb99e196d897e8f1b01625cf48a7b78d249bb4985c065aa8cd1402ed2ba1b6f908f63dcd84b66425df00000000000000000000"
      ];

      expect(fragmentsHex, equals(expectedFragments));

      var rejoinedMessage = FountainDecoder.joinFragments(fragments, message.length);
      expect(message, equals(rejoinedMessage));
    });

    test('Choose degree', () {
      var message = makeMessage(1024);
      var fragmentLen = FountainEncoder.findNominalFragmentLength(message.length, 10, 100);
      var fragments = FountainEncoder.partitionMessage(message, fragmentLen);
      var degrees = <int>[];

      for (var nonce = 1; nonce <= 200; nonce++) {
        var partRng = Xoshiro256.fromString("Wolf-$nonce");
        degrees.add(chooseDegree(fragments.length, partRng));
      }

      var expectedDegrees = [
        11,
        3,
        6,
        5,
        2,
        1,
        2,
        11,
        1,
        3,
        9,
        10,
        10,
        4,
        2,
        1,
        1,
        2,
        1,
        1,
        5,
        2,
        4,
        10,
        3,
        2,
        1,
        1,
        3,
        11,
        2,
        6,
        2,
        9,
        9,
        2,
        6,
        7,
        2,
        5,
        2,
        4,
        3,
        1,
        6,
        11,
        2,
        11,
        3,
        1,
        6,
        3,
        1,
        4,
        5,
        3,
        6,
        1,
        1,
        3,
        1,
        2,
        2,
        1,
        4,
        5,
        1,
        1,
        9,
        1,
        1,
        6,
        4,
        1,
        5,
        1,
        2,
        2,
        3,
        1,
        1,
        5,
        2,
        6,
        1,
        7,
        11,
        1,
        8,
        1,
        5,
        1,
        1,
        2,
        2,
        6,
        4,
        10,
        1,
        2,
        5,
        5,
        5,
        1,
        1,
        4,
        1,
        1,
        1,
        3,
        5,
        5,
        5,
        1,
        4,
        3,
        3,
        5,
        1,
        11,
        3,
        2,
        8,
        1,
        2,
        1,
        1,
        4,
        5,
        2,
        1,
        1,
        1,
        5,
        6,
        11,
        10,
        7,
        4,
        7,
        1,
        5,
        3,
        1,
        1,
        9,
        1,
        2,
        5,
        5,
        2,
        2,
        3,
        10,
        1,
        3,
        2,
        3,
        3,
        1,
        1,
        2,
        1,
        3,
        2,
        2,
        1,
        3,
        8,
        4,
        1,
        11,
        6,
        3,
        1,
        1,
        1,
        1,
        1,
        3,
        1,
        2,
        1,
        10,
        1,
        1,
        8,
        2,
        7,
        1,
        2,
        1,
        9,
        2,
        10,
        2,
        1,
        3,
        4,
        10
      ];
      expect(degrees, equals(expectedDegrees));
    });

    test('Choose Fragments', () {
      var message = makeMessage(1024);
      var checksum = crc32Int(message);
      var fragmentLen = FountainEncoder.findNominalFragmentLength(message.length, 10, 100);
      var fragments = FountainEncoder.partitionMessage(message, fragmentLen);
      var fragmentIndexes = <List<int>>[];
      for (var seqNum = 1; seqNum <= 30; seqNum++) {
        var indexesSet = chooseFragments(seqNum, fragments.length, checksum);
        var indexes = indexesSet.toList()..sort();
        fragmentIndexes.add(indexes);
      }

      var expectedFragmentIndexes = [
        [0],
        [1],
        [2],
        [3],
        [4],
        [5],
        [6],
        [7],
        [8],
        [9],
        [10],
        [9],
        [2, 5, 6, 8, 9, 10],
        [8],
        [1, 5],
        [1],
        [0, 2, 4, 5, 8, 10],
        [5],
        [2],
        [2],
        [0, 1, 3, 4, 5, 7, 9, 10],
        [0, 1, 2, 3, 5, 6, 8, 9, 10],
        [0, 2, 4, 5, 7, 8, 9, 10],
        [3, 5],
        [4],
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        [0, 1, 3, 4, 5, 6, 7, 9, 10],
        [6],
        [5, 6],
        [7]
      ];
      expect(fragmentIndexes, equals(expectedFragmentIndexes));
    });

    test('XOR', () {
      var rng = Xoshiro256.fromString("Wolf");
      var data1 = rng.nextData(10);
      expect(dataToHex(data1), equals("916ec65cf77cadf55cd7"));
      var data2 = rng.nextData(10);
      expect(dataToHex(data2), equals("f9cda1a1030026ddd42e"));
      var data3 = Uint8List.fromList(data1);
      xorInto(data3, data2);
      expect(dataToHex(data3), equals("68a367fdf47c8b2888f9"));
      xorInto(data3, data1);
      expect(data3, equals(data2));
    });

    test('Fountain Encoder', () {
      var message = makeMessage(256);
      var encoder = FountainEncoder(message, 30);
      var parts = <String>[];
      for (var i = 0; i < 20; i++) {
        parts.add(encoder.nextPart().description());
      }

      var expectedParts = [
        "seqNum:1, seqLen:9, messageLen:256, checksum:23570951, data:916ec65cf77cadf55cd7f9cda1a1030026ddd42e905b77adc36e4f2d3c",
        "seqNum:2, seqLen:9, messageLen:256, checksum:23570951, data:cba44f7f04f2de44f42d84c374a0e149136f25b01852545961d55f7f7a",
        "seqNum:3, seqLen:9, messageLen:256, checksum:23570951, data:8cde6d0e2ec43f3b2dcb644a2209e8c9e34af5c4747984a5e873c9cf5f",
        "seqNum:4, seqLen:9, messageLen:256, checksum:23570951, data:965e25ee29039fdf8ca74f1c769fc07eb7ebaec46e0695aea6cbd60b3e",
        "seqNum:5, seqLen:9, messageLen:256, checksum:23570951, data:c4bbff1b9ffe8a9e7240129377b9d3711ed38d412fbb4442256f1e6f59",
        "seqNum:6, seqLen:9, messageLen:256, checksum:23570951, data:5e0fc57fed451fb0a0101fb76b1fb1e1b88cfdfdaa946294a47de8fff1",
        "seqNum:7, seqLen:9, messageLen:256, checksum:23570951, data:73f021c0e6f65b05c0a494e50791270a0050a73ae69b6725505a2ec8a5",
        "seqNum:8, seqLen:9, messageLen:256, checksum:23570951, data:791457c9876dd34aadd192a53aa0dc66b556c0c215c7ceb8248b717c22",
        "seqNum:9, seqLen:9, messageLen:256, checksum:23570951, data:951e65305b56a3706e3e86eb01c803bbf915d80edcd64d4d0000000000",
        "seqNum:10, seqLen:9, messageLen:256, checksum:23570951, data:330f0f33a05eead4f331df229871bee733b50de71afd2e5a79f196de09",
        "seqNum:11, seqLen:9, messageLen:256, checksum:23570951, data:3b205ce5e52d8c24a52cffa34c564fa1af3fdffcd349dc4258ee4ee828",
        "seqNum:12, seqLen:9, messageLen:256, checksum:23570951, data:dd7bf725ea6c16d531b5f03254783803048ca08b87148daacd1cd7a006",
        "seqNum:13, seqLen:9, messageLen:256, checksum:23570951, data:760be7ad1c6187902bbc04f539b9ee5eb8ea6833222edea36031306c01",
        "seqNum:14, seqLen:9, messageLen:256, checksum:23570951, data:5bf4031217d2c3254b088fa7553778b5003632f46e21db129416f65b55",
        "seqNum:15, seqLen:9, messageLen:256, checksum:23570951, data:73f021c0e6f65b05c0a494e50791270a0050a73ae69b6725505a2ec8a5",
        "seqNum:16, seqLen:9, messageLen:256, checksum:23570951, data:b8546ebfe2048541348910267331c643133f828afec9337c318f71b7df",
        "seqNum:17, seqLen:9, messageLen:256, checksum:23570951, data:23dedeea74e3a0fb052befabefa13e2f80e4315c9dceed4c8630612e64",
        "seqNum:18, seqLen:9, messageLen:256, checksum:23570951, data:d01a8daee769ce34b6b35d3ca0005302724abddae405bdb419c0a6b208",
        "seqNum:19, seqLen:9, messageLen:256, checksum:23570951, data:3171c5dc365766eff25ae47c6f10e7de48cfb8474e050e5fe997a6dc24",
        "seqNum:20, seqLen:9, messageLen:256, checksum:23570951, data:e055c2433562184fa71b4be94f262e200f01c6f74c284b0dc6fae6673f"
      ];
      expect(parts, equals(expectedParts));
    });
    test('Fountain Encoder CBOR', () {
      var message = makeMessage(256);
      var encoder = FountainEncoder(message, 30);
      var parts = <String>[];
      for (var i = 0; i < 20; i++) {
        parts.add(dataToHex(encoder.nextPart().cbor()));
      }

      var expectedParts = [
        "8501091901001a0167aa07581d916ec65cf77cadf55cd7f9cda1a1030026ddd42e905b77adc36e4f2d3c",
        "8502091901001a0167aa07581dcba44f7f04f2de44f42d84c374a0e149136f25b01852545961d55f7f7a",
        "8503091901001a0167aa07581d8cde6d0e2ec43f3b2dcb644a2209e8c9e34af5c4747984a5e873c9cf5f",
        "8504091901001a0167aa07581d965e25ee29039fdf8ca74f1c769fc07eb7ebaec46e0695aea6cbd60b3e",
        "8505091901001a0167aa07581dc4bbff1b9ffe8a9e7240129377b9d3711ed38d412fbb4442256f1e6f59",
        "8506091901001a0167aa07581d5e0fc57fed451fb0a0101fb76b1fb1e1b88cfdfdaa946294a47de8fff1",
        "8507091901001a0167aa07581d73f021c0e6f65b05c0a494e50791270a0050a73ae69b6725505a2ec8a5",
        "8508091901001a0167aa07581d791457c9876dd34aadd192a53aa0dc66b556c0c215c7ceb8248b717c22",
        "8509091901001a0167aa07581d951e65305b56a3706e3e86eb01c803bbf915d80edcd64d4d0000000000",
        "850a091901001a0167aa07581d330f0f33a05eead4f331df229871bee733b50de71afd2e5a79f196de09",
        "850b091901001a0167aa07581d3b205ce5e52d8c24a52cffa34c564fa1af3fdffcd349dc4258ee4ee828",
        "850c091901001a0167aa07581ddd7bf725ea6c16d531b5f03254783803048ca08b87148daacd1cd7a006",
        "850d091901001a0167aa07581d760be7ad1c6187902bbc04f539b9ee5eb8ea6833222edea36031306c01",
        "850e091901001a0167aa07581d5bf4031217d2c3254b088fa7553778b5003632f46e21db129416f65b55",
        "850f091901001a0167aa07581d73f021c0e6f65b05c0a494e50791270a0050a73ae69b6725505a2ec8a5",
        "8510091901001a0167aa07581db8546ebfe2048541348910267331c643133f828afec9337c318f71b7df",
        "8511091901001a0167aa07581d23dedeea74e3a0fb052befabefa13e2f80e4315c9dceed4c8630612e64",
        "8512091901001a0167aa07581dd01a8daee769ce34b6b35d3ca0005302724abddae405bdb419c0a6b208",
        "8513091901001a0167aa07581d3171c5dc365766eff25ae47c6f10e7de48cfb8474e050e5fe997a6dc24",
        "8514091901001a0167aa07581de055c2433562184fa71b4be94f262e200f01c6f74c284b0dc6fae6673f"
      ];
      expect(parts, equals(expectedParts));
    });

    test('Fountain Encoder Is Complete', () {
      var message = makeMessage(256);
      var encoder = FountainEncoder(message, 30);
      var generatedPartsCount = 0;
      while (!encoder.isComplete) {
        encoder.nextPart();
        generatedPartsCount++;
      }

      expect(encoder.seqLen, equals(generatedPartsCount));
    });

    test('Fountain Decoder', () {
      var messageSeed = "Wolf";
      var messageSize = 32767;
      var maxFragmentLen = 1000;

      var message = makeMessage(messageSize, seed: messageSeed);
      var encoder = FountainEncoder(message, maxFragmentLen, firstSeqNum: 100);
      var decoder = FountainDecoder();

      while (true) {
        var part = encoder.nextPart();
        decoder.receivePart(part);
        if (decoder.isComplete()) {
          break;
        }
      }

      if (decoder.isSuccess()) {
        expect(decoder.resultMessage(), equals(message));
      } else {
        fail(decoder.resultError().toString());
      }
    });

    test('Fountain CBOR', () {
      var part = FountainEncoderPart(12, 8, 100, 0x12345678, Uint8List.fromList([1, 5, 3, 3, 5]));
      var cbor = part.cbor();
      var part2 = FountainEncoderPart.fromCbor(cbor);
      var cbor2 = part2.cbor();
      expect(cbor, equals(cbor2));
    });

    test('Single Part UR', () {
      var ur = makeMessageUR(50);
      var encoded = UREncoder.encode(ur);
      var expected =
          "ur:bytes/hdeymejtswhhylkepmykhhtsytsnoyoyaxaedsuttydmmhhpktpmsrjtgwdpfnsboxgwlbaawzuefywkdplrsrjynbvygabwjldapfcsdwkbrkch";
      expect(encoded, equals(expected));
      var decoded = URDecoder.decode(encoded);
      expect(ur, equals(decoded));
    });

    test('Short CRC32', () {
      var fragment =
          "ur:crypto-psbt/20-29/lpbbcscacfcmcpcybbrsptskhdssdtsbtkdechrhpkhkvwmdmnksgdaoaeaeaeaeaechptbbeodkpletlbldamjopmbnpeplwmfzltzthgoeqzteltlgaychaeaeaeaeaechptbbfxsawkidltenbskpjlfeflmnclpkemtpwpmhmhioltkecsamaeaeaeaeaechptbbintkmwzmynknkezcbgkthdfezopaynprmefthpkgltaeaeaeaeadaddnemmdaaaeaeaeaeaecpaecxhdgwfdvtsphdolbnkigeteeclkosoxlpjssnfxsgclahesjsvturdyjzcwsrkndtadahtkghclaofstdlnuysaasiesfdnrkhsmnjztonlpsldwftdmninoxehhnkotodrwpchrorhdaclaeetwdvl";

      var decoder = URDecoder();
      var status = decoder.receivePart(fragment);
      expect(status, isTrue);
    });

    test('UR Encoder', () {
      var ur = makeMessageUR(256);
      var encoder = UREncoder(ur, 30);
      var parts = <String>[];
      for (var i = 0; i < 20; i++) {
        parts.add(encoder.nextPart());
      }

      var expectedParts = [
        "ur:bytes/1-9/lpadascfadaxcywenbpljkhdcahkadaemejtswhhylkepmykhhtsytsnoyoyaxaedsuttydmmhhpktpmsrjtdkgslpgh",
        "ur:bytes/2-9/lpaoascfadaxcywenbpljkhdcagwdpfnsboxgwlbaawzuefywkdplrsrjynbvygabwjldapfcsgmghhkhstlrdcxaefz",
        "ur:bytes/3-9/lpaxascfadaxcywenbpljkhdcahelbknlkuejnbadmssfhfrdpsbiegecpasvssovlgeykssjykklronvsjksopdzmol",
        "ur:bytes/4-9/lpaaascfadaxcywenbpljkhdcasotkhemthydawydtaxneurlkosgwcekonertkbrlwmplssjtammdplolsbrdzcrtas",
        "ur:bytes/5-9/lpahascfadaxcywenbpljkhdcatbbdfmssrkzmcwnezelennjpfzbgmuktrhtejscktelgfpdlrkfyfwdajldejokbwf",
        "ur:bytes/6-9/lpamascfadaxcywenbpljkhdcackjlhkhybssklbwefectpfnbbectrljectpavyrolkzczcpkmwidmwoxkilghdsowp",
        "ur:bytes/7-9/lpatascfadaxcywenbpljkhdcavszmwnjkwtclrtvaynhpahrtoxmwvwatmedibkaegdosftvandiodagdhthtrlnnhy",
        "ur:bytes/8-9/lpayascfadaxcywenbpljkhdcadmsponkkbbhgsoltjntegepmttmoonftnbuoiyrehfrtsabzsttorodklubbuyaetk",
        "ur:bytes/9-9/lpasascfadaxcywenbpljkhdcajskecpmdckihdyhphfotjojtfmlnwmadspaxrkytbztpbauotbgtgtaeaevtgavtny",
        "ur:bytes/10-9/lpbkascfadaxcywenbpljkhdcahkadaemejtswhhylkepmykhhtsytsnoyoyaxaedsuttydmmhhpktpmsrjtwdkiplzs",
        "ur:bytes/11-9/lpbdascfadaxcywenbpljkhdcahelbknlkuejnbadmssfhfrdpsbiegecpasvssovlgeykssjykklronvsjkvetiiapk",
        "ur:bytes/12-9/lpbnascfadaxcywenbpljkhdcarllaluzmdmgstospeyiefmwejlwtpedamktksrvlcygmzemovovllarodtmtbnptrs",
        "ur:bytes/13-9/lpbtascfadaxcywenbpljkhdcamtkgtpknghchchyketwsvwgwfdhpgmgtylctotzopdrpayoschcmhplffziachrfgd",
        "ur:bytes/14-9/lpbaascfadaxcywenbpljkhdcapazewnvonnvdnsbyleynwtnsjkjndeoldydkbkdslgjkbbkortbelomueekgvstegt",
        "ur:bytes/15-9/lpbsascfadaxcywenbpljkhdcaynmhpddpzmversbdqdfyrehnqzlugmjzmnmtwmrouohtstgsbsahpawkditkckynwt",
        "ur:bytes/16-9/lpbeascfadaxcywenbpljkhdcawygekobamwtlihsnpalnsghenskkiynthdzotsimtojetprsttmukirlrsbtamjtpd",
        "ur:bytes/17-9/lpbyascfadaxcywenbpljkhdcamklgftaxykpewyrtqzhydntpnytyisincxmhtbceaykolduortotiaiaiafhiaoyce",
        "ur:bytes/18-9/lpbgascfadaxcywenbpljkhdcahkadaemejtswhhylkepmykhhtsytsnoyoyaxaedsuttydmmhhpktpmsrjtntwkbkwy",
        "ur:bytes/19-9/lpbwascfadaxcywenbpljkhdcadekicpaajootjzpsdrbalpeywllbdsnbinaerkurspbncxgslgftvtsrjtksplcpeo",
        "ur:bytes/20-9/lpbbascfadaxcywenbpljkhdcayapmrleeleaxpasfrtrdkncffwjyjzgyetdmlewtkpktgllepfrltataztksmhkbot"
      ];
      expect(parts, equals(expectedParts));
    });

    test('Multipart UR', () {
      var ur = makeMessageUR(32767);
      var maxFragmentLen = 1000;
      var firstSeqNum = 100;
      var encoder = UREncoder(ur, maxFragmentLen, firstSeqNum: firstSeqNum);
      var decoder = URDecoder();
      while (true) {
        var part = encoder.nextPart();
        decoder.receivePart(part);
        if (decoder.isComplete()) {
          break;
        }
      }

      if (decoder.isSuccess()) {
        expect(decoder.result, equals(ur));
      } else {
        fail(decoder.resultError().toString());
      }
    });

    test('UR Encode json', () {
      var sourceJson = {
        "int": 123,
        "bool": true,
        "str": "hello",
        "list": [1, 2, 3],
        "map": {"a": 1, "b": 2},
        "null": null
      };
      var sourceBytes = utf8.encode(json.encode(sourceJson));
      var cborEncoder = CBOREncoder();
      cborEncoder.encodeBytes(sourceBytes);
      var ur = UR("bytes", cborEncoder.getBytes());
      var encoded = UREncoder.encode(ur);
      expect(
          encoded,
          equals(
              'ur:bytes/hdghkgcpinjtjycpfteheyeodwcpidjljljzcpftjyjpkpihdwcpjkjyjpcpftcpisihjzjzjlcpdwcpjzinjkjycpfthpehdweydweohldwcpjnhsjocpftkgcphscpftehdwcpidcpfteykidwcpjtkpjzjzcpftjtkpjzjzkidndrpmhe'));
    });

    test('UR Decode json', () {
      var source =
          'ur:bytes/hdghkgcpinjtjycpfteheyeodwcpidjljljzcpftjyjpkpihdwcpjkjyjpcpftcpisihjzjzjlcpdwcpjzinjkjycpfthpehdweydweohldwcpjnhsjocpftkgcphscpftehdwcpidcpfteykidwcpjtkpjzjzcpftjtkpjzjzkidndrpmhe';
      var ur = URDecoder.decode(source);
      var cborDecorder = CBORDecoder(ur.cbor);
      var (bytes, length) = cborDecorder.decodeBytes();
      var decoded = utf8.decode(bytes);
      expect(
          json.decode(decoded),
          equals({
            "int": 123,
            "bool": true,
            "str": "hello",
            "list": [1, 2, 3],
            "map": {"a": 1, "b": 2},
            "null": null
          }));
    });
  });
}

bool checkCRC32(String input, String expectedHex) {
  int checksum = crc32Int(Uint8List.fromList(input.codeUnits));
  String hex = checksum.toRadixString(16).padLeft(8, '0');
  return hex == expectedHex;
}
