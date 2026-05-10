import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class StreamDatasource {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<String> getStreamUrl(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    // uso muxed e non audioOnly per bug youtube_explode_dart
    // https://github.com/Hexer10/youtube_explode_dart/issues/332
    final audio = manifest.muxed.withHighestBitrate();
    return audio.url.toString();
  }

  Future<StreamManifest> getManifest(String videoId) =>
      _yt.videos.streamsClient.getManifest(videoId);

  void dispose() {
    _yt.close();
  }
}
