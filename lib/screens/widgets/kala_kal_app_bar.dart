import 'package:flutter/material.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES A CUSTOM REUSABLE APPBAR WIDGET FOR THE KALAKALAPP.
// IT PROVIDES A CONSISTENT GREEN THEME, OPTIONAL BACK BUTTON, AND SUPPORT FOR CUSTOM ACTIONS.
class KalaKalAppBar extends StatelessWidget implements PreferredSizeWidget {
  // THESE ARE THE PROPERTIES FOR THE CUSTOM APPBAR.
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;

  const KalaKalAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    // THIS METHOD RENDERS THE VISUAL LAYOUT OF THE APPBAR.
    return AppBar(
      backgroundColor: Colors.green,
      elevation: 0,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: actions,
    );
  }

  @override
  // THIS GETTER DEFINES THE STANDARD HEIGHT OF THE APPBAR.
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
