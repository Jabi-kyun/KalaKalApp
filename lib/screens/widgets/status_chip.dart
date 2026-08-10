import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;

  const StatusChip({super.key, required this.label, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      backgroundColor: backgroundColor,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}