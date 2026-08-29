import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/kala_kal_app_bar.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES THE LOCATION PICKER PAGE.
// IT ALLOWS USERS TO VISUALLY SELECT A PICKUP LOCATION ON AN INTERACTIVE MAP
// CENTERED ON LEGAZPI CITY, AND RETURNS THE CHOSEN COORDINATES.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  // THESE HOLD THE MAP CONTROLLER AND THE SELECTED GPS COORDINATES.
  final MapController _mapController = MapController();

  // LEGAZPI CITY CENTER COORDINATES.
  final LatLng _legazpiCenter = const LatLng(13.1391, 123.7437);
  LatLng _selectedLocation = const LatLng(13.1391, 123.7437);

  // ==========================================================================
  // 2. UI BUILD METHOD
  // ==========================================================================

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE LOCATION PICKER SCREEN.
  /// IT DISPLAYS AN INTERACTIVE OPENSTREETMAP, A CENTERED PIN INDICATOR,
  /// AND A CONFIRM BUTTON THAT RETURNS THE SELECTED LATLNG TO THE PREVIOUS SCREEN.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(
        title: 'Select Pickup Location',
        showBackButton: true,
      ),
      body: Stack(
        children: [
          // 1. THE INTERACTIVE MAP LAYER
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _legazpiCenter,
              initialZoom: 14.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  // UPDATE SELECTED LOCATION AS USER DRAGS THE MAP
                  setState(() {
                    _selectedLocation = position.center!;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kalakal.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40.0,
                    height: 40.0,
                    point: _selectedLocation,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. CENTER PIN OVERLAY (VISUAL INDICATOR)
          const Center(
            child: Icon(Icons.location_on, color: Colors.red, size: 50),
          ),

          // 3. CONFIRM BUTTON AT THE BOTTOM
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: ElevatedButton.icon(
              onPressed: () {
                // RETURN THE SELECTED LOCATION TO THE PREVIOUS SCREEN
                Navigator.pop(context, _selectedLocation);
              },
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text(
                'CONFIRM THIS LOCATION',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
