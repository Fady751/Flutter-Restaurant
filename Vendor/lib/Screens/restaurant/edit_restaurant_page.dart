import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/s3_service.dart';

class EditRestaurantPage extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;

  const EditRestaurantPage({super.key, required this.id, required this.data});

  @override
  _EditRestaurantPageState createState() => _EditRestaurantPageState();
}

class _EditRestaurantPageState extends State<EditRestaurantPage> {
  late TextEditingController nameController;
  late TextEditingController descController;

  Uint8List? selectedImageBytes;
  String? imageUrl;

  String? selectedCategory;
  List<String> categories = [];

  int tablesCount = 1;
  List<int> tableSeats = [];

  double? lat;
  double? lng;

  List<String> timeSlots = [];

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.data["name"]);
    descController = TextEditingController(text: widget.data["description"]);

    selectedCategory = widget.data["categories"][0];
    imageUrl = widget.data["photoUrl"];

    final tables = widget.data["tables"];
    tablesCount = tables.length;
    tableSeats = List<int>.from(tables.map((e) => e["seats"]));

    lat = widget.data["location"]["lat"];
    lng = widget.data["location"]["lng"];

    timeSlots = List<String>.from(widget.data["timeSlots"]);

    loadCategories();
  }

  Future<void> loadCategories() async {
    final result =
        await FirebaseFirestore.instance.collection("categories").get();

    setState(() {
      categories = result.docs.isEmpty
          ? ["Uncategorized", "Fast Food", "Fine Dining", "Cafe"]
          : result.docs.map((e) => e['name'] as String).toList();
    });
  }

  Future<void> pickImage(ImageSource source) async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null) {
        setState(() {
          selectedImageBytes = result.files.first.bytes;
        });
      }
    } else {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: source);
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          selectedImageBytes = bytes;
        });
      }
    }
  }

  Future<String?> uploadImage(Uint8List bytes) async {
    try {
      final fileName =
          "restaurant_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final s3 = S3Service();
      return await s3.uploadImage(bytes, fileName);
    } catch (e) {
      print("Error uploading: $e");
      return null;
    }
  }

  Future<void> saveChanges() async {
    String newPhotoUrl = imageUrl!;

    if (selectedImageBytes != null) {
      final uploaded = await uploadImage(selectedImageBytes!);
      if (uploaded != null) newPhotoUrl = uploaded;
    }

    final data = {
      "name": nameController.text,
      "description": descController.text,
      "categories": [selectedCategory],
      "tables": List.generate(
        tablesCount,
        (i) => {"tableId": i + 1, "seats": tableSeats[i]},
      ),
      "timeSlots": timeSlots,
      "location": {"lat": lat, "lng": lng},
      "photoUrl": newPhotoUrl,
    };

    await FirebaseFirestore.instance
        .collection("restaurants")
        .doc(widget.id)
        .update(data);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Restaurant Updated Successfully")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Restaurant")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // IMAGE PICKER
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
              child: selectedImageBytes != null
                  ? Image.memory(selectedImageBytes!, fit: BoxFit.cover)
                  : Image.network(imageUrl!, fit: BoxFit.cover),
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

            // TABLES
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
                        (i) =>
                            DropdownMenuItem(value: i + 1, child: Text("${i + 1} seats")),
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
              onPressed: saveChanges,
              child: const Text("Save Changes"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            )
          ],
        ),
      ),
    );
  }
}
