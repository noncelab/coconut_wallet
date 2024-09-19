class DerivationPathUtil {
  static String getPurpose(String derivationPath) {
    List<String> pathComponents = derivationPath.split('/');
    if (pathComponents.length < 2) throw "Wrong derivationPath";
    if (pathComponents[0] != 'm') throw "Wrong derivationPath";

    return pathComponents[1];
  }
}
