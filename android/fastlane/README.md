fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android release_android_regtest

```sh
[bundle exec] fastlane android release_android_regtest
```

Release Android REGTEST to Play (pubspec에서 읽고, 성공 시 build +1)

### android release_android_mainnet

```sh
[bundle exec] fastlane android release_android_mainnet
```

Release Android MAINNET to Play (internal)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
