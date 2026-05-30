import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:io';

class HoverCarouselArrows extends StatefulWidget {
  final ScrollController controller;
  final Widget child;
  final double scrollAmount;

  const HoverCarouselArrows({
    super.key,
    required this.controller,
    required this.child,
    this.scrollAmount = 500.0,
  });

  @override
  State<HoverCarouselArrows> createState() => _HoverCarouselArrowsState();
}

class _HoverCarouselArrowsState extends State<HoverCarouselArrows> {
  bool _isHovering = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  bool get _isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateScrollButtons);
    // Schedule a check after the first frame is rendered to see if scrolling is possible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollButtons();
    });
  }

  @override
  void didUpdateWidget(covariant HoverCarouselArrows oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateScrollButtons);
      widget.controller.addListener(_updateScrollButtons);
      _updateScrollButtons();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateScrollButtons);
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!mounted || !widget.controller.hasClients) return;

    final position = widget.controller.position;
    final canScrollLeft = widget.controller.offset > 5;
    final canScrollRight =
        widget.controller.offset < position.maxScrollExtent - 5;

    if (canScrollLeft != _canScrollLeft || canScrollRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canScrollLeft;
        _canScrollRight = canScrollRight;
      });
    }
  }

  void _scroll(bool left) {
    if (!widget.controller.hasClients) return;
    final target = (left
            ? widget.controller.offset - widget.scrollAmount
            : widget.controller.offset + widget.scrollAmount)
        .clamp(0.0, widget.controller.position.maxScrollExtent);

    widget.controller.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isMobile) return widget.child;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_isHovering && _canScrollLeft)
            Positioned(
              left: -4,
              top: 0,
              bottom: 0,
              child: Center(child: _buildArrowButton(true)),
            ),
          if (_isHovering && _canScrollRight)
            Positioned(
              right: -4,
              top: 0,
              bottom: 0,
              child: Center(child: _buildArrowButton(false)),
            ),
        ],
      ),
    );
  }

  Widget _buildArrowButton(bool isLeft) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: IconButton(
        icon: Icon(isLeft ? LucideIcons.chevronLeft : LucideIcons.chevronRight),
        onPressed: () => _scroll(isLeft),
        iconSize: 20,
        color: colorScheme.onSurface,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
