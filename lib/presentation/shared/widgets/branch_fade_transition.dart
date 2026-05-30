import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BranchFadeTransition extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const BranchFadeTransition({super.key, required this.navigationShell});

  @override
  State<BranchFadeTransition> createState() => _BranchFadeTransitionState();
}

class _BranchFadeTransitionState extends State<BranchFadeTransition>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.navigationShell.currentIndex;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant BranchFadeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = widget.navigationShell.currentIndex;
    if (newIndex != _currentIndex) {
      _currentIndex = newIndex;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.navigationShell,
    );
  }
}