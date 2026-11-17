import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../data/services/device_link.dart';
import '../../../data/services/device_link_server.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/android_tv_provider.dart';
import '../../providers/youtube_account_provider.dart';
import '../tv/tv_metrics.dart';
import '../tv/widgets/tv_focusable.dart';

/// Shows a LAN QR for TV / Linux; applies cookies when the phone POSTs.
class DeviceLinkQrPanel extends ConsumerStatefulWidget {
  const DeviceLinkQrPanel({super.key, this.compact = false});

  /// When true (settings card), no Scaffold chrome.
  final bool compact;

  static Future<void> showAsDialog(BuildContext context) {
    final isTv = ProviderScope.containerOf(context).read(isAndroidTvProvider);
    if (isTv) {
      return showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        builder: (ctx) => Dialog(
          backgroundColor: TvColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: TvColors.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: DeviceLinkQrPanel(compact: true),
            ),
          ),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: const SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: DeviceLinkQrPanel(compact: true),
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<DeviceLinkQrPanel> createState() => _DeviceLinkQrPanelState();
}

class _DeviceLinkQrPanelState extends ConsumerState<DeviceLinkQrPanel> {
  final _server = DeviceLinkServer();
  DeviceLinkOffer? _offer;
  String? _error;
  var _waiting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    unawaited(_server.stop());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _waiting = true;
      _offer = null;
    });
    final ip = await localLanIpv4();
    if (!mounted) return;
    if (ip == null) {
      setState(() {
        _waiting = false;
        _error = AppLocalizations.of(context)!.deviceLinkNoLanIp;
      });
      return;
    }
    try {
      final (offer, future) = await _server.start(ip);
      if (!mounted) return;
      setState(() {
        _offer = offer;
        _waiting = true;
      });
      final session = await future;
      if (!mounted) return;
      await ref
          .read(youtubeAccountProvider.notifier)
          .applyCookieMap(session.cookies, account: session.account);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ref.read(actionFeedbackProvider.notifier).report(l10n.accountSignedIn);
      if (widget.compact) {
        Navigator.of(context).pop();
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _waiting = false;
          _error = AppLocalizations.of(context)!.deviceLinkErrorTimeout;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _waiting = false;
          _error = AppLocalizations.of(context)!.deviceLinkErrorGeneric;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTv = ref.watch(isAndroidTvProvider);
    final offer = _offer;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.deviceLinkQrTitle,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.deviceLinkQrHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (offer != null) ...[
          QrImageView(
            data: offer.qrPayload,
            size: isTv ? 176 : 220,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 14),
          Text(
            offer.confirmationCode,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.deviceLinkQrSasHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_waiting) ...[
            const SizedBox(height: 12),
            Text(l10n.deviceLinkQrWaiting),
          ],
        ] else if (_error == null) ...[
          const Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
          if (isTv)
            TvFocusable(
              onSelect: _start,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(l10n.deviceLinkRegenerate),
              ),
            )
          else
            FilledButton.tonal(
              onPressed: _start,
              child: Text(l10n.deviceLinkRegenerate),
            ),
        ],
        const SizedBox(height: 16),
        if (isTv)
          TvFocusable(
            autofocus: true,
            onSelect: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: TvColors.surfaceButton,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TvColors.borderSubtle),
              ),
              alignment: Alignment.center,
              child: Text(
                MaterialLocalizations.of(context).closeButtonLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: TvColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
      ],
    );

    if (widget.compact) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deviceLinkTitle),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: body,
        ),
      ),
    );
  }
}
