import 'package:flutter/material.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES A REUSABLE ACTION CARD WIDGET.
// IT DISPLAYS AN ICON, TITLE, SUBTITLE, AND AN OPTIONAL NOTIFICATION BADGE,
// COMMONLY USED IN DASHBOARDS FOR NAVIGATION AND QUICK ACTIONS.
class ActionCard extends StatelessWidget {
  // THESE ARE THE REQUIRED AND OPTIONAL PROPERTIES FOR THE ACTION CARD.
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool badge;
  final int? badgeCount;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge = false,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    // THIS METHOD RENDERS THE VISUAL LAYOUT OF THE ACTION CARD.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // MAIN CONTENT: ICON, TITLE, AND SUBTITLE.
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),

            // NOTIFICATION BADGE: DISPLAYS IF ENABLED AND COUNT IS GREATER THAN ZERO.
            if (badge && badgeCount != null && badgeCount! > 0)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    badgeCount! > 99 ? '99+' : badgeCount!.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
