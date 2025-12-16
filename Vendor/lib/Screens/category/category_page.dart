import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final TextEditingController _categoryController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addCategory() async {
    final name = _categoryController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a category name")),
      );
      return;
    }

    // Check if category already exists
    final existing = await _firestore
        .collection("categories")
        .where("name", isEqualTo: name)
        .get();

    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Category already exists")),
      );
      return;
    }

    await _firestore.collection("categories").add({
      "name": name,
      "createdAt": FieldValue.serverTimestamp(),
    });

    _categoryController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Category added successfully")),
    );
  }

  Future<void> deleteCategory(String docId, String categoryName) async {
    // Check if any restaurant uses this category
    final restaurants = await _firestore
        .collection("restaurants")
        .where("categories", arrayContains: categoryName)
        .get();

    if (restaurants.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Cannot delete: ${restaurants.docs.length} restaurant(s) use this category",
          ),
        ),
      );
      return;
    }

    await _firestore.collection("categories").doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Category deleted")),
    );
  }

  Future<void> editCategory(String docId, String currentName) async {
    final controller = TextEditingController(text: currentName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Category"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Category Name",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != currentName) {
      // Update category name
      await _firestore.collection("categories").doc(docId).update({
        "name": result,
      });

      // Update all restaurants that use this category
      final restaurants = await _firestore
          .collection("restaurants")
          .where("categories", arrayContains: currentName)
          .get();

      for (var doc in restaurants.docs) {
        final categories = List<String>.from(doc['categories']);
        final index = categories.indexOf(currentName);
        if (index != -1) {
          categories[index] = result;
          await doc.reference.update({"categories": categories});
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Category updated")),
      );
    }
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Food Categories"),
      ),
      body: Column(
        children: [
          // Add new category section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: "New Category",
                      hintText: "e.g., Fish Restaurant, Desserts",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: addCategory,
                  icon: const Icon(Icons.add),
                  label: const Text("Add"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Categories list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection("categories")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          "No categories yet",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Add your first food category above",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final categories = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: categories.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final doc = categories[index];
                    final name = doc['name'] as String;

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.restaurant_menu),
                        ),
                        title: Text(name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => editCategory(doc.id, name),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteCategory(doc.id, name),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
