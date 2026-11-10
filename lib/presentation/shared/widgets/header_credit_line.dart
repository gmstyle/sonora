import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

/// One name in an entity-header credit line.
class CreditSpan {
  final String label;

  /// Route opened by a tap. Null keeps the name as plain text.
  final String? route;

  const CreditSpan(this.label, {this.route});
}

/// Credited artists, each linked when [ArtistBasic.artistId] is present.
List<CreditSpan> artistCreditSpans(List<ArtistBasic> artists) {
  return [
    for (final artist in artists)
      if (artist.name.trim().isNotEmpty)
        CreditSpan(artist.name, route: artistRoute(artist.artistId)),
  ];
}

/// `/artist/:id` when [artistId] is usable, otherwise null.
String? artistRoute(String? artistId) {
  if (artistId == null || artistId.isEmpty) return null;
  return '/artist/$artistId';
}

/// Joined credit line for an entity header.
///
/// Separators match [ArtistBasic.formatNames]: `A & B`, `A, B & C`.
/// A span with a [CreditSpan.route] opens that page; the others stay text.
class HeaderCreditLine extends StatefulWidget {
  final List<CreditSpan> credits;
  final TextStyle? style;
  final TextAlign textAlign;

  const HeaderCreditLine({
    super.key,
    required this.credits,
    this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  State<HeaderCreditLine> createState() => _HeaderCreditLineState();
}

class _HeaderCreditLineState extends State<HeaderCreditLine> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final credits = [
      for (final credit in widget.credits)
        if (credit.label.trim().isNotEmpty) credit,
    ];
    if (credits.isEmpty) return const SizedBox.shrink();

    final spans = <InlineSpan>[];
    for (var i = 0; i < credits.length; i++) {
      if (i > 0) {
        final separator = credits.length == 2 || i == credits.length - 1
            ? ' & '
            : ', ';
        spans.add(TextSpan(text: separator));
      }
      spans.add(_nameSpan(credits[i]));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  InlineSpan _nameSpan(CreditSpan credit) {
    final route = credit.route;
    if (route == null) return TextSpan(text: credit.label);
    final recognizer = TapGestureRecognizer()
      ..onTap = () {
        if (!mounted) return;
        context.push(route);
      };
    _recognizers.add(recognizer);
    return TextSpan(text: credit.label, recognizer: recognizer);
  }
}
