class StepTransitionController<T> {
  T? displayedStep;
  T? pendingStep;
  T? lastObservedStep;
  int nonce = 0;

  bool markObserved(T step) {
    if (lastObservedStep == step) return false;
    lastObservedStep = step;
    return true;
  }

  void resetObserved() {
    lastObservedStep = null;
  }

  int bumpNonce() {
    nonce += 1;
    return nonce;
  }
}
