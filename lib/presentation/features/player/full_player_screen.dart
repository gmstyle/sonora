import 'package:flutter/material.dart';

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Text(
          'Full Player — Fase 6',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
