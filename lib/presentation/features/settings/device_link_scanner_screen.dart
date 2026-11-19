import 'dart:async';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../data/services/device_link.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/youtube_account_provider.dart';

/// Phone: scan a TV/Linux QR and POST the sealed session on the LAN.
class DeviceLinkScannerScreen extends ConsumerStatefulWidget {
  const DeviceLinkScannerScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DeviceLinkScannerScreen()));
  }

  @override
  ConsumerState<DeviceLinkScannerScreen> createState() =>
      _DeviceLinkScannerScreenState();
}

class _DeviceLinkScannerScreenState
    extends ConsumerState<DeviceLinkScannerScreen> {
  final _controller = MobileScannerController();
  DeviceLinkOffer? _offer;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _offer != null) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    final offer = DeviceLinkOffer.parseQr(raw);
    if (offer == null) {
      setState(
        () => _error = AppLocalizations.of(context)!.deviceLinkErrorPayload,
      );
      return;
    }
    setState(() {
      _offer = offer;
      _error = null;
    });
    await _controller.stop();
  }

  Future<void> _send() async {
    final offer = _offer;
    if (offer == null || _busy) return;
    final l10n = AppLocalizations.of(context)!;
    final signedIn = ref.read(youtubeAccountProvider).signedIn;
    if (!signedIn) {
      setState(() => _error = l10n.deviceLinkNeedLogin);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final www = await loadCookieMap(YTMusic().cookieJar, kYoutubeOrigin);
      final music = await loadCookieMap(YTMusic().cookieJar, kMusicOrigin);
      final cookies = <String, String>{
        for (final e in www.entries)
          if (e.value.isNotEmpty) e.key: e.value,
        for (final e in music.entries)
          if (e.value.isNotEmpty) e.key: e.value,
      };
      if (!jarHasAuth(cookies)) {
        setState(() {
          _busy = false;
          _error = l10n.deviceLinkNeedLogin;
        });
        return;
      }
      // Linux/TV often cannot refresh account_menu; send the phone card too.
      final account =
          ref.read(youtubeAccountInfoProvider).asData?.value ??
          await ref.read(youtubeAccountServiceProvider).cachedAccount();
      final sealed = await DeviceLinkCrypto(offer.key)
          .seal(cookies, account: account);
      final url = Uri(
        scheme: 'http',
        host: offer.ip,
        port: offer.port,
        path: '/session',
      );
      final response = await Dio().post<String>(
        url.toString(),
        data: Stream.fromIterable([sealed]),
        options: Options(
          contentType: 'application/octet-stream',
          headers: {Headers.contentLengthHeader: sealed.length},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          responseType: ResponseType.plain,
          validateStatus: (code) => code != null && code >= 200 && code < 300,
        ),
      );
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        if (mounted) {
          ref.read(actionFeedbackProvider.notifier).report(l10n.deviceLinkDone);
          Navigator.of(context).pop();
        }
        return;
      }
      setState(() {
        _busy = false;
        _error = l10n.deviceLinkErrorNetwork;
      });
    } on DioException {
      setState(() {
        _busy = false;
        _error = l10n.deviceLinkErrorNetwork;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = l10n.deviceLinkErrorGeneric;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final offer = _offer;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deviceLinkTitle),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.deviceLinkIntro),
            const SizedBox(height: 16),
            if (offer == null) ...[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.deviceLinkScanHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const Spacer(),
              Text(
                offer.confirmationCode,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.deviceLinkSasHint, textAlign: TextAlign.center),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _send,
                child: Text(
                  _busy ? l10n.deviceLinkSending : l10n.deviceLinkSend,
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() => _offer = null);
                        unawaited(_controller.start());
                      },
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
