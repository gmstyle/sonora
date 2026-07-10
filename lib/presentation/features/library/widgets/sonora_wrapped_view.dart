import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/stats_provider.dart';

class SonoraWrappedView extends StatefulWidget {
  final StatsState stats;

  const SonoraWrappedView({super.key, required this.stats});

  static Future<void> show(BuildContext context, StatsState stats) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => SonoraWrappedView(stats: stats),
      ),
    );
  }

  @override
  State<SonoraWrappedView> createState() => _SonoraWrappedViewState();
}

class _SonoraWrappedViewState extends State<SonoraWrappedView>
    with SingleTickerProviderStateMixin {
  int _currentSlide = 0;
  final int _totalSlides = 5;
  double _progress = 0.0;
  Timer? _timer;
  late AnimationController _vinylController;

  @override
  void initState() {
    super.initState();
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    _startSlideTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vinylController.dispose();
    super.dispose();
  }

  void _startSlideTimer() {
    _timer?.cancel();
    setState(() {
      _progress = 0.0;
    });

    const ticks = 100;
    const duration = Duration(milliseconds: 5000); // 5 seconds per slide
    final tickDuration = duration ~/ ticks;

    _timer = Timer.periodic(tickDuration, (t) {
      if (!mounted) return;
      setState(() {
        _progress += 1.0 / ticks;
      });

      if (_progress >= 1.0) {
        _timer?.cancel();
        _nextSlide();
      }
    });
  }

  void _nextSlide() {
    if (_currentSlide < _totalSlides - 1) {
      setState(() {
        _currentSlide++;
      });
      _startSlideTimer();
    } else {
      // Finished Wrapped
      Navigator.of(context).pop();
    }
  }

  void _prevSlide() {
    if (_currentSlide > 0) {
      setState(() {
        _currentSlide--;
      });
      _startSlideTimer();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    if (dx < screenWidth * 0.3) {
      // Tap on left side
      _prevSlide();
    } else {
      // Tap on right side
      _nextSlide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _handleTapDown,
        child: SafeArea(
          child: Stack(
            children: [
              // Beautiful animated background gradients
              _buildBackgroundGradient(),

              // Actual Slide Content
              Padding(
                padding: const EdgeInsets.only(
                  top: 48.0,
                  left: 24,
                  right: 24,
                  bottom: 24,
                ),
                child: Center(child: _buildSlideContent(l10n)),
              ),

              // Progress bars at the top
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: List.generate(_totalSlides, (index) {
                    double slideProgress = 0.0;
                    if (index < _currentSlide) {
                      slideProgress = 1.0;
                    } else if (index == _currentSlide) {
                      slideProgress = _progress;
                    }

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: slideProgress,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.25,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Exit button
              Positioned(
                top: 24,
                right: 16,
                child: IconButton(
                  icon: const Icon(
                    LucideIcons.x,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundGradient() {
    final List<Color> colors;
    switch (_currentSlide) {
      case 0:
        colors = [Colors.deepPurple.shade900, Colors.black];
        break;
      case 1:
        colors = [Colors.teal.shade900, Colors.black];
        break;
      case 2:
        colors = [Colors.pink.shade900, Colors.black];
        break;
      case 3:
        colors = [Colors.indigo.shade900, Colors.black];
        break;
      case 4:
      default:
        colors = [Colors.amber.shade900, Colors.black];
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildSlideContent(AppLocalizations l10n) {
    switch (_currentSlide) {
      case 0:
        return _buildIntroSlide(l10n);
      case 1:
        return _buildTimeSlide(l10n);
      case 2:
        return _buildTopArtistSlide(l10n);
      case 3:
        return _buildTopSongsSlide(l10n);
      case 4:
      default:
        return _buildSummarySlide(l10n);
    }
  }

  Widget _buildIntroSlide(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: CurvedAnimation(
            parent: _vinylController,
            curve: const Interval(0.0, 0.1, curve: Curves.easeOut),
          ).drive(Tween<double>(begin: 0.8, end: 1.0)),
          child: RotationTransition(
            turns: _vinylController,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple,
                    blurRadius: 36,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Vinyl disc texture representation
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade900,
                      border: Border.all(color: Colors.black, width: 4),
                    ),
                  ),
                  ...List.generate(6, (index) {
                    final size = 220.0 - (index * 30);
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                  // Label in the center
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.deepPurple,
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.sparkles,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
        Text(
          l10n.wrappedTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.wrappedIntro,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlide(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          LucideIcons.heartHandshake,
          color: Colors.tealAccent,
          size: 64,
        ),
        const SizedBox(height: 32),
        Text(
          l10n.wrappedTimeSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 32),
        TweenAnimationBuilder<double>(
          duration: const Duration(seconds: 2),
          tween: Tween(
            begin: 0.0,
            end: widget.stats.totalDurationMinutes.toDouble(),
          ),
          builder: (context, value, child) {
            return Text(
              value.round().toString(),
              style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 72,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.teal, blurRadius: 24)],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          l10n.minutesLabel.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }

  Widget _buildTopArtistSlide(AppLocalizations l10n) {
    final topArtist = widget.stats.topArtists.first;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.wrappedTopArtistSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        // Big artist avatar
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: Colors.pink, blurRadius: 32, spreadRadius: 2),
            ],
            image:
                topArtist.thumbnailUrl != null
                    ? DecorationImage(
                      image: CachedNetworkImageProvider(
                        topArtist.thumbnailUrl!,
                      ),
                      fit: BoxFit.cover,
                    )
                    : null,
          ),
          child:
              topArtist.thumbnailUrl == null
                  ? const Icon(LucideIcons.user, size: 64, color: Colors.white)
                  : null,
        ),
        const SizedBox(height: 32),
        Text(
          topArtist.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.pink.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.pink.withValues(alpha: 0.5)),
          ),
          child: Text(
            '${topArtist.playCount} ${l10n.plays}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopSongsSlide(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.wrappedTopSongsSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 40),
        ...List.generate(widget.stats.topSongs.length, (index) {
          final song = widget.stats.topSongs[index];

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                // Number badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child:
                        song.thumbnailUrl != null
                            ? CachedNetworkImage(
                              imageUrl: song.thumbnailUrl!,
                              fit: BoxFit.cover,
                            )
                            : Container(
                              color: Colors.grey.shade800,
                              child: const Icon(
                                LucideIcons.music,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummarySlide(AppLocalizations l10n) {
    final topArtist = widget.stats.topArtists.first;
    final topSong = widget.stats.topSongs.first;
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.wrappedSummary,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 32),
        // Summary Card to share
        Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.amber.shade900.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.amber.shade700.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.shade700.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.appTitle.toUpperCase(),
                    style: TextStyle(
                      color: Colors.amber.shade400,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                  Icon(
                    LucideIcons.sparkles,
                    color: Colors.amber.shade400,
                    size: 20,
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              const SizedBox(height: 8),
              _buildSummaryRow(
                l10n.listeningTime,
                '${widget.stats.totalDurationMinutes} ${l10n.minutesLabel}',
                Colors.tealAccent,
              ),
              const SizedBox(height: 20),
              _buildSummaryRow(
                l10n.topArtists,
                topArtist.name,
                Colors.pinkAccent,
              ),
              const SizedBox(height: 20),
              _buildSummaryRow(
                l10n.topSongs,
                topSong.title,
                Colors.indigoAccent,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(
                LucideIcons.refreshCw,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Ricomincia',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                setState(() {
                  _currentSlide = 0;
                });
                _startSlideTimer();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              icon: Icon(
                LucideIcons.share2,
                color: theme.colorScheme.onPrimary,
                size: 18,
              ),
              label: Text(
                'Condividi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              onPressed: () async {
                final message =
                    'Il mio profilo musicale su Sonora!\n'
                    'Tempo ascolto: ${widget.stats.totalDurationMinutes} minuti\n'
                    'Top Artista: ${topArtist.name}\n'
                    'Top Brano: ${topSong.title}\n'
                    'Ascoltato tramite Sonora Player 🎧';
                await SharePlus.instance.share(ShareParams(text: message));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
