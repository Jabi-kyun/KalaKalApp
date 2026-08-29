import 'package:flutter/material.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES A REUSABLE PRIMARY BUTTON WIDGET.
// IT PROVIDES A CONSISTENT GREEN THEME, LOADING STATE, AND ROUNDED CORNERS ACROSS THE APP.
class PrimaryButton extends StatelessWidget {
  // THESE ARE THE REQUIRED AND OPTIONAL PROPERTIES FOR THE PRIMARY BUTTON.
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // THIS METHOD RENDERS THE VISUAL LAYOUT OF THE PRIMARY BUTTON,
    // HANDLING BOTH NORMAL AND LOADING STATES.
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
