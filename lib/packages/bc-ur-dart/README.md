# Dart UR Library

**UR Implementation in Dart -- ported from the [Python Reference Implementation](https://github.com/Foundation-Devices/foundation-ur-py)**

## Introduction

URs ("Uniform Resources") are a method for encoding structured binary data for transport in URIs and QR Codes. They are described in [BCR-2020-005](https://github.com/BlockchainCommons/Research/blob/master/papers/bcr-2020-005-ur.md).

There are also reference implementations in other languages:
- [Swift: URKit](https://github.com/blockchaincommons/URKit)
- [C++: foundation-ur-py](https://github.com/BlockchainCommons/bc-ur)

## Origin, Authors, Copyright & Licenses

Unless otherwise noted (either in this README.md or in the file's header comments) the contents of this repository are Copyright © 2024 Aleksandr Bukata, and are [licensed](./LICENSE) under the [MIT License](https://opensource.org/licenses/MIT).

This code is a Dart port of the original Python implementation by Foundation Devices. See
[Foundation Devices Python UR Library](https://github.com/Foundation-Devices/foundation-ur-py) for the original version.

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  ur:
    git:
      url: https://github.com/bukata-sa/bc-ur-dart.git
      ref: main  # or use a specific tag or commit hash
```

Then run `dart pub get` or `flutter pub get` if you're using Flutter.

Alternatively, if the package is published to pub.dev, you can use:

```yaml
dependencies:
  ur: ^0.1.0
```

## Usage

1. Import the library:
    ```dart
    import 'package:ur/ur.dart';
    ```

2. Example usage from `ur_test.dart`

    ```dart
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
    ```

## Development

To run tests:

```
dart test
```

Ensure that you add new unit tests for new or modified functionality.

## Version History

### 0.1.0, [22.09.2024] - Initial release

* Initial Dart port and testing release.
