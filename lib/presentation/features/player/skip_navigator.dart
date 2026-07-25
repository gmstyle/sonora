import 'dart:math';

/// Owns skip navigation state (shuffle history, pending target index, backward
/// flag) and exposes pure index calculators for next/previous.
class SkipNavigator {
  final List<int> _shuffledHistory = [];
  bool _isGoingBackward = false;
  int? targetSkipIndex;

  bool get isGoingBackward => _isGoingBackward;

  void clearTarget() => targetSkipIndex = null;

  void clearHistory() => _shuffledHistory.clear();

  void beginBackward() => _isGoingBackward = true;

  void endBackward() => _isGoingBackward = false;

  /// Records [fromIndex] when skipping forward under shuffle.
  void recordForwardSkip(int fromIndex) {
    _shuffledHistory.add(fromIndex);
    if (_shuffledHistory.length > 50) {
      _shuffledHistory.removeAt(0);
    }
  }

  /// Pops the last shuffled-history index, or `null` when empty.
  int? popHistory() =>
      _shuffledHistory.isNotEmpty ? _shuffledHistory.removeLast() : null;

  /// Resolves the effective current target for a skip, clamping invalid values.
  int resolveCurrentTarget(int currentIndex, int length) {
    int currentTarget = targetSkipIndex ?? currentIndex;
    if (currentTarget < 0 || currentTarget >= length) {
      currentTarget = currentIndex >= 0 ? currentIndex : 0;
    }
    return currentTarget;
  }

  static int computeNextIndex({
    required int length,
    required int currentTarget,
    required bool shuffle,
    required bool repeatAll,
    Random? random,
  }) {
    if (shuffle) {
      if (length > 1) {
        final rng = random ?? Random();
        var nextIndex = currentTarget;
        while (nextIndex == currentTarget) {
          nextIndex = rng.nextInt(length);
        }
        return nextIndex;
      }
      return 0;
    }

    var nextIndex = currentTarget + 1;
    if (nextIndex >= length) {
      nextIndex = repeatAll ? 0 : length - 1;
    }
    return nextIndex;
  }

  static int computePreviousIndex({
    required int length,
    required int currentTarget,
    required bool shuffle,
    required bool repeatAll,
    int? historyIndex,
  }) {
    if (shuffle) {
      return historyIndex ?? currentTarget;
    }

    var prevIndex = currentTarget - 1;
    if (prevIndex < 0) {
      prevIndex = repeatAll ? length - 1 : 0;
    }
    return prevIndex;
  }
}
