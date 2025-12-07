import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';

class AddRestaurantPage extends StatefulWidget {
  const AddRestaurantPage({super.key});

  @override
  _AddRestaurantPageState createState() => _AddRestaurantPageState();
}

class _AddRestaurantPageState extends State<AddRestaurantPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final List<String> timeSlots = ["10:00", "10:30", "11:00", "11:30", "12:00"];

  File? selectedImage;
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

  Future<void> pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: source);
    if (img != null) {
      setState(() => selectedImage = File(img.path));
    }
  }

  // Upload image to Firebase Storage
  Future<String?> uploadImage(File image) async {
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref().child('restaurant_images/$fileName');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Image upload error: $e");
      return null;
    }
  }

  Future<void> saveRestaurant() async {
    if (nameController.text.isEmpty || selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter name and select category")),
      );
      return;
    }

    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image")),
      );
      return;
    }

    final imageUrl = await uploadImage(selectedImage!);
    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to upload image")),
      );
      return;
    }

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

    await FirebaseFirestore.instance.collection("restaurants").add(restaurantData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Restaurant Added Successfully")),
    );

    // Clear form
    nameController.clear();
    descController.clear();
    setState(() {
      selectedImage = null;
      selectedCategory = null;
      tablesCount = 1;
      tableSeats = [1];
    });
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
              child: selectedImage == null
                  ? const Icon(Icons.image, size: 50)
                  : Image.file(selectedImage!, fit: BoxFit.cover),
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
              onPressed: saveRestaurant,
              child: const Text("Save Restaurant"),
            ),
          ],
        ),
      ),
    );
  }
}
