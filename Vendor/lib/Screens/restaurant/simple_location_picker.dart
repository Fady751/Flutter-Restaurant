import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

class SimpleLocationPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const SimpleLocationPicker({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<SimpleLocationPicker> createState() => _SimpleLocationPickerState();
}

class _SimpleLocationPickerState extends State<SimpleLocationPicker> {
  double? _lat;
  double? _lng;
  String _address = "No location selected";
  bool _isLoading = false;
  bool _isGettingAddress = false;

  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _lat = widget.initialLat;
      _lng = widget.initialLng;
      _latController.text = widget.initialLat!.toStringAsFixed(6);
      _lngController.text = widget.initialLng!.toStringAsFixed(6);
      _getAddressFromCoordinates();
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError("Location services are disabled. Please enable them.");
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError("Location permission denied");
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError("Location permissions are permanently denied");
        setState(() => _isLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Location timeout');
        },
      );

      if (mounted) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
          _latController.text = position.latitude.toStringAsFixed(6);
          _lngController.text = position.longitude.toStringAsFixed(6);
          _isLoading = false;
        });
        _getAddressFromCoordinates();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError("Error getting location: $e");
      }
    }
  }

  Future<void> _getAddressFromCoordinates() async {
    if (_lat == null || _lng == null) return;

    setState(() => _isGettingAddress = true);

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _lat!,
        _lng!,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => <Placemark>[],
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        setState(() {
          _address = [
            place.street,
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((e) => e != null && e.isNotEmpty).join(', ');
          _isGettingAddress = false;
        });
      } else {
        setState(() {
          _address = "Address not found";
          _isGettingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _address = "Could not get address";
          _isGettingAddress = false;
        });
      }
    }
  }

  void _updateFromTextFields() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat != null && lng != null) {
      if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        setState(() {
          _lat = lat;
          _lng = lng;
        });
        _getAddressFromCoordinates();
      } else {
        _showError("Invalid coordinates. Lat: -90 to 90, Lng: -180 to 180");
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _confirmLocation() {
    if (_lat != null && _lng != null) {
      Navigator.pop(context, {
        'lat': _lat,
        'lng': _lng,
        'address': _address,
      });
    } else {
      _showError("Please select a location first");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Location"),
        actions: [
          if (_lat != null && _lng != null)
            TextButton(
              onPressed: _confirmLocation,
              child: const Text(
                "Confirm",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Location Button
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.my_location,
                      size: 48,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Use Current Location",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Automatically detect your current GPS location",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _getCurrentLocation,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.gps_fixed),
                        label: Text(_isLoading ? "Getting Location..." : "Get Current Location"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Divider with OR
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("OR", style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: 16),

            // Manual Entry
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Enter Coordinates Manually",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Latitude",
                        hintText: "e.g., 30.0444",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.north),
                      ),
                      onSubmitted: (_) => _updateFromTextFields(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Longitude",
                        hintText: "e.g., 31.2357",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.east),
                      ),
                      onSubmitted: (_) => _updateFromTextFields(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _updateFromTextFields,
                        icon: const Icon(Icons.check),
                        label: const Text("Apply Coordinates"),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Selected Location Display
            if (_lat != null && _lng != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          const Text(
                            "Selected Location",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Latitude",
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                Text(
                                  _lat!.toStringAsFixed(6),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Longitude",
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                Text(
                                  _lng!.toStringAsFixed(6),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Address",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      _isGettingAddress
                          ? const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text("Getting address..."),
                              ],
                            )
                          : Text(
                              _address,
                              style: const TextStyle(fontSize: 14),
                            ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Confirm Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_lat != null && _lng != null) ? _confirmLocation : null,
                icon: const Icon(Icons.check_circle),
                label: const Text(
                  "Confirm Location",
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
