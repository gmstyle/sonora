extension DurationFormat on Duration {
  String format() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    final secondsStr = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final minutesStr = minutes.toString().padLeft(2, '0');
      return '$hours:$minutesStr:$secondsStr';
    } else {
      return '$minutes:$secondsStr';
    }
  }
}
