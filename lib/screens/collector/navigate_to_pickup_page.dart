import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/top_snackbar.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES THE NAVIGATE TO PICKUP PAGE FOR COLLECTORS.
// IT ALLOWS COLLECTORS TO CHOOSE THEIR PREFERRED MAP APPLICATION TO NAVIGATE
// TO THE HOUSEHOLD'S LOCATION USING EXACT GPS COORDINATES.
class NavigateToPickupPage extends StatefulWidget {
  final String householdName;
  final String address;
  final double destinationLat;
  final double destinationLng;

  const NavigateToPickupPage({
    super.key,
    required this.householdName,
    required this.address,
    required this.destinationLat,
    required this.destinationLng,
  });

  @override
  State<NavigateToPickupPage> createState() => _NavigateToPickupPageState();
}

class _NavigateToPickupPageState extends State<NavigateToPickupPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  // THESE HOLD THE LOADING STATE AND THE LIST OF MAP APPS FOUND ON THE DEVICE.
  bool _isLoading = true;
  List<AvailableMap> _installedMaps = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // AUTOMATICALLY DETECT WHICH MAP APPS ARE INSTALLED WHEN THE PAGE OPENS.
    _getInstalledMaps();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THIS FUNCTION DETECTS INSTALLED MAP APPLICATIONS.
  /// IT USES THE MAP_LAUNCHER PACKAGE TO SCAN THE DEVICE FOR AVAILABLE NAVIGATION
  /// APPS (LIKE GOOGLE MAPS OR WAZE) SO THE COLLECTOR CAN CHOOSE THEIR PREFERRED ONE.
  Future<void> _getInstalledMaps() async {
    try {
      final maps = await MapLauncher.installedMaps;
      setState(() {
        _installedMaps = maps;
        _isLoading = false; // HIDE LOADING SPINNER ONCE APPS ARE DETECTED
      });
    } catch (e) {
      debugPrint('Error fetching installed maps: $e');
      setState(() => _isLoading = false);
    }
  }

  /// THIS FUNCTION LAUNCHES EXTERNAL NAVIGATION.
  /// IT TAKES THE SELECTED MAP APP AND PASSES THE HOUSEHOLD'S EXACT GPS COORDINATES
  /// AND NAME TO OPEN TURN-BY-TURN DIRECTIONS DIRECTLY IN THAT EXTERNAL APP.
  Future<void> _startNavigation(AvailableMap map) async {
    try {
      await map.showDirections(
        destination: Coords(widget.destinationLat, widget.destinationLng),
        destinationTitle: widget.householdName,
      );
    } catch (e) {
      if (mounted) {
        TopSnackBar.show(
          context,
          message: 'Failed to open navigation: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // ==========================================================================

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE NAVIGATION SELECTION SCREEN.
  @override
  Widget build(BuildContext context) {
    // SHOW A LOADING SPINNER WHILE SCANNING FOR INSTALLED MAP APPS.
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF2F7F3),
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(
        title: 'Navigate to Pickup',
        showBackButton: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LARGE NAVIGATION ICON AT THE TOP.
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.navigation,
                  size: 64,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 32),

              // HOUSEHOLD NAME AND ADDRESS DISPLAY.
              Text(
                'Navigate to ${widget.householdName}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.address,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),

              // ERROR STATE: SHOWN IF NO MAP APPS ARE FOUND ON THE DEVICE.
              if (_installedMaps.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No map apps found. Please install Google Maps or Waze.',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                )
              // SUCCESS STATE: DYNAMICALLY GENERATES BUTTONS FOR EVERY INSTALLED MAP APP.
              else
                ..._installedMaps.map((map) {
                  final isGoogle = map.mapType == MapType.google;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _startNavigation(map),
                        // USES THE OFFICIAL ICON PROVIDED BY THE MAP_LAUNCHER PACKAGE.
                        icon: Image.asset(map.icon, width: 24, height: 24),
                        label: Text(
                          'Open in ${map.mapName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // COLORS THE BUTTON BLUE FOR GOOGLE MAPS, GREEN FOR OTHERS (LIKE WAZE).
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isGoogle
                              ? Colors.blue
                              : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
