import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/ask_chat_models.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/repositories/library_repository.dart';
import 'package:sonora/domain/usecases/ai/apply_ask_playlist_write_use_case.dart';

class _FakeLibraryRepo extends Fake implements LibraryRepository {
  final Map<int, LocalPlaylistModel> playlists = {};
  final Map<int, List<PlaylistEntryModel>> entries = {};
  int _nextId = 1;

  @override
  Future<List<LocalPlaylistModel>> getAllPlaylists() async =>
      playlists.values.toList();

  @override
  Future<LocalPlaylistModel?> getPlaylist(int id) async => playlists[id];

  @override
  Future<int> createPlaylist(
    String name, {
    String? description,
    String? sourceKind,
    String? remoteId,
    String? remoteName,
    String linkStatus = 'local',
    DateTime? lastSyncedAt,
  }) async {
    final id = _nextId++;
    playlists[id] = LocalPlaylistModel(
      id: id,
      name: name,
      description: description,
      createdAt: DateTime(2026, 11, 21),
      sourceKind: sourceKind,
      remoteId: remoteId,
      remoteName: remoteName,
      lastSyncedAt: lastSyncedAt,
      linkStatus: linkStatus,
    );
    entries[id] = [];
    return id;
  }

  @override
  Future<List<PlaylistEntryModel>> getPlaylistEntries(int playlistId) async =>
      List.unmodifiable(entries[playlistId] ?? const []);

  @override
  Future<void> addEntry(
    int playlistId,
    String videoId,
    int position, {
    String? title,
    String? artist,
    String? artistsJson,
    String? thumbnailUrl,
    int? duration,
    bool isVideo = false,
    bool isExplicit = false,
  }) async {
    entries
        .putIfAbsent(playlistId, () => [])
        .add(
          PlaylistEntryModel(
            playlistId: playlistId,
            videoId: videoId,
            position: position,
            title: title,
            artist: artist,
            artistsJson: artistsJson,
            thumbnailUrl: thumbnailUrl,
            duration: duration,
            isVideo: isVideo,
            isExplicit: isExplicit,
          ),
        );
  }

  @override
  Future<void> removeEntry(int playlistId, String videoId) async {
    entries[playlistId]?.removeWhere((e) => e.videoId == videoId);
  }
}

void main() {
  const t1 = AskTrackRef(
    videoId: 'vid_1',
    title: 'Midnight City',
    artist: 'M83',
    durationSec: 244,
    thumbnailUrl: 'https://img/1.jpg',
  );
  const t2 = AskTrackRef(
    videoId: 'vid_2',
    title: 'Instant Crush',
    artist: 'Daft Punk',
    durationSec: 337,
    isExplicit: true,
  );

  test('create creates playlist and deduplicates tracks by videoId', () async {
    final lib = _FakeLibraryRepo();
    final useCase = ApplyAskPlaylistWriteUseCase(lib);

    final id = await useCase.execute(
      const AskPlaylistWriteProposal(
        operation: 'create',
        playlistName: 'Late Night Drive',
        tracks: [t1, t1, t2],
      ),
    );

    expect(id, 1);
    expect(lib.playlists[1]?.name, 'Late Night Drive');
    final saved = lib.entries[1]!;
    expect(saved.map((e) => e.videoId), ['vid_1', 'vid_2']);
    expect(saved.map((e) => e.position), [0, 1]);
    expect(saved[1].isExplicit, isTrue);
  });

  test('append resolves playlist by targetPlaylistId, skips existing tracks, and appends sequentially', () async {
    final lib = _FakeLibraryRepo();
    final existingId = await lib.createPlaylist('Synthwave');
    await lib.addEntry(
      existingId,
      'vid_1',
      0,
      title: 'Midnight City',
      artist: 'M83',
    );
    final useCase = ApplyAskPlaylistWriteUseCase(lib);

    final resultId = await useCase.execute(
      AskPlaylistWriteProposal(
        operation: 'append',
        targetPlaylistId: existingId,
        playlistName: 'Ignored Name',
        tracks: const [t1, t2],
      ),
    );

    expect(resultId, existingId);
    final list = lib.entries[existingId]!;
    expect(list.map((e) => e.videoId), ['vid_1', 'vid_2']);
    expect(list[1].position, 1);
  });

  test('append resolves playlist case-insensitively by name when targetPlaylistId is null, or creates it', () async {
    final lib = _FakeLibraryRepo();
    final existingId = await lib.createPlaylist('Focus Gems');
    final useCase = ApplyAskPlaylistWriteUseCase(lib);

    final matchedId = await useCase.execute(
      const AskPlaylistWriteProposal(
        operation: 'append',
        playlistName: '  focus gems ',
        tracks: [t1],
      ),
    );
    expect(matchedId, existingId);
    expect(lib.entries[existingId]!.single.videoId, 'vid_1');

    final createdId = await useCase.execute(
      const AskPlaylistWriteProposal(
        operation: 'append',
        playlistName: 'Brand New',
        tracks: [t2],
      ),
    );
    expect(createdId, isNot(existingId));
    expect(lib.playlists[createdId]?.name, 'Brand New');
    expect(lib.entries[createdId]!.single.videoId, 'vid_2');
  });

  test('remove deletes specified tracks and throws StateError if playlist is missing', () async {
    final lib = _FakeLibraryRepo();
    final id = await lib.createPlaylist('Cleanup');
    await lib.addEntry(id, 'vid_1', 0);
    await lib.addEntry(id, 'vid_2', 1);
    final useCase = ApplyAskPlaylistWriteUseCase(lib);

    await expectLater(
      () => useCase.execute(
        const AskPlaylistWriteProposal(
          operation: 'remove',
          playlistName: 'Does Not Exist',
          tracks: [t1],
        ),
      ),
      throwsStateError,
    );

    final updatedId = await useCase.execute(
      AskPlaylistWriteProposal(
        operation: 'remove',
        targetPlaylistId: id,
        playlistName: 'Cleanup',
        tracks: const [t1],
      ),
    );
    expect(updatedId, id);
    expect(lib.entries[id]!.map((e) => e.videoId), ['vid_2']);
  });

  test('saveMixAsPlaylist prefers customName, falls back to mix title or default, and saves subtitle', () async {
    final lib = _FakeLibraryRepo();
    final useCase = ApplyAskPlaylistWriteUseCase(lib);

    final id1 = await useCase.saveMixAsPlaylist(
      const AskMixAttachment(
        title: 'Generated Mix',
        subtitle: 'Electronic chill cuts',
        tracks: [t1, t1, t2],
      ),
      customName: '  My Custom Mix  ',
    );
    expect(lib.playlists[id1]?.name, 'My Custom Mix');
    expect(lib.playlists[id1]?.description, 'Electronic chill cuts');
    expect(lib.entries[id1]!.map((e) => e.videoId), ['vid_1', 'vid_2']);

    final id2 = await useCase.saveMixAsPlaylist(
      const AskMixAttachment(title: '', tracks: [t1]),
    );
    expect(lib.playlists[id2]?.name, 'Sonora Ask Mix');
  });

  test(
    'preserves isVideo across create, append, and saveMixAsPlaylist',
    () async {
      const videoTrack = AskTrackRef(
        videoId: 'mv_1',
        title: 'Around the World (Live)',
        artist: 'Daft Punk',
        isVideo: true,
      );
      final lib = _FakeLibraryRepo();
      final useCase = ApplyAskPlaylistWriteUseCase(lib);

      final createdId = await useCase.execute(
        const AskPlaylistWriteProposal(
          operation: 'create',
          playlistName: 'Video Cuts',
          tracks: [videoTrack],
        ),
      );
      expect(lib.entries[createdId]!.single.isVideo, isTrue);

      await useCase.execute(
        const AskPlaylistWriteProposal(
          operation: 'append',
          targetPlaylistId: null,
          playlistName: 'Video Cuts',
          tracks: [
            AskTrackRef(
              videoId: 'mv_2',
              title: 'One More Time',
              artist: 'Daft Punk',
              isVideo: true,
            ),
          ],
        ),
      );
      expect(lib.entries[createdId]![1].isVideo, isTrue);

      final mixId = await useCase.saveMixAsPlaylist(
        const AskMixAttachment(title: 'Video Mix', tracks: [videoTrack]),
      );
      expect(lib.entries[mixId]!.single.isVideo, isTrue);
    },
  );
}
