import 'dart:convert'; // For jsonEncode
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './restaurant/restaurant_page.dart'; // Make sure this exists

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  void goToAddRestaurant() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddRestaurantPage()),
    ).then((_) {
      setState(() {});
    });
  }

  void goToRestaurantDetails(DocumentSnapshot restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailsPage(restaurantId: restaurant.id),
      ),
    );
  }

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

          final restaurantDataList = restaurants
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
          // print("restaurants: ${jsonEncode(restaurantDataList)}");

          return ListView.builder(
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              final restaurant = restaurants[index];
              final data = restaurant.data() as Map<String, dynamic>;

              print("data['categories']: ${data['categories']}");

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
                  // subtitle: data['categories'] != null &&
                  //         (data['categories'] as List).isNotEmpty
                  //     ? Text(data['categories'][0])
                  //     : Text("No Category"),
                  trailing: Icon(Icons.arrow_forward_ios),
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

class RestaurantDetailsPage extends StatelessWidget {
  final String restaurantId;

  const RestaurantDetailsPage({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Restaurant Details")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("restaurants")
            .doc(restaurantId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text("Restaurant not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final tables = data['tables'] as List<dynamic>? ?? [];
          final timeSlots = data['timeSlots'] as List<dynamic>? ?? [];
          final categories = data['categories'] as List<dynamic>? ?? [];
          final location = data['location'] as Map<String, dynamic>?;

          print("data['photoUrl']: ${data['photoUrl']}");

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo
                if (data['photoUrl'] != null)
                  Center(
                    child: Image.network(
                      data['photoUrl'],
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                SizedBox(height: 16),

                // Name
                Text(
                  "Name: ${data['name'] ?? 'No name'}",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),

                // Description
                Text(
                  "Description: ${data['description'] ?? 'No description'}",
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),

                // Categories
                Text(
                  "Categories: ${categories.isNotEmpty ? categories.join(', ') : 'No category'}",
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),

                // Location
                if (location != null)
                  Text(
                    "Location: Lat ${location['lat']}, Lng ${location['lng']}",
                    style: TextStyle(fontSize: 16),
                  ),
                SizedBox(height: 16),

                // Time slots
                Text(
                  "Time Slots:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (timeSlots.isNotEmpty)
                  ...timeSlots.map((slot) => Text("- $slot")).toList()
                else
                  Text("No time slots available"),
                SizedBox(height: 16),

                // Tables & bookings
                Text(
                  "Tables & Bookings:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (tables.isNotEmpty)
                  ...tables.map((table) {
                    final t = table as Map<String, dynamic>;
                    final reservations = t['reservations'] as List<dynamic>? ?? [];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text("Table ${t['tableId']} - Seats: ${t['seats']}"),
                        subtitle: reservations.isNotEmpty
                            ? Text("Booked: ${reservations.join(', ')}")
                            : Text("No bookings"),
                      ),
                    );
                  }).toList()
                else
                  Text("No tables available"),
              ],
            ),
          );
        },
      ),
    );
  }
}
