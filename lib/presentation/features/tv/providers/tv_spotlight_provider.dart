import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Data model representing the currently spotlighted catalog item in Android TV.
@immutable
class TvSpotlightData {
  final String title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final String? tag;
  final VoidCallback? onPlay;
  final VoidCallback? onOpen;

  const TvSpotlightData({
    required this.title,
    this.subtitle,
    this.description,
    this.imageUrl,
    this.tag,
    this.onPlay,
    this.onOpen,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TvSpotlightData &&
        other.title == title &&
        other.subtitle == subtitle &&
        other.imageUrl == imageUrl;
  }

  @override
  int get hashCode => Object.hash(title, subtitle, imageUrl);
}

final tvSpotlightProvider =
    NotifierProvider<TvSpotlightNotifier, TvSpotlightData?>(
      TvSpotlightNotifier.new,
    );

class TvSpotlightNotifier extends Notifier<TvSpotlightData?> {
  @override
  TvSpotlightData? build() => null;

  void setSpotlight(TvSpotlightData data) {
    if (state == data) return;
    state = data;
  }
}
