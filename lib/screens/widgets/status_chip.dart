import 'package:flutter/material.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES A REUSABLE STATUS CHIP WIDGET.
// IT DISPLAYS A TEXT LABEL WITH A SPECIFIC BACKGROUND COLOR,
// COMMONLY USED TO INDICATE THE CURRENT STATUS OF LISTINGS OR BIDS.
class StatusChip extends StatelessWidget {
  // THESE ARE THE REQUIRED PROPERTIES FOR THE STATUS CHIP.
  final String label;
  final Color backgroundColor;

  const StatusChip({
    super.key,
    required this.label,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // THIS METHOD RENDERS THE VISUAL LAYOUT OF THE STATUS CHIP.
    return Chip(
      label: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: backgroundColor,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
