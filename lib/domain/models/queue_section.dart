/// Section of the playback queue a [MediaItem] belongs to.
///
/// Sonora splits the queue into two conceptual areas:
///
/// * [user] — the user-driven queue: tracks added explicitly via
///   "Play all", "Play next", "Add to queue", or any single-track tap.
///   This is the only section the user can fully manage (reorder, remove,
///   clear).
/// * [upnext] — the autoplay "Up Next" section, populated automatically by
///   the [StartRadioUseCase] when [Settings.autoPlayUpNext] is enabled.
///   Items are appended in a dedicated visual area of the queue sheet and
///   are removed automatically when the user disables autoplay.
///
/// The section is carried on [MediaItem.extras] under the `'section'` key
/// and persisted in the `queue_items.section` Drift column. Values are
/// persisted as Strings (`'user'` / `'upnext'`) for forward compatibility.
enum QueueSection {
  user,
  upnext;

  /// The string tag stored in [MediaItem.extras] and in the database.
  String get tag {
    switch (this) {
      case QueueSection.user:
        return 'user';
      case QueueSection.upnext:
        return 'upnext';
    }
  }

  /// Returns the [QueueSection] matching [tag]. Defaults to [QueueSection.user]
  /// for unknown / missing values (legacy items without the field).
  static QueueSection fromTag(String? tag) {
    switch (tag) {
      case 'upnext':
        return QueueSection.upnext;
      case 'user':
      default:
        return QueueSection.user;
    }
  }
}
