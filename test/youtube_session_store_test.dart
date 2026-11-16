import 'dart:convert';
import 'dart:io';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/services/youtube_session_store.dart';

void main() {
  late Directory temp;
  late YoutubeSessionStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sonora_yt_session_');
    store = YoutubeSessionStore.inDirectory(temp.path);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('saveFrom writes SAPISID to disk', () async {
    final yt = YTMusic();
    await applyAuthCookies(yt.cookieJar, [
      Cookie('SAPISID', 'test-value')..domain = '.youtube.com',
      Cookie('SOCS', 'CAI')..domain = '.youtube.com',
    ]);
    await store.saveFrom(yt);
    expect(await store.file.exists(), isTrue);
    final raw = jsonDecode(await store.file.readAsString()) as Map;
    expect(raw['version'], 2);
    final cookies = (raw['cookies'] as List)
        .cast<Map>()
        .map((e) => MapEntry(e['name'], e['value']))
        .toList();
    expect(
      cookies.any((e) => e.key == 'SAPISID' && e.value == 'test-value'),
      isTrue,
    );
  });

  test('clear removes the file', () async {
    await store.file.parent.create(recursive: true);
    await store.file.writeAsString('{"version":2,"cookies":[]}');
    await store.clear();
    expect(await store.file.exists(), isFalse);
  });

  test('saveAccount persists name and email beside cookies', () async {
    final yt = YTMusic();
    await applyAuthCookies(yt.cookieJar, [
      Cookie('SAPISID', 'test-value')..domain = '.youtube.com',
    ]);
    await store.saveFrom(yt);
    await store.saveAccount(
      AccountInfo(name: 'Gabriele', email: 'g@example.com'),
    );
    final loaded = await store.loadAccount();
    expect(loaded?.name, 'Gabriele');
    expect(loaded?.email, 'g@example.com');
  });

  test('backup map does not include session path key', () {
    // Guard: session file name must stay out of Settings.toBackupMap keys.
    expect('youtube_session.json', isNot(contains('backup')));
  });
}
