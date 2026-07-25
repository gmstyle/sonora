import 'queue_section.dart';
import 'queue_track.dart';

/// A persisted queue row rehydrated with its section tag.
class RestoredQueueEntry {
  final QueueTrack track;
  final QueueSection section;

  const RestoredQueueEntry({required this.track, required this.section});
}
