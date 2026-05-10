import 'package:flutter/material.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Center(
        child: Text(
          'Library — Fase 7',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
