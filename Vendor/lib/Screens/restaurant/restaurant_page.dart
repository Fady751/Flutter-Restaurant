import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/s3_service.dart';
import 'simple_location_picker.dart';

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

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    loadCategories();
    getCurrentLocation();
  }

  Future<void> loadCategories() async {
    final result = await FirebaseFirestore.instance.collection("categories").get();
    setState(() {
      categories = result.docs.isEmpty
          ? ["Fish Restaurant", "Desserts", "Fast Food", "Fine Dining", "Cafe", "Pizza", "Asian", "Italian"]
          : result.docs.map((e) => e['name'] as String).toList();
    });
  }

  Future<void> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Don't block - just skip getting location
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // Add timeout to prevent freezing
      var pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Location timeout');
        },
      );
      
      if (mounted) {
        setState(() {
          lat = pos.latitude;
          lng = pos.longitude;
          locationAddress = "Current Location";
        });
      }
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> openMapPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SimpleLocationPicker(initialLat: lat, initialLng: lng),
      ),
    );

    if (result != null) {
      setState(() {
        lat = result['lat'];
        lng = result['lng'];
        locationAddress = result['address'];
      });
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

            // LOCATION SECTION
            const Text("Sales Point Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on, color: Colors.red),
                title: Text(locationAddress ?? "Tap to select location"),
                subtitle: lat != null && lng != null
                    ? Text("Lat: ${lat!.toStringAsFixed(4)}, Lng: ${lng!.toStringAsFixed(4)}")
                    : const Text("No location selected"),
                trailing: const Icon(Icons.map),
                onTap: openMapPicker,
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
