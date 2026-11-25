import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/datasources/remote/stream_datasource.dart';
import 'package:sonora/data/datasources/remote/ytmusic_datasource.dart';
import 'package:sonora/data/services/youtube_account_service.dart';
import 'package:sonora/data/services/youtube_session_store.dart';
import 'package:youtube_explode_dart/js_challenge.dart';
import 'package:youtube_explode_dart/src/reverse_engineering/pages/watch_page.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class _RecordingPoTokenProvider extends BasePoTokenProvider {
  int invalidations = 0;

  @override
  Future<PoTokenResult?> getPoToken({
    required YoutubeApiClient client,
    required VideoId videoId,
    String? visitorData,
    WatchPage? watchPage,
    bool forceRefresh = false,
  }) async => null;

  @override
  void invalidateSession() {
    invalidations++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('handleRemoteRevocation invalidates PO token session', () async {
    final tempDir = await Directory.systemTemp.createTemp('sonora_acct_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final poProvider = _RecordingPoTokenProvider();
    final streams = StreamDatasource(poTokenProvider: poProvider);
    addTearDown(streams.dispose);

    final service = YoutubeAccountService(
      store: YoutubeSessionStore.inDirectory(tempDir.path),
      ytmusic: YtmusicDatasource(),
      streams: streams,
      gl: () => 'US',
      hl: () => 'en',
    );

    await service.handleRemoteRevocation();
    expect(poProvider.invalidations, 1);
  });
}
