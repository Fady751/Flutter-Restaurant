import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
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
  final List<String> timeSlots = ["10:00", "10:30", "11:00", "11:30", "12:00"];

  Uint8List? selectedImageBytes;
  String? selectedCategory;
  List<String> categories = [];

  int tablesCount = 1;
  List<int> tableSeats = [1];

  double? lat;
  double? lng;

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
          ? ["Uncategorized", "Fast Food", "Fine Dining", "Cafe"]
          : result.docs.map((e) => e['name'] as String).toList();
    });
  }

  Future<void> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    var pos = await Geolocator.getCurrentPosition();
    setState(() {
      lat = pos.latitude;
      lng = pos.longitude;
    });
  }

  // Pick image from web or mobile
  Future<void> pickImage(ImageSource source) async {
    if (kIsWeb) {
      // =========== WEB ============
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
      // =========== MOBILE ============
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

  // Upload bytes to AWS S3
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

    print("Saving restaurant...");
    if (nameController.text.isEmpty || selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter name and select category")),
      );
      return;
    }
   print("Saving restaurant2...");
    if (selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image")),
      );
      return;
    }
    print("Saving restaurant3...");
    final imageUrl = await uploadImage(selectedImageBytes!);
    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to upload image")),
      );
      return;
    }
    print("Saving restaurant4...");
    final restaurantData = {
      "name": nameController.text,
      "description": descController.text,
      "categories": [selectedCategory],
      "tables": List.generate(
        tablesCount,
        (idx) => {"tableId": idx + 1, "seats": tableSeats[idx]},
      ),
      "timeSlots": timeSlots,
      "location": {"lat": lat, "lng": lng},
      "photoUrl": imageUrl,
    };
    print("Saving restaurant5...");
    await FirebaseFirestore.instance.collection("restaurants").add(restaurantData);
    print("Saving restaurant6...");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Restaurant Added Successfully")),
    );

    nameController.clear();
    descController.clear();
    setState(() {
      selectedImageBytes = null;
      selectedCategory = null;
      tablesCount = 1;
      tableSeats = [1];
    });

    Navigator.pop(context);  
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Restaurant")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
              color: Colors.grey[300],
              child: selectedImageBytes == null
                  ? const Icon(Icons.image, size: 50)
                  : Image.memory(selectedImageBytes!, fit: BoxFit.cover),
            ),

            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Description"),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categories
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => selectedCategory = v),
              decoration: const InputDecoration(labelText: "Category"),
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Tables: $tablesCount"),
                ElevatedButton(
                  onPressed: () {
                    if (tablesCount < 20) {
                      setState(() {
                        tablesCount++;
                        tableSeats.add(1);
                      });
                    }
                  },
                  child: const Text("+"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (tablesCount > 1) {
                      setState(() {
                        tablesCount--;
                        tableSeats.removeLast();
                      });
                    }
                  },
                  child: const Text("-"),
                ),
              ],
            ),

            Column(
              children: List.generate(tablesCount, (index) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Table ${index + 1}"),
                    DropdownButton<int>(
                      value: tableSeats[index],
                      items: List.generate(
                        6,
                        (i) => DropdownMenuItem(
                            value: i + 1, child: Text("${i + 1} seats")),
                      ),
                      onChanged: (v) {
                        setState(() => tableSeats[index] = v!);
                      },
                    ),
                  ],
                );
              }),
            ),

            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: timeSlots.map((e) => Text("• $e")).toList(),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
                await saveRestaurant(); 
                ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Restaurant Added Successfully")),
              );
              },
              child: const Text("Save Restaurant"),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              // style: ElevatedButton.styleFrom(
              //   padding: const EdgeInsets.symmetric(vertical: 16),
              //   textStyle: const TextStyle(fontSize: 18),
              // ),
              child: const Text("cancel!"),
            )
          ],
        ),
      ),
    );
  }
}
