import 'package:flutter/material.dart';
import 'capacity_scaling_screen.dart';

/// main.dart (Standalone Demo)
/// To run this specifically: flutter run lib/capacity_scaling/main.dart
void main() {
  runApp(const ScalingApp());
}

class ScalingApp extends StatelessWidget {
  const ScalingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Capacity Scaling Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF9FAFF),
      ),
      home: const CapacityScalingScreen(),
    );
  }
}
