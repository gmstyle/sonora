import 'package:flutter/material.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: Center(
        child: Text(
          'Downloads — Fase 8',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
