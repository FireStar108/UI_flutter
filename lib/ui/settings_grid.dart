import 'package:flutter/material.dart';

class SettingsGrid extends StatelessWidget {
  const SettingsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_4x4, size: 48, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'SETTINGS GRID',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Content coming soon...',
              style: TextStyle(
                color: Colors.white10,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
