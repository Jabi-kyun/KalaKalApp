import 'package:flutter/material.dart';

// ============================================================================
// WIDGET CLASSES
// ============================================================================

// THIS CLASS DEFINES A REUSABLE STATIC STAR RATING WIDGET.
// IT DISPLAYS A ROW OF FILLED AND OUTLINED STARS BASED ON A GIVEN RATING VALUE,
// COMMONLY USED IN HISTORY PAGES TO SHOW PAST RATINGS.
class StarRating extends StatelessWidget {
  // THESE ARE THE PROPERTIES FOR THE STATIC STAR RATING.
  final double rating;
  final int starCount;
  final double size;
  final Color color;

  const StarRating({
    super.key,
    required this.rating,
    this.starCount = 5,
    this.size = 20,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    // THIS METHOD RENDERS THE VISUAL LAYOUT OF THE STATIC STAR RATING.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(starCount, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: color,
          size: size,
        );
      }),
    );
  }
}

// ============================================================================
// INTERACTIVE WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES AN INTERACTIVE STAR RATING WIDGET.
// IT ALLOWS USERS TO TAP ON STARS TO SELECT A RATING,
// COMMONLY USED IN THE RATING DIALOG TO GATHER USER FEEDBACK.
class InteractiveStarRating extends StatefulWidget {
  // THIS IS THE CALLBACK FUNCTION TRIGGERED WHEN A RATING IS SELECTED.
  final Function(int) onRatingSelected;

  const InteractiveStarRating({super.key, required this.onRatingSelected});

  @override
  State<InteractiveStarRating> createState() => _InteractiveStarRatingState();
}

class _InteractiveStarRatingState extends State<InteractiveStarRating> {
  // THIS HOLDS THE CURRENTLY SELECTED RATING VALUE.
  int _currentRating = 0;

  @override
  Widget build(BuildContext context) {
    // THIS METHOD RENDERS THE VISUAL LAYOUT OF THE INTERACTIVE STAR RATING.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () {
            // UPDATE THE LOCAL STATE AND NOTIFY THE PARENT WIDGET
            setState(() => _currentRating = index + 1);
            widget.onRatingSelected(index + 1);
          },
          child: Icon(
            index < _currentRating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 40,
          ),
        );
      }),
    );
  }
}
