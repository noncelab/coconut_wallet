import 'dart:typed_data';
import 'package:ur/random_sampler.dart';
import 'package:ur/utils.dart';
import 'package:ur/xoshiro256.dart';

// Fisher-Yates shuffle
List<T> shuffled<T>(List<T> items, Xoshiro256 rng) {
  List<T> remaining = List<T>.from(items);
  List<T> result = [];
  while (remaining.isNotEmpty) {
    int index = rng.nextInt(0, remaining.length - 1);
    T item = remaining.removeAt(index);
    result.add(item);
  }
  return result;
}

int chooseDegree(int seqLen, Xoshiro256 rng) {
  List<double> degreeProbabilities = [];
  for (int i = 1; i <= seqLen; i++) {
    degreeProbabilities.add(1.0 / i);
  }

  RandomSampler degreeChooser = RandomSampler(degreeProbabilities);
  return degreeChooser.next(() => rng.nextDouble()).toInt() + 1;
}

Set<int> chooseFragments(int seqNum, int seqLen, int checksum) {
  // The first `seqLen` parts are the "pure" fragments, not mixed with any
  // others. This means that if you only generate the first `seqLen` parts,
  // then you have all the parts you need to decode the message.
  if (seqNum <= seqLen) {
    return {seqNum - 1};
  } else {
    Uint8List seed = Uint8List.fromList(intToBytes(seqNum) + intToBytes(checksum));
    Xoshiro256 rng = Xoshiro256.fromBytes(seed);
    int degree = chooseDegree(seqLen, rng);
    List<int> indexes = List<int>.generate(seqLen, (i) => i);
    List<int> shuffledIndexes = shuffled(indexes, rng);
    return Set<int>.from(shuffledIndexes.sublist(0, degree));
  }
}

bool contains(Iterable<dynamic> setOrList, dynamic el) {
  return setOrList.contains(el);
}

bool isStrictSubset(Set<dynamic> a, Set<dynamic> b) {
  return a.difference(b).isEmpty && a.length < b.length;
}
