import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await RustBuilder(
      assetName: 'uniffi:bark_ffi',
      // COCONUT PATCH: rustc and the cc-built C crates must target the app's iOS version
      extraCargoEnvironmentVariables: _iosDeploymentTarget(input),
    ).run(input: input, output: output);
  });
}

Map<String, String> _iosDeploymentTarget(BuildInput input) {
  if (!input.config.buildCodeAssets) return const {};
  final code = input.config.code;
  if (code.targetOS != OS.iOS) return const {};
  return {'IPHONEOS_DEPLOYMENT_TARGET': '${code.iOS.targetVersion}.0'};
}
