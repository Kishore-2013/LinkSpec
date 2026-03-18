import 'package:flutter/material.dart';

/// UserController manages the state and logic for user capacity scaling.
/// It uses the ChangeNotifier pattern for reactive UI updates.
class UserController extends ChangeNotifier {
  // State variables as per requirements
  int _currentUsers = 0;
  int _maxCapacity = 100; // Initial value
  final double _threshold = 0.8; // 80%

  // Getters for external access
  int get currentUsers => _currentUsers;
  int get maxCapacity => _maxCapacity;
  double get threshold => _threshold;

  /// Increments the user count and applies threshold-based scaling logic.
  void addUser() {
    _currentUsers++;

    // ── Preemptive Scaling Logic ──────────────────────────────────────────
    // Check if the current user count has reached 80% of current max capacity.
    // If true, we increase the capacity by 100.
    // This allows the system to scale before reaching absolute exhaustion.
    if (_currentUsers >= _maxCapacity * _threshold) {
      _maxCapacity += 100;
      
      // Note on Constraint 5: 
      // Because maxCapacity increases immediately, the condition 
      // (currentUsers >= newMax * 0.8) becomes false for the same range,
      // preventing multiple increments for the same threshold crossing.
    }

    // Notify listeners to update the UI
    notifyListeners();
  }
}
