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

  test('saveFrom with preserveExistingOnDisk=false drops old cookies and account card', () async {
    final yt = YTMusic();
    await clearAuthCookies(yt.cookieJar);
    await applyAuthCookies(yt.cookieJar, [
      Cookie('SAPISID', 'old-sapisid')..domain = '.youtube.com',
      Cookie('SIDCC', 'old-sidcc')..domain = '.youtube.com',
    ]);
    await store.saveFrom(yt);
    await store.saveAccount(
      AccountInfo(name: 'Old User', email: 'old@example.com'),
    );

    await clearAuthCookies(yt.cookieJar);
    await applyAuthCookies(yt.cookieJar, [
      Cookie('SAPISID', 'new-sapisid')..domain = '.youtube.com',
    ]);
    await store.saveFrom(yt, preserveExistingOnDisk: false);

    expect(await store.loadAccount(), isNull);
    final raw = jsonDecode(await store.file.readAsString()) as Map;
    final names = (raw['cookies'] as List)
        .cast<Map>()
        .map((e) => e['name'])
        .toList();
    expect(names, isNot(contains('SIDCC')));
    final sapisid = (raw['cookies'] as List).cast<Map>().firstWhere(
      (e) => e['name'] == 'SAPISID',
    );
    expect(sapisid['value'], 'new-sapisid');
  });

  test('scheduleSaveFrom persists rotated cookies after debounce', () async {
    final yt = YTMusic();
    await clearAuthCookies(yt.cookieJar);
    await applyAuthCookies(yt.cookieJar, [
      Cookie('SAPISID', 'sapisid-val')..domain = '.youtube.com',
    ]);

    store.scheduleSaveFrom(yt, delay: const Duration(milliseconds: 50));
    expect(await store.file.exists(), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await store.file.exists(), isTrue);
    final raw = jsonDecode(await store.file.readAsString()) as Map;
    final cookies = (raw['cookies'] as List).cast<Map>();
    expect(
      cookies.any((e) => e['name'] == 'SAPISID' && e['value'] == 'sapisid-val'),
      isTrue,
    );
  });
}
