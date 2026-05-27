import 'package:flutter/material.dart';

class HorizontalScrollRow extends StatefulWidget {
  final Widget Function(BuildContext context, ScrollController controller) builder;
  final double arrowSize;
  final EdgeInsets padding;

  const HorizontalScrollRow({
    super.key,
    required this.builder,
    this.arrowSize = 36,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<HorizontalScrollRow> createState() => _HorizontalScrollRowState();
}

class _HorizontalScrollRowState extends State<HorizontalScrollRow> {
  final ScrollController _scrollController = ScrollController();
  bool _hovering = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollPosition();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollPosition);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollPosition() {
    if (!mounted || !_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final canLeft = offset > 2;
    final canRight = offset < (max - 2);
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final current = _scrollController.offset;
    final max = _scrollController.position.maxScrollExtent;
    final target = (current + delta).clamp(0.0, max);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildArrow({
    required IconData icon,
    required bool visible,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    if (!_hovering || !visible) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      bottom: 0,
      left: isLeft ? widget.padding.left : null,
      right: isLeft ? null : widget.padding.right,
      width: widget.arrowSize + 16,
      child: Center(
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            minimumSize: Size(widget.arrowSize, widget.arrowSize),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _updateScrollPosition();
              return false;
            },
            child: widget.builder(context, _scrollController),
          ),
          _buildArrow(
            icon: Icons.chevron_left_rounded,
            visible: _canScrollLeft,
            onTap: () => _scrollBy(-300),
            isLeft: true,
          ),
          _buildArrow(
            icon: Icons.chevron_right_rounded,
            visible: _canScrollRight,
            onTap: () => _scrollBy(300),
            isLeft: false,
          ),
        ],
      ),
    );
  }
}