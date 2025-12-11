import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
