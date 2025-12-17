import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/s3_service.dart';

class AddRestaurantPage extends StatefulWidget {
  const AddRestaurantPage({super.key});

  @override
  _AddRestaurantPageState createState() => _AddRestaurantPageState();
}

class _AddRestaurantPageState extends State<AddRestaurantPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  
  // 5 constant time slots as per requirement
  final List<String> timeSlots = ["10:00", "10:30", "11:00", "11:30", "12:00"];

  Uint8List? selectedImageBytes;
  String? selectedCategory;
  List<String> categories = [];

  int tablesCount = 1;
  List<int> tableSeats = [1]; // Max 6 seats per table

  double? lat;
  double? lng;
  String? locationAddress;
  bool _isGettingLocation = false;
  String? _locationError;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    loadCategories();
    _getAutoLocation();
  }

  Future<void> loadCategories() async {
    final result = await FirebaseFirestore.instance.collection("categories").get();
    setState(() {
      categories = result.docs.isEmpty
          ? ["Fish Restaurant", "Desserts", "Fast Food", "Fine Dining", "Cafe", "Pizza", "Asian", "Italian"]
          : result.docs.map((e) => e['name'] as String).toList();
    });
  }

  Future<void> _getAutoLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = "Location services are disabled. Please enable them.";
          _isGettingLocation = false;
        });
        return;
      }

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = "Location permission denied. Please grant permission.";
            _isGettingLocation = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = "Location permission permanently denied. Please enable in settings.";
          _isGettingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Location request timed out');
        },
      );

      // Get address from coordinates using geocoding
      String address = "Location obtained";
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 10));

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          address = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((s) => s != null && s.isNotEmpty).join(', ');
        }
      } catch (e) {
        print("Geocoding error: $e");
        address = "Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}";
      }

      if (mounted) {
        setState(() {
          lat = position.latitude;
          lng = position.longitude;
          locationAddress = address;
          _isGettingLocation = false;
          _locationError = null;
        });
      }
    } catch (e) {
      print("Error getting location: $e");
      if (mounted) {
        setState(() {
          _locationError = "Failed to get location: ${e.toString()}";
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<void> pickImage(ImageSource source) async {
    if (kIsWeb) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null) {
        setState(() {
          selectedImageBytes = result.files.first.bytes;
        });
      }

    } else {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          selectedImageBytes = bytes;
        });
      }
    }
  }

  Future<String?> uploadImage(Uint8List bytes) async {
    try {
      final fileName = "restaurant_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final s3Service = S3Service();
      return await s3Service.uploadImage(bytes, fileName);
    } catch (e) {
      print("Image upload error: $e");
      return null;
    }
  }

  Future<void> saveRestaurant() async {
    if (_isSaving) return;

    if (nameController.text.isEmpty || selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter name and select category")),
      );
      return;
    }

    if (selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image")),
      );
      return;
    }

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a location")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final imageUrl = await uploadImage(selectedImageBytes!);
      if (imageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload image")),
        );
        setState(() => _isSaving = false);
        return;
      }

      final restaurantData = {
        "name": nameController.text,
        "description": descController.text,
        "categories": [selectedCategory],
        "tables": List.generate(
          tablesCount,
          (idx) => {
            "tableId": idx + 1,
            "seats": tableSeats[idx],
            "reservations": [], // Initialize empty reservations
          },
        ),
        "timeSlots": timeSlots,
        "location": {
          "lat": lat,
          "lng": lng,
          "address": locationAddress ?? "",
        },
        "photoUrl": imageUrl,
        "createdAt": FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection("restaurants").add(restaurantData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Restaurant Added Successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      print("Error saving restaurant: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Restaurant")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE PICKER SECTION
            const Text("Restaurant Image", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: () => pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                ),
                ElevatedButton.icon(
                  onPressed: () => pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Gallery"),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: selectedImageBytes == null
                  ? const Center(child: Icon(Icons.image, size: 50, color: Colors.grey))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(selectedImageBytes!, fit: BoxFit.cover),
                    ),
            ),

            const SizedBox(height: 20),
            
            // BASIC INFO SECTION
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Restaurant Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // CATEGORY DROPDOWN
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categories
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => selectedCategory = v),
              decoration: const InputDecoration(
                labelText: "Food Category",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // LOCATION SECTION - Automatic GPS Location
            const Text("Sales Point Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              "Location is automatically obtained from your device GPS",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (_isGettingLocation)
                      const Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text("Getting your location..."),
                        ],
                      )
                    else if (_locationError != null)
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _locationError!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _getAutoLocation,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Try Again"),
                          ),
                        ],
                      )
                    else if (lat != null && lng != null)
                      Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.check_circle, color: Colors.green),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Location Obtained",
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      locationAddress ?? "Address not available",
                                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Lat: ${lat!.toStringAsFixed(6)}, Lng: ${lng!.toStringAsFixed(6)}",
                                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _getAutoLocation,
                                icon: const Icon(Icons.refresh),
                                tooltip: "Refresh Location",
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.location_off, color: Colors.grey),
                          const SizedBox(width: 12),
                          const Expanded(child: Text("Location not set")),
                          ElevatedButton.icon(
                            onPressed: _getAutoLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text("Get Location"),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // TABLES SECTION
            const Text("Tables Configuration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Number of Tables: $tablesCount", style: const TextStyle(fontSize: 16)),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (tablesCount > 1) {
                                  setState(() {
                                    tablesCount--;
                                    tableSeats.removeLast();
                                  });
                                }
                              },
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                            ),
                            IconButton(
                              onPressed: () {
                                if (tablesCount < 20) {
                                  setState(() {
                                    tablesCount++;
                                    tableSeats.add(1);
                                  });
                                }
                              },
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text("Seats per table (max 6):", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    ...List.generate(tablesCount, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Table ${index + 1}"),
                            DropdownButton<int>(
                              value: tableSeats[index],
                              items: List.generate(
                                6,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text("${i + 1} seats"),
                                ),
                              ),
                              onChanged: (v) {
                                setState(() => tableSeats[index] = v!);
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // TIME SLOTS SECTION
            const Text("Time Slots (5 slots per day)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: timeSlots.map((slot) => Chip(
                    avatar: const Icon(Icons.access_time, size: 18),
                    label: Text(slot),
                  )).toList(),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : saveRestaurant,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Restaurant", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Cancel", style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
