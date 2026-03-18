import 'package:flutter/material.dart';
import 'user_controller.dart';

/// CapacityScalingScreen provides the UI for monitoring and simulating user growth.
class CapacityScalingScreen extends StatefulWidget {
  const CapacityScalingScreen({super.key});

  @override
  State<CapacityScalingScreen> createState() => _CapacityScalingScreenState();
}

class _CapacityScalingScreenState extends State<CapacityScalingScreen> {
  // Controller instance local to this screen
  final UserController _controller = UserController();

  @override
  Widget build(BuildContext context) {
    // We use the ListenableBuilder to ensure the UI updates in real-time
    // whenever the controller notifies listeners.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preemptive Scaling Demo'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, child) {
          // Calculate usage metrics
          final current = _controller.currentUsers;
          final max = _controller.maxCapacity;
          final ratio = current / max;
          final thresholdVal = (max * _controller.threshold).toInt();
          final isNearLimit = current >= thresholdVal;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Visual Dashboard
                    _buildCapacityCard(current, max, isNearLimit),
                    const SizedBox(height: 48),

                    // Progress & Threshold View
                    _buildProgressSection(current, max, thresholdVal, isNearLimit),
                    const SizedBox(height: 48),

                    // Interaction Section
                    _buildActionButton(),
                    const SizedBox(height: 16),
                    const Text(
                      'System will auto-scale (+100) at 80% usage.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCapacityCard(int current, int max, bool isNearLimit) {
    return Card(
      elevation: 6,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isNearLimit 
              ? [Colors.deepOrange[400]!, Colors.orange[600]!]
              : [Colors.indigo[400]!, Colors.indigo[800]!],
          ),
        ),
        child: Column(
          children: [
            Text(isNearLimit ? 'WARNING: HIGH LOAD' : 'SYSTEM STATUS: OPTIMAL',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$current', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white)),
                Text(' / $max', style: const TextStyle(fontSize: 24, color: Colors.white60, fontWeight: FontWeight.bold)),
              ],
            ),
            const Text('USERS CONNECTED', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(int current, int max, int thresholdVal, bool isNearLimit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Capacity Yield', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            Text('${(current / max * 100).toStringAsFixed(1)}%', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isNearLimit ? Colors.orange[700] : Colors.indigo[700])),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: current / max,
            minHeight: 16,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(isNearLimit ? Colors.orange : Colors.indigo),
          ),
        ),
        const SizedBox(height: 8),
        Text('Scaling Trigger Point: $thresholdVal users', 
          style: TextStyle(color: Colors.grey[600], fontSize: 13, decoration: isNearLimit ? TextDecoration.underline : null)),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        onPressed: () => _controller.addUser(),
        icon: const Icon(Icons.person_add_rounded, size: 24),
        label: const Text('Add User Sim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo[700],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
      ),
    );
  }
}
