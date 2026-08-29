import 'package:flutter/material.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES A REUSABLE EMPTY STATE WIDGET.
// IT DISPLAYS AN ICON, TITLE, AND SUBTITLE CENTERED ON THE SCREEN,
// COMMONLY USED WHEN A LIST OR DATA FETCH RETURNS NO RESULTS.
class EmptyState extends StatelessWidget {
  // THESE ARE THE REQUIRED PROPERTIES FOR THE EMPTY STATE WIDGET.
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    // THIS METHOD RENDERS THE VISUAL LAYOUT OF THE EMPTY STATE.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
