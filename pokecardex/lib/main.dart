import 'package:flutter/material.dart';

import 'screens/set_selection_screen.dart';

void main() {
  runApp(const PokeCardexScannerApp());
}

class PokeCardexScannerApp extends StatelessWidget {
  const PokeCardexScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PokeCardex Scanner MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
      ),
      home: const SetSelectionScreen(),
    );
  }
}
