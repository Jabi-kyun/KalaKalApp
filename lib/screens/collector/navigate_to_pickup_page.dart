import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/top_snackbar.dart'; // ✅ Added for consistent notifications

// ============================================================================
// WIDGET CLASS
// ============================================================================

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
  // These hold the loading state and the list of map apps found on the device
  // ==========================================================================

  bool _isLoading = true;
  List<AvailableMap> _installedMaps = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // Automatically detect which map apps are installed when the page opens
    _getInstalledMaps();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR DETECTING INSTALLED MAP APPLICATIONS.
  /// It uses the map_launcher package to scan the device for available navigation
  /// apps (like Google Maps or Waze) so the collector can choose their preferred one.
  Future<void> _getInstalledMaps() async {
    try {
      final maps = await MapLauncher.installedMaps;
      setState(() {
        _installedMaps = maps;
        _isLoading = false; // Hide loading spinner once apps are detected
      });
    } catch (e) {
      debugPrint('❌ Error fetching installed maps: $e');
      setState(() => _isLoading = false);
    }
  }

  /// THESE CODES ARE FOR LAUNCHING EXTERNAL NAVIGATION.
  /// It takes the selected map app and passes the household's exact GPS coordinates
  /// and name to open turn-by-turn directions directly in that external app.
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
  // This code renders the visual layout of the Navigation Selection screen
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    // Show a loading spinner while scanning for installed map apps
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
              // Large Navigation Icon at the top
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

              // Household Name and Address Display
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

              // ERROR STATE: Shown if no map apps are found on the device
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
              // SUCCESS STATE: Dynamically generates buttons for every installed map app
              else
                ..._installedMaps.map((map) {
                  final isGoogle = map.mapType == MapType.google;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _startNavigation(map),
                        // Uses the official icon provided by the map_launcher package
                        icon: Image.asset(map.icon, width: 24, height: 24),
                        label: Text(
                          'Open in ${map.mapName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Colors the button blue for Google Maps, green for others (like Waze)
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
