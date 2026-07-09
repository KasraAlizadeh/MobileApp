import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Fetches the current GPS position of the user.
  ///
  /// Permissions should be checked and requested at the UI layer (e.g., HomePage)
  /// before calling this method to ensure a smooth user experience.
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if system location services are enabled on the device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Verify app permission levels
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      // Fetch position with a safe 10-second timeout limit to prevent infinite waiting hooks
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      print('LocationService Error: $e');
      return null;
    }
  }
}