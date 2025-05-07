import 'package:ur/xoshiro256.dart';

class RandomSampler {
  final List<double> _probs;
  final List<double> _aliases;

  RandomSampler._(List<double> probs, List<double> _aliases)
      : _probs = probs,
        _aliases = _aliases {}

  factory RandomSampler(List<double> probs) {
    assert(probs.every((p) => p > 0), "All probabilities must be positive");

    // Normalize given probabilities
    double total = probs.reduce((a, b) => a + b);
    assert(total > 0, "Total probability must be positive");

    int n = probs.length;

    List<double> P = probs.map((p) => (p * n) / total).toList();

    List<int> S = [];
    List<int> L = [];

    // Set separate index lists for small and large probabilities:
    for (int i = n - 1; i >= 0; i--) {
      // at variance from Schwarz, we reverse the index order
      if (P[i] < 1) {
        S.add(i);
      } else {
        L.add(i);
      }
    }

    // Work through index lists
    List<double> _probs = List<double>.filled(n, 0);
    List<double> _aliases = List<double>.filled(n, 0);

    while (S.isNotEmpty && L.isNotEmpty) {
      int a = S.removeLast(); // Schwarz's l
      int g = L.removeLast(); // Schwarz's g
      _probs[a] = P[a];
      _aliases[a] = g.toDouble();
      P[g] += P[a] - 1;
      if (P[g] < 1) {
        S.add(g);
      } else {
        L.add(g);
      }
    }

    while (L.isNotEmpty) {
      _probs[L.removeLast()] = 1;
    }

    while (S.isNotEmpty) {
      // can only happen through numeric instability
      _probs[S.removeLast()] = 1;
    }

    return RandomSampler._(_probs, _aliases);
  }

  int next(Function rndDouble) {
    double r1 = rndDouble();
    double r2 = rndDouble();
    int n = _probs.length;
    int i = (n * r1).floor();
    return r2 < _probs[i] ? i : _aliases[i].toInt();
  }
}

List<T> shuffled<T>(List<T> list, Xoshiro256 rng) {
  var result = List<T>.from(list);
  for (var i = result.length - 1; i > 0; i--) {
    var j = rng.nextInt(0, i + 1);
    var temp = result[i];
    result[i] = result[j];
    result[j] = temp;
  }
  return result;
}
