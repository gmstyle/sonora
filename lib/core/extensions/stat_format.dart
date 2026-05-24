extension CompactNumber on int {
  String toCompact() {
    if (this >= 1000000000) {
      final v = this / 1000000000;
      final s = v.toStringAsFixed(1);
      return '${s.replaceAll(RegExp(r'\.0$'), '')}B';
    }
    if (this >= 1000000) {
      final v = this / 1000000;
      final s = v.toStringAsFixed(1);
      return '${s.replaceAll(RegExp(r'\.0$'), '')}M';
    }
    if (this >= 1000) {
      final v = this / 1000;
      final s = v.toStringAsFixed(1);
      return '${s.replaceAll(RegExp(r'\.0$'), '')}K';
    }
    return toString();
  }
}

String? stripYtLabel(String? value) {
  if (value == null || value.isEmpty) return null;
  return value
      .replaceAll(
        RegExp(
          r'\s+(plays|riproduzioni|views?|visualizzazioni|monthly audience|ascoltatori mensili|subscribers?|iscritti)$',
          caseSensitive: false,
        ),
        '',
      )
      .trim()
      .nullIfEmpty;
}

extension StringX on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}