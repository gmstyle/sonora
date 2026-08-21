import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Closes the full player (imperative root route), then pushes [location]
/// onto the shell navigator so the detail screen is visible with the mini player.
void closeFullPlayerAndNavigate(BuildContext context, String location) {
  final router = GoRouter.of(context);
  Navigator.of(context).pop();
  router.push(location);
}
