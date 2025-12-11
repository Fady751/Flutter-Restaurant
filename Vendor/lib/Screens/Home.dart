import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './restaurant/restaurant_page.dart';
import './restaurant/edit_restaurant_page.dart';
import './restaurant/restaurant_details_page.dart';
import '../services/s3_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // ---------------- Navigations ---------------- //

  void goToAddRestaurant() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddRestaurantPage()),
    ).then((_) {
      setState(() {});
    });
  }

  void goToEditRestaurant(DocumentSnapshot restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditRestaurantPage(
          id: restaurant.id,
          data: restaurant.data() as Map<String, dynamic>,
        ),
      ),
    );
  }

  void goToRestaurantDetails(DocumentSnapshot restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailsPage(restaurantId: restaurant.id),
      ),
    );
  }

  // ---------------- Delete ---------------- //

  Future<void> deleteRestaurant(String docId, String imageUrl) async {
    try {
      // 1. Extract file name from URL
      final fileName = imageUrl.split('/').last;

      // 2. Delete from S3
      final s3 = S3Service();
      await s3.deleteImage(fileName);

      // 3. Delete Firestore document
      await FirebaseFirestore.instance.collection("restaurants").doc(docId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Restaurant deleted")),
      );
    } catch (e) {
      print("Error deleting restaurant: $e");
    }
  }

  // ---------------- UI ---------------- //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Vendor Home"),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: goToAddRestaurant,
          )
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection("restaurants").snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No restaurants added yet."));
          }

          final restaurants = snapshot.data!.docs;

          return ListView.builder(
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              final restaurant = restaurants[index];
              final data = restaurant.data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  leading: data['photoUrl'] != null
                      ? Image.network(
                          data['photoUrl'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                      : Container(width: 60, height: 60, color: Colors.grey),

                  title: Text(data['name'] ?? "No Name"),

                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        goToEditRestaurant(restaurant);
                      } else if (value == 'delete') {
                        deleteRestaurant(restaurant.id, data['photoUrl']);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 10),
                            Text("Edit")
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 10),
                            Text("Delete")
                          ],
                        ),
                      ),
                    ],
                  ),

                  onTap: () => goToRestaurantDetails(restaurant),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
